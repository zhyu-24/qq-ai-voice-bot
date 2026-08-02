[CmdletBinding()]
param(
    [int]$StartupDelaySeconds = -1,
    [switch]$SkipGptSoVits,
    [switch]$NoAstrBotRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeConfigPath = Join-Path $projectRoot 'config\local-runtime.psd1'
$logsPath = Join-Path $projectRoot 'logs'
$statePath = Join-Path $projectRoot 'state'
$composePath = Join-Path $projectRoot 'compose.yml'
$dockerGuidePath = Join-Path $projectRoot 'docs\DOCKER_WSL2_GUIDE.md'

if (-not (Test-Path -LiteralPath $runtimeConfigPath)) {
    throw "Missing local runtime config: $runtimeConfigPath. Copy config\local-runtime.psd1.example to local-runtime.psd1 first."
}
if (-not (Test-Path -LiteralPath $composePath)) {
    throw "Missing compose file: $composePath"
}

$config = Import-PowerShellDataFile -Path $runtimeConfigPath
[System.IO.Directory]::CreateDirectory($logsPath) | Out-Null
[System.IO.Directory]::CreateDirectory($statePath) | Out-Null

function Get-Setting {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue
    )

    if ($config.ContainsKey($Name) -and $null -ne $config[$Name] -and -not [string]::IsNullOrWhiteSpace([string]$config[$Name])) {
        return $config[$Name]
    }
    return $DefaultValue
}

function Test-DockerEngine {
    try {
        $serverVersion = & docker version --format '{{.Server.Version}}' 2>$null
        return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]($serverVersion | Select-Object -First 1)))
    }
    catch {
        return $false
    }
}

function Get-DockerDesktopExecutable {
    $candidates = New-Object System.Collections.Generic.List[string]
    $configuredPath = [string](Get-Setting -Name 'DockerDesktopPath' -DefaultValue '')
    if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
        $candidates.Add($configuredPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $candidates.Add((Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'))
    }
    $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidates.Add((Join-Path $programFilesX86 'Docker\Docker\Docker Desktop.exe'))
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $null
}

function Wait-Until {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Condition,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [string]$WaitingMessage,
        [int]$IntervalSeconds = 2
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return $true
        }
        if (-not [string]::IsNullOrWhiteSpace($WaitingMessage)) {
            Write-Host $WaitingMessage
        }
        Start-Sleep -Seconds $IntervalSeconds
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Test-GsvApi {
    param([Parameter(Mandatory = $true)][int]$Port)

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/openapi.json" -TimeoutSec 4
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

function Resolve-GsvPath {
    param(
        [Parameter(Mandatory = $true)][string]$PathValue,
        [Parameter(Mandatory = $true)][string]$GsvRoot
    )

    if (Test-Path -LiteralPath $PathValue) {
        return (Resolve-Path -LiteralPath $PathValue).Path
    }

    $relativeCandidate = Join-Path $GsvRoot $PathValue
    if (Test-Path -LiteralPath $relativeCandidate) {
        return (Resolve-Path -LiteralPath $relativeCandidate).Path
    }

    return $null
}

function Start-GsvApi {
    param(
        [Parameter(Mandatory = $true)][string]$GsvRoot,
        [Parameter(Mandatory = $true)][string]$BindAddress,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][int]$ReadyTimeoutSeconds
    )

    if (Test-GsvApi -Port $Port) {
        Write-Host "[OK] GPT-SoVITS API is already listening on port $Port."
        return
    }

    $pythonPath = Join-Path $GsvRoot 'runtime\python.exe'
    $apiPath = Join-Path $GsvRoot 'api_v2.py'
    $yamlPath = Join-Path $GsvRoot 'GPT_SoVITS\configs\tts_infer.yaml'
    foreach ($requiredPath in @($pythonPath, $apiPath, $yamlPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "GPT-SoVITS file not found: $requiredPath"
        }
    }

    $stdoutPath = Join-Path $logsPath 'gpt-sovits-api.out.log'
    $stderrPath = Join-Path $logsPath 'gpt-sovits-api.err.log'
    $oldPath = $env:Path
    try {
        $env:Path = "$(Join-Path $GsvRoot 'runtime');$oldPath"
        $arguments = @('-I', $apiPath, '-a', $BindAddress, '-p', [string]$Port, '-c', $yamlPath)
        $process = Start-Process -FilePath $pythonPath -ArgumentList $arguments -WorkingDirectory $GsvRoot -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
        [System.IO.File]::WriteAllText((Join-Path $statePath 'gpt-sovits-api.pid'), [string]$process.Id)
    }
    finally {
        $env:Path = $oldPath
    }

    $ready = Wait-Until -TimeoutSeconds $ReadyTimeoutSeconds -WaitingMessage "Waiting for GPT-SoVITS API on port $Port..." -Condition { Test-GsvApi -Port $Port }
    if (-not $ready) {
        throw "GPT-SoVITS did not become ready. See $stdoutPath and $stderrPath."
    }

    Write-Host "[OK] GPT-SoVITS API is ready on port $Port."
}

function Preload-GsvWeights {
    param(
        [Parameter(Mandatory = $true)][string]$GsvRoot,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $astrConfigPath = Join-Path $projectRoot 'data\cmd_config.json'
    if (-not (Test-Path -LiteralPath $astrConfigPath)) {
        Write-Warning "AstrBot configuration has not been created yet; skipping custom-weight preload."
        return
    }

    try {
        $astrConfig = Get-Content -LiteralPath $astrConfigPath -Raw | ConvertFrom-Json
        $ttsSettings = $astrConfig.provider_tts_settings
        if ($null -eq $ttsSettings -or -not $ttsSettings.enable -or [string]::IsNullOrWhiteSpace([string]$ttsSettings.provider_id)) {
            Write-Host "[INFO] AstrBot TTS is not enabled; no GPT-SoVITS weights were preloaded."
            return
        }

        $provider = @($astrConfig.provider | Where-Object { $_.id -eq $ttsSettings.provider_id }) | Select-Object -First 1
        if ($null -eq $provider -or $provider.type -ne 'gsv_tts_selfhost') {
            Write-Host "[INFO] The current default TTS provider is not local GPT-SoVITS; no custom weights were preloaded."
            return
        }

        $weightsToLoad = @(
            @{ Endpoint = 'set_gpt_weights'; Value = [string]$provider.gpt_weights_path; Label = 'GPT' },
            @{ Endpoint = 'set_sovits_weights'; Value = [string]$provider.sovits_weights_path; Label = 'SoVITS' }
        )

        foreach ($weight in $weightsToLoad) {
            if ([string]::IsNullOrWhiteSpace($weight.Value)) {
                Write-Warning "No $($weight.Label) weight path is configured in AstrBot."
                continue
            }

            $resolvedPath = Resolve-GsvPath -PathValue $weight.Value -GsvRoot $GsvRoot
            if ($null -eq $resolvedPath) {
                Write-Warning "Configured $($weight.Label) weight was not found, so it was not preloaded."
                continue
            }

            $encodedPath = [uri]::EscapeDataString($resolvedPath)
            Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/$($weight.Endpoint)?weights_path=$encodedPath" -TimeoutSec 180 | Out-Null
            Write-Host "[OK] Preloaded $($weight.Label) voice weights."
        }
    }
    catch {
        Write-Warning "Could not preload custom TTS weights. AstrBot will still start. Details: $($_.Exception.Message)"
    }
}

$delay = $StartupDelaySeconds
if ($delay -lt 0) {
    $delay = [int](Get-Setting -Name 'DefaultStartupDelaySeconds' -DefaultValue 45)
}
if ($delay -gt 0) {
    Write-Host "Waiting $delay seconds for VPN, GPU driver and Docker Desktop..."
    Start-Sleep -Seconds $delay
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker command was not found. First complete the WSL 2 / virtualization prerequisite, then install Docker Desktop. See: $dockerGuidePath"
}

if (-not (Test-DockerEngine)) {
    $dockerDesktop = Get-DockerDesktopExecutable
    if ($null -eq $dockerDesktop) {
        throw "Docker Engine is unavailable and Docker Desktop.exe could not be found. Install Docker Desktop after completing the WSL 2 / virtualization prerequisite. See: $dockerGuidePath"
    }
    Write-Host 'Starting Docker Desktop...'
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
    $dockerTimeout = [int](Get-Setting -Name 'DockerReadyTimeoutSeconds' -DefaultValue 240)
    $dockerReady = Wait-Until -TimeoutSeconds $dockerTimeout -WaitingMessage 'Waiting for Docker Engine...' -Condition { Test-DockerEngine }
    if (-not $dockerReady) {
        throw "Docker Engine did not become ready in time. If Docker Desktop displays the Virtualization support not detected message, enable CPU virtualization and install/update WSL 2. See: $dockerGuidePath"
    }
}
Write-Host '[OK] Docker Engine is ready.'

$gsvRoot = [string](Get-Setting -Name 'GsvRoot' -DefaultValue '')
$gsvPort = [int](Get-Setting -Name 'GsvPort' -DefaultValue 9880)
if (-not $SkipGptSoVits -and -not [string]::IsNullOrWhiteSpace($gsvRoot)) {
    $gsvBindAddress = [string](Get-Setting -Name 'GsvBindAddress' -DefaultValue '0.0.0.0')
    $gsvTimeout = [int](Get-Setting -Name 'GsvReadyTimeoutSeconds' -DefaultValue 180)
    Start-GsvApi -GsvRoot $gsvRoot -BindAddress $gsvBindAddress -Port $gsvPort -ReadyTimeoutSeconds $gsvTimeout
    Preload-GsvWeights -GsvRoot $gsvRoot -Port $gsvPort
}
elseif (-not $SkipGptSoVits) {
    Write-Warning 'GsvRoot is blank. Starting AstrBot without a local GPT-SoVITS service.'
}

$wasAstrBotRunning = $false
try {
    $containerId = (& docker compose -f $composePath ps -q astrbot 2>$null | Select-Object -First 1)
    if (-not [string]::IsNullOrWhiteSpace([string]$containerId)) {
        $containerState = (& docker inspect -f '{{.State.Running}}' $containerId 2>$null | Select-Object -First 1)
        $wasAstrBotRunning = ([string]$containerState).Trim() -eq 'true'
    }
}
catch {
    $wasAstrBotRunning = $false
}

Write-Host 'Starting AstrBot...'
& docker compose -f $composePath up -d
if ($LASTEXITCODE -ne 0) {
    throw 'docker compose up failed.'
}

if ($wasAstrBotRunning -and -not $NoAstrBotRestart) {
    Write-Host 'Restarting the existing AstrBot container so its TTS provider reconnects cleanly...'
    & docker compose -f $composePath restart astrbot
    if ($LASTEXITCODE -ne 0) {
        throw 'AstrBot restart failed.'
    }
}

Write-Host ''
Write-Host '[DONE] Local QQ AI voice bot is running.'
Write-Host 'AstrBot dashboard: http://localhost:6185'
Write-Host "GPT-SoVITS API: http://127.0.0.1:$gsvPort/docs"
Write-Host "Logs: $logsPath"

[CmdletBinding()]
param(
    [switch]$CheckVpnEgress,
    [switch]$ConfigOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$projectRoot = Split-Path -Parent $PSScriptRoot
$cmdConfigHelperPath = Join-Path $PSScriptRoot 'CmdConfig.Common.ps1'
if (-not (Test-Path -LiteralPath $cmdConfigHelperPath -PathType Leaf)) {
    Write-Host '[FAIL] AstrBot TTS configuration The safe configuration helper is missing.'
    exit 1
}
. $cmdConfigHelperPath

$configPath = Join-Path $projectRoot 'config\local-runtime.psd1'
$composePath = Join-Path $projectRoot 'compose.yml'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Import-PowerShellDataFile -Path $configPath
}
else {
    Write-Host '[FAIL] This folder has no local runtime config (config\local-runtime.psd1).'
    Write-Host '[HINT] This is usually the creator/source folder. Run status or daily start from the actual runtime folder.'
    exit 1
}

$script:statusFailed = $false

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Detail = ''
    )

    if (-not $Passed) {
        $script:statusFailed = $true
    }
    $state = if ($Passed) { 'OK  ' } else { 'FAIL' }
    Write-Host "[$state] $Label $Detail"
}

function Get-Setting {
    param([string]$Name, $DefaultValue)

    if ($null -ne $config -and $config.ContainsKey($Name) -and $null -ne $config[$Name] -and -not [string]::IsNullOrWhiteSpace([string]$config[$Name])) {
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

function Test-GsvApi {
    param([int]$Port)

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/openapi.json" -TimeoutSec 4
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

function Resolve-GsvPath {
    param([string]$PathValue, [string]$GsvRoot)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }
    if (Test-Path -LiteralPath $PathValue) {
        return (Resolve-Path -LiteralPath $PathValue).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($GsvRoot)) {
        $candidate = Join-Path $GsvRoot $PathValue
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

$gsvPort = [int](Get-Setting -Name 'GsvPort' -DefaultValue 9880)
$gsvRoot = [string](Get-Setting -Name 'GsvRoot' -DefaultValue '')
if (-not $ConfigOnly) {
    $dockerAvailable = Get-Command docker -ErrorAction SilentlyContinue
    $dockerReady = $false
    if ($null -ne $dockerAvailable) {
        $dockerReady = Test-DockerEngine
    }
    Write-Check -Label 'Docker Engine' -Passed $dockerReady
    if (-not $dockerReady) {
        Write-Host '[HINT] Docker is not ready. On a new PC, read docs\DOCKER_WSL2_GUIDE.md. If Docker Desktop says "Virtualization support not detected", enable CPU virtualization and install/update WSL 2; Docker sign-in will not fix it.'
    }

    $astrBotRunning = $false
    if ($dockerReady -and (Test-Path -LiteralPath $composePath)) {
        try {
            $containerId = (& docker compose -f $composePath ps -q astrbot 2>$null | Select-Object -First 1)
            if (-not [string]::IsNullOrWhiteSpace([string]$containerId)) {
                $containerState = (& docker inspect -f '{{.State.Running}}' $containerId 2>$null | Select-Object -First 1)
                $astrBotRunning = ([string]$containerState).Trim() -eq 'true'
            }
        }
        catch {
            $astrBotRunning = $false
        }
    }
    Write-Check -Label 'AstrBot container' -Passed $astrBotRunning

    $gsvReady = Test-GsvApi -Port $gsvPort
    Write-Check -Label "GPT-SoVITS API :$gsvPort" -Passed $gsvReady
}

$astrConfigPath = Join-Path $projectRoot 'data\cmd_config.json'
if (Test-Path -LiteralPath $astrConfigPath) {
    try {
        $astrConfig = Read-StrictUtf8Json -Path $astrConfigPath -Label 'AstrBot configuration'
        $tts = $astrConfig.provider_tts_settings
        $ttsEnabled = $null -ne $tts -and $tts.enable -and -not [string]::IsNullOrWhiteSpace([string]$tts.provider_id)
        $dualOutput = $ttsEnabled -and $tts.dual_output
        $providerDetail = if ($ttsEnabled) { "provider=$($tts.provider_id)" } else { '' }
        Write-Check -Label 'AstrBot TTS enabled' -Passed $ttsEnabled -Detail $providerDetail
        Write-Check -Label 'Text plus voice output' -Passed $dualOutput

        if ($ttsEnabled) {
            $provider = @($astrConfig.provider | Where-Object { $_.id -eq $tts.provider_id }) | Select-Object -First 1
            if ($null -ne $provider -and $provider.type -eq 'gsv_tts_selfhost') {
                $gptPath = Resolve-GsvPath -PathValue ([string]$provider.gpt_weights_path) -GsvRoot $gsvRoot
                $sovitsPath = Resolve-GsvPath -PathValue ([string]$provider.sovits_weights_path) -GsvRoot $gsvRoot
                Write-Check -Label 'Configured GPT voice weights' -Passed ($null -ne $gptPath)
                Write-Check -Label 'Configured SoVITS voice weights' -Passed ($null -ne $sovitsPath)
            }
        }
    }
    catch {
        $statusFailed = $true
        Write-Check -Label 'AstrBot TTS configuration' -Passed $false -Detail 'The configuration could not be safely read as UTF-8 JSON. Its contents were not printed.'
    }
}
else {
    $statusFailed = $true
    Write-Check -Label 'AstrBot TTS configuration' -Passed $false -Detail 'AstrBot has not created data\cmd_config.json yet.'
}

if (-not $ConfigOnly) {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($null -ne $nvidiaSmi) {
        $gpuInfo = & nvidia-smi --query-gpu=name,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0 -and $gpuInfo) {
            Write-Host "[INFO] GPU: $($gpuInfo -join '; ')"
        }
    }
    else {
        Write-Host '[INFO] nvidia-smi was not found. This is normal for text-only or cloud-TTS use.'
    }
}

if ($CheckVpnEgress -and -not $ConfigOnly) {
    try {
        $ipReply = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 10
        $actualIp = [string]$ipReply.ip
        $expectedIp = [string](Get-Setting -Name 'ExpectedVpnPublicIp' -DefaultValue '')
        if ([string]::IsNullOrWhiteSpace($expectedIp)) {
            Write-Host "[INFO] Current public egress IP: $actualIp"
        }
        else {
            Write-Check -Label 'VPN/IP whitelist egress' -Passed ($actualIp -eq $expectedIp) -Detail "current=$actualIp"
        }
    }
    catch {
        Write-Host "[WARN] Could not check the public egress IP: $($_.Exception.Message)"
    }
}

if (-not $ConfigOnly) {
    Write-Host ''
    Write-Host 'Dashboard: http://localhost:6185'
    Write-Host "GPT-SoVITS docs: http://127.0.0.1:$gsvPort/docs"
}
if ($statusFailed) {
    exit 1
}

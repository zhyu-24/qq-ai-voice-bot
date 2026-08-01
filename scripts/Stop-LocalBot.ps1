[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$KeepAstrBotRunning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'config\local-runtime.psd1'
$composePath = Join-Path $projectRoot 'compose.yml'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Import-PowerShellDataFile -Path $configPath
}

function Get-Setting {
    param([string]$Name, $DefaultValue)

    if ($null -ne $config -and $config.ContainsKey($Name) -and $null -ne $config[$Name] -and -not [string]::IsNullOrWhiteSpace([string]$config[$Name])) {
        return $config[$Name]
    }
    return $DefaultValue
}

function Test-GsvApi {
    param([int]$Port)

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/openapi.json" -TimeoutSec 3
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

if (-not $KeepAstrBotRunning -and (Get-Command docker -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $composePath)) {
    if ($PSCmdlet.ShouldProcess('AstrBot container', 'Stop')) {
        & docker compose -f $composePath stop astrbot
        if ($LASTEXITCODE -eq 0) {
            Write-Host '[OK] AstrBot container stopped.'
        }
        else {
            Write-Warning 'AstrBot container stop returned an error.'
        }
    }
}

$gsvPort = [int](Get-Setting -Name 'GsvPort' -DefaultValue 9880)
$gsvRoot = [string](Get-Setting -Name 'GsvRoot' -DefaultValue '')
if (Test-GsvApi -Port $gsvPort) {
    if ($PSCmdlet.ShouldProcess("GPT-SoVITS API on port $gsvPort", 'Request graceful shutdown')) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$gsvPort/control?command=exit" -TimeoutSec 5 | Out-Null
            Start-Sleep -Seconds 3
        }
        catch {
            Write-Warning "GPT-SoVITS graceful shutdown request failed: $($_.Exception.Message)"
        }
    }
}

if ((Test-GsvApi -Port $gsvPort) -and -not [string]::IsNullOrWhiteSpace($gsvRoot)) {
    $apiPath = Join-Path $gsvRoot 'api_v2.py'
    $matches = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $null -ne $_.CommandLine -and $_.CommandLine.IndexOf($apiPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    })

    foreach ($processInfo in $matches) {
        if ($PSCmdlet.ShouldProcess("GPT-SoVITS process $($processInfo.ProcessId)", 'Stop')) {
            Stop-Process -Id $processInfo.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Stopped GPT-SoVITS process $($processInfo.ProcessId)."
        }
    }
}

$pidPath = Join-Path $projectRoot 'state\gpt-sovits-api.pid'
if (Test-Path -LiteralPath $pidPath) {
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
}

Write-Host 'Docker Desktop was left running intentionally.'

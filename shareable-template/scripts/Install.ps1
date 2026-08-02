[CmdletBinding()]
param(
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeExample = Join-Path $projectRoot 'config\local-runtime.psd1.example'
$runtimeConfig = Join-Path $projectRoot 'config\local-runtime.psd1'
$startScript = Join-Path $PSScriptRoot 'Start-LocalBot.ps1'

if (-not (Test-Path -LiteralPath $runtimeConfig)) {
    Copy-Item -LiteralPath $runtimeExample -Destination $runtimeConfig
    Write-Host '[OK] Created local runtime configuration. It is ignored by Git.'
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. First complete docs\DOCKER_WSL2_GUIDE.md (CPU virtualization + WSL 2), then install and open Docker Desktop before running Install.cmd again.'
}

& $startScript -StartupDelaySeconds 0

Write-Host ''
Write-Host '[DONE] AstrBot has been started.'
Write-Host 'Next: open the dashboard and configure your own QQ Official Bot, model provider, and TTS provider.'
Write-Host 'Dashboard: http://localhost:6185'

if (-not $NoBrowser) {
    Start-Process 'http://localhost:6185'
}

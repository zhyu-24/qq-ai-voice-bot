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
    Write-Host '[OK] Created local runtime configuration. It is not included when exporting the shareable package.'
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. Install Docker Desktop, open it once, then try again.'
}

& $startScript -StartupDelaySeconds 0

Write-Host ''
Write-Host '[DONE] AstrBot has been started.'
Write-Host 'Next: use Setup-Center.cmd to configure your QQ Official Bot, model provider, and optional local voice.'
Write-Host 'Dashboard: http://localhost:6185'

if (-not $NoBrowser) {
    Start-Process 'http://localhost:6185'
}

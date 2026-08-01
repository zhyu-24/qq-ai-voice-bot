[CmdletBinding()]
param(
    [string]$DestinationDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release'),
    [string]$PackageName = 'qq-ai-voice-bot-starter-v5'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $projectRoot 'shareable-template'
$checker = Join-Path $PSScriptRoot 'Test-ShareablePackage.ps1'
if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Missing shareable template: $templateRoot"
}

& $checker -PackagePath $templateRoot

[System.IO.Directory]::CreateDirectory($DestinationDirectory) | Out-Null
$zipPath = Join-Path $DestinationDirectory "$PackageName.zip"
if (Test-Path -LiteralPath $zipPath) {
    throw "Refusing to overwrite an existing ZIP: $zipPath"
}

Compress-Archive -Path (Join-Path $templateRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "[DONE] Created safe starter ZIP: $zipPath"

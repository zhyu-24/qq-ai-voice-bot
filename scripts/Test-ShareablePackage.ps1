[CmdletBinding()]
param(
    [string]$PackagePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shareable-template')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$templateChecker = Join-Path (Split-Path -Parent $PSScriptRoot) 'shareable-template\scripts\Test-ShareablePackage.ps1'
if (-not (Test-Path -LiteralPath $templateChecker)) {
    throw "Missing template safety checker: $templateChecker"
}

& $templateChecker -PackagePath $PackagePath

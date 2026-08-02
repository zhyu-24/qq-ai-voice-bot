[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testsRoot = $PSScriptRoot
$testFiles = @(
    'Test-CmdConfigSafety.ps1',
    'Test-IsolatedPackImports.ps1',
    'Test-StatusRedaction.ps1'
)

foreach ($testFile in $testFiles) {
    Write-Host "[TEST] $testFile"
    & (Join-Path $testsRoot $testFile)
}

Write-Host '[PASS] All isolated regression tests passed.'

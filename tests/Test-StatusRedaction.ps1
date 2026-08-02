[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $PSScriptRoot '.tmp-status-redaction'
$secret = 'SIMULATED_STATUS_SECRET_428d'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

try {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    foreach ($directory in @(
        (Join-Path $fixtureRoot 'scripts'),
        (Join-Path $fixtureRoot 'config'),
        (Join-Path $fixtureRoot 'data')
    )) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }

    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/Get-LocalBotStatus.ps1') -Destination (Join-Path $fixtureRoot 'scripts/Get-LocalBotStatus.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/CmdConfig.Common.ps1') -Destination (Join-Path $fixtureRoot 'scripts/CmdConfig.Common.ps1')
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'config/local-runtime.psd1'), "@{ GsvRoot = ''; GsvPort = 9880 }`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'compose.yml'), "services: {}`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'data/cmd_config.json'), ('{"api_key":"' + $secret + '", invalid'), $utf8)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & (Join-Path $fixtureRoot 'scripts/Get-LocalBotStatus.ps1') -ConfigOnly *>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldPreference

    Assert-True ($exitCode -ne 0) 'Malformed cmd_config.json status check must return a nonzero exit code'
    Assert-True (-not $output.Contains($secret)) 'Status output must not contain simulated secret'
    Assert-True (-not $output.Contains('invalid')) 'Status output must not contain malformed input fragment'
    Assert-True ($output.Contains('contents were not printed')) 'Status output must explicitly say configuration contents were not printed'

    [System.IO.File]::WriteAllBytes((Join-Path $fixtureRoot 'data/cmd_config.json'), [byte[]](0x7B, 0x22, 0x78, 0x22, 0x3A, 0x22, 0xC3, 0x28, 0x22, 0x7D))
    $invalidUtf8Output = & (Join-Path $fixtureRoot 'scripts/Get-LocalBotStatus.ps1') -ConfigOnly *>&1 | Out-String
    $invalidUtf8ExitCode = $LASTEXITCODE
    Assert-True ($invalidUtf8ExitCode -ne 0) 'Invalid UTF-8 status check must return a nonzero exit code'
    Assert-True ($invalidUtf8Output.Contains('contents were not printed')) 'Invalid UTF-8 status output must be redacted'

    $utf16 = New-Object System.Text.UnicodeEncoding($false, $true)
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'data/cmd_config.json'), ('{"api_key":"' + $secret + '"}'), $utf16)
    $utf16Output = & (Join-Path $fixtureRoot 'scripts/Get-LocalBotStatus.ps1') -ConfigOnly *>&1 | Out-String
    $utf16ExitCode = $LASTEXITCODE
    Assert-True ($utf16ExitCode -ne 0) 'UTF-16 status check must return a nonzero exit code'
    Assert-True (-not $utf16Output.Contains($secret)) 'UTF-16 status output must not contain simulated secret'

    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'data/cmd_config.json') -Force
    $missingOutput = & (Join-Path $fixtureRoot 'scripts/Get-LocalBotStatus.ps1') -ConfigOnly *>&1 | Out-String
    $missingExitCode = $LASTEXITCODE
    Assert-True ($missingExitCode -ne 0) 'Missing cmd_config.json status check must return a nonzero exit code'
    Assert-True ($missingOutput.Contains('has not created')) 'Missing cmd_config.json status check must report a safe fixed summary'

    Write-Host '[PASS] Status redaction and nonzero-exit regression test passed in an isolated fake-credential fixture.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

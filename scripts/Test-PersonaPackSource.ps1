[CmdletBinding()]
param(
    [string]$SourcePersonaPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'persona\aemeath.md')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$builderPath = Join-Path $PSScriptRoot 'New-PersonaPack.ps1'
if (-not (Test-Path -LiteralPath $builderPath -PathType Leaf)) {
    throw "Missing persona-pack builder: $builderPath"
}

$temporaryDestination = Join-Path ([System.IO.Path]::GetTempPath()) ('qq-ai-persona-pack-check-' + [Guid]::NewGuid().ToString('N'))
try {
    [System.IO.Directory]::CreateDirectory($temporaryDestination) | Out-Null
    & $builderPath -SourcePersonaPath $SourcePersonaPath -DestinationDirectory $temporaryDestination
    $zipPath = Join-Path $temporaryDestination 'aemeath-persona.zip'
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw 'The persona-pack validation did not produce the expected temporary ZIP.'
    }
    Write-Host '[OK] The local persona source can be packaged and passed all safety checks.'
}
finally {
    if (Test-Path -LiteralPath $temporaryDestination) {
        Remove-Item -LiteralPath $temporaryDestination -Recurse -Force
    }
}

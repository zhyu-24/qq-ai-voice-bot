[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$VoicePackZip,
    [switch]$NoStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $VoicePackZip -PathType Leaf)) {
    throw "Voice-pack ZIP was not found: $VoicePackZip"
}
if ([System.IO.Path]::GetExtension($VoicePackZip) -ine '.zip') {
    throw 'Select a .zip voice-pack file.'
}

$tempParent = [System.IO.Path]::GetTempPath().TrimEnd([char]92, [char]47)
$tempRoot = Join-Path $tempParent ('qq-ai-voice-pack-' + [Guid]::NewGuid().ToString('N'))

function Remove-SafeTemporaryDirectory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char]92, [char]47)
    $requiredPrefix = $tempParent + [System.IO.Path]::DirectorySeparatorChar + 'qq-ai-voice-pack-'
    if ($fullPath.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    Expand-Archive -LiteralPath $VoicePackZip -DestinationPath $tempRoot -Force

    $manifests = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'manifest.json' -Recurse -File)
    if ($manifests.Count -ne 1) {
        throw 'The ZIP must contain exactly one voice-pack manifest.json file.'
    }

    $packRoot = Split-Path -Parent $manifests[0].FullName
    $trustedInstaller = Join-Path $PSScriptRoot 'Install-VoicePack.ps1'
    if (-not (Test-Path -LiteralPath $trustedInstaller -PathType Leaf)) {
        throw "Missing trusted voice-pack installer: $trustedInstaller"
    }

    Write-Host '[INFO] Checking and importing the selected voice pack. This can take a minute.'
    if ($NoStart) {
        & $trustedInstaller -BotProjectPath $projectRoot -PackRoot $packRoot -NoStart
    }
    else {
        & $trustedInstaller -BotProjectPath $projectRoot -PackRoot $packRoot
    }
}
finally {
    Remove-SafeTemporaryDirectory -Path $tempRoot
}

Write-Host '[DONE] Voice-pack ZIP imported successfully.'

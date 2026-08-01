[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PersonaPackZip,
    [switch]$NoBrowser,
    [switch]$NoClipboard,
    [switch]$SetAsDefault
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $PersonaPackZip -PathType Leaf)) {
    throw "Persona-pack ZIP was not found: $PersonaPackZip"
}
if ([System.IO.Path]::GetExtension($PersonaPackZip) -ine '.zip') {
    throw 'Select a .zip persona-pack file.'
}

$tempParent = [System.IO.Path]::GetTempPath().TrimEnd([char]92, [char]47)
$tempRoot = Join-Path $tempParent ('qq-ai-persona-pack-' + [Guid]::NewGuid().ToString('N'))

function Remove-SafeTemporaryDirectory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char]92, [char]47)
    $requiredPrefix = $tempParent + [System.IO.Path]::DirectorySeparatorChar + 'qq-ai-persona-pack-'
    if ($fullPath.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    Expand-Archive -LiteralPath $PersonaPackZip -DestinationPath $tempRoot -Force

    $manifests = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'manifest.json' -Recurse -File)
    if ($manifests.Count -ne 1) {
        throw 'The ZIP must contain exactly one persona-pack manifest.json file.'
    }

    $packRoot = Split-Path -Parent $manifests[0].FullName
    $trustedInstaller = Join-Path $PSScriptRoot 'Install-PersonaPack.ps1'
    if (-not (Test-Path -LiteralPath $trustedInstaller -PathType Leaf)) {
        throw "Missing trusted persona-pack installer: $trustedInstaller"
    }

    Write-Host '[INFO] Checking and preparing the selected text-only persona pack.'
    $installerArguments = @{
        BotProjectPath = $projectRoot
        PackRoot = $packRoot
    }
    if ($NoBrowser) { $installerArguments.NoBrowser = $true }
    if ($NoClipboard) { $installerArguments.NoClipboard = $true }
    if ($SetAsDefault) { $installerArguments.SetAsDefault = $true }
    & $trustedInstaller @installerArguments
}
finally {
    Remove-SafeTemporaryDirectory -Path $tempRoot
}

Write-Host '[DONE] Persona-pack ZIP processed successfully.'

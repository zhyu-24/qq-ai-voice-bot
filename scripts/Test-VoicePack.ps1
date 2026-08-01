[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = (Resolve-Path -LiteralPath $PackPath).Path
$manifestPath = Join-Path $packRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing manifest: $manifestPath"
}

$manifestJson = [System.IO.File]::ReadAllText($manifestPath, (New-Object System.Text.UTF8Encoding($false)))
$manifest = $manifestJson | ConvertFrom-Json
if ([int]$manifest.format_version -ne 1) {
    throw 'Unsupported voice pack format.'
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.pack_id)) {
    throw 'Voice pack has no pack_id.'
}

function Get-SafeChildPath {
    param([string]$Root, [string]$RelativePath)

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $relativeWindowsPath = $RelativePath -replace '/', '\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relativeWindowsPath))
    $prefix = $rootFull.TrimEnd([char]92, [char]47) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe voice pack path: $RelativePath"
    }
    return $candidate
}

$entries = @($manifest.files.gpt_weights, $manifest.files.sovits_weights) + @($manifest.files.reference_audio)
foreach ($entry in $entries) {
    if ($null -eq $entry) {
        throw 'Voice pack is missing an asset entry.'
    }

    $relativePath = [string]$entry.relative_path
    $filePath = Get-SafeChildPath -Root $packRoot -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Missing asset: $relativePath"
    }

    $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "Hash mismatch: $relativePath"
    }
}

$forbiddenPaths = @(
    (Join-Path $packRoot 'data'),
    (Join-Path $packRoot '.env'),
    (Join-Path $packRoot 'cmd_config.json')
)
foreach ($forbiddenPath in $forbiddenPaths) {
    if (Test-Path -LiteralPath $forbiddenPath) {
        throw "Private runtime content found in voice pack: $forbiddenPath"
    }
}

$secretPatterns = @(
    '(?i)appsecret\s*[:=]',
    '(?i)api[_-]?key\s*[:=]',
    '(?i)authorization\s*[:=]\s*bearer',
    '(?i)sk-[a-z0-9_-]{12,}',
    '(?i)access[_-]?token\s*[:=]'
)
$textFiles = Get-ChildItem -LiteralPath $packRoot -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @('.ps1', '.cmd', '.md', '.json', '.txt')
}
foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
            throw "Possible secret pattern in voice pack: $($file.FullName)"
        }
    }
}

Write-Host '[OK] Voice pack hashes and privacy checks passed.'

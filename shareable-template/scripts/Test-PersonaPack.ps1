[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = (Resolve-Path -LiteralPath $PackPath).Path
$manifestPath = Join-Path $packRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing manifest: $manifestPath"
}

function Get-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-SafeChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath.IndexOf([char]0) -ge 0) {
        throw 'Persona pack contains an empty or invalid file path.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:') {
        throw "Persona pack path must be relative: $RelativePath"
    }

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([char]92, [char]47)
    $relativeWindowsPath = $RelativePath -replace '/', '\\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relativeWindowsPath))
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe file path in persona pack: $RelativePath"
    }
    return $candidate
}

function Get-RelativePackagePath {
    param([Parameter(Mandatory = $true)][string]$FullPath)

    return $FullPath.Substring($packRoot.Length).TrimStart([char]92, [char]47).Replace('\', '/')
}

$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
try {
    $manifestText = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($manifestPath))
}
catch {
    throw 'manifest.json must be UTF-8 text.'
}
$manifestText = $manifestText.TrimStart([char]0xFEFF)
try {
    $manifest = $manifestText | ConvertFrom-Json
}
catch {
    throw "manifest.json is not valid JSON: $($_.Exception.Message)"
}

if ([int](Get-ObjectProperty -Object $manifest -Name 'format_version') -ne 1) {
    throw 'Unsupported persona-pack format.'
}
if ([string](Get-ObjectProperty -Object $manifest -Name 'kind') -ne 'astrbot-persona') {
    throw 'This ZIP is not an AstrBot persona pack.'
}

$packId = [string](Get-ObjectProperty -Object $manifest -Name 'pack_id')
if ($packId -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{1,80}$') {
    throw 'The persona-pack identifier is invalid.'
}
$displayName = [string](Get-ObjectProperty -Object $manifest -Name 'display_name')
if ([string]::IsNullOrWhiteSpace($displayName) -or $displayName.Length -gt 120) {
    throw 'The persona-pack display name is missing or too long.'
}

$astrbot = Get-ObjectProperty -Object $manifest -Name 'astrbot'
$personaId = [string](Get-ObjectProperty -Object $astrbot -Name 'persona_id')
if ($personaId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{1,80}$') {
    throw 'The AstrBot persona_id is invalid.'
}

$beginDialogs = Get-ObjectProperty -Object $astrbot -Name 'begin_dialogs'
if ($null -ne $beginDialogs) {
    $dialogItems = @($beginDialogs)
    if (($dialogItems.Count % 2) -ne 0) {
        throw 'begin_dialogs must contain an even number of user/assistant entries.'
    }
    foreach ($dialogItem in $dialogItems) {
        if ([string]::IsNullOrWhiteSpace([string]$dialogItem)) {
            throw 'begin_dialogs may not contain blank entries.'
        }
    }
}

$files = Get-ObjectProperty -Object $manifest -Name 'files'
$systemPromptEntry = Get-ObjectProperty -Object $files -Name 'system_prompt'
if ($null -eq $systemPromptEntry) {
    throw 'Persona pack is missing files.system_prompt.'
}
$systemPromptRelative = [string](Get-ObjectProperty -Object $systemPromptEntry -Name 'relative_path')
if ($systemPromptRelative -ne 'assets/system-prompt.md') {
    throw 'Persona pack system prompt must be stored at assets/system-prompt.md.'
}
$expectedHash = [string](Get-ObjectProperty -Object $systemPromptEntry -Name 'sha256')
if ($expectedHash -notmatch '^[a-f0-9]{64}$') {
    throw 'Persona pack system-prompt hash is invalid.'
}
$expectedBytes = Get-ObjectProperty -Object $systemPromptEntry -Name 'bytes'
if ($null -eq $expectedBytes -or [int64]$expectedBytes -le 0 -or [int64]$expectedBytes -gt 262144) {
    throw 'Persona pack system-prompt size is invalid.'
}

$systemPromptPath = Get-SafeChildPath -Root $packRoot -RelativePath $systemPromptRelative
if (-not (Test-Path -LiteralPath $systemPromptPath -PathType Leaf)) {
    throw 'Persona pack is missing assets/system-prompt.md.'
}
$systemPromptBytes = [System.IO.File]::ReadAllBytes($systemPromptPath)
if ([int64]$systemPromptBytes.Length -ne [int64]$expectedBytes) {
    throw 'Persona pack system-prompt byte count does not match the manifest.'
}
if ((Get-FileHash -LiteralPath $systemPromptPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Persona pack hash verification failed for assets/system-prompt.md.'
}
try {
    $systemPromptText = $strictUtf8.GetString($systemPromptBytes)
}
catch {
    throw 'assets/system-prompt.md must be UTF-8 text.'
}
if ([string]::IsNullOrWhiteSpace($systemPromptText)) {
    throw 'Persona pack system prompt is blank.'
}

$requiredFiles = @(
    'manifest.json',
    'README.md',
    'LICENSE-AND-AUTHORIZATION.md',
    'assets/system-prompt.md'
)
$actualFiles = @(Get-ChildItem -LiteralPath $packRoot -Recurse -File -Force | ForEach-Object { Get-RelativePackagePath -FullPath $_.FullName })
foreach ($requiredFile in $requiredFiles) {
    if ($actualFiles -notcontains $requiredFile) {
        throw "Persona pack is missing required file: $requiredFile"
    }
}
foreach ($actualFile in $actualFiles) {
    if ($requiredFiles -notcontains $actualFile) {
        throw "Persona pack contains an unexpected file: $actualFile"
    }
}

$secretPatterns = @(
    '(?i)\bsk-[a-z0-9_-]{12,}\b',
    '(?i)\b(?:api[_-]?key|appsecret|access[_-]?token)\b\s*[:=]\s*[a-z0-9_-]{12,}'
)
foreach ($textFile in $requiredFiles) {
    $textPath = Get-SafeChildPath -Root $packRoot -RelativePath $textFile
    try {
        $text = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($textPath))
    }
    catch {
        throw "Persona pack text file is not UTF-8: $textFile"
    }
    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            throw "Persona pack appears to contain a credential in: $textFile"
        }
    }
}

Write-Host '[OK] Persona-pack manifest and prompt hash are valid.'
Write-Host "[OK] Persona ID: $personaId"
Write-Host "[OK] Display name: $displayName"

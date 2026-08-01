[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GsvRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeExample = Join-Path $projectRoot 'config\local-runtime.psd1.example'
$runtimeConfig = Join-Path $projectRoot 'config\local-runtime.psd1'

if (-not (Test-Path -LiteralPath $GsvRoot -PathType Container)) {
    throw "GPT-SoVITS folder was not found: $GsvRoot"
}

$resolvedRoot = (Resolve-Path -LiteralPath $GsvRoot).Path
$requiredPaths = @(
    (Join-Path $resolvedRoot 'api_v2.py'),
    (Join-Path $resolvedRoot 'runtime\python.exe'),
    (Join-Path $resolvedRoot 'GPT_SoVITS\configs\tts_infer.yaml')
)
foreach ($requiredPath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "This folder is not a compatible GPT-SoVITS runtime. Missing: $requiredPath"
    }
}

if (-not (Test-Path -LiteralPath $runtimeConfig)) {
    if (-not (Test-Path -LiteralPath $runtimeExample)) {
        throw "Missing runtime configuration template: $runtimeExample"
    }
    Copy-Item -LiteralPath $runtimeExample -Destination $runtimeConfig
}

$content = [System.IO.File]::ReadAllText($runtimeConfig)
$escapedRoot = $resolvedRoot.Replace("'", "''")
$replacement = "GsvRoot = '$escapedRoot'"
if ($content -match '(?m)^\s*GsvRoot\s*=\s*.*$') {
    $content = [regex]::Replace($content, '(?m)^\s*GsvRoot\s*=\s*.*$', $replacement, 1)
}
else {
    $content = $content.Replace('@{', "@{`r`n    # Local GPT-SoVITS installation selected through Setup Center.`r`n    $replacement")
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($runtimeConfig, $content, $utf8Bom)

Write-Host '[OK] Local GPT-SoVITS folder saved.'
Write-Host "GsvRoot: $resolvedRoot"

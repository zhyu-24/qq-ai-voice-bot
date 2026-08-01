[CmdletBinding()]
param(
    [string]$PackagePath = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$violations = New-Object System.Collections.Generic.List[string]
$forbiddenDirectories = @('data', 'runtime', 'logs', 'state', 'release', '.tools', 'models', 'reference-audio', 'outputs', 'persona-imports')
$forbiddenExtensions = @('.m4a', '.mp3', '.wav', '.flac', '.ogg', '.aac', '.ckpt', '.pth', '.safetensors', '.onnx', '.index', '.exe')
$textExtensions = @('.ps1', '.cmd', '.md', '.txt', '.json', '.yml', '.yaml', '.env', '.example', '.gitignore', '.dockerignore')
$secretPatterns = @(
    '(?i)appsecret\s*[:=]',
    '(?i)api[_-]?key\s*[:=]',
    '(?i)authorization\s*[:=]\s*bearer',
    '(?i)sk-[a-z0-9_-]{12,}',
    '(?i)access[_-]?token\s*[:=]'
)

foreach ($directoryName in $forbiddenDirectories) {
    $directoryPath = Join-Path $packageRoot $directoryName
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
        $nonMarkerItems = @(Get-ChildItem -LiteralPath $directoryPath -Force | Where-Object { $_.Name -ne '.gitignore' })
        if ($nonMarkerItems.Count -gt 0) {
            $violations.Add("Forbidden runtime or private directory contains files: $directoryName")
        }
    }
}

$allFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Force
foreach ($file in $allFiles) {
    $extension = $file.Extension.ToLowerInvariant()
    if ($forbiddenExtensions -contains $extension) {
        $violations.Add("Forbidden file type: $($file.FullName)")
        continue
    }

    $relativePath = $file.FullName.Substring($packageRoot.Length).TrimStart([char]92, [char]47)
    $topLevel = ($relativePath -split '[\\/]' | Select-Object -First 1)
    if (($forbiddenDirectories -contains $topLevel) -and $file.Name -ne '.gitignore') {
        $violations.Add("Forbidden path: $relativePath")
        continue
    }

    $isText = ($textExtensions -contains $extension) -or $file.Name -in @('.gitignore', '.dockerignore', 'Dockerfile', 'LICENSE')
    if ($isText -and $file.Length -le 2MB) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                $violations.Add("Possible secret pattern in: $relativePath")
                break
            }
        }
    }
}

if ($violations.Count -gt 0) {
    $message = '[FAIL] Do not publish this package yet:' + [Environment]::NewLine + (($violations | Sort-Object -Unique | ForEach-Object { " - $_" }) -join [Environment]::NewLine)
    throw $message
}

Write-Host '[OK] Shareable package safety check passed.'
Write-Host 'This check is conservative, not a guarantee. Review screenshots and configuration manually.'

[CmdletBinding()]
param(
    [string]$PackId = 'aemeath-persona',
    [string]$PersonaId = 'aemeath-fan-v1',
    [string]$DisplayName = '爱弥斯（非官方同人）',
    [string]$SourcePersonaPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'persona\aemeath.md'),
    [string]$DestinationDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $projectRoot 'persona-pack-template'
$validatorPath = Join-Path $PSScriptRoot 'Test-PersonaPack.ps1'

if ($PackId -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{1,80}$') {
    throw 'PackId may contain only letters, digits, and hyphens.'
}
if ($PersonaId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{1,80}$') {
    throw 'PersonaId may contain only letters, digits, dot, underscore, and hyphen.'
}
if ([string]::IsNullOrWhiteSpace($DisplayName) -or $DisplayName.Length -gt 120) {
    throw 'DisplayName is required and must be at most 120 characters.'
}
foreach ($requiredPath in @($templateRoot, $validatorPath, $SourcePersonaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required file or folder: $requiredPath"
    }
}

$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
try {
    $sourceText = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($SourcePersonaPath))
}
catch {
    throw 'The source persona file must be UTF-8 text.'
}
$heading = [regex]::Match($sourceText, '(?ms)^\s*##\s*系统提示词\s*\r?\n+')
if (-not $heading.Success) {
    throw 'Could not find the heading "## 系统提示词" in the source persona file.'
}
$systemPrompt = $sourceText.Substring($heading.Index + $heading.Length).Trim()
if ([string]::IsNullOrWhiteSpace($systemPrompt)) {
    throw 'The source persona has no text after "## 系统提示词".'
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qq-ai-persona-pack-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $DestinationDirectory "$PackId.zip"
if (Test-Path -LiteralPath $zipPath) {
    throw "Refusing to overwrite an existing persona-pack ZIP: $zipPath"
}

try {
    [System.IO.Directory]::CreateDirectory($stageRoot) | Out-Null
    Copy-Item -Path (Join-Path $templateRoot '*') -Destination $stageRoot -Recurse -Force
    $assetsRoot = Join-Path $stageRoot 'assets'
    [System.IO.Directory]::CreateDirectory($assetsRoot) | Out-Null

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    $systemPromptRelative = 'assets/system-prompt.md'
    $systemPromptPath = Join-Path $stageRoot $systemPromptRelative
    [System.IO.File]::WriteAllText($systemPromptPath, $systemPrompt + [Environment]::NewLine, $utf8Bom)
    $promptBytes = (Get-Item -LiteralPath $systemPromptPath).Length
    if ($promptBytes -gt 262144) {
        throw 'The extracted system prompt exceeds the 256 KiB persona-pack limit.'
    }

    $readme = @"
# $DisplayName

This is a text-only AstrBot persona pack. It contains one system prompt and no executable code, QQ credentials, model API keys, chat logs, audio, training material, voice weights, images, or account data.

## Import it safely

1. Install and open the **QQ AI Voice Bot Starter Kit** first.
2. Open its `Setup-Center.cmd` and go to **人格包**.
3. Select this ZIP and click **安全准备：复制提示词并打开人格页**.
4. In AstrBot, create a new persona with ID `$PersonaId`, paste the copied system prompt, and save it.
5. Return to the setup center and click **设为默认人格**. Restart AstrBot or use **日常启动** once afterward.

## Notes

- This is a non-official fan-created text configuration. It does not make the bot an official game account or character.
- The recipient remains responsible for reviewing the prompt and for any use, sharing, or modification of the pack.
"@
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'README.md'), $readme.Trim() + [Environment]::NewLine, $utf8Bom)

    $manifest = [ordered]@{
        format_version = 1
        kind = 'astrbot-persona'
        pack_id = $PackId
        display_name = $DisplayName
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        compatibility = [ordered]@{
            astrbot_min_version = '4.0'
            content_type = 'text/markdown; charset=utf-8'
        }
        files = [ordered]@{
            system_prompt = [ordered]@{
                relative_path = $systemPromptRelative
                sha256 = (Get-FileHash -LiteralPath $systemPromptPath -Algorithm SHA256).Hash.ToLowerInvariant()
                bytes = [int64]$promptBytes
            }
        }
        astrbot = [ordered]@{
            persona_id = $PersonaId
            begin_dialogs = @()
            recommended_default = $true
        }
        notice = [ordered]@{
            unofficial_fan_extension = $true
            contains = 'publisher-provided text persona configuration only'
            does_not_contain = @('QQ credentials', 'LLM keys', 'chat logs', 'audio', 'model weights', 'training material')
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'manifest.json'), ($manifest | ConvertTo-Json -Depth 12) + [Environment]::NewLine, $utf8Bom)

    & $validatorPath -PackPath $stageRoot
    [System.IO.Directory]::CreateDirectory($DestinationDirectory) | Out-Null
    Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}

$zipSize = (Get-Item -LiteralPath $zipPath).Length
Write-Host "[DONE] Created persona pack: $zipPath"
Write-Host ("ZIP size: {0:N1} KiB" -f ($zipSize / 1KB))
Write-Host 'The pack is text-only. Review its content and distribution rights before sharing it.'

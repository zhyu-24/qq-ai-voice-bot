[CmdletBinding()]
param(
    [string]$BotProjectPath = '',
    [string]$PackRoot = '',
    [switch]$NoBrowser,
    [switch]$NoClipboard,
    [switch]$SetAsDefault
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmdConfigHelperPath = Join-Path $PSScriptRoot 'CmdConfig.Common.ps1'
if (-not (Test-Path -LiteralPath $cmdConfigHelperPath -PathType Leaf)) {
    throw 'The safe configuration helper is missing.'
}
. $cmdConfigHelperPath

if ([string]::IsNullOrWhiteSpace($PackRoot)) {
    $packRoot = Split-Path -Parent $PSScriptRoot
}
elseif (-not (Test-Path -LiteralPath $PackRoot -PathType Container)) {
    throw "Persona-pack folder was not found: $PackRoot"
}
else {
    $packRoot = (Resolve-Path -LiteralPath $PackRoot).Path
}

function Select-BotProject {
    param([string]$SuggestedPath)

    if (-not [string]::IsNullOrWhiteSpace($SuggestedPath)) {
        return $SuggestedPath
    }

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择已安装的 QQ AI Voice Bot 基础项目文件夹'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'No base project folder was selected.'
    }
    return $dialog.SelectedPath
}

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $property.Value = $Value
    }
}

$validatorPath = Join-Path $PSScriptRoot 'Test-PersonaPack.ps1'
if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw "Missing trusted persona-pack validator: $validatorPath"
}
& $validatorPath -PackPath $packRoot

$manifestPath = Join-Path $packRoot 'manifest.json'
$manifest = ([System.IO.File]::ReadAllText($manifestPath, (New-Object System.Text.UTF8Encoding($false)))) | ConvertFrom-Json
$packId = [string]$manifest.pack_id
$displayName = [string]$manifest.display_name
$personaId = [string]$manifest.astrbot.persona_id
$promptPath = Join-Path $packRoot 'assets\system-prompt.md'
$systemPrompt = [System.IO.File]::ReadAllText($promptPath, (New-Object System.Text.UTF8Encoding($false)))

$botProjectPath = Select-BotProject -SuggestedPath $BotProjectPath
$botRoot = (Resolve-Path -LiteralPath $botProjectPath).Path
foreach ($requiredPath in @(
    (Join-Path $botRoot 'compose.yml'),
    (Join-Path $botRoot 'scripts\Setup-Center.ps1')
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "This is not a QQ AI Voice Bot base project. Missing: $requiredPath"
    }
}

$importRoot = Join-Path $botRoot (Join-Path 'persona-imports' $packId)
[System.IO.Directory]::CreateDirectory($importRoot) | Out-Null
$importAssetsRoot = Join-Path $importRoot 'assets'
[System.IO.Directory]::CreateDirectory($importAssetsRoot) | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $importRoot 'manifest.json') -Force
$importPromptPath = Join-Path $importAssetsRoot 'system-prompt.md'
Copy-Item -LiteralPath $promptPath -Destination $importPromptPath -Force
$readmePath = Join-Path $packRoot 'README.md'
if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    Copy-Item -LiteralPath $readmePath -Destination (Join-Path $importRoot 'README.md') -Force
}
$licensePath = Join-Path $packRoot 'LICENSE-AND-AUTHORIZATION.md'
if (Test-Path -LiteralPath $licensePath -PathType Leaf) {
    Copy-Item -LiteralPath $licensePath -Destination (Join-Path $importRoot 'LICENSE-AND-AUTHORIZATION.md') -Force
}

Write-Host "[OK] Persona pack verified and saved locally: $importRoot"
Write-Host "[INFO] Persona ID: $personaId"
Write-Host "[INFO] Display name: $displayName"

if (-not $NoClipboard) {
    try {
        Set-Clipboard -Value $systemPrompt
        Write-Host '[OK] The complete system prompt has been copied to the clipboard.'
    }
    catch {
        Write-Warning "Could not copy the prompt to the clipboard. Open this file instead: $importPromptPath"
    }
}

if (-not $NoBrowser) {
    try {
        Start-Process -FilePath 'http://localhost:6185/#/persona'
        Write-Host '[OK] Opened AstrBot Persona page in the browser.'
    }
    catch {
        Write-Warning 'Could not open the browser. Open http://localhost:6185/#/persona yourself.'
    }
}

if ($SetAsDefault) {
    $astrConfigPath = Join-Path $botRoot 'data\cmd_config.json'
    if (-not (Test-Path -LiteralPath $astrConfigPath -PathType Leaf)) {
        throw 'AstrBot configuration is not available yet. Create and save the persona in AstrBot first, then run this step again.'
    }
    $astrConfig = Read-StrictUtf8Json -Path $astrConfigPath -Label 'AstrBot configuration'
    $providerSettings = $astrConfig.provider_settings
    if ($null -eq $providerSettings) {
        $providerSettings = [pscustomobject]@{}
        Set-ObjectProperty -Object $astrConfig -Name 'provider_settings' -Value $providerSettings
    }
    Set-ObjectProperty -Object $providerSettings -Name 'default_personality' -Value $personaId

    $validatePersonaConfig = {
        param($candidate)
        if ($null -eq $candidate.provider_settings -or [string]$candidate.provider_settings.default_personality -ne $personaId) {
            throw 'The updated AstrBot configuration did not retain the selected default persona.'
        }
    }
    $backupDirectory = Join-Path $botRoot 'backups'
    $backupPath = Write-AtomicUtf8Json -Path $astrConfigPath -Value $astrConfig -BackupDirectory $backupDirectory -BackupPrefix 'cmd_config.before-persona-pack' -Validate $validatePersonaConfig -Label 'AstrBot configuration' -Depth 30
    Write-Host "[OK] Set default_personality to $personaId"
    Write-Host "[OK] Backed up AstrBot configuration: $backupPath"
    Write-Host '[INFO] Restart AstrBot or click 日常启动 once before testing a new conversation.'
}
else {
    Write-Host '[NEXT] In AstrBot, create a persona with the Persona ID shown above, paste the copied prompt, and save it.'
    Write-Host '[NEXT] Return here afterward and use “设为默认人格”. Existing conversations can retain their previous persona.'
}

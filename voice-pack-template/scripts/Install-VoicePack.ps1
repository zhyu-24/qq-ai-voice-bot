[CmdletBinding()]
param(
    [string]$BotProjectPath = '',
    [switch]$NoStart,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmdConfigHelperPath = Join-Path $PSScriptRoot 'CmdConfig.Common.ps1'
if (-not (Test-Path -LiteralPath $cmdConfigHelperPath -PathType Leaf)) {
    throw 'The safe configuration helper is missing.'
}
. $cmdConfigHelperPath

$packRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $packRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing voice pack manifest: $manifestPath"
}

$manifestJson = [System.IO.File]::ReadAllText($manifestPath, (New-Object System.Text.UTF8Encoding($false)))
$manifest = $manifestJson | ConvertFrom-Json
if ([int]$manifest.format_version -ne 1) {
    throw 'Unsupported voice pack format.'
}
$packId = [string]$manifest.pack_id
if ([string]::IsNullOrWhiteSpace($packId) -or $packId -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{1,80}$') {
    throw 'The voice pack identifier is invalid.'
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

function Get-SafeChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $relativeWindowsPath = $RelativePath -replace '/', '\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relativeWindowsPath))
    $prefix = $rootFull.TrimEnd([char]92, [char]47) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe file path in voice pack: $RelativePath"
    }
    return $candidate
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$botProjectPath = Select-BotProject -SuggestedPath $BotProjectPath
$botRoot = (Resolve-Path -LiteralPath $botProjectPath).Path
$runtimeConfigPath = Join-Path $botRoot 'config\local-runtime.psd1'
$astrConfigPath = Join-Path $botRoot 'data\cmd_config.json'
$startScriptPath = Join-Path $botRoot 'scripts\Start-LocalBot.ps1'

foreach ($requiredPath in @($runtimeConfigPath, $astrConfigPath, $startScriptPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "This is not a configured base bot project. Missing: $requiredPath"
    }
}

$runtimeConfig = Import-PowerShellDataFile -Path $runtimeConfigPath
$gsvRoot = [string]$runtimeConfig.GsvRoot
if ([string]::IsNullOrWhiteSpace($gsvRoot)) {
    throw 'GsvRoot is blank in config\local-runtime.psd1. Configure local GPT-SoVITS first.'
}
$gsvRoot = (Resolve-Path -LiteralPath $gsvRoot).Path

foreach ($requiredPath in @(
    (Join-Path $gsvRoot 'api_v2.py'),
    (Join-Path $gsvRoot 'runtime\python.exe'),
    (Join-Path $gsvRoot 'GPT_SoVITS\configs\tts_infer.yaml')
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "The selected GPT-SoVITS installation is incomplete: $requiredPath"
    }
}

$entries = @($manifest.files.gpt_weights, $manifest.files.sovits_weights) + @($manifest.files.reference_audio)
foreach ($entry in $entries) {
    if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.relative_path)) {
        throw 'Voice pack manifest has a missing asset entry.'
    }
    $sourcePath = Get-SafeChildPath -Root $packRoot -RelativePath ([string]$entry.relative_path)
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Voice pack asset is missing: $($entry.relative_path)"
    }
    $actualHash = Get-Sha256 -Path $sourcePath
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "Voice pack hash verification failed: $($entry.relative_path)"
    }
}

$astrConfig = Read-StrictUtf8Json -Path $astrConfigPath -Label 'AstrBot configuration'

$gptTargetDirectory = Join-Path $gsvRoot 'GPT_weights_v2ProPlus'
$sovitsTargetDirectory = Join-Path $gsvRoot 'SoVITS_weights_v2ProPlus'
$referenceTargetDirectory = Join-Path $gsvRoot "reference_audio\$packId"
[System.IO.Directory]::CreateDirectory($gptTargetDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory($sovitsTargetDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory($referenceTargetDirectory) | Out-Null

$gptEntry = $manifest.files.gpt_weights
$sovitsEntry = $manifest.files.sovits_weights
$referenceEntry = $manifest.files.reference_audio
$gptTarget = Join-Path $gptTargetDirectory "$packId-$([System.IO.Path]::GetFileName([string]$gptEntry.relative_path))"
$sovitsTarget = Join-Path $sovitsTargetDirectory "$packId-$([System.IO.Path]::GetFileName([string]$sovitsEntry.relative_path))"
$referenceTarget = Join-Path $referenceTargetDirectory ([System.IO.Path]::GetFileName([string]$referenceEntry.relative_path))

foreach ($targetPath in @($gptTarget, $sovitsTarget, $referenceTarget)) {
    if (Test-Path -LiteralPath $targetPath) {
        if ($Force) {
            throw "Replacing an existing imported voice pack is not supported by the safe installer. Remove or rename the existing pack after making your own backup, then import again: $targetPath"
        }
        throw "A destination file already exists: $targetPath. Repeated import was safely refused."
    }
}
$providerId = [string]$manifest.astrbot.provider_id
$providers = @($astrConfig.provider)
$provider = @($providers | Where-Object { $_.id -eq $providerId }) | Select-Object -First 1
if ($null -eq $provider) {
    $provider = [pscustomobject]@{}
    $providers += $provider
    Set-ObjectProperty -Object $astrConfig -Name 'provider' -Value @($providers)
}

$gsvParameters = $manifest.astrbot.gsv_default_parms | ConvertTo-Json -Depth 20 | ConvertFrom-Json
Set-ObjectProperty -Object $gsvParameters -Name 'gsv_ref_audio_path' -Value $referenceTarget

Set-ObjectProperty -Object $provider -Name 'id' -Value $providerId
Set-ObjectProperty -Object $provider -Name 'type' -Value 'gsv_tts_selfhost'
Set-ObjectProperty -Object $provider -Name 'provider_type' -Value 'text_to_speech'
Set-ObjectProperty -Object $provider -Name 'provider' -Value 'gpt_sovits'
Set-ObjectProperty -Object $provider -Name 'enable' -Value $true
Set-ObjectProperty -Object $provider -Name 'api_base' -Value "http://host.docker.internal:$([int]$runtimeConfig.GsvPort)"
Set-ObjectProperty -Object $provider -Name 'timeout' -Value ([int]$manifest.astrbot.timeout)
Set-ObjectProperty -Object $provider -Name 'gpt_weights_path' -Value $gptTarget
Set-ObjectProperty -Object $provider -Name 'sovits_weights_path' -Value $sovitsTarget
Set-ObjectProperty -Object $provider -Name 'gsv_default_parms' -Value $gsvParameters

$ttsSettings = $astrConfig.provider_tts_settings
if ($null -eq $ttsSettings) {
    $ttsSettings = [pscustomobject]@{}
    Set-ObjectProperty -Object $astrConfig -Name 'provider_tts_settings' -Value $ttsSettings
}
Set-ObjectProperty -Object $ttsSettings -Name 'enable' -Value $true
Set-ObjectProperty -Object $ttsSettings -Name 'provider_id' -Value $providerId
Set-ObjectProperty -Object $ttsSettings -Name 'dual_output' -Value $true
Set-ObjectProperty -Object $ttsSettings -Name 'trigger_probability' -Value 1

$validateVoiceConfig = {
    param($candidate)
    if ($null -eq $candidate.provider_tts_settings -or [string]$candidate.provider_tts_settings.provider_id -ne $providerId -or -not $candidate.provider_tts_settings.enable) {
        throw 'The updated AstrBot configuration did not retain the selected TTS provider.'
    }
    $candidateProvider = @($candidate.provider | Where-Object { [string]$_.id -eq $providerId }) | Select-Object -First 1
    if ($null -eq $candidateProvider -or [string]$candidateProvider.type -ne 'gsv_tts_selfhost') {
        throw 'The updated AstrBot configuration did not retain the local GPT-SoVITS provider.'
    }
}

$expectedNewAssetPaths = @($gptTarget, $sovitsTarget, $referenceTarget)
$backupDirectory = Join-Path $botRoot 'backups'
try {
    Copy-Item -LiteralPath (Get-SafeChildPath -Root $packRoot -RelativePath ([string]$gptEntry.relative_path)) -Destination $gptTarget
    Copy-Item -LiteralPath (Get-SafeChildPath -Root $packRoot -RelativePath ([string]$sovitsEntry.relative_path)) -Destination $sovitsTarget
    Copy-Item -LiteralPath (Get-SafeChildPath -Root $packRoot -RelativePath ([string]$referenceEntry.relative_path)) -Destination $referenceTarget

    $backupPath = Write-AtomicUtf8Json -Path $astrConfigPath -Value $astrConfig -BackupDirectory $backupDirectory -BackupPrefix 'cmd_config.before-voice-pack' -Validate $validateVoiceConfig -Label 'AstrBot configuration' -Depth 30
}
catch {
    foreach ($expectedNewAssetPath in $expectedNewAssetPaths) {
        if (Test-Path -LiteralPath $expectedNewAssetPath -PathType Leaf) {
            Remove-Item -LiteralPath $expectedNewAssetPath -Force -ErrorAction SilentlyContinue
        }
    }
    if ((Test-Path -LiteralPath $referenceTargetDirectory -PathType Container) -and -not (Get-ChildItem -LiteralPath $referenceTargetDirectory -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $referenceTargetDirectory -Force -ErrorAction SilentlyContinue
    }
    throw
}

Write-Host '[OK] Voice assets copied and hashes verified.'
Write-Host "[OK] Backed up AstrBot configuration: $backupPath"
Write-Host '[OK] Configured text plus voice output with the imported local GPT-SoVITS provider.'

if (-not $NoStart) {
    Write-Host 'Starting local GPT-SoVITS and AstrBot with the imported voice...'
    & $startScriptPath -StartupDelaySeconds 0
}

Write-Host ''
Write-Host '[DONE] Voice pack installation finished.'

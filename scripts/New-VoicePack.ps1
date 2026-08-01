[CmdletBinding()]
param(
    [string]$PackId = 'aemeath-local-voice',
    [string]$DisplayName = '本地自定义语音包',
    [string]$DestinationDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'release')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$astrConfigPath = Join-Path $projectRoot 'data\cmd_config.json'
$templateRoot = Join-Path $projectRoot 'voice-pack-template'
$validatorPath = Join-Path $PSScriptRoot 'Test-VoicePack.ps1'

if ($PackId -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{1,80}$') {
    throw 'PackId may contain only letters, digits, and hyphens.'
}
foreach ($requiredPath in @($astrConfigPath, $templateRoot, $validatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required file or folder: $requiredPath"
    }
}

function Set-ObjectProperty {
    param($Object, [string]$Name, $Value)

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $property.Value = $Value
    }
}

function Get-RequiredFile {
    param([string]$Label, [string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "The current TTS provider has no $Label path."
    }
    if (-not (Test-Path -LiteralPath $PathValue)) {
        throw "The current $Label file is missing: $PathValue"
    }
    return (Resolve-Path -LiteralPath $PathValue).Path
}

$astrConfig = Get-Content -LiteralPath $astrConfigPath -Raw | ConvertFrom-Json
$ttsSettings = $astrConfig.provider_tts_settings
if ($null -eq $ttsSettings -or -not $ttsSettings.enable -or [string]::IsNullOrWhiteSpace([string]$ttsSettings.provider_id)) {
    throw 'AstrBot local TTS is not enabled.'
}
$provider = @($astrConfig.provider | Where-Object { $_.id -eq $ttsSettings.provider_id }) | Select-Object -First 1
if ($null -eq $provider -or $provider.type -ne 'gsv_tts_selfhost') {
    throw 'The current default TTS provider is not self-hosted GPT-SoVITS.'
}
if ($null -eq $provider.gsv_default_parms) {
    throw 'The current GPT-SoVITS provider has no default reference-audio parameters.'
}

$gptSource = Get-RequiredFile -Label 'GPT weight' -PathValue ([string]$provider.gpt_weights_path)
$sovitsSource = Get-RequiredFile -Label 'SoVITS weight' -PathValue ([string]$provider.sovits_weights_path)
$referenceSource = Get-RequiredFile -Label 'reference audio' -PathValue ([string]$provider.gsv_default_parms.gsv_ref_audio_path)

$totalBytes = (Get-Item -LiteralPath $gptSource).Length + (Get-Item -LiteralPath $sovitsSource).Length + (Get-Item -LiteralPath $referenceSource).Length
Write-Host ("Preparing voice assets: {0:N1} MiB" -f ($totalBytes / 1MB))

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qq-ai-voice-pack-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $DestinationDirectory "$PackId.zip"
if (Test-Path -LiteralPath $zipPath) {
    throw "Refusing to overwrite an existing voice pack ZIP: $zipPath"
}

try {
    [System.IO.Directory]::CreateDirectory($stageRoot) | Out-Null
    Copy-Item -Path (Join-Path $templateRoot '*') -Destination $stageRoot -Recurse -Force

    $gptRelative = 'assets/gpt/' + [System.IO.Path]::GetFileName($gptSource)
    $sovitsRelative = 'assets/sovits/' + [System.IO.Path]::GetFileName($sovitsSource)
    $referenceRelative = 'assets/reference/' + [System.IO.Path]::GetFileName($referenceSource)

    foreach ($relativePath in @($gptRelative, $sovitsRelative, $referenceRelative)) {
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent (Join-Path $stageRoot $relativePath))) | Out-Null
    }

    Copy-Item -LiteralPath $gptSource -Destination (Join-Path $stageRoot $gptRelative)
    Copy-Item -LiteralPath $sovitsSource -Destination (Join-Path $stageRoot $sovitsRelative)
    Copy-Item -LiteralPath $referenceSource -Destination (Join-Path $stageRoot $referenceRelative)

    $gsvParameters = $provider.gsv_default_parms | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    Set-ObjectProperty -Object $gsvParameters -Name 'gsv_ref_audio_path' -Value $referenceRelative
    Set-ObjectProperty -Object $gsvParameters -Name 'gsv_aux_ref_audio_paths' -Value ''

    $manifest = [ordered]@{
        format_version = 1
        pack_id = $PackId
        display_name = $DisplayName
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        compatibility = [ordered]@{
            runtime_flavor = 'GPT-SoVITS-v2ProPlus'
            tts_provider_type = 'gsv_tts_selfhost'
            required_gpu_for_local_inference = $true
        }
        files = [ordered]@{
            gpt_weights = [ordered]@{
                relative_path = $gptRelative
                sha256 = (Get-FileHash -LiteralPath (Join-Path $stageRoot $gptRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            sovits_weights = [ordered]@{
                relative_path = $sovitsRelative
                sha256 = (Get-FileHash -LiteralPath (Join-Path $stageRoot $sovitsRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            reference_audio = [ordered]@{
                relative_path = $referenceRelative
                sha256 = (Get-FileHash -LiteralPath (Join-Path $stageRoot $referenceRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        astrbot = [ordered]@{
            provider_id = [string]$provider.id
            timeout = [int]$provider.timeout
            gsv_default_parms = $gsvParameters
        }
    }

    $utf8 = New-Object System.Text.UTF8Encoding($true)
    $manifestJson = $manifest | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'manifest.json'), $manifestJson + [Environment]::NewLine, $utf8)

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
Write-Host "[DONE] Created voice pack: $zipPath"
Write-Host ("ZIP size: {0:N1} MiB" -f ($zipSize / 1MB))
Write-Host 'This ZIP contains voice assets. Share it only under the authorization that covers redistribution.'

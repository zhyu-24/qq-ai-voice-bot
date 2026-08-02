[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $PSScriptRoot '.tmp-isolated-pack-imports'
$secret = 'SIMULATED_IMPORT_SECRET_91b0'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ([string]$Expected -cne [string]$Actual) { throw "ASSERTION FAILED: $Message. Expected '$Expected', got '$Actual'." }
}
function Write-Utf8 {
    param([string]$Path, [string]$Text)
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Get-HashLower {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

try {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    $botRoot = Join-Path $fixtureRoot 'fake-bot'
    $packRoot = Join-Path $fixtureRoot 'fake-voice-pack'
    $personaRoot = Join-Path $fixtureRoot 'fake-persona-pack'
    $fakeGsv = Join-Path $fixtureRoot 'fake-gsv'

    foreach ($directory in @(
        (Join-Path $botRoot 'scripts'),
        (Join-Path $botRoot 'data'),
        (Join-Path $botRoot 'config'),
        (Join-Path $packRoot 'assets/gpt'),
        (Join-Path $packRoot 'assets/sovits'),
        (Join-Path $packRoot 'assets/reference'),
        (Join-Path $personaRoot 'assets'),
        (Join-Path $fakeGsv 'runtime'),
        (Join-Path $fakeGsv 'GPT_SoVITS/configs')
    )) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }

    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/CmdConfig.Common.ps1') -Destination (Join-Path $botRoot 'scripts/CmdConfig.Common.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/Install-VoicePack.ps1') -Destination (Join-Path $botRoot 'scripts/Install-VoicePack.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/Install-PersonaPack.ps1') -Destination (Join-Path $botRoot 'scripts/Install-PersonaPack.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/Test-PersonaPack.ps1') -Destination (Join-Path $botRoot 'scripts/Test-PersonaPack.ps1')
    Write-Utf8 -Path (Join-Path $botRoot 'scripts/Start-LocalBot.ps1') -Text "param([int]`$StartupDelaySeconds=0)`nthrow 'Start script must not run in isolated tests.'`n"
    Write-Utf8 -Path (Join-Path $botRoot 'scripts/Setup-Center.ps1') -Text "# isolated placeholder`n"
    Write-Utf8 -Path (Join-Path $botRoot 'compose.yml') -Text "services: {}`n"

    foreach ($file in @(
        (Join-Path $fakeGsv 'api_v2.py'),
        (Join-Path $fakeGsv 'runtime/python.exe'),
        (Join-Path $fakeGsv 'GPT_SoVITS/configs/tts_infer.yaml')
    )) { Write-Utf8 -Path $file -Text "fake`n" }

    $runtimeConfig = "@{`n    GsvRoot = '$($fakeGsv.Replace("'", "''"))'`n    GsvPort = 9880`n}`n"
    Write-Utf8 -Path (Join-Path $botRoot 'config/local-runtime.psd1') -Text $runtimeConfig

    $initialJson = @"
{
  "provider": [
    {
      "id": "cloud-chat",
      "type": "text_chat",
      "api_key": "$secret",
      "display_name": "中文聊天模型"
    }
  ],
  "provider_tts_settings": {
    "enable": false,
    "provider_id": ""
  },
  "provider_settings": {
    "default_personality": "old-persona"
  },
  "unrelated": {
    "中文说明": "不可改变",
    "number": 42
  }
}
"@
    $configPath = Join-Path $botRoot 'data/cmd_config.json'
    Write-Utf8 -Path $configPath -Text $initialJson

    $gptAsset = Join-Path $packRoot 'assets/gpt/fake.ckpt'
    $sovitsAsset = Join-Path $packRoot 'assets/sovits/fake.pth'
    $referenceAsset = Join-Path $packRoot 'assets/reference/fake.wav'
    Write-Utf8 -Path $gptAsset -Text "fake-gpt`n"
    Write-Utf8 -Path $sovitsAsset -Text "fake-sovits`n"
    Write-Utf8 -Path $referenceAsset -Text "fake-audio`n"

    $voiceManifest = [ordered]@{
        format_version = 1
        pack_id = 'isolated-test-voice'
        display_name = '隔离测试语音'
        files = [ordered]@{
            gpt_weights = [ordered]@{ relative_path = 'assets/gpt/fake.ckpt'; sha256 = Get-HashLower $gptAsset }
            sovits_weights = [ordered]@{ relative_path = 'assets/sovits/fake.pth'; sha256 = Get-HashLower $sovitsAsset }
            reference_audio = [ordered]@{ relative_path = 'assets/reference/fake.wav'; sha256 = Get-HashLower $referenceAsset }
        }
        astrbot = [ordered]@{
            provider_id = 'isolated-gsv-provider'
            timeout = 120
            gsv_default_parms = [ordered]@{
                text_lang = 'zh'
                prompt_lang = 'zh'
                prompt_text = '你好，隔离测试'
                gsv_ref_audio_path = 'assets/reference/fake.wav'
            }
        }
    }
    Write-Utf8 -Path (Join-Path $packRoot 'manifest.json') -Text (($voiceManifest | ConvertTo-Json -Depth 20) + [Environment]::NewLine)

    & (Join-Path $botRoot 'scripts/Install-VoicePack.ps1') -BotProjectPath $botRoot -PackRoot $packRoot -NoStart
    $afterVoice = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-Equal $secret $afterVoice.provider[0].api_key 'Voice import must preserve unrelated simulated secret'
    Assert-Equal '中文聊天模型' $afterVoice.provider[0].display_name 'Voice import must preserve Chinese provider text'
    Assert-Equal '不可改变' $afterVoice.unrelated.中文说明 'Voice import must preserve unrelated Chinese configuration'
    Assert-Equal 'isolated-gsv-provider' $afterVoice.provider_tts_settings.provider_id 'Voice import must select imported provider'
    $installedProvider = @($afterVoice.provider | Where-Object { $_.id -eq 'isolated-gsv-provider' }) | Select-Object -First 1
    Assert-True ($null -ne $installedProvider) 'Voice import must add a provider'
    Assert-True (Test-Path -LiteralPath $installedProvider.gpt_weights_path -PathType Leaf) 'Voice import must copy fake GPT asset'
    Assert-True (Test-Path -LiteralPath $installedProvider.sovits_weights_path -PathType Leaf) 'Voice import must copy fake SoVITS asset'
    Assert-True (Test-Path -LiteralPath $installedProvider.gsv_default_parms.gsv_ref_audio_path -PathType Leaf) 'Voice import must copy fake reference audio'

    $repeatOutput = ''
    $repeatFailed = $false
    try {
        & (Join-Path $botRoot 'scripts/Install-VoicePack.ps1') -BotProjectPath $botRoot -PackRoot $packRoot -NoStart *>&1 | ForEach-Object { $repeatOutput += [string]$_ + "`n" }
    }
    catch {
        $repeatFailed = $true
        $repeatOutput += [string]$_.Exception.Message
    }
    Assert-True $repeatFailed 'Repeated voice import must fail'
    Assert-True ($repeatOutput.Contains('Repeated import was safely refused')) 'Repeated voice import must explain safe refusal'
    Assert-True (-not $repeatOutput.Contains($secret)) 'Repeated voice import error must not leak simulated secret'

    $personaPromptPath = Join-Path $personaRoot 'assets/system-prompt.md'
    Write-Utf8 -Path $personaPromptPath -Text "你是一个隔离测试人格。`n"
    Write-Utf8 -Path (Join-Path $personaRoot 'README.md') -Text "# isolated persona`n"
    Write-Utf8 -Path (Join-Path $personaRoot 'LICENSE-AND-AUTHORIZATION.md') -Text "authorized for isolated test`n"
    $personaManifest = [ordered]@{
        format_version = 1
        kind = 'astrbot-persona'
        pack_id = 'isolated-persona'
        display_name = '隔离测试人格'
        astrbot = [ordered]@{ persona_id = 'isolated-persona-id'; begin_dialogs = @() }
        files = [ordered]@{
            system_prompt = [ordered]@{
                relative_path = 'assets/system-prompt.md'
                sha256 = Get-HashLower $personaPromptPath
                bytes = (Get-Item -LiteralPath $personaPromptPath).Length
            }
        }
    }
    Write-Utf8 -Path (Join-Path $personaRoot 'manifest.json') -Text (($personaManifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)

    & (Join-Path $botRoot 'scripts/Install-PersonaPack.ps1') -BotProjectPath $botRoot -PackRoot $personaRoot -NoBrowser -NoClipboard -SetAsDefault
    $afterPersona = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-Equal 'isolated-persona-id' $afterPersona.provider_settings.default_personality 'Persona import must atomically set default persona'
    Assert-Equal $secret $afterPersona.provider[0].api_key 'Persona import must preserve simulated secret'
    Assert-Equal '不可改变' $afterPersona.unrelated.中文说明 'Persona import must preserve unrelated Chinese configuration'
    Assert-True (Test-Path -LiteralPath (Join-Path $botRoot 'persona-imports/isolated-persona/assets/system-prompt.md')) 'Persona pack must be saved in persona-imports/pack_id'

    $backups = @(Get-ChildItem -LiteralPath (Join-Path $botRoot 'backups') -Filter '*.json' -File)
    Assert-True ($backups.Count -ge 2) 'Successful voice and persona updates must each create backups'

    $cleanupBotRoot = Join-Path $fixtureRoot 'fake-bot-cleanup'
    Copy-Item -LiteralPath $botRoot -Destination $cleanupBotRoot -Recurse
    $cleanupConfigPath = Join-Path $cleanupBotRoot 'data/cmd_config.json'
    $cleanupConfigBefore = [System.IO.File]::ReadAllBytes($cleanupConfigPath)
    $cleanupBackupsPath = Join-Path $cleanupBotRoot 'backups'
    if (Test-Path -LiteralPath $cleanupBackupsPath) { Remove-Item -LiteralPath $cleanupBackupsPath -Recurse -Force }
    Write-Utf8 -Path $cleanupBackupsPath -Text "This file intentionally blocks creation of the backups directory.`n"
    foreach ($cleanupPath in @(
        (Join-Path $fakeGsv 'GPT_weights_v2ProPlus/isolated-test-voice-fake.ckpt'),
        (Join-Path $fakeGsv 'SoVITS_weights_v2ProPlus/isolated-test-voice-fake.pth'),
        (Join-Path $fakeGsv 'reference_audio/isolated-test-voice/fake.wav')
    )) {
        if (Test-Path -LiteralPath $cleanupPath) { Remove-Item -LiteralPath $cleanupPath -Force }
    }
    $cleanupOutput = ''
    $cleanupFailed = $false
    try {
        & (Join-Path $cleanupBotRoot 'scripts/Install-VoicePack.ps1') -BotProjectPath $cleanupBotRoot -PackRoot $packRoot -NoStart *>&1 | ForEach-Object { $cleanupOutput += [string]$_ + "`n" }
    }
    catch {
        $cleanupFailed = $true
        $cleanupOutput += [string]$_.Exception.Message
    }
    Assert-True $cleanupFailed 'Voice import must fail when the atomic backup location cannot be created'
    Assert-True (-not $cleanupOutput.Contains($secret)) 'Voice import failure must not leak simulated secret'
    Assert-True ([System.Linq.Enumerable]::SequenceEqual([byte[]]$cleanupConfigBefore, [byte[]][System.IO.File]::ReadAllBytes($cleanupConfigPath))) 'Voice import failure must leave config byte-for-byte unchanged'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fakeGsv 'GPT_weights_v2ProPlus/isolated-test-voice-fake.ckpt'))) 'Failed voice import must not leave GPT asset'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fakeGsv 'SoVITS_weights_v2ProPlus/isolated-test-voice-fake.pth'))) 'Failed voice import must not leave SoVITS asset'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fakeGsv 'reference_audio/isolated-test-voice/fake.wav'))) 'Failed voice import must not leave reference audio'

    Write-Host '[PASS] Isolated fake voice/persona import regression tests passed; no real bot, credentials, weights, or audio were used.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

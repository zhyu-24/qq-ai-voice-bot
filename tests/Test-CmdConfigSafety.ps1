[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repoRoot 'scripts/CmdConfig.Common.ps1'
. $helperPath

$fixtureRoot = Join-Path $PSScriptRoot '.tmp-cmd-config-safety'
$secret = 'SIMULATED_SECRET_DO_NOT_PRINT_7f4a2d'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ([string]$Expected -cne [string]$Actual) {
        throw "ASSERTION FAILED: $Message. Expected '$Expected', got '$Actual'."
    }
}

function Write-Utf8Fixture {
    param([string]$Path, [string]$Text)
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

try {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
    [System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null

    $configPath = Join-Path $fixtureRoot 'data/cmd_config.json'
    $backupRoot = Join-Path $fixtureRoot 'backups'
    $initialJson = @"
{
  "provider": [
    {
      "id": "existing-provider",
      "type": "text_chat",
      "api_key": "$secret",
      "中文字段": "你好，世界"
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
    "nested": [1, 2, 3],
    "说明": "必须保持"
  }
}
"@
    Write-Utf8Fixture -Path $configPath -Text $initialJson

    $config = Read-StrictUtf8Json -Path $configPath -Label 'AstrBot configuration'
    Assert-Equal '你好，世界' $config.provider[0].中文字段 'Strict UTF-8 read must preserve Chinese text'
    Assert-Equal $secret $config.provider[0].api_key 'Strict UTF-8 read must preserve simulated secret'

    $config.provider_settings.default_personality = '新人格-id'
    $validate = {
        param($candidate)
        if ([string]$candidate.provider_settings.default_personality -ne '新人格-id') {
            throw 'Persona validation failed.'
        }
    }
    $backupPath = Write-AtomicUtf8Json -Path $configPath -Value $config -BackupDirectory $backupRoot -BackupPrefix 'cmd_config.before-test' -Validate $validate -Label 'AstrBot configuration' -Depth 30
    Assert-True (Test-Path -LiteralPath $backupPath -PathType Leaf) 'Atomic write must create a backup'

    $updated = Read-StrictUtf8Json -Path $configPath -Label 'AstrBot configuration'
    Assert-Equal '新人格-id' $updated.provider_settings.default_personality 'Persona default must be updated'
    Assert-Equal '你好，世界' $updated.provider[0].中文字段 'Chinese text must survive atomic write'
    Assert-Equal $secret $updated.provider[0].api_key 'Unrelated secret field must survive unchanged'
    Assert-Equal '必须保持' $updated.unrelated.说明 'Unrelated nested configuration must survive unchanged'
    Assert-Equal 3 $updated.unrelated.nested.Count 'Unrelated arrays must survive unchanged'

    $beforeMalformed = [System.IO.File]::ReadAllBytes($configPath)
    $malformedPath = Join-Path $fixtureRoot 'data/malformed.json'
    Write-Utf8Fixture -Path $malformedPath -Text ('{"api_key":"' + $secret + '", invalid')
    $safeError = ''
    try {
        Read-StrictUtf8Json -Path $malformedPath -Label 'AstrBot configuration' | Out-Null
        throw 'Malformed JSON was unexpectedly accepted.'
    }
    catch {
        $safeError = [string]$_.Exception.Message
    }
    Assert-True (-not $safeError.Contains($secret)) 'Malformed JSON error must not leak simulated secret'
    Assert-True (-not $safeError.Contains('invalid')) 'Malformed JSON error must not include input fragments'
    Assert-True ([System.Linq.Enumerable]::SequenceEqual([byte[]]$beforeMalformed, [byte[]][System.IO.File]::ReadAllBytes($configPath))) 'Malformed JSON handling must not alter valid config'

    $invalidUtf8Path = Join-Path $fixtureRoot 'data/invalid-utf8.json'
    [System.IO.File]::WriteAllBytes($invalidUtf8Path, [byte[]](0x7B, 0x22, 0x78, 0x22, 0x3A, 0x22, 0xC3, 0x28, 0x22, 0x7D))
    $utf8Error = ''
    try {
        Read-StrictUtf8Json -Path $invalidUtf8Path -Label 'AstrBot configuration' | Out-Null
        throw 'Invalid UTF-8 was unexpectedly accepted.'
    }
    catch {
        $utf8Error = [string]$_.Exception.Message
    }
    Assert-True ($utf8Error.Contains('not valid UTF-8')) 'Invalid UTF-8 must be rejected with a fixed safe message'

    $beforeValidationFailure = [System.IO.File]::ReadAllBytes($configPath)
    $candidate = Read-StrictUtf8Json -Path $configPath -Label 'AstrBot configuration'
    $candidate.provider_settings.default_personality = 'should-not-commit'
    $rejectAll = { param($value) throw 'Simulated validation failure.' }
    try {
        Write-AtomicUtf8Json -Path $configPath -Value $candidate -BackupDirectory $backupRoot -BackupPrefix 'cmd_config.before-reject' -Validate $rejectAll -Label 'AstrBot configuration' -Depth 30 | Out-Null
        throw 'Validation failure was unexpectedly accepted.'
    }
    catch {
        Assert-True (-not ([string]$_.Exception.Message).Contains($secret)) 'Atomic-write failure must not leak simulated secret'
    }
    Assert-True ([System.Linq.Enumerable]::SequenceEqual([byte[]]$beforeValidationFailure, [byte[]][System.IO.File]::ReadAllBytes($configPath))) 'Validation failure must leave original file byte-for-byte unchanged'
    Assert-True (-not @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter '*.tmp' -Force).Count) 'Validation failure must not leave temp files'

    if ($IsWindows) {
        $beforeLockedFailure = [System.IO.File]::ReadAllBytes($configPath)
        $lockedCandidate = Read-StrictUtf8Json -Path $configPath -Label 'AstrBot configuration'
        $lockedCandidate.provider_settings.default_personality = 'blocked-by-lock'
        $validateLockedCandidate = {
            param($candidateValue)
            if ([string]$candidateValue.provider_settings.default_personality -ne 'blocked-by-lock') {
                throw 'Locked candidate validation failed.'
            }
        }
        $lockStream = New-Object System.IO.FileStream($configPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            try {
                Write-AtomicUtf8Json -Path $configPath -Value $lockedCandidate -BackupDirectory $backupRoot -BackupPrefix 'cmd_config.before-lock' -Validate $validateLockedCandidate -Label 'AstrBot configuration' -Depth 30 | Out-Null
                throw 'Locked-file replacement was unexpectedly accepted.'
            }
            catch {
                Assert-True (([string]$_.Exception.Message).Contains('original file was preserved')) 'Locked-file replacement must report preservation of the original'
                Assert-True (-not ([string]$_.Exception.Message).Contains($secret)) 'Locked-file replacement error must not leak simulated secret'
            }
        }
        finally {
            $lockStream.Dispose()
        }
        Assert-True ([System.Linq.Enumerable]::SequenceEqual([byte[]]$beforeLockedFailure, [byte[]][System.IO.File]::ReadAllBytes($configPath))) 'Locked-file replacement failure must leave original file byte-for-byte unchanged'
        Assert-True (-not @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter '*.tmp' -Force).Count) 'Locked-file replacement failure must clean up temp files'
    }
    else {
        Write-Host '[SKIP] Windows file-lock replacement failure test requires NTFS/Windows sharing semantics.'
    }

    foreach ($relativePath in @(
        'scripts/Get-LocalBotStatus.ps1',
        'scripts/Start-LocalBot.ps1',
        'scripts/Install-PersonaPack.ps1',
        'scripts/Install-VoicePack.ps1',
        'scripts/New-VoicePack.ps1',
        'shareable-template/scripts/Get-LocalBotStatus.ps1',
        'shareable-template/scripts/Start-LocalBot.ps1',
        'shareable-template/scripts/Install-PersonaPack.ps1',
        'shareable-template/scripts/Install-VoicePack.ps1',
        'voice-pack-template/scripts/Install-VoicePack.ps1'
    )) {
        $text = [System.IO.File]::ReadAllText((Join-Path $repoRoot $relativePath), $utf8)
        Assert-True (-not ($text -match 'Get-Content[^\r\n]*cmd_config')) "$relativePath must not read cmd_config.json with Get-Content"
        Assert-True (-not ($text -match 'WriteAllText\(\$astrConfigPath')) "$relativePath must not directly overwrite cmd_config.json"
    }

    $setupCenterText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts/Setup-Center.ps1'), $utf8)
    Assert-True ($setupCenterText.Contains("@('-PersonaPackZip', `$script:PersonaPackTextBox.Text, '-NoBrowser', '-NoClipboard', '-SetAsDefault')")) 'Setup Center persona button arguments must remain unchanged'
    Assert-True ($setupCenterText.Contains("@('-VoicePackZip', `$script:VoicePackTextBox.Text)")) 'Setup Center voice button arguments must remain unchanged'

    $rootVoice = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts/Install-VoicePack.ps1'), $utf8)
    Assert-True ($rootVoice.Contains('Repeated import was safely refused.')) 'Voice installer must safely refuse repeated imports'
    Assert-True ($rootVoice.Contains('$createdAssetPaths')) 'Voice installer must track newly created assets for cleanup'

    Write-Host '[PASS] cmd_config.json safety regression tests passed in an isolated fake-credential fixture.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

function Read-StrictUtf8Text {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Label = 'File'
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    }
    catch {
        throw "Could not read $Label."
    }

    if ($bytes.Length -ge 2) {
        $hasUtf16Bom = (($bytes[0] -eq 0xFF) -and ($bytes[1] -eq 0xFE)) -or (($bytes[0] -eq 0xFE) -and ($bytes[1] -eq 0xFF))
        $hasUtf32BeBom = $bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF
        if ($hasUtf16Bom -or $hasUtf32BeBom) {
            throw "$Label must use UTF-8 encoding."
        }
    }

    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $strictUtf8.GetString($bytes)
    }
    catch {
        throw "$Label is not valid UTF-8."
    }

    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) {
        $text = $text.Substring(1)
    }
    return $text
}

function Read-StrictUtf8Json {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Label = 'JSON file'
    )

    $text = Read-StrictUtf8Text -Path $Path -Label $Label
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$Label is empty."
    }

    try {
        $value = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "$Label is not valid JSON."
    }

    if ($null -eq $value -or $value -is [System.Array] -or $value -is [string] -or $value -is [ValueType]) {
        throw "$Label must contain one JSON object at the top level."
    }
    return $value
}

function ConvertTo-ValidatedUtf8Json {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Value,
        [scriptblock]$Validate,
        [string]$Label = 'JSON file',
        [int]$Depth = 50
    )

    try {
        $json = $Value | ConvertTo-Json -Depth $Depth -ErrorAction Stop
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $bytes = $strictUtf8.GetBytes($json + [Environment]::NewLine)
        $roundTripText = $strictUtf8.GetString($bytes)
        $roundTripValue = $roundTripText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "$Label could not be serialized as valid UTF-8 JSON."
    }

    if ($null -ne $Validate) {
        & $Validate $roundTripValue
    }

    return [pscustomobject]@{
        Bytes = $bytes
        Value = $roundTripValue
    }
}

function Write-AtomicUtf8Json {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$BackupPrefix,
        [scriptblock]$Validate,
        [string]$Label = 'JSON file',
        [int]$Depth = 50,
        [scriptblock]$AfterCommit
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $targetDirectory = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
        throw "The folder containing $Label does not exist."
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "$Label does not exist."
    }

    $validated = ConvertTo-ValidatedUtf8Json -Value $Value -Validate $Validate -Label $Label -Depth $Depth
    [System.IO.Directory]::CreateDirectory($BackupDirectory) | Out-Null

    $uniqueId = [Guid]::NewGuid().ToString('N')
    $tempPath = Join-Path $targetDirectory ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + $uniqueId + '.tmp')
    $backupPath = Join-Path $BackupDirectory ($BackupPrefix + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $uniqueId.Substring(0, 8) + '.json')
    $restorePath = $null
    $discardPath = $null
    $committed = $false
    $rollbackSucceeded = $true

    try {
        $stream = New-Object System.IO.FileStream($tempPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $stream.Write($validated.Bytes, 0, $validated.Bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }

        $tempValue = Read-StrictUtf8Json -Path $tempPath -Label $Label
        if ($null -ne $Validate) {
            & $Validate $tempValue
        }

        [System.IO.File]::Replace($tempPath, $fullPath, $backupPath, $true)
        $committed = $true

        $installedValue = Read-StrictUtf8Json -Path $fullPath -Label $Label
        if ($null -ne $Validate) {
            & $Validate $installedValue
        }
        if ($null -ne $AfterCommit) {
            & $AfterCommit $installedValue
        }

        return $backupPath
    }
    catch {
        if ($committed -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            try {
                $restorePath = Join-Path $targetDirectory ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [Guid]::NewGuid().ToString('N') + '.restore')
                [System.IO.File]::Copy($backupPath, $restorePath, $false)
                $discardPath = Join-Path $targetDirectory ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [Guid]::NewGuid().ToString('N') + '.discard')
                [System.IO.File]::Replace($restorePath, $fullPath, $discardPath, $true)
                $restorePath = $null
                if (Test-Path -LiteralPath $discardPath) {
                    Remove-Item -LiteralPath $discardPath -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                $rollbackSucceeded = $false
            }
        }
        if (-not $rollbackSucceeded) {
            throw "Could not safely update $Label, and automatic rollback also failed. Restore it from: $backupPath"
        }
        throw "Could not safely update $Label. The original file was preserved."
    }
    finally {
        foreach ($cleanupPath in @($tempPath, $restorePath, $discardPath)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$cleanupPath) -and (Test-Path -LiteralPath $cleanupPath)) {
                Remove-Item -LiteralPath $cleanupPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

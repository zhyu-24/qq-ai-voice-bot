[CmdletBinding()]
param(
    [int]$StartupDelaySeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'Start-LocalBot.ps1'
$taskName = 'Local QQ AI Voice Bot'
$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing start script: $scriptPath"
}

$arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $scriptPath + '" -StartupDelaySeconds ' + $StartupDelaySeconds
$action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Starts local AstrBot and GPT-SoVITS after the user logs in.' -Force | Out-Null

Write-Host '[DONE] Login autostart has been registered.'
Write-Host "Task: $taskName"
Write-Host "Delay: $StartupDelaySeconds seconds"
Write-Host 'Set your VPN client itself to auto-connect before login if QQ requires a whitelisted VPN egress IP.'

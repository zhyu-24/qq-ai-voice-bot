[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'Local QQ AI Voice Bot'
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -eq $existingTask) {
    Write-Host '[INFO] No local bot autostart task was registered.'
    exit 0
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Write-Host '[DONE] Login autostart has been removed.'

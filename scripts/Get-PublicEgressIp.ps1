[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    $reply = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 10
    $ip = [string]$reply.ip
    if ([string]::IsNullOrWhiteSpace($ip)) {
        throw 'The public IP service returned no address.'
    }
    Write-Host "[INFO] Current public egress IP: $ip"
}
catch {
    Write-Error "Could not check the public egress IP: $($_.Exception.Message)"
    exit 1
}

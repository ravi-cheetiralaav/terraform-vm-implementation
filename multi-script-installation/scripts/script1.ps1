# script1.ps1
# Receives -Param1 from Terraform via CustomScriptExtension commandToExecute.
# Runs independently — no knowledge of script2 or script3 required.

param(
    [Parameter(Mandatory = $true)]
    [string]$Param1
)

$logFile = "C:\Logs\script1.log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [script1] $Message" | Tee-Object -FilePath $logFile -Append
}

Write-Log "Starting script1.ps1"
Write-Log "Received Param1 = '$Param1'"

function Set-RegistryDword {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}

try {
    Write-Log "Enabling RDP connections (fDenyTSConnections=0)."
    Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0

    Write-Log "Enforcing NLA for RDP (UserAuthentication=1)."
    Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1

    Write-Log "Setting RDP security layer (SecurityLayer=1)."
    Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value 1

    Write-Log "Enabling Windows Firewall rules for Remote Desktop."
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop

    Write-Log "Ensuring Remote Desktop Services is set to Automatic and running."
    Set-Service -Name "TermService" -StartupType Automatic
    if ((Get-Service -Name "TermService").Status -ne "Running") {
        Start-Service -Name "TermService"
    }

    # Param1 is treated as a local username to grant RDP access.
    # Example terraform value: param1 = "azureadmin"
    $localUser = Get-LocalUser -Name $Param1 -ErrorAction SilentlyContinue
    if ($null -ne $localUser) {
        Write-Log "Found local user '$($localUser.Name)'. Adding to 'Remote Desktop Users' group."
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $localUser.Name -ErrorAction SilentlyContinue
        Write-Log "RDP remediation completed successfully for local user '$($localUser.Name)'."
    }
    else {
        Write-Log "WARNING: Local user '$Param1' was not found. Skipping group membership update."
        Write-Log "RDP/NLA/service/firewall remediation completed; user assignment step skipped."
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}

Write-Log "script1.ps1 completed successfully."

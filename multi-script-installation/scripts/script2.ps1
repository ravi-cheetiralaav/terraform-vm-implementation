# script2.ps1
# Receives -Param2 from Terraform via CustomScriptExtension commandToExecute.
# Runs independently — no knowledge of script1 or script3 required.

param(
    [Parameter(Mandatory = $true)]
    [string]$Param2
)

$logFile = "C:\Logs\script2.log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [script2] $Message" | Tee-Object -FilePath $logFile -Append
}

Write-Log "Starting script2.ps1"
Write-Log "Received Param2 = '$Param2'"

# ---------------------------------------------------------
# TODO: Replace this section with your actual installation
#       or configuration logic that uses $Param2.
# ---------------------------------------------------------
Write-Log "Performing script2 action with Param2='$Param2'..."
Start-Sleep -Seconds 2   # Simulated work

Write-Log "script2.ps1 completed successfully."

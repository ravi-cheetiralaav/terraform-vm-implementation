# script3.ps1
# Receives -Param3 from Terraform via CustomScriptExtension commandToExecute.
# Runs independently — no knowledge of script1 or script2 required.

param(
    [Parameter(Mandatory = $true)]
    [string]$Param3
)

$logFile = "C:\Logs\script3.log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [script3] $Message" | Tee-Object -FilePath $logFile -Append
}

Write-Log "Starting script3.ps1"
Write-Log "Received Param3 = '$Param3'"

# ---------------------------------------------------------
# TODO: Replace this section with your actual installation
#       or configuration logic that uses $Param3.
# ---------------------------------------------------------
Write-Log "Performing script3 action with Param3='$Param3'..."
Start-Sleep -Seconds 2   # Simulated work

Write-Log "script3.ps1 completed successfully."

# Software Installation Script for Windows Server
# This script downloads, extracts, and installs Notepad++ from a ZIP file

# Set error action preference
$ErrorActionPreference = "Continue"

# Create log file
$logFile = "C:\Windows\Temp\software-install.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "=== Software Installation Started ==="

# Get current working directory (where Azure extension downloads files)
$currentDir = Get-Location
Write-Log "Current working directory: $currentDir"

# Create installation directory
$installDir = "C:\Temp\software"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Log "Created installation directory: $installDir"
}

# Define software ZIP file (look in current directory first)
$zipFile = "npp.8.9.1.Installer.x64.zip"
$zipFilePath = $null

# Check current directory first (where extension downloads files)
if (Test-Path ".\$zipFile") {
    $zipFilePath = ".\$zipFile"
    Write-Log "Found ZIP file in current directory: $zipFilePath"
} elseif (Test-Path "$installDir\$zipFile") {
    $zipFilePath = "$installDir\$zipFile"
    Write-Log "Found ZIP file in install directory: $zipFilePath"
} else {
    Write-Log "ERROR: ZIP file not found in current directory or install directory"
    Write-Log "Current directory contents:"
    Get-ChildItem . | ForEach-Object { Write-Log "  $($_.Name)" }
}
$extractDir = "$installDir\extracted"

try {
    # Check if ZIP file exists
    if ($zipFilePath) {
        Write-Log "Processing ZIP file: $zipFilePath"
        
        # Create extraction directory
        if (!(Test-Path $extractDir)) {
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            Write-Log "Created extraction directory: $extractDir"
        }
        
        # Extract ZIP file
        Write-Log "Extracting ZIP file..."
        Expand-Archive -Path $zipFilePath -DestinationPath $extractDir -Force
        Write-Log "Successfully extracted ZIP file"
        
        # Find the installer executable
        $installerExe = Get-ChildItem -Path $extractDir -Filter "*.exe" -Recurse | Select-Object -First 1
        
        if ($installerExe) {
            Write-Log "Found installer: $($installerExe.Name)"
            
            # Install software silently
            Write-Log "Starting installation..."
            $installProcess = Start-Process -FilePath $installerExe.FullName -ArgumentList "/S" -Wait -PassThru -NoNewWindow
            
            if ($installProcess.ExitCode -eq 0) {
                Write-Log "Successfully installed $($installerExe.Name) - Exit Code: 0"
            } else {
                Write-Log "Installation completed with exit code: $($installProcess.ExitCode)"
            }
        } else {
            Write-Log "ERROR: No .exe installer found in the extracted files"
        }
    } else {
        Write-Log "ERROR: ZIP file not found: $zipFile"
    }
} catch {
    Write-Log "ERROR: Installation failed - $($_.Exception.Message)"
}

Write-Log "=== Software Installation Completed ==="
Write-Log "Log file location: $logFile"

# Keep the extracted files for verification, but you can uncomment below to clean up
# Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue

exit 0

# Simple Setup Script for Windows Server
# Parameters from Terraform template
$Server = "${ServerParam}"
$Tags = "${TagsParam}"

# Start transcript logging to capture everything
$logFile = "C:\script_execution_log.txt"
Start-Transcript -Path $logFile -Force

try {
    Write-Output "=== SCRIPT EXECUTION STARTED ==="
    Write-Output "Script started at: $(Get-Date)"
    Write-Output "Server Parameter: $Server"
    Write-Output "Tags Parameter: $Tags"
    Write-Output "Current User: $env:USERNAME"
    Write-Output "Current Directory: $(Get-Location)"
    Write-Output "PowerShell Version: $($PSVersionTable.PSVersion)"

    # Create software directory and timestamped subfolder to prove script execution
    $softwareDir = "C:\software"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $folderName = "$Server" + "_" + "$timestamp"
    $timestampDir = Join-Path $softwareDir $folderName

    Write-Output "=== DIRECTORY CREATION PHASE ==="
    Write-Output "Target software directory: $softwareDir"
    Write-Output "Target timestamped directory: $timestampDir"

    # Check current user permissions
    Write-Output "Checking permissions..."
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    Write-Output "Current user: $($currentUser.Name)"

    # Create software directory if it doesn't exist
    Write-Output "Checking if software directory exists..."
    if (-not (Test-Path $softwareDir)) {
        Write-Output "Software directory does not exist. Creating..."
        try {
            New-Item -ItemType Directory -Path $softwareDir -Force -ErrorAction Stop
            Write-Output "SUCCESS: Created software directory: $softwareDir"
        }
        catch {
            Write-Output "ERROR creating software directory: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Output "Software directory already exists: $softwareDir"
    }

    # Verify software directory was created
    if (Test-Path $softwareDir) {
        Write-Output "CONFIRMED: Software directory exists at $softwareDir"
    } else {
        Write-Output "FAILED: Software directory not found at $softwareDir"
        throw "Failed to create software directory"
    }

    # Create timestamped subdirectory with server name
    Write-Output "Creating timestamped subdirectory..."
    try {
        New-Item -ItemType Directory -Path $timestampDir -Force -ErrorAction Stop
        Write-Output "SUCCESS: Created timestamped directory: $timestampDir"
    }
    catch {
        Write-Output "ERROR creating timestamped directory: $($_.Exception.Message)"
        throw
    }

    # Verify timestamped directory was created
    if (Test-Path $timestampDir) {
        Write-Output "CONFIRMED: Timestamped directory exists at $timestampDir"
    } else {
        Write-Output "FAILED: Timestamped directory not found at $timestampDir"
        throw "Failed to create timestamped directory"
    }

    # Create text file with tags content
    Write-Output "Creating tags file..."
    $tagsFile = Join-Path $timestampDir "tags.txt"
    try {
        $Tags | Out-File -FilePath $tagsFile -Encoding UTF8 -ErrorAction Stop
        Write-Output "SUCCESS: Created tags file: $tagsFile"
    }
    catch {
        Write-Output "ERROR creating tags file: $($_.Exception.Message)"
    }

    # Create a simple test file to confirm script execution
    Write-Output "Creating test file..."
    $testFile = Join-Path $timestampDir "script_executed.txt"
    try {
        "Script executed successfully at $(Get-Date)" | Out-File -FilePath $testFile -Encoding UTF8 -ErrorAction Stop
        Write-Output "SUCCESS: Created test file: $testFile"
    }
    catch {
        Write-Output "ERROR creating test file: $($_.Exception.Message)"
    }

    # Create a simple marker file on C:\ root
    Write-Output "Creating root marker file..."
    $markerFile = "C:\SCRIPT_RAN_SUCCESSFULLY_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    try {
        "Script executed successfully - Server: $Server - Time: $(Get-Date)" | Out-File -FilePath $markerFile -Encoding UTF8 -ErrorAction Stop
        Write-Output "SUCCESS: Created marker file: $markerFile"
    }
    catch {
        Write-Output "ERROR creating marker file: $($_.Exception.Message)"
    }

    Write-Output "=== FINAL VERIFICATION ==="
    Write-Output "Listing C:\ contents:"
    Get-ChildItem C:\ | ForEach-Object { Write-Output "  $($_.Name)" }
    
    Write-Output "Checking software directory contents:"
    if (Test-Path $softwareDir) {
        Get-ChildItem $softwareDir -Recurse | ForEach-Object { Write-Output "  $($_.FullName)" }
    }

    Write-Output "=== SCRIPT COMPLETED SUCCESSFULLY ==="
    exit 0
}
catch {
    Write-Output "=== SCRIPT FAILED ==="
    Write-Output "ERROR: $($_.Exception.Message)"
    Write-Output "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    Stop-Transcript
}
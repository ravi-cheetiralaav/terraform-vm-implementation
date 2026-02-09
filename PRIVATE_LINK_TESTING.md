# Private Link Testing Guide

## Connection Info
- **VM Public IP**: `20.191.224.13`
- **Username**: `azureadmin`
- **Storage Account**: `safec2805e`

## Test 1: DNS Resolution
```powershell
# Should resolve to private IP (10.0.1.x)
nslookup safec2805e.blob.core.windows.net
```

## Test 2: Download Files with Managed Identity
```powershell
# Get access token
$response = Invoke-WebRequest -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/" -Headers @{Metadata="true"}
$token = ($response.Content | ConvertFrom-Json).access_token
$headers = @{"Authorization" = "Bearer $token"}

# Download script
$url = "https://safec2805e.blob.core.windows.net/software/install-software.ps1"
Invoke-WebRequest -Uri $url -Headers $headers -OutFile "C:\temp\downloaded-script.ps1"

# Download ZIP
$zipUrl = "https://safec2805e.blob.core.windows.net/software/npp.8.9.1.Installer.x64.zip"
Invoke-WebRequest -Uri $zipUrl -Headers $headers -OutFile "C:\temp\downloaded-software.zip"

# Verify downloads
Get-ChildItem C:\temp\
```

## Test 3: Verify Network Path
```powershell
# Should show private IP connection
Test-NetConnection safec2805e.blob.core.windows.net -Port 443
```

## Test 4: Check Extension Results
```powershell
# Verify Notepad++ installation
Get-ChildItem "C:\Program Files\Notepad++" -ErrorAction SilentlyContinue
```

## Expected Results
- DNS resolves to `10.0.1.4` (private IP)
- Files download successfully via managed identity
- Network traffic uses private endpoint
- Notepad++ installed successfully
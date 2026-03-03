# VM to Storage Account Private Link Deployment Guide

This guide outlines all the components and steps required to deploy a VM that can connect to a storage account using a user-managed identity over private link with no internet connectivity.

## Infrastructure Components Required

### 1. **Virtual Network Setup**
- Create a Virtual Network (VNet) with appropriate address space
- Create a subnet for the VM
- Create a dedicated subnet for private endpoints
- Configure Network Security Groups (NSGs) to block internet access and allow internal communication

### 2. **User-Assigned Managed Identity**
- Create a user-assigned managed identity
- This will be used by the VM to authenticate to the storage account

### 3. **Storage Account Configuration**
- Create storage account with blob containers
- **Critical**: Configure storage account to deny public network access
- Enable "Allow Azure services on the trusted services list to access this storage account" if needed
- Create the blob containers and upload your files

### 4. **Private Endpoint for Storage Account**
- Create a private endpoint for the storage account blob service
- Deploy it in the dedicated private endpoint subnet
- This creates a private IP for the storage account within your VNet

### 5. **DNS Configuration**
- Create a Private DNS Zone for `privatelink.blob.core.windows.net`
- Link the Private DNS Zone to your Virtual Network
- Configure DNS records for the private endpoint (usually auto-created)
- Ensure the VM can resolve the storage account FQDN to the private IP

### 6. **Virtual Machine Deployment**
- Deploy VM in the VM subnet
- Assign the user-assigned managed identity to the VM
- Configure VM to use the VNet's DNS settings

### 7. **RBAC Permissions**
- Assign appropriate storage roles to the managed identity:
  - `Storage Blob Data Reader` (minimum for downloading files)
  - `Storage Blob Data Contributor` (if you need read/write access)
- Scope the role assignment to the storage account or specific containers

### 8. **Network Security Configuration**
- Configure NSG rules to:
  - Allow communication between VM and storage private endpoint
  - Block all outbound internet traffic
  - Allow internal VNet communication as needed

## Deployment Order

1. **VNet and Subnets** → **NSGs**
2. **User-Assigned Managed Identity**
3. **Storage Account** (with public access denied)
4. **Private DNS Zone**
5. **Private Endpoint** for storage account
6. **Link DNS Zone to VNet**
7. **Deploy VM** with managed identity assigned
8. **Configure RBAC** permissions
9. **Test connectivity** from VM to storage account

## Key Considerations

### Security Requirements
- **DNS Resolution**: Ensure the VM resolves `storageaccount.blob.core.windows.net` to the private endpoint IP
- **Firewall Rules**: Storage account should have firewall rules to deny public access
- **Managed Identity**: VM must have the managed identity assigned and proper RBAC roles
- **Private Link**: Traffic flows entirely within Azure backbone, never touches public internet

### Network Configuration
- All traffic must flow through private endpoints
- No public IP addresses should be assigned to the VM
- NSG rules must block internet access while allowing private endpoint communication
- DNS must be properly configured to resolve storage account to private IP

### Testing and Validation
- Use tools like `nslookup`, `Test-NetConnection`, or storage SDK to verify connectivity
- Test managed identity authentication to storage account
- Verify file download capabilities from blob storage
- Ensure no traffic flows over public internet

## Security Benefits

This setup ensures:
- **Zero Trust Network**: No public internet connectivity
- **Identity-based Authentication**: Using Azure AD managed identities instead of keys
- **Private Connectivity**: All traffic flows over Azure's private network infrastructure
- **Least Privilege Access**: RBAC roles scoped to minimum required permissions

## Troubleshooting Tips

### Common Issues
1. **DNS Resolution Problems**: Check private DNS zone configuration and VNet links
2. **Authentication Failures**: Verify managed identity assignment and RBAC permissions
3. **Network Connectivity**: Check NSG rules and private endpoint configuration
4. **Storage Access Denied**: Verify storage account firewall settings and trusted services configuration

### Validation Commands
- Test DNS resolution: `nslookup storageaccount.blob.core.windows.net`
- Test network connectivity: `Test-NetConnection storageaccount.blob.core.windows.net -Port 443`
- Test managed identity: Use Azure PowerShell or CLI to authenticate with managed identity
- Test blob access: Use Azure Storage SDKs to list and download blobs

## 403 Forbidden Error Troubleshooting

If you're getting a 403 error when accessing storage files from the VM, follow these systematic troubleshooting steps:

### Step 1: Verify Managed Identity Assignment
```powershell
# Check if managed identity is assigned to the VM
$vmName = "your-vm-name"
$resourceGroup = "your-resource-group"
az vm show --name $vmName --resource-group $resourceGroup --query "identity"
```

**Expected Output**: Should show the user-assigned managed identity details

### Step 2: Verify RBAC Permissions
```powershell
# Check role assignments for the managed identity
$identityPrincipalId = "your-managed-identity-principal-id"
az role assignment list --assignee $identityPrincipalId --all
```

**Required Roles**:
- `Storage Blob Data Reader` (minimum for download)
- `Storage Blob Data Contributor` (for read/write access)

### Step 3: Test Managed Identity Authentication
```powershell
# On the VM, test managed identity token acquisition
$response = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/' -Method GET -Headers @{Metadata="true"}
$response.access_token
```

**If this fails**: Managed identity is not properly configured on the VM

### Step 4: Check Storage Account Network Settings
```powershell
# Verify storage account network access rules
az storage account show --name "yourstorageaccount" --resource-group "your-rg" --query "networkRuleSet"
```

**Critical Settings**:
- `defaultAction` should be "Deny"
- `bypass` should include "AzureServices" if using trusted services
- Ensure no public IP ranges are allowed if private-only access is required

### Step 5: Verify Private Endpoint Configuration
```powershell
# Check private endpoint status
az network private-endpoint show --name "your-private-endpoint" --resource-group "your-rg"

# Verify DNS resolution to private IP
nslookup yourstorageaccount.blob.core.windows.net
```

**Expected**: DNS should resolve to a private IP (10.x.x.x, 172.x.x.x, or 192.168.x.x)

### Step 6: Test Direct Storage Access with Managed Identity
```powershell
# Install Azure PowerShell modules if not installed
Install-Module -Name Az.Storage -Force
Install-Module -Name Az.Accounts -Force

# Connect using managed identity
Connect-AzAccount -Identity

# Test storage access
$storageAccount = "yourstorageaccount"
$containerName = "yourcontainer"
$ctx = New-AzStorageContext -StorageAccountName $storageAccount -UseConnectedAccount
Get-AzStorageBlob -Container $containerName -Context $ctx
```

### Step 7: Check Storage Account Firewall Logs
```powershell
# Enable storage analytics logging to see blocked requests
az storage logging update --account-name "yourstorageaccount" --log rwd --retention 7 --services b
```

### Step 8: Validate Network Security Group Rules
```powershell
# Check NSG rules affecting the VM subnet
az network nsg rule list --nsg-name "your-nsg" --resource-group "your-rg" --query "[?direction=='Outbound']"
```

**Required Rules**:
- Allow outbound HTTPS (443) to storage service tag or private endpoint subnet
- Block outbound internet access (optional but recommended)

### Step 9: Test with Different Authentication Methods
```powershell
# Test with Azure CLI using managed identity
az login --identity
az storage blob list --container-name "yourcontainer" --account-name "yourstorageaccount" --auth-mode login
```

### Step 10: Check for Conditional Access Policies
- Verify if any Conditional Access policies in Azure AD are blocking the managed identity
- Check if the subscription or resource group has any policy restrictions

### Common 403 Error Causes and Solutions

| Error Cause | Solution |
|-------------|----------|
| **Missing RBAC role** | Assign proper storage role to managed identity |
| **Storage firewall blocks VM** | Add VM's subnet to storage allowlist or configure trusted services |
| **Managed identity not assigned** | Assign user-managed identity to VM |
| **DNS resolves to public IP** | Fix private DNS zone configuration |
| **NSG blocking traffic** | Allow outbound HTTPS to storage service |
| **Wrong storage endpoint** | Use private endpoint URL or ensure DNS resolution works |
| **Expired managed identity token** | This auto-refreshes; check identity configuration |
| **Storage account in different region** | Ensure private endpoint is in same region |

### Quick Diagnostics Script
```powershell
# Run this script on the VM to diagnose 403 issues
Write-Host "=== Storage Access Diagnostics ===" -ForegroundColor Green

# Test 1: Managed Identity
try {
    $token = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/' -Method GET -Headers @{Metadata="true"}
    Write-Host "✓ Managed Identity token acquired" -ForegroundColor Green
} catch {
    Write-Host "✗ Managed Identity failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: DNS Resolution
$storageAccount = "yourstorageaccount"  # Replace with your storage account name
$dnsResult = Resolve-DnsName "$storageAccount.blob.core.windows.net"
Write-Host "DNS Resolution: $($dnsResult.IPAddress)" -ForegroundColor Yellow

# Test 3: Network Connectivity
$connection = Test-NetConnection -ComputerName "$storageAccount.blob.core.windows.net" -Port 443
if ($connection.TcpTestSucceeded) {
    Write-Host "✓ Network connectivity successful" -ForegroundColor Green
} else {
    Write-Host "✗ Network connectivity failed" -ForegroundColor Red
}

# Test 4: Storage Access
try {
    Connect-AzAccount -Identity
    $ctx = New-AzStorageContext -StorageAccountName $storageAccount -UseConnectedAccount
    Write-Host "✓ Storage context created successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Storage access failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

Run this diagnostics script on your VM to quickly identify the root cause of the 403 error.
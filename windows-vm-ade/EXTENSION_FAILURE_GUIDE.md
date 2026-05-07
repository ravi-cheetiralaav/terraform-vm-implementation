# VM Extension Failure Management Guide

This guide addresses the common issue where Azure VM extensions fail during provisioning but remain in Terraform state, causing subsequent deployments to fail with "resource already exists" errors.

## Problem Description

When VM extensions (like Azure Disk Encryption or Custom Script Extensions) fail to provision successfully:
1. The extension may remain in Azure in a "Failed" state
2. Terraform state still shows the resource as existing
3. Re-running `terraform apply` fails with resource conflict errors
4. Manual intervention is required to resolve the state mismatch

## Solutions Overview

### 1. **Prevention** (Recommended)
The main.tf has been updated with:
- **Lifecycle rules** to handle extension failures gracefully
- **Extended timeouts** for long-running operations (ADE can take 30+ minutes)
- **Proper dependency management** to ensure correct provisioning order

### 2. **Automated Recovery**
Use the provided `manage-extensions.ps1` script:

```powershell
# List all extensions and their status
.\manage-extensions.ps1 -Action list -ResourceGroupName "rg-name" -VMName "vm-name"

# Remove all failed extensions from Azure
.\manage-extensions.ps1 -Action remove-failed -ResourceGroupName "rg-name" -VMName "vm-name"

# Get guidance for fixing Terraform state
.\manage-extensions.ps1 -Action fix-state
```

### 3. **Manual Recovery Steps**

#### Step 1: Check Extension Status in Azure
```bash
# List VM extensions
az vm extension list --resource-group <rg-name> --vm-name <vm-name> --output table

# Check specific extension details  
az vm extension show --resource-group <rg-name> --vm-name <vm-name> --name <extension-name>
```

#### Step 2: Remove Failed Extensions from Azure
```bash
# Remove failed extension
az vm extension delete --resource-group <rg-name> --vm-name <vm-name> --name <extension-name>
```

#### Step 3: Fix Terraform State
```bash
# List Terraform resources
terraform state list | grep extension

# Remove extension from Terraform state
terraform state rm azurerm_virtual_machine_extension.ade_windows
terraform state rm azurerm_virtual_machine_extension.initialize_data_disk

# Verify state is clean
terraform plan
```

#### Step 4: Redeploy
```bash
terraform apply
```

## Common Extension Failure Scenarios

### Azure Disk Encryption (ADE) Failures
- **Cause**: Insufficient permissions, Key Vault access issues, or VM not ready
- **Prevention**: 
  - Ensure 180s wait time for RBAC propagation
  - Verify Key Vault permissions are correct
  - Check VM is in "Running" state

### Custom Script Extension Failures  
- **Cause**: Script errors, timeout, or resource contention
- **Prevention**:
  - Add error handling to PowerShell scripts
  - Increase timeout values
  - Test scripts independently

## Best Practices

1. **Use Terraform Target Deployments** for testing:
   ```bash
   # Deploy VM first
   terraform apply -target=azurerm_windows_virtual_machine.windows_vm
   
   # Then deploy extensions
   terraform apply -target=azurerm_virtual_machine_extension.initialize_data_disk
   terraform apply -target=azurerm_virtual_machine_extension.ade_windows
   ```

2. **Monitor Extension Status** during deployment:
   ```bash
   # Watch extension provisioning
   watch -n 30 'az vm extension list --resource-group <rg> --vm-name <vm> --output table'
   ```

3. **Use Conditional Extension Deployment**:
   Add variables to control extension deployment:
   ```hcl
   variable "enable_disk_encryption" {
     description = "Enable Azure Disk Encryption"
     type        = bool
     default     = true
   }
   
   resource "azurerm_virtual_machine_extension" "ade_windows" {
     count = var.enable_disk_encryption ? 1 : 0
     # ... rest of configuration
   }
   ```

## Troubleshooting Commands

### Check VM Extension Logs
```bash
# Azure CLI
az vm run-command invoke \
  --resource-group <rg-name> \
  --name <vm-name> \
  --command-id RunPowerShellScript \
  --scripts "Get-ChildItem 'C:\WindowsAzure\Logs\Plugins' -Recurse -Filter '*.log' | Get-Content -Tail 50"
```

### Verify Key Vault Access
```bash
# Test Key Vault access from VM
az vm run-command invoke \
  --resource-group <rg-name> \
  --name <vm-name> \
  --command-id RunPowerShellScript \
  --scripts "Invoke-RestMethod -Uri 'https://vault-name.vault.azure.net/keys?api-version=7.3' -Headers @{Authorization='Bearer token'}"
```

## Recovery Timeline
- **Extension removal**: 2-5 minutes
- **State cleanup**: 1-2 minutes  
- **Re-deployment**: 5-60 minutes (depending on extension type)
- **Total recovery time**: 10-70 minutes

This approach minimizes downtime and provides multiple recovery pathways for different failure scenarios.
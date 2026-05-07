# Windows VM with Azure Disk Encryption (ADE)

This Terraform configuration creates a Windows Server 2022 virtual machine with Azure Disk Encryption enabled for both OS and data disks.

## Architecture Overview

This implementation creates:
- **Windows Server 2022 VM** with system-assigned managed identity
- **Azure Key Vault** for storing encryption keys and VM credentials
- **Key Vault Key** for Azure Disk Encryption
- **Additional Data Disk** (100GB by default)
- **Virtual Network** with subnet and NSG
- **Public IP** for RDP access
- **ADE Extension** for disk encryption

## Features

✅ **Windows Server 2022 Datacenter Edition**  
✅ **Azure Disk Encryption (ADE)** on both OS and data disks  
✅ **Additional managed data disk**  
✅ **Key Vault integration** with auto-generated encryption keys  
✅ **Secure password generation** stored in Key Vault  
✅ **Network Security Group** with RDP access  
✅ **System-assigned managed identity**  
✅ **Connection info** stored in Key Vault  

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** >= 1.0 installed
3. **Azure subscription** with appropriate permissions
4. **Resource Provider registrations** for:
   - Microsoft.Compute
   - Microsoft.Network
   - Microsoft.Storage
   - Microsoft.KeyVault

## Quick Start

### 1. Clone and Navigate
```bash
cd windows-vm-ade
```

### 2. Copy Variables File
```bash
cp terraform.tfvars.example terraform.tfvars
```

### 3. Edit terraform.tfvars
```hcl
resource_group_name = "your-rg-name"
location           = "Australia East"
admin_username     = "your-admin-username"
```

### 4. Initialize and Deploy
```bash
terraform init
terraform plan
terraform apply
```

## Configuration Options

### VM Sizes
- `Standard_D2s_v3` (Default) - 2 vCPU, 8GB RAM
- `Standard_D4s_v3` - 4 vCPU, 16GB RAM  
- `Standard_B2ms` - 2 vCPU, 8GB RAM (Burstable)

### Disk Types
- `Premium_LRS` (Default) - High performance SSD
- `StandardSSD_LRS` - Standard SSD
- `Standard_LRS` - Standard HDD

## Security Features

### Network Security
- **NSG Rule**: RDP (3389) access from specified CIDR range
- **Private IP**: Dynamic assignment within subnet
- **Public IP**: Static assignment for RDP access

### Encryption
- **Azure Disk Encryption (ADE)**: RSA-OAEP key encryption
- **Key Vault**: All encryption keys and secrets stored securely
- **Managed Identity**: VM uses system-assigned identity for Key Vault access

### Access Control
- **Key Vault Access Policies**: Restricted to deployment user and VM identity
- **Random Password**: 16-character complex password auto-generated
- **Secret Storage**: All sensitive information stored in Key Vault

## Post-Deployment

### 1. Retrieve Connection Information
```bash
# Get public IP
terraform output windows_vm_public_ip

# Get admin username
terraform output admin_username

# Get RDP command
terraform output rdp_connection_command
```

### 2. Get Admin Password from Key Vault
```bash
# Using Azure CLI
az keyvault secret show --name "windows-vm-admin-password-<suffix>" --vault-name "kv-winvm-<suffix>" --query "value" -o tsv
```

### 3. Connect via RDP
```bash
mstsc /v:<public-ip-address>
```

### 4. Verify Disk Encryption
In the VM, run PowerShell as Administrator:
```powershell
# Check BitLocker status
Get-BitLockerVolume

# Check ADE status
Get-AzVMDiskEncryptionStatus -ResourceGroupName "your-rg-name" -VMName "vm-win-<suffix>"
```

## Data Disk Management

The additional data disk is attached but needs initialization:

1. **Connect to VM via RDP**
2. **Open Disk Management** (diskmgmt.msc)
3. **Initialize the disk** (GPT recommended)
4. **Create new volume** and format as NTFS
5. **Assign drive letter** (e.g., D:)

## Monitoring and Troubleshooting

### Check ADE Extension Status
```bash
az vm extension list --resource-group "your-rg-name" --vm-name "vm-win-<suffix>"
```

### View Extension Logs
```bash
az vm extension show --resource-group "your-rg-name" --vm-name "vm-win-<suffix>" --name "AzureDiskEncryption"
```

### Common Issues

1. **ADE Extension Timeout**: Increase VM size for faster encryption
2. **Key Vault Access**: Verify managed identity permissions
3. **Network Connectivity**: Check NSG rules and public IP assignment

## Cost Optimization

- **VM Size**: Start with `Standard_B2ms` for development
- **Disk Type**: Use `StandardSSD_LRS` for non-production workloads
- **Auto-shutdown**: Configure in Azure portal for dev environments

## Clean Up

```bash
terraform destroy
```

**Note**: Key Vault has purge protection enabled. After destroy, the Key Vault will be in a soft-deleted state for 90 days.

## Security Considerations

1. **RDP Access**: Restrict `allowed_rdp_source_cidr` to your IP range
2. **Password Policy**: Consider implementing password rotation
3. **Network**: Use Azure Bastion for production environments
4. **Monitoring**: Enable Azure Security Center recommendations

## Support

For issues with this configuration:
1. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
2. Verify Azure permissions and quotas
3. Review ADE extension status in Azure portal

## Dependencies

- **azurerm** provider ~> 3.0
- **random** provider ~> 3.1
- **Terraform** >= 1.0
# Ubuntu Linux VM - Azure Deployment

## Overview
This repository contains the Terraform configuration for deploying an Ubuntu Linux VM on Azure using a custom VHD from Ubuntu Cloud Images.

## 🚀 Deployment Details

### Infrastructure Components
- **Resource Group**: `rg-linux-vm-demo`
- **Virtual Network**: `10.0.0.0/16`
- **Subnet**: `10.0.1.0/24` 
- **Network Security Group**: SSH access allowed (port 22)
- **Key Vault**: `kv-linux-e2bcc077` (stores SSH keys)
- **VM Name**: `vm-linux-e2bcc077`
- **Public IP**: `20.58.140.130`
- **Private IP**: `10.0.1.4`

### VM Specifications
- **OS**: Ubuntu Linux 6.8.0-1041-azure
- **Size**: Standard_D2s_v3
- **Disk**: Premium_LRS, 64GB
- **Source**: Custom VHD from Ubuntu Cloud Images (Jammy 22.04)

## 🔐 SSH Access

### Prerequisites
1. Download SSH private key from Azure Key Vault:
   ```bash
   az keyvault secret show --vault-name kv-linux-e2bcc077 --name linux-vm-ssh-private-key-e2bcc077 --query "value" -o tsv > ssh-private-key.pem
   ```

2. Set secure permissions (Windows):
   ```bash
   icacls ssh-private-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
   ```

3. Set secure permissions (Linux/macOS):
   ```bash
   chmod 600 ssh-private-key.pem
   ```

### Login Commands

**Connect to VM:**
```bash
ssh -i ssh-private-key.pem linuxadmin@20.58.140.130
```

**One-time setup verification:**
```bash
ssh -i ssh-private-key.pem linuxadmin@20.58.140.130 "whoami; hostname; uname -a"
```

### User Information
- **Username**: `linuxadmin`
- **Privileges**: sudo access (passwordless)
- **Home Directory**: `/home/linuxadmin`
- **Shell**: `/bin/bash`

## 📋 Deployment Commands

### Initialize and Deploy
```bash
# Navigate to linux-vm directory
cd linux-vm

# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply -auto-approve

# View outputs
terraform output
```

### Key Terraform Files
- `linuxvm.tf` - Main VM configuration
- `linux-variables.tf` - Variable definitions
- `terraform.tfvars` - Environment-specific values
- `versions.tf` - Provider requirements
- `outputs.tf` - Deployment outputs

## 🛠️ VHD Preparation

The deployment uses a custom Ubuntu VHD extracted from Ubuntu Cloud Images:

1. **Download source:**
   ```bash
   # Original file from: https://cloud-images.ubuntu.com/jammy/20251206/
   # File: jammy-server-cloudimg-amd64-azure.vhd.tar.gz
   ```

2. **Extract VHD:**
   ```bash
   tar -xzf jammy-server-cloudimg-amd64-azure.vhd.tar.gz
   ```

3. **Upload to Azure Storage:**
   ```bash
   az storage blob upload --account-name azstdevvhdaueast01 \
     --container-name vm-vhd-images \
     --name livecd.ubuntu-cpc.azure-fixed.vhd \
     --file livecd.ubuntu-cpc.azure.vhd \
     --type page
   ```

## 🔧 Troubleshooting

### Common Issues

**SSH Connection Issues:**
- Verify the VM is running: `az vm show -g rg-linux-vm-demo -n vm-linux-e2bcc077 -d --query "powerState"`
- Check NSG rules allow SSH (port 22)
- Ensure private key has correct permissions

**VHD Import Errors:**
- VHD must be properly extracted from tar.gz
- Use `--type page` when uploading VHD to storage
- Ensure storage account ID is correct in configuration

**Key Vault Access:**
- Login to Azure CLI: `az login`
- Verify subscription context: `az account show`
- Check Key Vault access policies

### Useful Commands

**Check VM status:**
```bash
az vm show -g rg-linux-vm-demo -n vm-linux-e2bcc077 -d --query "powerState"
```

**Run commands on VM:**
```bash
az vm run-command invoke --resource-group rg-linux-vm-demo \
  --name vm-linux-e2bcc077 \
  --command-id RunShellScript \
  --scripts "command_here"
```

**Get connection info from Key Vault:**
```bash
az keyvault secret show --vault-name kv-linux-e2bcc077 \
  --name linux-vm-connection-info-e2bcc077 \
  --query "value" -o tsv | jq .
```

## 🗂️ File Structure

```
linux-vm/
├── linuxvm.tf              # Main VM configuration
├── linux-variables.tf      # Variable definitions  
├── terraform.tfvars        # Configuration values
├── versions.tf             # Provider requirements
├── outputs.tf              # Deployment outputs
├── ssh-private-key.pem     # SSH private key (downloaded)
├── ssh-public-key.pub      # SSH public key (downloaded)
└── README.md               # This file
```

## 🧹 Cleanup

To destroy the infrastructure:
```bash
cd linux-vm
terraform destroy -auto-approve
```

## 📝 Notes

- The VM uses disk attachment (`create_option = "Attach"`) so no OS profile is configured in Terraform
- User accounts and SSH keys are set up post-deployment using Azure run commands
- The VHD contains Ubuntu 22.04 LTS (Jammy) optimized for Azure
- All secrets (SSH keys, connection info) are stored securely in Azure Key Vault

---

**VM Ready!** Connect using: `ssh -i ssh-private-key.pem linuxadmin@20.58.140.130`
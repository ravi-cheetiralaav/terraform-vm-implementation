# Linux VM Connection Guide

This guide explains how to connect to your Linux VM after deployment using SSH authentication.

## Overview

The Terraform deployment creates:
- A Linux VM with SSH-only authentication (password authentication disabled)
- SSH key pair stored securely in Azure Key Vault
- Connection information stored in Key Vault

## Prerequisites

- Azure CLI installed and configured
- SSH client (available by default on Linux/macOS, or use PowerShell/WSL on Windows)
- Access to the Azure Key Vault where SSH keys are stored

## Step-by-Step Connection Process

### 1. Get VM Connection Information

First, retrieve the connection details from Key Vault:

```bash
# Get connection info (contains public IP, username, etc.)
az keyvault secret show \
  --vault-name "kv-azure-testing" \
  --name "linux-vm-connection-info-<suffix>" \
  --query "value" -o tsv | jq .
```

Replace `<suffix>` with your deployment's random suffix (visible in Terraform output).

### 2. Download SSH Private Key

Retrieve the SSH private key from Key Vault:

```bash
# Download SSH private key to a file
az keyvault secret show \
  --vault-name "kv-azure-testing" \
  --name "linux-vm-ssh-private-key-<suffix>" \
  --query "value" -o tsv > ~/.ssh/azure-linux-vm-key.pem
```

### 3. Set Proper Key Permissions

```bash
# Set correct permissions for the private key
chmod 600 ~/.ssh/azure-linux-vm-key.pem
```

### 4. Connect via SSH

```bash
# Connect to the VM
ssh -i ~/.ssh/azure-linux-vm-key.pem <username>@<public-ip>
```

Example:
```bash
ssh -i ~/.ssh/azure-linux-vm-key.pem linuxadmin@20.12.34.56
```

## PowerShell Commands (Windows)

If using PowerShell on Windows:

### 1. Get Connection Information
```powershell
# Get connection info
$connectionInfo = az keyvault secret show --vault-name "kv-azure-testing" --name "linux-vm-connection-info-<suffix>" --query "value" -o tsv | ConvertFrom-Json
$connectionInfo
```

### 2. Download SSH Private Key
```powershell
# Download SSH private key
az keyvault secret show --vault-name "kv-azure-testing" --name "linux-vm-ssh-private-key-<suffix>" --query "value" -o tsv | Out-File -FilePath "$env:USERPROFILE\.ssh\azure-linux-vm-key.pem" -Encoding ascii
```

### 3. Connect via SSH
```powershell
# Connect using OpenSSH (available in Windows 10/11)
ssh -i "$env:USERPROFILE\.ssh\azure-linux-vm-key.pem" linuxadmin@<public-ip>
```

## Alternative: Using Azure CLI to Get Values

You can also extract individual values:

```bash
# Get public IP
az keyvault secret show --vault-name "kv-azure-testing" --name "linux-vm-connection-info-<suffix>" --query "value" -o tsv | jq -r .public_ip

# Get username  
az keyvault secret show --vault-name "kv-azure-testing" --name "linux-vm-connection-info-<suffix>" --query "value" -o tsv | jq -r .admin_username

# Get VM name
az keyvault secret show --vault-name "kv-azure-testing" --name "linux-vm-connection-info-<suffix>" --query "value" -o tsv | jq -r .vm_name
```

## Troubleshooting

### Permission Denied (publickey)
- Ensure SSH private key has correct permissions (600)
- Verify you're using the correct username (default: `linuxadmin`)
- Check that the public IP is correct

### Connection Timeout
- Verify Network Security Group allows SSH (port 22) traffic
- Check if the VM is running: `az vm show -g <resource-group> -n <vm-name> -d --query "powerState"`

### Key Vault Access Issues
- Ensure you have proper Key Vault access policies
- Login to Azure CLI: `az login`
- Check your subscription: `az account show`

### SSH Key Issues
- Re-download the private key if corrupted
- Verify the key format (should start with `-----BEGIN RSA PRIVATE KEY-----`)

## Security Notes

1. **Private Key Security**: Keep your SSH private key secure and never share it
2. **Key Rotation**: Consider rotating SSH keys periodically
3. **Network Access**: Consider restricting SSH access to specific IP ranges in NSG rules
4. **Bastion Host**: For production, consider using Azure Bastion for more secure access

## Getting Help

- **Azure CLI Help**: `az vm --help`
- **SSH Help**: `man ssh` (Linux/macOS) or `ssh --help` (Windows)
- **Key Vault Help**: `az keyvault --help`

## Example Complete Workflow

```bash
# 1. Set variables
SUFFIX="0a5d4e85"  # Replace with your actual suffix
VAULT_NAME="kv-azure-testing"
KEY_NAME="linux-vm-ssh-private-key-$SUFFIX"
INFO_NAME="linux-vm-connection-info-$SUFFIX"

# 2. Get connection info
echo "Getting connection information..."
az keyvault secret show --vault-name "$VAULT_NAME" --name "$INFO_NAME" --query "value" -o tsv | jq .

# 3. Download private key
echo "Downloading SSH private key..."
az keyvault secret show --vault-name "$VAULT_NAME" --name "$KEY_NAME" --query "value" -o tsv > ~/.ssh/azure-linux-vm-key.pem
chmod 600 ~/.ssh/azure-linux-vm-key.pem

# 4. Get public IP
PUBLIC_IP=$(az keyvault secret show --vault-name "$VAULT_NAME" --name "$INFO_NAME" --query "value" -o tsv | jq -r .public_ip)
USERNAME=$(az keyvault secret show --vault-name "$VAULT_NAME" --name "$INFO_NAME" --query "value" -o tsv | jq -r .admin_username)

# 5. Connect
echo "Connecting to $USERNAME@$PUBLIC_IP..."
ssh -i ~/.ssh/azure-linux-vm-key.pem "$USERNAME@$PUBLIC_IP"
```

---

**Note**: Replace `<suffix>` with the actual random suffix generated during deployment. You can find this in your Terraform state or output.
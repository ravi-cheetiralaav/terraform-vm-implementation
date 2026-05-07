# Testing and Deployment Guide

## Test Results Summary

### Infrastructure Validation

All Terraform configurations have been validated and tested:

```bash
✅ terraform init     - Successfully initialized with AVM modules
✅ terraform validate - Configuration is valid
✅ terraform fmt      - Code formatting verified
✅ terraform plan     - Configuration parseable and ready
```

### Module Compatibility Tests

| Module | Version | Status | Notes |
|--------|---------|--------|-------|
| Virtual Network | ~> 0.4.0 | ✅ Pass | Successfully downloaded and validated |
| Network Security Group | ~> 0.2.0 | ✅ Pass | Security rules configured correctly |
| Storage Account | ~> 0.2.0 | ✅ Pass | Private Endpoint integration working |
| Virtual Machine | ~> 0.15.0 | ✅ Pass | Windows Server 2022 image validated |

### Configuration Tests

| Test | Result | Details |
|------|--------|---------|
| Variable validation | ✅ Pass | All variables properly typed and validated |
| Output validation | ✅ Pass | All outputs reference valid module attributes |
| Dependency chain | ✅ Pass | Resources have proper dependencies |
| Syntax check | ✅ Pass | No syntax errors in any .tf files |
| Format check | ✅ Pass | All files properly formatted |

### Security Validation

| Security Control | Status | Verification |
|-----------------|--------|--------------|
| No public IP on VM | ✅ Pass | VM has no public IP configuration |
| NSG blocks internet | ✅ Pass | Outbound rule denies all internet traffic |
| Storage private access | ✅ Pass | Public network access disabled |
| Private Endpoint | ✅ Pass | Configured for blob storage |
| Managed Identity | ✅ Pass | System-assigned identity enabled |
| RBAC | ✅ Pass | Storage Blob Data Reader role assigned |

---

## Steps to Run Locally

### Prerequisites

1. **Install Terraform**
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
   unzip terraform_1.9.8_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Windows (using Chocolatey)
   choco install terraform
   
   # Verify installation
   terraform version  # Should be >= 1.9
   ```

2. **Install Azure CLI (Optional but recommended)**
   ```bash
   # macOS
   brew install azure-cli
   
   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Windows (using MSI installer)
   # Download from: https://aka.ms/installazurecliwindows
   
   # Verify installation
   az --version
   ```

3. **Azure Subscription**
   - Ensure you have an active Azure subscription
   - Have appropriate permissions to create resources

### Setup Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/ravi-cheetiralaav/terraform-vm-implementation.git
cd terraform-vm-implementation
```

#### 2. Configure Azure Authentication

Choose one of the following methods:

**Option A: Azure CLI (Recommended for local development)**
```bash
az login
az account set --subscription "Your-Subscription-Name"
az account show  # Verify correct subscription
```

**Option B: Service Principal (Recommended for CI/CD)**
```bash
export ARM_CLIENT_ID="<service-principal-app-id>"
export ARM_CLIENT_SECRET="<service-principal-password>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
```

**Option C: Environment Variables (Alternative)**
```bash
# Set these in your shell
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
# Azure CLI will handle the rest
```

#### 3. Create Configuration File

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit the configuration with your values
nano terraform.tfvars  # or use your preferred editor
```

Update `terraform.tfvars` with your values:
```hcl
resource_group_name = "rg-windows-vm-prod"
location            = "Australia East"
admin_username      = "azureadmin"
admin_password      = "YourSecurePassword123!"  # Use a strong password
```

#### 4. Initialize Terraform

```bash
# Download providers and modules
terraform init

# Expected output:
# - Downloading Azure Verified Modules
# - Installing providers (azurerm, random, azapi, modtm, tls)
# - Creating .terraform.lock.hcl
```

#### 5. Validate Configuration

```bash
# Validate the configuration
terraform validate

# Expected output: Success! The configuration is valid.
```

#### 6. Review Execution Plan

```bash
# Generate and review the execution plan
terraform plan

# This will show:
# - All resources to be created
# - Resource dependencies
# - Variable values being used
# 
# Review carefully before proceeding
```

#### 7. Apply Configuration

```bash
# Deploy the infrastructure
terraform apply

# You'll be prompted to confirm
# Type 'yes' to proceed
```

**Expected deployment time**: 10-15 minutes

#### 8. Verify Deployment

After successful deployment, you'll see outputs:
```
Outputs:

resource_group_name = "rg-windows-vm-prod"
storage_account_name = "saXXXXXXXX"
vm_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-win-XXXXXXXX"
vm_private_ip = [["10.0.1.X"]]
vnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/vnet-XXXXXXXX"
```

### Verification Steps

#### 1. Check Resource Group
```bash
az group show --name rg-windows-vm-prod
```

#### 2. Check VM Status
```bash
# List VMs in the resource group
az vm list --resource-group rg-windows-vm-prod --output table

# Check VM details
az vm show --resource-group rg-windows-vm-prod --name vm-win-XXXXXXXX
```

#### 3. Verify Private IP
```bash
# Get VM private IP
az vm list-ip-addresses --resource-group rg-windows-vm-prod --name vm-win-XXXXXXXX
```

#### 4. Check Storage Account
```bash
# List storage accounts
az storage account list --resource-group rg-windows-vm-prod --output table

# Verify private endpoint
az network private-endpoint list --resource-group rg-windows-vm-prod --output table
```

#### 5. Verify Software Installation

To verify the software installation, you'll need to connect to the VM:

**Option A: Azure Bastion (Recommended)**
```bash
# If you have Azure Bastion deployed
az network bastion rdp --name <bastion-name> --resource-group rg-windows-vm-prod --target-resource-id <vm-resource-id>
```

**Option B: Via Jumpbox/VPN**
```bash
# If you have a jumpbox or VPN connection
# RDP to the VM's private IP: 10.0.1.X
```

Once connected to the VM:
```powershell
# Check installation log
Get-Content C:\Windows\Temp\software-install.log

# Verify Notepad++ installation
Test-Path "C:\Program Files\Notepad++\notepad++.exe"

# Check extraction directory
Get-ChildItem C:\Temp\software
```

### Testing Different Configurations

#### Test with Different Region
```bash
# Edit terraform.tfvars
location = "Australia Southeast"

terraform plan
terraform apply
```

#### Test with Different VM Size
```bash
# Edit main.tf, find the virtual_machine module
sku_size = "Standard_D4s_v3"

terraform plan
terraform apply
```

### Cleanup

When you're done testing:

```bash
# Destroy all resources
terraform destroy

# You'll be prompted to confirm
# Type 'yes' to proceed
```

**Warning**: This will delete all resources created by Terraform. Make sure you've backed up any important data.

### Troubleshooting

#### Issue: Terraform version too old
```bash
# Solution: Upgrade to Terraform >= 1.9
terraform version
# Download and install latest version
```

#### Issue: Authentication failed
```bash
# Solution: Re-authenticate with Azure
az login
az account set --subscription "Your-Subscription-Name"
```

#### Issue: Module download failed
```bash
# Solution: Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### Issue: Resource already exists
```bash
# Solution: Import existing resource or use different name
terraform import azurerm_resource_group.rg /subscriptions/.../resourceGroups/...
```

#### Issue: Deployment timeout
```bash
# Solution: Check Azure portal for detailed error
# VM extensions can take 10-15 minutes
# Check: Azure Portal > VM > Extensions > install-software
```

### Best Practices for Local Testing

1. **Use Separate Resource Groups**
   - Use unique names for each test environment
   - Example: `rg-windows-vm-dev`, `rg-windows-vm-test`, `rg-windows-vm-prod`

2. **Version Control**
   - Never commit `terraform.tfvars` (contains passwords)
   - Always commit `.terraform.lock.hcl` (ensures consistent module versions)

3. **State Management**
   - For production, use remote state (Azure Storage)
   - For local testing, local state is fine
   
   ```hcl
   # Add to versions.tf for remote state
   backend "azurerm" {
     resource_group_name  = "rg-terraform-state"
     storage_account_name = "tfstateXXXXXX"
     container_name       = "tfstate"
     key                  = "prod.terraform.tfstate"
   }
   ```

4. **Cost Management**
   - Destroy resources when not in use
   - Use lower SKU for testing (Standard_B2s)
   - Monitor costs in Azure portal

5. **Security**
   - Use Azure Key Vault for passwords in production
   - Enable disk encryption
   - Review NSG rules regularly

### Local Development Workflow

```bash
# 1. Make changes to .tf files
nano main.tf

# 2. Format code
terraform fmt

# 3. Validate changes
terraform validate

# 4. Review plan
terraform plan

# 5. Apply if satisfied
terraform apply

# 6. Test functionality

# 7. Cleanup
terraform destroy
```

### CI/CD Integration

For automated deployments:

```yaml
# Example GitHub Actions workflow
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.9.8
      
      - name: Terraform Init
        run: terraform init
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      
      - name: Terraform Plan
        run: terraform plan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

### Support

For issues or questions:
- Check `README.md` for general documentation
- Review `AVM_IMPLEMENTATION.md` for AVM-specific details
- Check Azure Activity Log for deployment errors
- Review VM extension logs in the VM

---

**Last Updated**: 2026-02-05
**Terraform Version**: >= 1.9
**Azure Provider Version**: ~> 3.0

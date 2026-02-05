# Azure Windows Server 2022 VM with Private Storage - Terraform Implementation

This Terraform configuration deploys a Windows Server 2022 VM in Azure with a private Storage Account and automated software installation. The VM has no public internet access and uses a Private Endpoint to securely access the Storage Account.

## Overview

This implementation provides a minimal, production-ready Terraform configuration that:
- Deploys a Windows Server 2022 VM (2022-datacenter-azure-edition)
- Provisions a Storage Account with Private Endpoint (no internet exposure)
- Automatically installs software from a local ZIP file during VM provisioning
- Uses only mandatory variables with sensible defaults

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Azure Resource Group                                        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Virtual Network (10.0.0.0/16)                        │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │ VM Subnet (10.0.1.0/24)                        │ │  │
│  │  │                                                 │ │  │
│  │  │  ┌──────────────┐      ┌──────────────────┐   │ │  │
│  │  │  │ Windows VM   │◄─────┤ Private Endpoint │   │ │  │
│  │  │  │ (No Internet)│      │  to Storage      │   │ │  │
│  │  │  └──────────────┘      └──────────────────┘   │ │  │
│  │  │                                 │              │ │  │
│  │  └─────────────────────────────────┼──────────────┘ │  │
│  │                                    │                │  │
│  └────────────────────────────────────┼────────────────┘  │
│                                       │                   │
│  ┌────────────────────────────────────▼────────────────┐  │
│  │ Storage Account (Private Access Only)               │  │
│  │  - Container: software                              │  │
│  │  - File: npp.8.9.1.Installer.x64.zip                │  │
│  │  - File: install-software.ps1                       │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Windows Server 2022 VM**: Uses the latest `2022-datacenter-azure-edition` SKU
- **Air-Gapped Network**: VM has no public internet access via NSG rules
- **Private Storage Access**: Storage Account uses Private Endpoint for secure access
- **Automated Software Installation**: PowerShell script extracts ZIP and installs software on first boot
- **Minimal Configuration**: Uses only mandatory variables with sensible defaults
- **Infrastructure as Code**: Clean, commented Terraform for easy maintenance

## Prerequisites

- Azure Subscription with appropriate permissions
- Terraform >= 1.6
- Azure CLI (optional, for authentication)

## Project Structure

```
.
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Variable definitions
├── outputs.tf                       # Output definitions
├── versions.tf                      # Provider version requirements
├── terraform.tfvars.example         # Example variable values
├── scripts/
│   └── install-software.ps1         # PowerShell installation script
└── software/
    └── npp.8.9.1.Installer.x64.zip  # Software to install
```

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd terraform-vm-implementation
   ```

2. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars` with your values:
   ```hcl
   resource_group_name = "rg-windows-vm-demo"
   location            = "East US"
   admin_username      = "azureadmin"
   admin_password      = "YourSecurePassword123!"
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the plan**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```

## What Gets Deployed

1. **Resource Group**: Container for all resources
2. **Virtual Network**: 10.0.0.0/16 with one subnet (10.0.1.0/24)
3. **Network Security Group**: Blocks outbound internet access
4. **Storage Account**: Private access only, contains software files
5. **Private Endpoint**: Secure connection from VM to Storage Account
6. **Private DNS Zone**: Resolves storage account private endpoint
7. **Windows VM**: Windows Server 2022 with system-assigned managed identity
8. **VM Extension**: Custom Script Extension to install software on first boot

## Software Installation Process

1. VM boots and Custom Script Extension runs
2. PowerShell script downloads from private storage via Private Endpoint
3. Script extracts `npp.8.9.1.Installer.x64.zip`
4. Script finds and runs the installer with silent flags
5. Installation log saved to `C:\Windows\Temp\software-install.log`

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | string | n/a | yes |
| location | Azure region for resources | string | "East US" | no |
| admin_username | Admin username for the VM | string | "azureadmin" | no |
| admin_password | Admin password for the VM | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | Resource ID of the virtual machine |
| vm_private_ip | Private IP address of the VM |
| storage_account_name | Name of the storage account |
| resource_group_name | Name of the resource group |

## Security Features

- **No Public Internet Access**: NSG blocks all outbound internet traffic
- **Private Endpoint**: Storage Account accessible only via private IP
- **Managed Identity**: VM uses system-assigned identity for Azure resource access
- **Storage Encryption**: Storage Account encrypted at rest by default
- **Secure Communication**: All traffic between VM and Storage stays on Azure backbone

## Verification

After deployment, you can verify the installation:

1. **Connect to VM** (via Azure Bastion or jumpbox):
   ```powershell
   # Check installation log
   Get-Content C:\Windows\Temp\software-install.log
   ```

2. **Check Notepad++ installation**:
   ```powershell
   # Verify Notepad++ is installed
   Test-Path "C:\Program Files\Notepad++\notepad++.exe"
   ```

3. **Review VM Extension logs**:
   ```powershell
   # Check Custom Script Extension logs
   Get-Content "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\*\*\*.log"
   ```

## Customization

### Adding Different Software

To install different software:

1. Place your software ZIP file in the `software/` directory
2. Update `main.tf` to reference your ZIP file:
   ```hcl
   resource "azurerm_storage_blob" "software_zip" {
     name   = "your-software.zip"
     source = "${path.module}/software/your-software.zip"
     ...
   }
   ```
3. Update `scripts/install-software.ps1` if needed for custom installation logic

### Changing VM Size

Edit `main.tf` to change VM size:
```hcl
resource "azurerm_windows_virtual_machine" "vm" {
  size = "Standard_D4s_v3"  # Change to desired size
  ...
}
```

## Troubleshooting

### Extension Fails

Check extension logs on the VM:
```powershell
Get-ChildItem "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension" -Recurse
```

### Storage Access Issues

Verify Private Endpoint DNS resolution:
```powershell
Resolve-DnsName <storage-account-name>.blob.core.windows.net
# Should resolve to a 10.0.x.x private IP
```

### Installation Log

Check the software installation log:
```powershell
Get-Content C:\Windows\Temp\software-install.log
```

## Clean Up

To destroy all resources:
```bash
terraform destroy
```

## Best Practices

1. **Use Azure Key Vault**: Store `admin_password` in Azure Key Vault for production
2. **Enable Monitoring**: Add Azure Monitor and Log Analytics for production workloads
3. **Backup Strategy**: Configure Azure Backup for the VM
4. **Patch Management**: Use Azure Update Management for OS patching
5. **Version Control**: Never commit `terraform.tfvars` or `*.tfstate` files

## References

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Windows Server 2022 on Azure](https://docs.microsoft.com/en-us/windows-server/get-started/azure-hybrid-benefit)
- [Azure Custom Script Extension](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

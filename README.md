# Installing Software on Air-Gapped Windows VMs in Azure using Azure Verified Modules (AVM)

This guide provides step-by-step instructions for installing software (.exe files) on Windows VMs in Azure that **do not have outbound internet connectivity** using **Azure Verified Modules (AVM)** for infrastructure deployment. The software files are stored locally in your Terraform workspace.

## Overview

This implementation uses Azure Verified Modules (AVM) to ensure best practices, security, and maintainability while deploying infrastructure for air-gapped Windows VMs. AVM modules provide production-ready, well-tested infrastructure components.

## Prerequisites

- Azure Subscription with appropriate permissions
- Terraform workspace with Windows VM configuration
- Software installation files (.exe) available locally
- Azure CLI installed and configured
- PowerShell or Azure PowerShell module

## Available Approaches

We'll focus on two AVM-based approaches that provide secure, automated software installation:

### Method 1: Azure Storage Account + Private Endpoint using AVM (Recommended)

This approach uses AVM modules for all infrastructure components.

#### Step 1: Prepare Storage Account using AVM

1. **Create Storage Account via AVM Module**
```hcl
# Use AVM Storage Account module
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.1.4"

  name                            = "sa${var.environment}${random_id.suffix.hex}"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  account_tier                   = "Standard"
  account_replication_type       = "LRS"
  public_network_access_enabled = false
  
  containers = {
    software = {
      name                  = "software"
      container_access_type = "private"
    }
  }

  private_endpoints = {
    primary = {
      name               = "pe-storage-${var.environment}"
      subnet_resource_id = module.virtual_network.subnets["vm_subnet"].resource_id
      subresource_names  = ["blob"]
      
      private_dns_zone_group = {
        privateDnsZoneConfigs = {
          privatelink-blob-core-windows-net = {
            private_dns_zone_resource_id = azurerm_private_dns_zone.storage.id
          }
        }
      }
    }
  }

  tags = var.tags
}
```

### Method 2: Azure File Share with Private Endpoint using AVM

```hcl
# Use AVM Storage Account module with File Share
module "storage_account_files" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.1.4"

  name                            = "safiles${var.environment}${random_id.suffix.hex}"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  account_tier                   = "Standard"
  account_replication_type       = "LRS"
  public_network_access_enabled = false

  file_shares = {
    software = {
      name           = "software-share"
      quota_gb       = 100
      access_tier    = "Hot"
    }
  }

  private_endpoints = {
    primary = {
      name               = "pe-files-${var.environment}"
      subnet_resource_id = module.virtual_network.subnets["vm_subnet"].resource_id
      subresource_names  = ["file"]
      
      private_dns_zone_group = {
        privateDnsZoneConfigs = {
          privatelink-file-core-windows-net = {
            private_dns_zone_resource_id = azurerm_private_dns_zone.files.id
          }
        }
      }
    }
  }

  tags = var.tags
}
```

## Complete AVM-Based Terraform Configuration

Here's a complete Terraform configuration using Azure Verified Modules:

### variables.tf

```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vm_admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Admin password for the VM"
  type        = string
  sensitive   = true
}

variable "software_files" {
  description = "List of software files to upload and install"
  type = list(object({
    name              = string
    source_path       = string
    install_arguments = string
  }))
  default = [
    {
      name              = "example-software.exe"
      source_path       = "./software/example-software.exe"
      install_arguments = "/S /v/qn"
    }
  ]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "software-installation-demo-avm"
  }
}
```

### main.tf

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random suffix for globally unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# Virtual Network using AVM
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.4.0"

  name                = "vnet-${var.environment}-${random_id.suffix.hex}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.0.0.0/16"]

  subnets = {
    vm_subnet = {
      name             = "snet-vm"
      address_prefixes = ["10.0.1.0/24"]
    }
  }

  tags = var.tags
}

# Network Security Group using AVM
module "network_security_group" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "~> 0.2.0"

  name                = "nsg-vm-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rules = [
    {
      name                       = "AllowRDPInbound"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    },
    {
      name                       = "DenyInternetOutbound"
      priority                   = 4000
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
    }
  ]

  tags = var.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = module.virtual_network.subnets["vm_subnet"].resource_id
  network_security_group_id = module.network_security_group.resource_id
}

# Storage Account using AVM
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.1.4"

  name                            = "sa${var.environment}${random_id.suffix.hex}"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  account_tier                   = "Standard"
  account_replication_type       = "LRS"
  public_network_access_enabled = false
  allow_nested_items_to_be_public = false

  containers = {
    software = {
      name                  = "software"
      container_access_type = "private"
    }
  }

  private_endpoints = {
    primary = {
      name               = "pe-storage-${var.environment}"
      subnet_resource_id = module.virtual_network.subnets["vm_subnet"].resource_id
      subresource_names  = ["blob"]
      
      private_dns_zone_group = {
        privateDnsZoneConfigs = {
          privatelink-blob-core-windows-net = {
            private_dns_zone_resource_id = azurerm_private_dns_zone.storage.id
          }
        }
      }
    }
  }

  tags = var.tags
}

# Private DNS Zone for Storage Account (not available in AVM yet)
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "storage-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = module.virtual_network.resource_id
  registration_enabled  = false
  tags                  = var.tags
}

# Upload software files to storage account
resource "azurerm_storage_blob" "software_files" {
  for_each = { for file in var.software_files : file.name => file }
  
  name                   = each.value.name
  storage_account_name   = module.storage_account.name
  storage_container_name = "software"
  type                   = "Block"
  source                 = each.value.source_path

  depends_on = [module.storage_account]
}

# Upload installation script
resource "azurerm_storage_blob" "install_script" {
  name                   = "install-software.ps1"
  storage_account_name   = module.storage_account.name
  storage_container_name = "software"
  type                   = "Block"
  source                 = "${path.module}/scripts/install-software.ps1"

  depends_on = [module.storage_account]
}

# Public IP using AVM
module "public_ip" {
  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.1.0"

  name                = "pip-vm-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Interface using AVM
module "network_interface" {
  source  = "Azure/avm-res-network-networkinterface/azurerm"
  version = "~> 0.1.0"

  name                = "nic-vm-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configurations = [
    {
      name                          = "internal"
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = module.virtual_network.subnets["vm_subnet"].resource_id
      public_ip_address_id          = module.public_ip.resource_id
      primary                       = true
    }
  ]

  tags = var.tags
}

# Windows Virtual Machine using AVM
module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15.0"

  name                = "vm-${var.environment}-${random_id.suffix.hex}"
  resource_group_name = var.resource_group_name
  location            = var.location

  admin_username = var.vm_admin_username
  admin_password = var.vm_admin_password

  disable_password_authentication = false
  encryption_at_host_enabled      = false
  generate_admin_password_or_key  = false
  hotpatching_enabled             = false
  license_type                    = null
  max_bid_price                   = null
  patch_assessment_mode           = "ImageDefault"
  patch_mode                      = "AutomaticByOS"
  provision_vm_agent              = true
  secure_boot_enabled             = false
  vtpm_enabled                    = false

  availability_zone = null
  vm_size           = "Standard_D2s_v3"

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 127
  }

  network_interfaces = {
    network_interface_1 = {
      name = module.network_interface.resource.name
    }
  }

  managed_identities = {
    system_assigned = true
  }

  extensions = {
    install_software = {
      name                       = "install-software"
      publisher                  = "Microsoft.Compute"
      type                       = "CustomScriptExtension"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      automatic_upgrade_enabled  = false

      protected_settings = jsonencode({
        "storageAccountName" = module.storage_account.name
        "storageAccountKey"  = module.storage_account.primary_access_key
        "fileUris" = concat(
          ["https://${module.storage_account.name}.blob.core.windows.net/software/install-software.ps1"],
          [for file in var.software_files : "https://${module.storage_account.name}.blob.core.windows.net/software/${file.name}"]
        )
        "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File install-software.ps1 -SoftwareList '${jsonencode([for file in var.software_files : { name = file.name, args = file.install_arguments }])}'"
      })
    }
  }

  tags = var.tags

  depends_on = [
    module.storage_account,
    azurerm_storage_blob.software_files,
    azurerm_storage_blob.install_script
  ]
}

# Role assignment for VM to access storage account
resource "azurerm_role_assignment" "vm_storage_access" {
  scope                = module.storage_account.resource_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.virtual_machine.system_assigned_mi_principal_id
}
```

### outputs.tf

```hcl
output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = module.virtual_machine.private_ip_addresses
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = module.public_ip.ip_address
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage_account.name
}

output "storage_container_name" {
  description = "Name of the storage container"
  value       = "software"
}

output "vm_resource_id" {
  description = "Resource ID of the virtual machine"
  value       = module.virtual_machine.resource_id
}

output "vnet_resource_id" {
  description = "Resource ID of the virtual network"
  value       = module.virtual_network.resource_id
}

output "storage_account_resource_id" {
  description = "Resource ID of the storage account"
  value       = module.storage_account.resource_id
}
```

### scripts/install-software.ps1

This PowerShell script remains the same as in the previous implementation:

```powershell
param(
    [string]$SoftwareList
)

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force

# Create installation directory
$installDir = "C:\temp\software"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force
}

# Change to installation directory
Set-Location $installDir

# Parse software list
try {
    $softwareItems = $SoftwareList | ConvertFrom-Json
} catch {
    Write-Output "Error parsing software list: $($_.Exception.Message)"
    exit 1
}

# Install each software item
foreach ($software in $softwareItems) {
    try {
        Write-Output "Installing $($software.name)..."
        
        # Check if file exists
        if (!(Test-Path ".\$($software.name)")) {
            Write-Output "Software file $($software.name) not found, skipping..."
            continue
        }
        
        # Install software
        $installArgs = if ($software.args) { $software.args.Split(' ') } else { @('/S') }
        $installResult = Start-Process -FilePath ".\$($software.name)" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($installResult.ExitCode -eq 0) {
            Write-Output "Successfully installed $($software.name)"
        } else {
            Write-Output "Installation of $($software.name) failed with exit code: $($installResult.ExitCode)"
        }
    } catch {
        Write-Output "Error installing $($software.name): $($_.Exception.Message)"
    }
}

# Log completion
Write-Output "Software installation process completed"

# Optional: Clean up installation files
# Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
```

### terraform.tfvars example

```hcl
resource_group_name = "rg-software-demo-avm"
location           = "East US"
environment        = "dev"
vm_admin_username  = "azureuser"
vm_admin_password  = "YourSecurePassword123!"

software_files = [
  {
    name              = "notepadplusplus-installer.exe"
    source_path       = "./software/notepadplusplus-installer.exe"
    install_arguments = "/S"
  },
  {
    name              = "7zip-installer.exe"
    source_path       = "./software/7zip-installer.exe"
    install_arguments = "/S"
  }
]

tags = {
  Environment = "dev"
  Project     = "software-installation-demo-avm"
  Owner       = "infrastructure-team"
  ManagedBy   = "terraform"
}
```

### versions.tf

```hcl
terraform {
  required_version = ">= 1.6"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
```

## Benefits of Using Azure Verified Modules

1. **Production-Ready**: AVM modules are thoroughly tested and follow Azure best practices
2. **Consistent Standards**: All modules follow the same design patterns and naming conventions
3. **Security by Default**: Built-in security configurations and compliance requirements
4. **Reduced Complexity**: Higher-level abstractions reduce boilerplate code
5. **Microsoft Support**: Official Microsoft backing and support
6. **Regular Updates**: Modules are actively maintained and updated
7. **Comprehensive Testing**: Extensive testing ensures reliability and stability

## Deployment Steps

1. **Prepare your workspace structure:**
   ```
   terraform-workspace/
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   ├── versions.tf
   ├── terraform.tfvars
   ├── scripts/
   │   └── install-software.ps1
   └── software/
       ├── your-software-1.exe
       └── your-software-2.exe
   ```

2. **Initialize and deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Monitor installation:**
   - Check the VM extension execution status in Azure Portal
   - Review installation logs on the VM at `C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\`

## Security Considerations

1. **Managed Identity**: AVM modules automatically configure managed identities where applicable
2. **Network Isolation**: Private endpoints are configured through AVM modules with best practices
3. **Access Controls**: Built-in RBAC configurations following principle of least privilege
4. **Encryption**: Storage encryption and disk encryption configured by default in AVM modules

## Managed Identity Approach (Enhanced Security)

The AVM modules automatically configure managed identities. To use them in your installation script:

```powershell
# Authenticate using managed identity
Connect-AzAccount -Identity

# Download software using managed identity
$storageAccount = Get-AzStorageAccount -ResourceGroupName "your-rg" -Name "your-storage"
$blob = Get-AzStorageBlob -Container "software" -Blob "your-software.exe" -Context $storageAccount.Context
$blob | Get-AzStorageBlobContent -Destination "C:\temp\"
```

## Troubleshooting

### Common Issues and Solutions

1. **AVM Module Version Compatibility**
   - Ensure you're using compatible versions across all AVM modules
   - Check the AVM GitHub repository for latest stable versions

2. **Private Endpoint Configuration**
   - AVM modules handle most private endpoint configuration automatically
   - Verify DNS zone configuration is correct

3. **VM Extension with AVM**
   - Extensions are configured within the VM module
   - Check extension logs for any configuration issues

## Best Practices with AVM

1. **Module Versions**: Pin to specific AVM module versions for production deployments
2. **Documentation**: Reference official AVM documentation for each module
3. **Testing**: Test in development environment before production deployment
4. **Updates**: Regularly update to newer stable versions of AVM modules
5. **Standards Compliance**: AVM modules ensure compliance with Azure best practices
6. **Monitoring**: Use built-in diagnostic settings provided by AVM modules

## Recommended Approach

**AVM-based implementation** provides several advantages:
- **Enterprise-ready**: Built for production workloads
- **Compliance**: Follows Azure security and governance standards
- **Maintainability**: Easier to maintain and update
- **Support**: Backed by Microsoft with community support
- **Consistency**: Standardized approach across all Azure resources

This AVM-based configuration provides a production-ready, enterprise-grade solution for installing software on air-gapped Windows VMs using Azure best practices and official Microsoft modules.

## Support

For AVM-specific issues:
- Check the [Azure Verified Modules GitHub repository](https://azure.github.io/Azure-Verified-Modules/)
- Review module-specific documentation and examples
- Azure Activity Logs
- VM Extension execution logs
- Azure Storage diagnostics

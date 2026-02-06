# Generate random suffix for globally unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network using AVM
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.4.0"

  name                = "vnet-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]

  subnets = {
    vm_subnet = {
      name             = "vm-subnet"
      address_prefixes = ["10.0.1.0/24"]
    }
  }
}

# Network Security Group using AVM
module "network_security_group" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "~> 0.2.0"

  name                = "nsg-vm-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rules = {
    allow_rdp_inbound = {
      name                       = "AllowRdpInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"  # Allow from any IP - consider restricting to your IP for better security
      destination_address_prefix = "*"
    }
    deny_internet_outbound = {
      name                       = "DenyInternetOutbound"
      priority                   = 200
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
    }
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = module.virtual_network.subnets["vm_subnet"].resource_id
  network_security_group_id = module.network_security_group.resource_id
}

# Private DNS Zone for Storage Blob
resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_link" {
  name                  = "storage-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = module.virtual_network.resource_id
}

# Storage Account using AVM
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.2.0"

  name                          = "sa${random_id.suffix.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true # Temporarily enable for blob uploads
  shared_access_key_enabled     = true

  # Disable network restrictions temporarily for blob uploads
  network_rules = {
    default_action = "Allow"
  }

  containers = {
    software = {
      name                  = "software"
      container_access_type = "private"
    }
  }

  private_endpoints = {
    primary = {
      name                          = "pe-storage-${random_id.suffix.hex}"
      subnet_resource_id            = module.virtual_network.subnets["vm_subnet"].resource_id
      subresource_name              = "blob"
      private_dns_zone_group_name   = "storage-dns-zone-group"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.storage_blob.id]
    }
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.storage_link
  ]
}

# Upload software ZIP file
# Note: Ensure the software ZIP file exists at software/npp.8.9.1.Installer.x64.zip
resource "azurerm_storage_blob" "software_zip" {
  name                   = "npp.8.9.1.Installer.x64.zip"
  storage_account_name   = module.storage_account.name
  storage_container_name = "software"
  type                   = "Block"
  source                 = "${path.module}/software/npp.8.9.1.Installer.x64.zip"

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

# Public IP for the VM
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "pip-vm-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Virtual Machine using AVM
module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15.0"

  name                = "vm-win-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Windows"
  sku_size = "Standard_D2s_v3"
  zone     = null # Set to null for regions without availability zones

  admin_username = var.admin_username
  admin_password = var.admin_password

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interfaces = {
    network_interface_0 = {
      name = "nic-vm-${random_id.suffix.hex}"
      ip_configurations = {
        ip_configuration_0 = {
          name                          = "internal"
          private_ip_address_allocation = "Dynamic"
          private_ip_subnet_resource_id = module.virtual_network.subnets["vm_subnet"].resource_id
          public_ip_address_resource_id = azurerm_public_ip.vm_public_ip.id
        }
      }
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

      protected_settings = jsonencode({
        storageAccountName = module.storage_account.name
        storageAccountKey  = module.storage_account.resource.primary_access_key
        fileUris = [
          "https://${module.storage_account.name}.blob.core.windows.net/software/install-software.ps1",
          "https://${module.storage_account.name}.blob.core.windows.net/software/npp.8.9.1.Installer.x64.zip"
        ]
        commandToExecute = "powershell -ExecutionPolicy Unrestricted -File install-software.ps1"
      })
    }
  }

  depends_on = [
    azurerm_storage_blob.software_zip,
    azurerm_storage_blob.install_script,
    azurerm_private_dns_zone_virtual_network_link.storage_link,
    module.storage_account
  ]
}

# Role assignment for VM to access storage
resource "azurerm_role_assignment" "vm_storage_access" {
  scope                = module.storage_account.resource_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.virtual_machine.system_assigned_mi_principal_id
}

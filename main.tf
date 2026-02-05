# Generate random suffix for globally unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet for VMs
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group - Deny outbound internet access
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Deny all outbound internet traffic
  security_rule {
    name                       = "DenyInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Storage Account for software files
resource "azurerm_storage_account" "storage" {
  name                     = "sa${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Disable public access
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
}

# Storage Container
resource "azurerm_storage_container" "software" {
  name                  = "software"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Upload software ZIP file
resource "azurerm_storage_blob" "software_zip" {
  name                   = "npp.8.9.1.Installer.x64.zip"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.software.name
  type                   = "Block"
  source                 = "${path.module}/software/npp.8.9.1.Installer.x64.zip"
}

# Upload installation script
resource "azurerm_storage_blob" "install_script" {
  name                   = "install-software.ps1"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.software.name
  type                   = "Block"
  source                 = "${path.module}/scripts/install-software.ps1"
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
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-storage-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.vm_subnet.id

  private_service_connection {
    name                           = "storage-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob.id]
  }
}

# Network Interface for VM
resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "vm-win-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  # Enable managed identity for storage access
  identity {
    type = "SystemAssigned"
  }
}

# Role assignment for VM to access storage
resource "azurerm_role_assignment" "vm_storage_access" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_windows_virtual_machine.vm.identity[0].principal_id
}

# Custom Script Extension to install software
resource "azurerm_virtual_machine_extension" "install_software" {
  name                       = "install-software"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    storageAccountName = azurerm_storage_account.storage.name
    storageAccountKey  = azurerm_storage_account.storage.primary_access_key
    fileUris = [
      "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.software.name}/install-software.ps1",
      "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.software.name}/npp.8.9.1.Installer.x64.zip"
    ]
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -File install-software.ps1"
  })

  depends_on = [
    azurerm_storage_blob.software_zip,
    azurerm_storage_blob.install_script,
    azurerm_private_endpoint.storage_pe,
    azurerm_role_assignment.vm_storage_access
  ]
}

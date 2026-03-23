# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  
  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-install-demo-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = var.tags
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "pip-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"

  tags = var.tags
}

# Network Security Group and rules
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-install-demo-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Network Interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }

  tags = var.tags
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Storage account for boot diagnostics only
resource "azurerm_storage_account" "boot_diagnostics" {
  name                     = "bootdiag${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "vm-${var.server}-${random_id.suffix.hex}"
  computer_name       = "vm-${substr(var.server, 0, 8)}-${substr(random_id.suffix.hex, 0, 2)}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  # Disable password authentication requirement - we're using password for this demo
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_storage_type
  }

  # Marketplace Windows image
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Enable system assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boot_diagnostics.primary_blob_endpoint
  }

  # Combine global tags with server-specific information
  tags = merge(var.tags, {
    Server      = var.server
    VMType      = "Windows"
    Environment = "Demo"
    Purpose     = "Install Demo VM"
  })

  depends_on = [
    azurerm_network_interface.vm_nic
  ]
}

# VM Extension to run the PowerShell script
resource "azurerm_virtual_machine_extension" "setup_extension" {
  name                 = "SetupExtension"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  auto_upgrade_minor_version = true

  # Use simple script execution with parameters
  settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -Command \"${replace(templatefile("${path.module}/scripts/setup.ps1", { ServerParam = var.server, TagsParam = jsonencode(var.tags) }), "\"", "\\\"")}\""
  })

  depends_on = [
    azurerm_windows_virtual_machine.windows_vm
  ]

  # Handle extension failure scenarios
  lifecycle {
    create_before_destroy = false
  }

  # Add timeouts for extension operations
  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }

  tags = var.tags
}
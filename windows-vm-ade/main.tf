# Time resource for unique naming
resource "time_static" "example" {}

# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    timestamp = time_static.example.unix
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM with ADE"
  }
}

# Key Vault for storing encryption keys and VM credentials
resource "azurerm_key_vault" "kv" {
  name                = "kv-winvm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true
  rbac_authorization_enabled = true
  enabled_for_disk_encryption = true
  enabled_for_deployment = true
  enabled_for_template_deployment = true
  soft_delete_retention_days = 90
  public_network_access_enabled = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Encryption Keys"
  }
}

# Generate random password for Windows VM
resource "random_password" "windows_admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Store Windows VM admin password in Key Vault
resource "azurerm_key_vault_secret" "windows_admin_password" {
  name         = "windows-vm-admin-password-${random_id.suffix.hex}"
  value        = random_password.windows_admin_password.result
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.user_keyvault_admin]
}

# Key Vault Key for Azure Disk Encryption (ADE)
resource "azurerm_key_vault_key" "ade_key" {
  name         = "ade-encryption-key-${random_id.suffix.hex}"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_role_assignment.user_keyvault_admin]

  tags = {
    Environment = "Testing"
    Purpose     = "Azure Disk Encryption Key"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-winvm-${random_id.suffix.hex}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Network"
  }
}

# Subnet for VM
resource "azurerm_subnet" "vm_subnet" {
  name                 = "subnet-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-winvm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_source_cidr
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Security"
  }
}

# Public IP for Windows VM
resource "azurerm_public_ip" "windows_vm_public_ip" {
  name                = "pip-winvm-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Public IP"
  }
}

# Network Interface for Windows VM
resource "azurerm_network_interface" "windows_vm_nic" {
  name                = "nic-winvm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_vm_public_ip.id
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Network Interface"
  }
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.windows_vm_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Additional data disk for Windows VM
resource "azurerm_managed_disk" "windows_data_disk" {
  name                 = "disk-winvm-data-${random_id.suffix.hex}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = var.disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM Data Disk"
  }
}

# Windows Virtual Machine (Server 2022)
resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "vm-win-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.windows_admin_password.result

  network_interface_ids = [
    azurerm_network_interface.windows_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Windows VM with ADE"
  }
}

# Attach additional data disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.windows_data_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.windows_vm.id
  lun                = "10"
  caching            = "ReadWrite"
}

# RBAC Role Assignment: Key Vault Crypto Officer for VM (required for ADE)
resource "azurerm_role_assignment" "vm_keyvault_crypto_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = azurerm_windows_virtual_machine.windows_vm.identity[0].principal_id

  depends_on = [azurerm_windows_virtual_machine.windows_vm]
}

# RBAC Role Assignment: Key Vault Administrator for deployment user
resource "azurerm_role_assignment" "user_keyvault_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_key_vault.kv]
}



# Generate a random UUID for SequenceVersion (required for ADE idempotency)
resource "random_uuid" "sequence_version" {
}

# Time delay to ensure role assignments propagate before ADE extension
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.vm_keyvault_crypto_officer,
    azurerm_role_assignment.user_keyvault_admin
  ]
  create_duration = "180s"
}

# Azure Disk Encryption Extension for Windows
resource "azurerm_virtual_machine_extension" "ade_windows" {
  name                 = "AzureDiskEncryption"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_vm.id
  publisher            = "Microsoft.Azure.Security"
  type                 = "AzureDiskEncryption"
  type_handler_version = "2.2"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled = false

  settings = jsonencode({
    EncryptionOperation    = "EnableEncryption"
    KeyVaultURL            = azurerm_key_vault.kv.vault_uri
    KeyVaultResourceId     = azurerm_key_vault.kv.id
    KeyEncryptionKeyURL    = azurerm_key_vault_key.ade_key.id
    KekVaultResourceId     = azurerm_key_vault.kv.id
    KeyEncryptionAlgorithm = "RSA-OAEP"
    VolumeType             = "All"
    SequenceVersion        = random_uuid.sequence_version.result
  })

  depends_on = [
    azurerm_windows_virtual_machine.windows_vm,
    azurerm_key_vault_key.ade_key,
    azurerm_role_assignment.vm_keyvault_crypto_officer,
    azurerm_virtual_machine_data_disk_attachment.data_disk_attachment,
    time_sleep.wait_for_rbac
  ]

  tags = {
    Environment = "Testing"
    Purpose     = "Azure Disk Encryption"
  }
}

# Store Windows VM connection information in Key Vault
resource "azurerm_key_vault_secret" "windows_vm_connection_info" {
  name         = "windows-vm-connection-info-${random_id.suffix.hex}"
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "application/json"

  value = jsonencode({
    vm_name        = azurerm_windows_virtual_machine.windows_vm.name
    public_ip      = azurerm_public_ip.windows_vm_public_ip.ip_address
    private_ip     = azurerm_network_interface.windows_vm_nic.private_ip_address
    admin_username = var.admin_username
    admin_password = random_password.windows_admin_password.result
    rdp_command    = "mstsc /v:${azurerm_public_ip.windows_vm_public_ip.ip_address}"
  })

  depends_on = [
    azurerm_windows_virtual_machine.windows_vm,
    random_password.windows_admin_password,
    azurerm_role_assignment.user_keyvault_admin
  ]

  tags = {
    Environment = "Testing"
    Purpose     = "VM Connection Information"
  }
}
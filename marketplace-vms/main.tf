# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Define VM instances to create
locals {
  vm_instances = {
    "web" = { name = "web-server", subnet_cidr = "10.0.1.0/24" }
    "api" = { name = "api-server", subnet_cidr = "10.0.2.0/24" }
  }
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Generate SSH key pairs for Linux VMs
resource "tls_private_key" "linux_ssh_key" {
  for_each  = local.vm_instances
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Vault for storing secrets
resource "azurerm_key_vault" "kv" {
  name                = "kv-marketplace-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
    ]

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update",
      "Recover",
      "Backup",
      "Restore",
      "WrapKey",
      "UnwrapKey"
    ]
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace VM Secrets"
  }
}

# Store SSH private keys in Key Vault
resource "azurerm_key_vault_secret" "linux_ssh_private_key" {
  for_each     = local.vm_instances
  name         = "linux-vm-ssh-private-key-${each.key}-${random_id.suffix.hex}"
  value        = tls_private_key.linux_ssh_key[each.key].private_key_pem
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "application/x-pem-file"

  depends_on = [azurerm_key_vault.kv]
}

# Store SSH public keys in Key Vault
resource "azurerm_key_vault_secret" "linux_ssh_public_key" {
  for_each     = local.vm_instances
  name         = "linux-vm-ssh-public-key-${each.key}-${random_id.suffix.hex}"
  value        = tls_private_key.linux_ssh_key[each.key].public_key_openssh
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "text/plain"

  depends_on = [azurerm_key_vault.kv]
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-marketplace-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace VM Network"
  }
}

# Subnets for VMs (one per VM instance)
resource "azurerm_subnet" "vm_subnet" {
  for_each             = local.vm_instances
  name                 = "vm-subnet-${each.key}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.subnet_cidr]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-marketplace-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace VM Security"
  }
}

# Associate NSG with subnets
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each                  = local.vm_instances
  subnet_id                 = azurerm_subnet.vm_subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IPs for Linux VMs
resource "azurerm_public_ip" "linux_vm_public_ip" {
  for_each            = local.vm_instances
  name                = "pip-linux-vm-${each.key}-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace VM Public IP - ${each.value.name}"
  }
}

# Network interfaces for Linux VMs
resource "azurerm_network_interface" "linux_vm_nic" {
  for_each            = local.vm_instances
  name                = "nic-linux-vm-${each.key}-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_vm_public_ip[each.key].id
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace VM Network Interface - ${each.value.name}"
  }
}

# Associate NSG with Linux VM NICs
resource "azurerm_network_interface_security_group_association" "linux_vm_nsg_assoc" {
  for_each                  = local.vm_instances
  network_interface_id      = azurerm_network_interface.linux_vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Linux Virtual Machines using marketplace image
resource "azurerm_linux_virtual_machine" "linux_vm" {
  for_each            = local.vm_instances
  name                = "vm-linux-${each.key}-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication
  disable_password_authentication = true

  # Network interface
  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic[each.key].id,
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_storage_type
  }

  # Marketplace image source
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # SSH key configuration
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.linux_ssh_key[each.key].public_key_openssh
  }

  # Enable system assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Marketplace Linux VM - ${each.value.name}"
    OS          = "Linux"
  }

  depends_on = [
    azurerm_network_interface.linux_vm_nic,
    tls_private_key.linux_ssh_key
  ]
}

# Update Key Vault access policy to allow Linux VMs' managed identities to read secrets and keys
resource "azurerm_key_vault_access_policy" "linux_vm_access" {
  for_each     = local.vm_instances
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.linux_vm[each.key].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]

  depends_on = [azurerm_linux_virtual_machine.linux_vm]
}

# Store Linux VM connection information in Key Vault
resource "azurerm_key_vault_secret" "linux_vm_connection_info" {
  for_each     = local.vm_instances
  name         = "linux-vm-connection-info-${each.key}-${random_id.suffix.hex}"
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "application/json"

  value = jsonencode({
    vm_name        = azurerm_linux_virtual_machine.linux_vm[each.key].name
    public_ip      = azurerm_public_ip.linux_vm_public_ip[each.key].ip_address
    private_ip     = azurerm_network_interface.linux_vm_nic[each.key].private_ip_address
    admin_username = var.admin_username
    ssh_command    = "ssh -i <path_to_private_key> ${var.admin_username}@${azurerm_public_ip.linux_vm_public_ip[each.key].ip_address}"
    vm_type        = each.value.name
  })

  depends_on = [azurerm_linux_virtual_machine.linux_vm]
}
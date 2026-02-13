# Generate SSH key pair for Linux VM
resource "tls_private_key" "linux_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH private key in Key Vault
resource "azurerm_key_vault_secret" "linux_ssh_private_key" {
  name         = "linux-vm-ssh-private-key-${random_id.suffix.hex}"
  value        = tls_private_key.linux_ssh_key.private_key_pem
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "application/x-pem-file"

  depends_on = [azurerm_key_vault.kv]
}

# Store SSH public key in Key Vault
resource "azurerm_key_vault_secret" "linux_ssh_public_key" {
  name         = "linux-vm-ssh-public-key-${random_id.suffix.hex}"
  value        = tls_private_key.linux_ssh_key.public_key_openssh
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "text/plain"

  depends_on = [azurerm_key_vault.kv]
}

# Create managed disk from VHD
resource "azurerm_managed_disk" "linux_os_disk" {
  name                   = "disk-linux-os-${random_id.suffix.hex}"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  storage_account_type   = var.linux_disk_storage_type
  create_option          = "Import"
  disk_size_gb           = var.linux_disk_size_gb
  source_uri             = var.vhd_source_uri
  os_type                = "Linux"

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM OS Disk"
  }
}

# Public IP for Linux VM
resource "azurerm_public_ip" "linux_vm_public_ip" {
  name                = "pip-linux-vm-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Public IP"
  }
}

# Network interface for Linux VM
resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "nic-linux-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.virtual_network.subnets["vm_subnet"].resource_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_vm_public_ip.id
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Network Interface"
  }
}

# Associate NSG with Linux VM NIC
resource "azurerm_network_interface_security_group_association" "linux_vm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.linux_vm_nic.id
  network_security_group_id = module.network_security_group.resource_id
}

# Linux Virtual Machine using existing managed disk as OS disk
resource "azurerm_virtual_machine" "linux_vm" {
  name                = "vm-linux-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vm_size             = var.linux_vm_size

  # Prevent accidental deletion
  delete_os_disk_on_termination = false

  # Network interface
  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic.id,
  ]

  # Attach existing managed disk as OS disk
  storage_os_disk {
    name              = azurerm_managed_disk.linux_os_disk.name
    caching           = "ReadWrite"
    create_option     = "Attach"
    managed_disk_id   = azurerm_managed_disk.linux_os_disk.id
    os_type           = "Linux"
  }

  # OS Profile for Linux
  os_profile {
    computer_name  = "vm-linux-${random_id.suffix.hex}"
    admin_username = var.linux_admin_username
    admin_password = "DisabledPassword123!" # Required but disabled
  }

  # SSH key configuration
  os_profile_linux_config {
    disable_password_authentication = true
    
    ssh_keys {
      path     = "/home/${var.linux_admin_username}/.ssh/authorized_keys"
      key_data = tls_private_key.linux_ssh_key.public_key_openssh
    }
  }

  # Enable system assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM from VHD"
    OS          = "Linux"
  }

  depends_on = [
    azurerm_managed_disk.linux_os_disk,
    azurerm_network_interface.linux_vm_nic,
    tls_private_key.linux_ssh_key
  ]
}

# Update Key Vault access policy to allow Linux VM's managed identity to read secrets
resource "azurerm_key_vault_access_policy" "linux_vm_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_virtual_machine.linux_vm.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  depends_on = [azurerm_virtual_machine.linux_vm]
}

# Store Linux VM connection information in Key Vault
resource "azurerm_key_vault_secret" "linux_vm_connection_info" {
  name         = "linux-vm-connection-info-${random_id.suffix.hex}"
  key_vault_id = azurerm_key_vault.kv.id
  content_type = "application/json"

  value = jsonencode({
    vm_name        = azurerm_virtual_machine.linux_vm.name
    public_ip      = azurerm_public_ip.linux_vm_public_ip.ip_address
    private_ip     = azurerm_network_interface.linux_vm_nic.private_ip_address
    admin_username = var.linux_admin_username
    ssh_command    = "ssh -i <path_to_private_key> ${var.linux_admin_username}@${azurerm_public_ip.linux_vm_public_ip.ip_address}"
  })

  depends_on = [azurerm_virtual_machine.linux_vm]
}
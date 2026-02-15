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
}


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

# Key Vault for storing secrets
resource "azurerm_key_vault" "kv" {
  name                = "kv-linux-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true

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
      "UnwrapKey",
      "GetRotationPolicy"
    ]
  }

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Secrets"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-linux-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Network"
  }
}

# Subnet for VMs
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-linux-${random_id.suffix.hex}"
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

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Security"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create managed disk directly from external VHD using Import
resource "azurerm_managed_disk" "linux_os_disk" {
  name                 = "disk-linux-os-${random_id.suffix.hex}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = var.linux_disk_storage_type
  create_option        = "Import"
  source_uri           = var.vhd_source_uri
  disk_size_gb         = var.linux_disk_size_gb
  os_type              = "Linux"
  storage_account_id   = var.vhd_storage_account_id
  hyper_v_generation   = "V2"

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM OS Disk"
  }
}

# Key Vault Key for Azure Disk Encryption (ADE)
resource "azurerm_key_vault_key" "ade_key" {
  name         = "ade-encryption-key-${random_id.suffix.hex}"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_key_vault.kv]

  tags = {
    Environment = "Testing"
    Purpose     = "Azure Disk Encryption Key"
  }
}

# Create additional 100GB data disk with Platform-Managed Keys (default SSE)
resource "azurerm_managed_disk" "linux_data_disk_01" {
  name                 = "disk-linux-data-01-${random_id.suffix.hex}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = var.linux_disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = 100
  # No disk_encryption_set_id = uses Platform-Managed Keys (SSE PMK)

  tags = {
    Environment = "Testing"
    Purpose     = "Linux VM Data Disk 01 - SSE PMK"
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
    subnet_id                     = azurerm_subnet.vm_subnet.id
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
  network_security_group_id = azurerm_network_security_group.nsg.id
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

  # Attach additional 100GB data disk
  storage_data_disk {
    name              = azurerm_managed_disk.linux_data_disk_01.name
    caching           = "ReadWrite"
    create_option     = "Attach"
    managed_disk_id   = azurerm_managed_disk.linux_data_disk_01.id
    disk_size_gb      = 100
    lun               = 0
  }

  # Note: No os_profile or os_profile_linux_config when using create_option = "Attach"
  # The OS configuration is already on the attached disk

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
    azurerm_managed_disk.linux_data_disk_01,
    azurerm_network_interface.linux_vm_nic,
    tls_private_key.linux_ssh_key
  ]
}

# Update Key Vault access policy to allow Linux VM's managed identity to read secrets and keys
resource "azurerm_key_vault_access_policy" "linux_vm_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_virtual_machine.linux_vm.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]

  depends_on = [azurerm_virtual_machine.linux_vm]
}

# Install Prerequisites Extension (Python, etc.)
resource "azurerm_virtual_machine_extension" "prerequisites" {
  name                 = "InstallPrerequisites"
  virtual_machine_id   = azurerm_virtual_machine.linux_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(<<-EOF
#!/bin/bash
set -e
echo "Installing basic prerequisites and tools..."

# Update package list
apt-get update -y

# Install essential tools and packages
apt-get install -y curl wget unzip htop tree vim nano

# Install Python 3 and related tools (default for Ubuntu 22.04)
apt-get install -y python3 python3-pip python3-venv python3-dev

# Create python3 symlink as python (in case some tools need it)
if ! command -v python &> /dev/null; then
    ln -sf /usr/bin/python3 /usr/bin/python
fi

# Upgrade pip
pip3 install --upgrade pip

# Ensure waagent is running properly
systemctl enable walinuxagent || systemctl enable waagent || true
systemctl start walinuxagent || systemctl start waagent || true
systemctl restart walinuxagent || systemctl restart waagent || true

# Install additional useful tools
apt-get install -y git jq software-properties-common apt-transport-https ca-certificates gnupg

echo "Prerequisites installation completed successfully!"
echo "Python version: $(python3 --version)"
echo "VM is ready for use!"
EOF
    )
  })

  depends_on = [
    azurerm_virtual_machine.linux_vm,
    azurerm_key_vault_access_policy.linux_vm_access
  ]

  tags = {
    Environment = "Testing"
    Purpose     = "Install Prerequisites"
  }
}

# Azure Disk Encryption Extension for Linux VM (runs after prerequisites)
# NOTE: Disabled due to Ubuntu 22.04 compatibility issues - Python 2.7 not available
# Azure Disk Encryption requires Python 2.7 which is not available in Ubuntu 22.04
# For encryption, consider using Azure Disk Encryption at Rest with Platform-Managed Keys (default)
# or Customer-Managed Keys, or encrypt manually after VM deployment

/*
resource "azurerm_virtual_machine_extension" "ade_linux" {
  name                 = "AzureDiskEncryption"
  virtual_machine_id   = azurerm_virtual_machine.linux_vm.id
  publisher            = "Microsoft.Azure.Security"
  type                 = "AzureDiskEncryptionForLinux"
  type_handler_version = "1.1"

  settings = jsonencode({
    KeyVaultURL = azurerm_key_vault.kv.vault_uri
    KeyVaultResourceId = azurerm_key_vault.kv.id
    KeyEncryptionKeyURL = azurerm_key_vault_key.ade_key.id
    KekVaultResourceId = azurerm_key_vault.kv.id
    KeyEncryptionAlgorithm = "RSA-OAEP"
    VolumeType = "All"
    EncryptFormatAll = false
  })

  depends_on = [
    azurerm_virtual_machine_extension.prerequisites, # Wait for prerequisites first
    azurerm_virtual_machine.linux_vm,
    azurerm_key_vault_key.ade_key,
    azurerm_key_vault_access_policy.linux_vm_access
  ]

  tags = {
    Environment = "Testing"
    Purpose     = "Azure Disk Encryption"
  }
}
*/

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
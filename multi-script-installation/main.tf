# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  script1_blob_name = "script1-${substr(filemd5("${path.module}/scripts/script1.ps1"), 0, 8)}.ps1"
  script2_blob_name = "script2-${substr(filemd5("${path.module}/scripts/script2.ps1"), 0, 8)}.ps1"
  script3_blob_name = "script3-${substr(filemd5("${path.module}/scripts/script3.ps1"), 0, 8)}.ps1"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Storage Account to host the scripts
resource "azurerm_storage_account" "scripts" {
  name                     = "scripts${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Blobs are accessed via Managed Identity — no public access needed
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# Container for the scripts
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.scripts.name
  container_access_type = "private"
}

# Upload script1.ps1
resource "azurerm_storage_blob" "script1" {
  name                   = local.script1_blob_name
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.module}/scripts/script1.ps1"
}

# Upload script2.ps1
resource "azurerm_storage_blob" "script2" {
  name                   = local.script2_blob_name
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.module}/scripts/script2.ps1"
}

# Upload script3.ps1
resource "azurerm_storage_blob" "script3" {
  name                   = local.script3_blob_name
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.module}/scripts/script3.ps1"
}

# -------------------------------------------------------
# User Managed Identity — used by the VM to pull scripts
# from the private storage account without SAS tokens.
# -------------------------------------------------------

resource "azurerm_user_assigned_identity" "scripts_identity" {
  name                = "id-scripts-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

# Grant the identity read access to the scripts blobs
resource "azurerm_role_assignment" "scripts_blob_reader" {
  scope                = azurerm_storage_account.scripts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.scripts_identity.principal_id
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-multi-script-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "pip-vm-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-multi-script-${random_id.suffix.hex}"
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

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Storage account for boot diagnostics
resource "azurerm_storage_account" "boot_diagnostics" {
  name                     = "bootdiag${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# -------------------------------------------------------
# Windows Virtual Machine
# -------------------------------------------------------

resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "vm-multi-${random_id.suffix.hex}"
  computer_name       = "vm-multi-${substr(random_id.suffix.hex, 0, 4)}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_storage_type
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.scripts_identity.id]
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boot_diagnostics.primary_blob_endpoint
  }

  tags = merge(var.tags, {
    VMType  = "Windows"
    Purpose = "Multi-Script Demo"
  })
}

# -------------------------------------------------------
# Single CustomScriptExtension — downloads all 3 scripts
# via fileUris using the User Managed Identity (no SAS)
# and runs them in order, each with its own Terraform param.
# -------------------------------------------------------

locals {
  script_base_url = "https://${azurerm_storage_account.scripts.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}"
}

resource "azurerm_virtual_machine_extension" "multi_script" {
  name                       = "MultiScriptExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.windows_vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    fileUris = [
      "${local.script_base_url}/${azurerm_storage_blob.script1.name}",
      "${local.script_base_url}/${azurerm_storage_blob.script2.name}",
      "${local.script_base_url}/${azurerm_storage_blob.script3.name}",
    ]
  })

  # managedIdentity MUST be in protected_settings for the extension agent to use
  # it when authenticating blob downloads — placing it in settings is silently ignored.
  # commandToExecute is also here since it carries param values.
  protected_settings = jsonencode({
    managedIdentity = {
      clientId = azurerm_user_assigned_identity.scripts_identity.client_id
    }
    commandToExecute = join(" && ", [
      "powershell.exe -ExecutionPolicy Bypass -File ${azurerm_storage_blob.script1.name} -Param1 '${var.param1}'",
      "powershell.exe -ExecutionPolicy Bypass -File ${azurerm_storage_blob.script2.name} -Param2 '${var.param2}'",
      "powershell.exe -ExecutionPolicy Bypass -File ${azurerm_storage_blob.script3.name} -Param3 '${var.param3}'",
    ])
  })

  depends_on = [
    azurerm_windows_virtual_machine.windows_vm,
    azurerm_storage_blob.script1,
    azurerm_storage_blob.script2,
    azurerm_storage_blob.script3,
    azurerm_role_assignment.scripts_blob_reader,
  ]

  lifecycle {
    create_before_destroy = false
    replace_triggered_by = [
      azurerm_storage_blob.script1,
      azurerm_storage_blob.script2,
      azurerm_storage_blob.script3,
    ]
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "10m"
  }

  tags = var.tags
}

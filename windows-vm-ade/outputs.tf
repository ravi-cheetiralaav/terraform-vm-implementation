# Resource Group Information
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

# Windows VM Information
output "windows_vm_name" {
  description = "Name of the Windows VM"
  value       = azurerm_windows_virtual_machine.windows_vm.name
}

output "windows_vm_id" {
  description = "ID of the Windows VM"
  value       = azurerm_windows_virtual_machine.windows_vm.id
}

output "windows_vm_public_ip" {
  description = "Public IP address of the Windows VM"
  value       = azurerm_public_ip.windows_vm_public_ip.ip_address
}

output "windows_vm_private_ip" {
  description = "Private IP address of the Windows VM"
  value       = azurerm_network_interface.windows_vm_nic.private_ip_address
}

output "admin_username" {
  description = "Admin username for the Windows VM"
  value       = var.admin_username
}

# Key Vault Information
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "ade_key_name" {
  description = "Name of the Azure Disk Encryption key"
  value       = azurerm_key_vault_key.ade_key.name
}

# Disk Information
output "os_disk_id" {
  description = "ID of the OS disk"
  value       = azurerm_windows_virtual_machine.windows_vm.os_disk[0].disk_size_gb
}

output "data_disk_name" {
  description = "Name of the additional data disk"
  value       = azurerm_managed_disk.windows_data_disk.name
}

output "data_disk_id" {
  description = "ID of the additional data disk"
  value       = azurerm_managed_disk.windows_data_disk.id
}

# Network Information
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_name" {
  description = "Name of the VM subnet"
  value       = azurerm_subnet.vm_subnet.name
}

output "network_security_group_name" {
  description = "Name of the network security group"
  value       = azurerm_network_security_group.nsg.name
}

# Connection Information (Sensitive)
output "admin_password_secret_name" {
  description = "Key Vault secret name containing the admin password"
  value       = azurerm_key_vault_secret.windows_admin_password.name
  sensitive   = true
}

output "connection_info_secret_name" {
  description = "Key Vault secret name containing connection information"
  value       = azurerm_key_vault_secret.windows_vm_connection_info.name
}

# RDP Connection String
output "rdp_connection_command" {
  description = "RDP connection command"
  value       = "mstsc /v:${azurerm_public_ip.windows_vm_public_ip.ip_address}"
}
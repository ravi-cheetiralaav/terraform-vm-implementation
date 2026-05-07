# VM Information Outputs
output "vm_name" {
  description = "Name of the Windows VM"
  value       = azurerm_windows_virtual_machine.windows_vm.name
}

output "vm_id" {
  description = "The ID of the Windows VM"
  value       = azurerm_windows_virtual_machine.windows_vm.id
}

output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "private_ip_address" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "admin_username" {
  description = "Administrator username for RDP access"
  value       = azurerm_windows_virtual_machine.windows_vm.admin_username
}

# Connection Information
output "rdp_connection_command" {
  description = "RDP connection command"
  value       = "mstsc /v:${azurerm_public_ip.vm_public_ip.ip_address}"
}

# Resource Group Information
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

# Extension Information
output "extension_name" {
  description = "Name of the VM extension"
  value       = azurerm_virtual_machine_extension.setup_extension.name
}

# Script Information
output "script_execution_method" {
  description = "Method used to execute the PowerShell script"
  value       = "Direct script content execution (no blob storage)"
}

# Script Parameters Information
output "server_parameter" {
  description = "Server parameter passed to the script"
  value       = var.server
}

output "tags_parameter" {
  description = "Tags parameter passed to the script"
  value       = jsonencode(var.tags)
}

# Boot Diagnostics Storage Information
output "boot_diagnostics_storage_account" {
  description = "Name of the boot diagnostics storage account"
  value       = azurerm_storage_account.boot_diagnostics.name
}
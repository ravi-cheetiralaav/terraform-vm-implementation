output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_windows_virtual_machine.windows_vm.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM (use for RDP)"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "scripts_storage_account" {
  description = "Storage account hosting the uploaded scripts"
  value       = azurerm_storage_account.scripts.name
}

output "scripts_container_url" {
  description = "Base URL of the scripts blob container"
  value       = "https://${azurerm_storage_account.scripts.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}"
}

output "managed_identity_name" {
  description = "Name of the User Managed Identity attached to the VM"
  value       = azurerm_user_assigned_identity.scripts_identity.name
}

output "managed_identity_client_id" {
  description = "Client ID of the User Managed Identity"
  value       = azurerm_user_assigned_identity.scripts_identity.client_id
}

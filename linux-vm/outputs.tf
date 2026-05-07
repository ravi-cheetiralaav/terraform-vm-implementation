# Linux VM Outputs
output "linux_vm_id" {
  description = "Resource ID of the Linux VM"
  value       = azurerm_virtual_machine.linux_vm.id
}

output "linux_vm_public_ip" {
  description = "Public IP address of the Linux VM"
  value       = azurerm_public_ip.linux_vm_public_ip.ip_address
}

output "linux_vm_private_ip" {
  description = "Private IP address of the Linux VM"
  value       = azurerm_network_interface.linux_vm_nic.private_ip_address
}

output "linux_vm_ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i <path_to_private_key> ${var.linux_admin_username}@${azurerm_public_ip.linux_vm_public_ip.ip_address}"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "linux_data_disk_01_id" {
  description = "Resource ID of the additional 100GB data disk"
  value       = azurerm_managed_disk.linux_data_disk_01.id
}

output "linux_data_disk_01_name" {
  description = "Name of the additional 100GB data disk"
  value       = azurerm_managed_disk.linux_data_disk_01.name
}
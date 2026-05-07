# Linux VM Outputs
output "linux_vm_ids" {
  description = "Resource IDs of the Linux VMs"
  value       = { for k, v in azurerm_linux_virtual_machine.linux_vm : k => v.id }
}

output "linux_vm_names" {
  description = "Names of the Linux VMs"
  value       = { for k, v in azurerm_linux_virtual_machine.linux_vm : k => v.name }
}

output "linux_vm_public_ips" {
  description = "Public IP addresses of the Linux VMs"
  value       = { for k, v in azurerm_public_ip.linux_vm_public_ip : k => v.ip_address }
}

output "linux_vm_private_ips" {
  description = "Private IP addresses of the Linux VMs"
  value       = { for k, v in azurerm_network_interface.linux_vm_nic : k => v.private_ip_address }
}

output "linux_vm_ssh_commands" {
  description = "SSH commands to connect to the VMs"
  value       = { for k, v in azurerm_public_ip.linux_vm_public_ip : k => "ssh -i <path_to_private_key> ${var.admin_username}@${v.ip_address}" }
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "vm_instances" {
  description = "VM instance configuration"
  value       = local.vm_instances
}

output "ssh_private_key_secrets" {
  description = "Key Vault secret names for SSH private keys"
  value       = { for k, v in azurerm_key_vault_secret.linux_ssh_private_key : k => v.name }
}

output "ssh_public_key_secrets" {
  description = "Key Vault secret names for SSH public keys"
  value       = { for k, v in azurerm_key_vault_secret.linux_ssh_public_key : k => v.name }
}
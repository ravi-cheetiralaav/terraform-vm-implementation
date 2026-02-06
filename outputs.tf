output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = module.virtual_machine.resource_id
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = [for nic_key, nic in module.virtual_machine.network_interfaces : nic.private_ip_addresses]
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage_account.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = module.virtual_network.resource_id
}

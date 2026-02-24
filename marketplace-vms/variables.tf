# Core Infrastructure Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-marketplace-vms"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# VM Configuration Variables
variable "admin_username" {
  description = "Admin username for the Linux VMs"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "Size of the Linux VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "disk_storage_type" {
  description = "Storage account type for VM OS disks"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.disk_storage_type)
    error_message = "The storage account type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS."
  }
}

# Marketplace Image Variables
variable "image_publisher" {
  description = "Publisher of the marketplace image"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Offer of the marketplace image"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "SKU of the marketplace image"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "Version of the marketplace image"
  type        = string
  default     = "latest"
}
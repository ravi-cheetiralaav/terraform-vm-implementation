# Core Infrastructure Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# Linux VM Variables
variable "vhd_source_uri" {
  description = "URI of the VHD file stored in storage account"
  type        = string
  default     = "https://mystorageaccount.blob.core.windows.net/container/mydisk.vhd"
}

variable "vhd_storage_account_id" {
  description = "Resource ID of the storage account containing the VHD"
  type        = string
  default     = "/subscriptions/5dea8835-8c38-4f4d-8ac2-7accd278807d/resourceGroups/avm-testing-rg/providers/Microsoft.Storage/storageAccounts/azstdevvhdaueast01"
}

variable "linux_admin_username" {
  description = "Admin username for the Linux VM"
  type        = string
  default     = "linuxadmin"
}

variable "linux_vm_size" {
  description = "Size of the Linux VM"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "linux_disk_storage_type" {
  description = "Storage account type for Linux VM OS disk"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.linux_disk_storage_type)
    error_message = "The storage account type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS."
  }
}

variable "linux_disk_size_gb" {
  description = "Size of the Linux OS disk in GB"
  type        = number
  default     = 64
  validation {
    condition     = var.linux_disk_size_gb >= 30 && var.linux_disk_size_gb <= 1024
    error_message = "Disk size must be between 30 GB and 1024 GB."
  }
}

# Admin credentials (for compatibility)
variable "admin_username" {
  description = "Admin username for Windows VM (not used for Linux VM)"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for Windows VM (not used for Linux VM)"
  type        = string
  sensitive   = true
  default     = "NotUsedForLinuxVM123!"
}
# Core Infrastructure Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-install-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# VM Configuration Variables
variable "server" {
  description = "Server name identifier - passed to PowerShell script"
  type        = string
  validation {
    condition     = length(var.server) > 0
    error_message = "Server name must not be empty."
  }
}

variable "tags" {
  description = "Tags to be applied to resources - passed to PowerShell script"
  type        = map(string)
  default     = {
    Environment = "Demo"
    Project     = "InstallDemo"
  }
}

variable "admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for the Windows VM"
  type        = string
  sensitive   = true
  validation {
    condition = length(var.admin_password) >= 8 && length(var.admin_password) <= 123
    error_message = "Password must be 8-123 characters long."
  }
}

variable "vm_size" {
  description = "Size of the Windows VM"
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

# Marketplace Windows Image Variables
variable "image_publisher" {
  description = "Publisher of the marketplace image"
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "image_offer" {
  description = "Offer of the marketplace image"
  type        = string
  default     = "WindowsServer"
}

variable "image_sku" {
  description = "SKU of the marketplace image"
  type        = string
  default     = "2022-datacenter-g2"
}

variable "image_version" {
  description = "Version of the marketplace image"
  type        = string
  default     = "latest"
}
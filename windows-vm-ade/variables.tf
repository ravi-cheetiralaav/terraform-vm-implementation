# Core Infrastructure Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "Resource group name cannot be empty."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Australia East"
}

# Windows VM Variables
variable "admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "winadmin"
  validation {
    condition     = length(var.admin_username) >= 3 && length(var.admin_username) <= 20
    error_message = "Admin username must be between 3 and 20 characters."
  }
}

variable "vm_size" {
  description = "Size of the Windows VM"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "disk_storage_type" {
  description = "Storage account type for VM disks"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.disk_storage_type)
    error_message = "The storage account type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS."
  }
}

variable "os_disk_size_gb" {
  description = "Size of the Windows OS disk in GB"
  type        = number
  default     = 127
  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 2048
    error_message = "OS disk size must be between 30 and 2048 GB."
  }
}

variable "data_disk_size_gb" {
  description = "Size of the additional data disk in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.data_disk_size_gb >= 4 && var.data_disk_size_gb <= 32767
    error_message = "Data disk size must be between 4 and 32767 GB."
  }
}

# Networking Variables
variable "allowed_rdp_source_cidr" {
  description = "CIDR block allowed for RDP access (for enhanced security, use specific IP ranges)"
  type        = string
  default     = "*"
}

# Tags
variable "environment" {
  description = "Environment tag for resources"
  type        = string
  default     = "Testing"
}

variable "purpose" {
  description = "Purpose tag for resources"
  type        = string
  default     = "Windows VM with Azure Disk Encryption"
}
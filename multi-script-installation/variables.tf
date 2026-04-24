variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-multi-script-demo"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Australia East"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "image_publisher" {
  description = "VM image publisher"
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "image_offer" {
  description = "VM image offer"
  type        = string
  default     = "WindowsServer"
}

variable "image_sku" {
  description = "VM image SKU"
  type        = string
  default     = "2022-Datacenter"
}

variable "image_version" {
  description = "VM image version"
  type        = string
  default     = "latest"
}

variable "disk_storage_type" {
  description = "OS disk storage account type"
  type        = string
  default     = "Standard_LRS"
}

# -------------------------------------------------------
# Script parameters — each passed to its respective script
# -------------------------------------------------------

variable "param1" {
  description = "Parameter passed to script1.ps1 (-Param1)"
  type        = string
}

variable "param2" {
  description = "Parameter passed to script2.ps1 (-Param2)"
  type        = string
  default     = ""
}

variable "param3" {
  description = "Parameter passed to script3.ps1 (-Param3)"
  type        = string
  default     = ""
}

variable "run_script2" {
  description = "Whether to download and execute script2.ps1"
  type        = bool
  default     = true
}

variable "run_script3" {
  description = "Whether to download and execute script3.ps1"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "MultiScriptInstallation"
  }
}

variable "name" {
  description = "VM name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VM's network interface."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the admin user."
  type        = string
}

variable "admin_username" {
  description = "Admin username."
  type        = string
  default     = "azureuser"
}

variable "size" {
  description = "VM size."
  type        = string
  default     = "Standard_B2s"
}

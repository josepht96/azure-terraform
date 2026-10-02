variable "name" {
  description = "Web app name (must be globally unique)."
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

variable "docker_image" {
  description = "Docker Hub image to run, e.g. \"nginx:latest\"."
  type        = string
  default     = "nginx:latest"
}

variable "vnet_integration_subnet_id" {
  description = "Subnet delegated to Microsoft.Web/serverFarms for outbound VNet integration. Null disables it."
  type        = string
  default     = null
}

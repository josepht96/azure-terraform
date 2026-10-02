variable "name" {
  description = "VNet name."
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

variable "address_space" {
  description = "VNet address space, e.g. [\"10.10.0.0/16\"]."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets keyed by name. delegation is an optional service name, e.g. \"Microsoft.Web/serverFarms\"."
  type = map(object({
    address_prefixes = list(string)
    delegation       = optional(string)
  }))
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000" # placeholder; never applied
}

variable "admin_ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAA-placeholder"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo"
  location = "eastus2"
}

module "vnet" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vnet?ref=azure-vnet/v0.1.0"

  name                = "vnet-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.10.0.0/16"]

  subnets = {
    vm  = { address_prefixes = ["10.10.1.0/24"] }
    app = { address_prefixes = ["10.10.2.0/26"], delegation = "Microsoft.Web/serverFarms" }
  }
}

module "vm" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vm?ref=azure-vm/v0.1.0"

  name                 = "vm-demo"
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  subnet_id            = module.vnet.subnet_ids["vm"]
  admin_ssh_public_key = var.admin_ssh_public_key
}

module "app" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-app-service?ref=azure-app-service/v0.1.0"

  name                       = "app-demo"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  vnet_integration_subnet_id = module.vnet.subnet_ids["app"]
}

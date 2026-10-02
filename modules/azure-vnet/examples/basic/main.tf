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
}

resource "azurerm_resource_group" "this" {
  name     = "rg-example"
  location = "eastus2"
}

module "vnet" {
  source = "../.."

  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.10.0.0/16"]

  subnets = {
    vm  = { address_prefixes = ["10.10.1.0/24"] }
    app = { address_prefixes = ["10.10.2.0/26"], delegation = "Microsoft.Web/serverFarms" }
  }
}

output "subnet_ids" {
  value = module.vnet.subnet_ids
}

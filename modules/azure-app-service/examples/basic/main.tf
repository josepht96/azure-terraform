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

resource "azurerm_resource_group" "this" {
  name     = "rg-example"
  location = "eastus2"
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.30.2.0/26"]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

module "app" {
  source = "../.."

  name                       = "app-example-change-me"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  vnet_integration_subnet_id = azurerm_subnet.app.id
}

output "default_hostname" {
  value = module.app.default_hostname
}

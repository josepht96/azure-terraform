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

resource "azurerm_virtual_network" "this" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "vm" {
  name                 = "vm"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.1.0/24"]
}

module "vm" {
  source = "../.."

  name                 = "vm-example"
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  subnet_id            = azurerm_subnet.vm.id
  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKhn+vY+xgBtEluZx1v8/AEw34hLuiU2xY3Os6MQx3yz terraform-test-only" # throwaway test key
}

output "private_ip_address" {
  value = module.vm.private_ip_address
}

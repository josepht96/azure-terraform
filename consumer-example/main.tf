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

variable "admin_ssh_public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSfOQiaBumVexEL+6V+6v8HLDYXLFI3nirPGA+dEtxcPWAYf9tBMoDr6d1o1fJiap+uBrBIieLySlwlgm+S3Mk37FRi7v+m/ONymZcJu2KJqpBUU/uBZpR50EJr62HiT2Yr5ARW4pTCE58CPSFJ8VK31XaFW5jlehOqUefxBWW9AqUF02+JBtSKKw/SurWOxSAMPQRT6+LJi7t3kenOMuHCMqgBrN34xol++OWrE+NFFw6RpCDK1joiGJjjWNPjUJRa4kZi5iQZQ5rXgxBLZOllteyg2C2eoogC2J1KrYenBTOUKz7ciATdswHdB+si7ypWlWzEstgo41hljzdiKMFebag0bQ9XbpMq6IdGenA5sM4GTWMv7y57vnEiHMeuMMKqJGXq+YIP4yh+eW/BHKysM6XpYljVK7QOc0IwEgMxyIYx7Cfgx7hBhBhzDrJ6wkBRuwcY6i4n3p99/u+JdwA3D9YAQ2QC2AGdNOmpxffydpZfaEJ0kGAPsvDgSSBLlVW5vXB1ZiSmjctcGdqYl7o3DmKYF086KNXQAI+PAaL/b1wfr2OuBKiV6lWhg5Rma8qVx8Vzm2I23cvXwlSxi6+D9FOFIZtPlXF2NFRYj5+detcxTUh27aZ/dOEPoILJbPuHuA4BR175u28pD4agLRUeWUCJvozcdYC/TCAL46xmQ== joe@DESKTOP-R66PFDP"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo"
  location = "eastus2"
}

module "vnet" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vnet?ref=azure-vnet/v0.3.0"

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

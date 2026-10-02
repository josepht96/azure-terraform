# Unit tests: the mock provider stands in for azurerm, so these run without
# Azure credentials and create nothing. Run with `terraform test`.
mock_provider "azurerm" {}

variables {
  name                = "app-test"
  resource_group_name = "rg-test"
  location            = "eastus2"
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_service_plan.this.sku_name == "B1" && azurerm_service_plan.this.os_type == "Linux"
    error_message = "Service plan should be Linux B1."
  }

  assert {
    condition     = azurerm_linux_web_app.this.https_only == true
    error_message = "HTTPS-only must be enabled."
  }

  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "nginx:latest"
    error_message = "Default image should be nginx:latest."
  }
}

run "no_vnet_integration_by_default" {
  command = plan

  assert {
    condition     = azurerm_linux_web_app.this.virtual_network_subnet_id == null
    error_message = "VNet integration should be off unless a subnet is given."
  }
}

run "vnet_integration_when_subnet_given" {
  command = plan

  variables {
    vnet_integration_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/app"
  }

  assert {
    condition     = azurerm_linux_web_app.this.virtual_network_subnet_id == var.vnet_integration_subnet_id
    error_message = "The web app should integrate with the given subnet."
  }
}

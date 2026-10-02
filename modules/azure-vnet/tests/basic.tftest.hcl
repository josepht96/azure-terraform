# Unit tests: the mock provider stands in for azurerm, so these run without
# Azure credentials and create nothing. Run with `terraform test`.
mock_provider "azurerm" {}

variables {
  name                = "vnet-test"
  resource_group_name = "rg-test"
  location            = "eastus2"
  address_space       = ["10.10.0.0/16"]

  subnets = {
    vm  = { address_prefixes = ["10.10.1.0/24"] }
    app = { address_prefixes = ["10.10.2.0/26"], delegation = "Microsoft.Web/serverFarms" }
  }
}

run "creates_one_subnet_per_map_entry" {
  command = plan

  assert {
    condition     = length(azurerm_subnet.this) == 2
    error_message = "Expected one subnet per entry in var.subnets."
  }

  assert {
    condition     = azurerm_subnet.this["vm"].name == "vm"
    error_message = "Subnet name should come from the map key."
  }
}

run "delegation_is_optional" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["app"].delegation[0].service_delegation[0].name == "Microsoft.Web/serverFarms"
    error_message = "The app subnet should be delegated to Microsoft.Web/serverFarms."
  }

  assert {
    condition     = length(azurerm_subnet.this["vm"].delegation) == 0
    error_message = "The vm subnet should have no delegation."
  }
}

# apply against the mock provider fills in computed values like IDs,
# so we can check the outputs consumers depend on.
run "subnet_ids_output_is_keyed_by_name" {
  command = apply

  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["vm", "app"])
    error_message = "subnet_ids should have one key per subnet name."
  }

  assert {
    condition     = output.subnet_ids["vm"] == azurerm_subnet.this["vm"].id
    error_message = "subnet_ids values should be the subnet IDs."
  }
}

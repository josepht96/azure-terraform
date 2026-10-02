# Unit tests: the mock provider stands in for azurerm, so these run without
# Azure credentials and create nothing. Run with `terraform test`.
mock_provider "azurerm" {}

variables {
  name                = "vm-test"
  resource_group_name = "rg-test"
  location            = "eastus2"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/vm"
  # Throwaway key generated for tests; its private half was discarded.
  # The provider validates the key format even with a mock, so it must be real.
  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKhn+vY+xgBtEluZx1v8/AEw34hLuiU2xY3Os6MQx3yz terraform-test-only"
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_B2s"
    error_message = "Default size should be Standard_B2s."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.admin_username == "azureuser"
    error_message = "Default admin_username should be azureuser."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.source_image_reference[0].offer == "ubuntu-24_04-lts"
    error_message = "Image should be Ubuntu 24.04 LTS."
  }
}

run "ssh_key_only" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication == true
    error_message = "Password authentication must be disabled."
  }

  assert {
    condition     = one(azurerm_linux_virtual_machine.this.admin_ssh_key).public_key == var.admin_ssh_public_key
    error_message = "The admin SSH key should be the one passed in."
  }
}

run "nic_uses_given_subnet" {
  command = plan

  assert {
    condition     = azurerm_network_interface.this.ip_configuration[0].subnet_id == var.subnet_id
    error_message = "The NIC should be placed in var.subnet_id."
  }
}

run "size_can_be_overridden" {
  command = plan

  variables {
    size = "Standard_D2s_v5"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_D2s_v5"
    error_message = "size input should override the default."
  }
}

output "vnet_id" {
  description = "VNet ID."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Map of subnet name to subnet ID."
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
}

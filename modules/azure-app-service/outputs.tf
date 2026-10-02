output "app_id" {
  description = "Web app ID."
  value       = azurerm_linux_web_app.this.id
}

output "default_hostname" {
  description = "Default *.azurewebsites.net hostname."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "acr_id" {
  description = "Resource ID of the Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Name of the Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL — used to push/pull Docker images e.g. acrazureshopdev.azurecr.io"
  value       = azurerm_container_registry.main.login_server
}

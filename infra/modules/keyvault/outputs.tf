output "key_vault_id" {
  description = "Resource ID of the Key Vault — used to grant additional role assignments"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault — used by Key Vault CSI Driver on AKS to mount secrets"
  value       = azurerm_key_vault.main.vault_uri
}

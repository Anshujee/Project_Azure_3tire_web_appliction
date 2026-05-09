# ── Azure SQL Outputs ──────────────────────────────
output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server — used in connection strings"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.main.name
}

output "sql_users_db_name" {
  description = "Name of the users database"
  value       = azurerm_mssql_database.users.name
}

output "sql_orders_db_name" {
  description = "Name of the orders database"
  value       = azurerm_mssql_database.orders.name
}

# ── Cosmos DB Outputs ──────────────────────────────
output "cosmos_endpoint" {
  description = "Cosmos DB endpoint URL — used in application connection strings"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmos_primary_key" {
  description = "Cosmos DB primary key — stored in Key Vault, never in code"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "cosmos_account_name" {
  description = "Name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

# ── Redis Outputs ──────────────────────────────────
output "redis_hostname" {
  description = "Redis Cache hostname — used in connection strings"
  value       = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  description = "Redis Cache SSL port (TLS-only connection)"
  value       = azurerm_redis_cache.main.ssl_port
}

output "redis_primary_access_key" {
  description = "Redis Cache primary access key — stored in Key Vault, never in code"
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

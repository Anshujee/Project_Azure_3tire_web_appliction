output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace — passed to AKS module for Container Insights"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "application_insights_keys" {
  description = "Map of service name to Application Insights instrumentation key — injected into pods via Key Vault"
  value       = { for svc, appi in azurerm_application_insights.services : svc => appi.instrumentation_key }
  sensitive   = true
}

output "application_insights_connection_strings" {
  description = "Map of service name to Application Insights connection string"
  value       = { for svc, appi in azurerm_application_insights.services : svc => appi.connection_string }
  sensitive   = true
}

output "grafana_endpoint" {
  description = "Azure Managed Grafana endpoint URL"
  value       = azurerm_dashboard_grafana.main.endpoint
}

output "grafana_id" {
  description = "Resource ID of the Grafana instance"
  value       = azurerm_dashboard_grafana.main.id
}

# ─────────────────────────────────────────────
# Log Analytics Workspace
# Central store for all logs and metrics from AKS, App Insights, and Azure resources
# ─────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"   # Pay per GB ingested — most common and cost-effective
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# ─────────────────────────────────────────────
# Application Insights — one per microservice
#
# for_each creates one resource per item in the services list
# Instead of writing 8 identical blocks, we write one block
# and Terraform creates 8 resources automatically
# ─────────────────────────────────────────────
resource "azurerm_application_insights" "services" {
  for_each            = toset(var.services)   # toset() removes duplicates and sorts
  name                = "appi-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = each.key == "product-service" ? "other" : "web"
  # product-service uses Python/FastAPI — type "other" covers non-.NET/Node apps
  # All other services use "web" which works for Node.js and React apps
  tags = var.tags
}

# ─────────────────────────────────────────────
# Azure Managed Grafana
# Pre-built Grafana instance managed by Azure — no server to maintain
# Connected to Log Analytics for dashboards and alerting
# ─────────────────────────────────────────────
resource "azurerm_dashboard_grafana" "main" {
  name                              = "grafana-${var.project}-${var.environment}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  sku                               = "Standard"
  api_key_enabled                   = true    # Allow API access for dashboard automation
  deterministic_outbound_ip_enabled = true    # Fixed outbound IP for firewall rules
  public_network_access_enabled     = true    # Allow browser access to Grafana UI
  tags                              = var.tags

  # System-assigned identity — used to query Azure Monitor and Log Analytics
  identity {
    type = "SystemAssigned"
  }
}

# Grant Grafana Monitoring Reader on the resource group
# Allows Grafana to read metrics from all resources in the group
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# Read current client config for subscription ID
data "azurerm_client_config" "current" {}

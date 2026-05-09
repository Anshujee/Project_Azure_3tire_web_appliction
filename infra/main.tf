locals {
  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  })
}

module "networking" {
  source              = "./modules/networking"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

module "acr" {
  source              = "./modules/acr"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  # AKS kubelet identity needs AcrPull so nodes can pull images from this registry
  aks_kubelet_identity_object_id = module.aks.kubelet_identity_object_id
}

module "aks" {
  source              = "./modules/aks"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = module.networking.aks_subnet_id
  tags                = local.tags

  # Connected to Log Analytics Workspace created in monitoring module (Step 2.8)
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

module "databases" {
  source              = "./modules/databases"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  aks_subnet_id       = module.networking.aks_subnet_id
  tags                = local.tags

  sql_admin_password = var.sql_admin_password
  sql_location       = var.sql_location
}

module "keyvault" {
  source              = "./modules/keyvault"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  # Identity — who can access secrets
  aks_identity_id       = module.aks.kubelet_identity_object_id
  pipeline_sp_object_id = var.pipeline_sp_object_id

  # Secrets sourced from databases module outputs
  sql_server_fqdn          = module.databases.sql_server_fqdn
  sql_admin_username       = "sqladmin"
  sql_admin_password       = var.sql_admin_password
  cosmos_endpoint          = module.databases.cosmos_endpoint
  cosmos_primary_key       = module.databases.cosmos_primary_key
  redis_hostname           = module.databases.redis_hostname
  redis_ssl_port           = module.databases.redis_ssl_port
  redis_primary_access_key = module.databases.redis_primary_access_key

  network_default_action = var.keyvault_network_default_action
}

module "appgateway" {
  source              = "./modules/appgateway"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  appgw_subnet_id = module.networking.appgw_subnet_id
  # aks_ingress_ip populated after Phase 6 when AKS ingress controller is deployed
}

module "monitoring" {
  source              = "./modules/monitoring"
  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
  log_retention_days  = var.log_retention_days
}

# ── AKS Diagnostic Settings ────────────────────────────────────────────────────
# Defined here in main.tf (not inside monitoring module) to avoid circular dependency:
# monitoring needs no AKS dependency to create the workspace,
# AKS needs workspace ID to enable Container Insights.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-${var.environment}"
  target_resource_id         = module.aks.aks_cluster_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  # AKS control plane logs
  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "kube-audit" }
  enabled_log { category = "cluster-autoscaler" }

  # AKS metrics — CPU, memory, pod counts
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

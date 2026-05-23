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

  # App Insights connection strings from monitoring module — stored as Key Vault secrets
  # so CSI driver can inject them into pods as APPINSIGHTS_CONNECTION_STRING env var
  application_insights_connection_strings = module.monitoring.application_insights_connection_strings

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
  enabled_metric {
    category = "AllMetrics"
  }
}

# ── Key Vault CSI Addon Role Assignment ───────────────────────────────────────
# The Key Vault Secrets Provider addon uses its OWN managed identity to read
# secrets — separate from the kubelet identity assigned in the keyvault module.
# Without this, SecretProviderClass mounts will fail with 403 Forbidden.
resource "azurerm_role_assignment" "csi_addon_kv_secrets_user" {
  principal_id         = module.aks.addon_identity_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.keyvault.key_vault_id
}

# ── AKS Cluster Admin Role Assignment ────────────────────────────────────────
# Grants the developer Azure Kubernetes Service RBAC Cluster Admin on the AKS cluster.
# Required because azure_rbac_enabled = true — Azure AD controls kubectl access.
# Without this, kubectl commands fail with 403 Forbidden even after az aks get-credentials.
resource "azurerm_role_assignment" "aks_cluster_admin" {
  principal_id         = var.aks_admin_object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = module.aks.aks_cluster_id
}

# ── Workload Identity — notification-service ──────────────────────────────────
# Workload Identity allows pods to authenticate to Azure AD using their
# Kubernetes ServiceAccount token — no credentials stored anywhere.
#
# How it works:
# 1. Pod's ServiceAccount has annotation: azure.workload.identity/client-id
# 2. Pod has label: azure.workload.identity/use: "true"
# 3. Workload Identity webhook injects AZURE_CLIENT_ID env var + token mount
# 4. Azure SDK uses the projected token to get a short-lived Azure AD token
# 5. Token is scoped to what the Managed Identity has been granted

# User Assigned Managed Identity for notification-service
# Using User Assigned (not System Assigned) so it can be referenced before AKS exists
resource "azurerm_user_assigned_identity" "notification_service" {
  name                = "id-notification-service-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

# Federated Identity Credential — links the K8s ServiceAccount to the Managed Identity
# AKS OIDC issuer signs the ServiceAccount token; Azure AD trusts this issuer
# and exchanges the token for an Azure AD access token
resource "azurerm_federated_identity_credential" "notification_service" {
  name                = "fic-notification-service-${var.environment}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.notification_service.id

  # The OIDC issuer of our AKS cluster — Azure AD will trust tokens from this issuer
  issuer = module.aks.oidc_issuer_url

  # The subject is the ServiceAccount: system:serviceaccount:<namespace>:<serviceaccount-name>
  subject = "system:serviceaccount:${var.environment}:notification-service"

  # Azure AD audience — must match what the projected token uses (always this value for AKS)
  audience = ["api://AzureADTokenExchange"]
}

# Grant notification-service read access to Key Vault secrets
# With Workload Identity the pod can call Key Vault SDK directly at runtime
resource "azurerm_role_assignment" "notification_service_kv_secrets_user" {
  principal_id         = azurerm_user_assigned_identity.notification_service.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.keyvault.key_vault_id
}

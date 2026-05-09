# Read current Terraform executor's identity
# Used to grant Terraform itself permission to write secrets during apply
data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────────
# Azure Key Vault
# ─────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  # RBAC authorization — use Azure roles instead of legacy Access Policies
  # Allows the same RBAC system used across all Azure to control Key Vault access
  enable_rbac_authorization = true

  # Soft delete — deleted vault and secrets are retained for 90 days
  # Protects against accidental deletion — vault is recoverable
  soft_delete_retention_days = 90

  # Purge protection — prevents permanent deletion during soft-delete period
  # Even an admin cannot permanently delete until retention period expires
  purge_protection_enabled = true

  # Network access — allow Azure services + specific VNet
  network_acls {
    default_action = "Deny"         # Block all traffic by default
    bypass         = "AzureServices" # Allow trusted Azure services (Azure Monitor, Pipelines)
    ip_rules       = []
  }
}

# ─────────────────────────────────────────────
# Role Assignments
# ─────────────────────────────────────────────

# Grant Terraform executor Key Vault Secrets Officer
# Without this, Terraform cannot write secrets during terraform apply
resource "azurerm_role_assignment" "terraform_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant AKS kubelet identity Key Vault Secrets User (read-only)
# Pods use this identity via Key Vault CSI Driver to mount secrets as files
resource "azurerm_role_assignment" "aks_secrets_user" {
  scope                            = azurerm_key_vault.main.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.aks_identity_id
  skip_service_principal_aad_check = true
}

# Grant Azure DevOps pipeline Service Principal Key Vault Secrets Officer
# Pipelines can read AND write secrets — needed to update secrets during CD
resource "azurerm_role_assignment" "pipeline_secrets_officer" {
  scope                            = azurerm_key_vault.main.id
  role_definition_name             = "Key Vault Secrets Officer"
  principal_id                     = var.pipeline_sp_object_id
  skip_service_principal_aad_check = true
}

# ─────────────────────────────────────────────
# Secrets — Application Credentials
# ─────────────────────────────────────────────
# All secrets depend on role assignment for Terraform to write them
# depends_on ensures the role assignment exists before secret creation

# ── Azure SQL Secrets ──────────────────────────
resource "azurerm_key_vault_secret" "sql_server_fqdn" {
  name         = "sql-server-fqdn"
  value        = var.sql_server_fqdn
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

resource "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  value        = var.sql_admin_username
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

# ── Cosmos DB Secrets ──────────────────────────
resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmos-endpoint"
  value        = var.cosmos_endpoint
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

resource "azurerm_key_vault_secret" "cosmos_primary_key" {
  name         = "cosmos-primary-key"
  value        = var.cosmos_primary_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

# ── Redis Secrets ──────────────────────────────
resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = var.redis_hostname
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_ssl_port" {
  name         = "redis-ssl-port"
  value        = tostring(var.redis_ssl_port)
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_primary_access_key" {
  name         = "redis-primary-access-key"
  value        = var.redis_primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}

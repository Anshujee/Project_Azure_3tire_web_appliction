# ─────────────────────────────────────────────
# Azure Container Registry
# ─────────────────────────────────────────────

# ACR names: globally unique, alphanumeric only, no hyphens, 5–50 chars
resource "azurerm_container_registry" "main" {
  name                = "acr${var.project}${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  tags                = var.tags

  # Disable admin account — we use Managed Identity for authentication
  # Admin account uses a shared username/password which is a security risk
  admin_enabled = false

  # Enable geo-replication only for Premium SKU
  # For dev we skip geo-replication to save cost
  # Uncomment for prod:
  # georeplications {
  #   location                = "westus"
  #   zone_redundancy_enabled = true
  # }
}

# ─────────────────────────────────────────────
# AcrPull Role Assignment
# ─────────────────────────────────────────────

# Grant the AKS kubelet identity permission to pull images from this ACR
# AcrPull = read-only access to pull images, cannot push or delete
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = var.aks_kubelet_identity_object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

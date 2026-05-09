# ─────────────────────────────────────────────
# AKS Cluster
# ─────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project}-${var.environment}"
  tags                = var.tags

  # Kubernetes version — omitting uses latest stable automatically
  # Pin this in prod: kubernetes_version = "1.29.x"

  # ── Identity ──────────────────────────────
  # SystemAssigned = Azure manages the identity automatically
  # No service principal credentials to rotate or expire
  identity {
    type = "SystemAssigned"
  }

  # ── System Node Pool ──────────────────────
  # System pool runs critical Kubernetes components (CoreDNS, metrics-server)
  # Must always have at least 1 node — cannot be scaled to 0
  default_node_pool {
    name           = "system"
    node_count     = var.system_node_count
    vm_size        = var.system_node_vm_size
    vnet_subnet_id = var.subnet_id

    # Only system workloads run on this pool
    only_critical_addons_enabled = true

    os_disk_size_gb = 128
    os_disk_type    = "Managed"

    # Enable availability zones for high availability
    zones = ["1", "2"]
  }

  # ── Networking ────────────────────────────
  # Azure CNI: every pod gets a real VNet IP address
  # Allows pods to communicate directly with Azure services
  # Alternative is Kubenet where pods get private IPs behind NAT
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"     # Enforces Kubernetes NetworkPolicy resources
    load_balancer_sku = "standard"  # Required for availability zones
    outbound_type     = "loadBalancer"
  }

  # ── RBAC + Azure AD Integration ──────────
  # azure_rbac_enabled = use Azure RBAC to control who can run kubectl commands
  # managed = true means Azure manages the AD integration automatically
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # ── API Server Access ─────────────────────
  # Restrict which IPs can reach the Kubernetes API server
  # Empty list = no restriction (fine for dev, lock down for prod)
  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  # ── Azure Monitor Addon ───────────────────
  # Sends container logs and metrics to Log Analytics Workspace
  # Only enabled when log_analytics_workspace_id is provided
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  # ── Azure Policy Addon ────────────────────
  # Enforces policies on workloads running in AKS
  # e.g. deny privileged containers, require resource limits
  azure_policy_enabled = true

  # ── Key Vault CSI Driver ──────────────────
  # Allows pods to mount secrets from Azure Key Vault as files
  # secret_rotation_enabled = automatically updates mounted secrets when they change
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # ── Maintenance Window ────────────────────
  # Schedule automatic upgrades during off-peak hours
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }
}

# ─────────────────────────────────────────────
# User Node Pool
# ─────────────────────────────────────────────
# Separate from system pool — runs application workloads
# Can be scaled to 0 during off-hours to save cost
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = var.subnet_id
  mode                  = "User"
  tags                  = var.tags

  # Autoscaling — Kubernetes adds/removes nodes based on pending pods
  enable_auto_scaling = true
  node_count          = var.user_node_count
  min_count           = var.user_node_min_count
  max_count           = var.user_node_max_count

  os_disk_size_gb = 128
  os_disk_type    = "Managed"

  # Spread nodes across availability zones for resilience
  zones = ["1", "2", "3"]

  # Lifecycle: ignore node_count changes made by autoscaler
  # Without this Terraform would reset count to 3 on every apply
  lifecycle {
    ignore_changes = [node_count]
  }
}

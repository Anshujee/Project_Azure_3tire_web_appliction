data "azurerm_client_config" "current" {}

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

    # zones removed — free tier subscriptions only support zone 2 in eastus
    # Re-add zones = ["1","2","3"] when using a paid subscription
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
  # managed = true enables AKS-managed Entra integration (required in azurerm v3.x)
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
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

  # ── OIDC Issuer ───────────────────────────
  # Required for Workload Identity — exposes an OIDC endpoint so Azure AD
  # can verify tokens issued by Kubernetes ServiceAccounts
  oidc_issuer_enabled = true

  # ── Workload Identity ─────────────────────
  # Installs the Workload Identity webhook on the cluster
  # Allows pods to authenticate to Azure AD using their ServiceAccount token
  # without any credentials stored in the pod or Kubernetes Secrets
  workload_identity_enabled = true

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
  auto_scaling_enabled = true
  node_count          = var.user_node_count
  min_count           = var.user_node_min_count
  max_count           = var.user_node_max_count

  os_disk_size_gb = 128
  os_disk_type    = "Managed"

  # zones removed — free tier subscription zone limitation (see system node pool comment)

  # Lifecycle: ignore node_count changes made by autoscaler
  # Without this Terraform would reset count to 3 on every apply
  lifecycle {
    ignore_changes = [node_count]
  }
}

# ─────────────────────────────────────────────
# Spot Node Pool (Cost Optimisation)
# ─────────────────────────────────────────────
# Spot VMs are unused Azure capacity at up to 90% discount.
# Trade-off: Azure can evict them with 30 seconds notice when capacity is needed.
# Safe for: batch jobs, queue workers, stateless burst workloads.
# NOT safe for: stateful services, databases, or anything that can't tolerate sudden termination.
#
# Taint: kubernetes.azure.com/scalesetpriority=spot:NoSchedule
# Pods must explicitly tolerate this taint to be scheduled here.
# This prevents regular workloads from accidentally landing on spot nodes.
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                 = var.enable_spot_node_pool ? 1 : 0
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.spot_node_vm_size
  vnet_subnet_id        = var.subnet_id
  mode                  = "User"
  tags                  = var.tags

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1  # -1 means cap at the on-demand price — no surprise bills

  auto_scaling_enabled = true
  node_count           = 1
  min_count            = 1
  max_count            = var.spot_node_max_count

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
    "workload-type"                         = "batch"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  os_disk_size_gb = 128
  os_disk_type    = "Managed"

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ─────────────────────────────────────────────
# Flux v2 Extension
# ─────────────────────────────────────────────
# Installs the Flux GitOps operator on the AKS cluster via the AKS managed extension.
# This deploys flux-system components: source-controller, helm-controller,
# kustomize-controller, notification-controller.
resource "azurerm_kubernetes_cluster_extension" "flux" {
  count          = var.enable_flux ? 1 : 0
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
  release_train  = "Stable"

  configuration_settings = {
    "helm-controller.enabled"         = "true"
    "source-controller.enabled"       = "true"
    "kustomize-controller.enabled"    = "true"
    "notification-controller.enabled" = "true"
    "image-automation-controller.enabled"  = "false"
    "image-reflector-controller.enabled"   = "false"
  }
}

# ─────────────────────────────────────────────
# Flux GitOps Configuration
# ─────────────────────────────────────────────
# Creates a GitRepository source + Kustomization pointing at our Azure DevOps repo.
# Flux polls the repo every 60 seconds and applies any changes found at the kustomizations path.
#
# Authentication: var.git_https_pat is a plain-text Azure DevOps PAT.
# Terraform base64-encodes it before passing to the resource (API requirement).
# Mark the variable as sensitive so it never appears in plan output.
resource "azurerm_kubernetes_flux_configuration" "main" {
  count      = var.enable_flux ? 1 : 0
  name       = "azureshop"
  cluster_id = azurerm_kubernetes_cluster.main.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = var.git_repository_url
    reference_type           = "branch"
    reference_value          = var.git_branch
    sync_interval_in_seconds = 60
    https_user               = var.git_https_user
    https_key_base64         = base64encode(var.git_https_pat)
  }

  kustomizations {
    name                       = "releases"
    path                       = "./k8s/gitops/releases"
    sync_interval_in_seconds   = 60
    retry_interval_in_seconds  = 30
    garbage_collection_enabled = true
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}

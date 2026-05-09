output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster — used by monitoring module"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster — used in kubectl commands"
  value       = azurerm_kubernetes_cluster.main.name
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity — used by ACR (AcrPull) and Key Vault modules"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS system-assigned managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "kube_config" {
  description = "Kubeconfig for connecting kubectl to this cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "node_resource_group" {
  description = "Auto-created resource group where AKS node VMs live"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

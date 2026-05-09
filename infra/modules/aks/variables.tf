variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "Subnet ID where AKS nodes are deployed — from networking module"
  type        = string
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "system_node_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_count" {
  description = "Initial number of nodes in the user node pool"
  type        = number
  default     = 1   # reduced from 3 — free tier vCPU quota is 10 total (2 used by system pool)
}

variable "user_node_vm_size" {
  description = "VM size for user node pool"
  type        = string
  default     = "Standard_D2s_v3"   # reduced from D4s_v3 (4 vCPU) to D2s_v3 (2 vCPU) for free tier quota
}

variable "user_node_min_count" {
  description = "Minimum nodes for user node pool autoscaler"
  type        = number
  default     = 1   # reduced from 2 for free tier vCPU quota
}

variable "user_node_max_count" {
  description = "Maximum nodes for user node pool autoscaler"
  type        = number
  default     = 3   # reduced from 10 for free tier vCPU quota
}

variable "api_server_authorized_ip_ranges" {
  description = "List of IP ranges allowed to access the AKS API server. Empty list means no restriction."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for Azure Monitor — connected after monitoring module is created"
  type        = string
  default     = null
}

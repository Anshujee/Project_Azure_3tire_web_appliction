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
  default     = 3
}

variable "user_node_vm_size" {
  description = "VM size for user node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "user_node_min_count" {
  description = "Minimum nodes for user node pool autoscaler"
  type        = number
  default     = 2
}

variable "user_node_max_count" {
  description = "Maximum nodes for user node pool autoscaler"
  type        = number
  default     = 10
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

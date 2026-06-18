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

# ── Identity Variables ─────────────────────────────────
variable "aks_identity_id" {
  description = "Object ID of the AKS kubelet managed identity — granted Key Vault Secrets User (read-only)"
  type        = string
}

variable "pipeline_sp_object_id" {
  description = "Object ID of the Azure DevOps Service Principal — granted Key Vault Secrets Officer (read/write)"
  type        = string
}

# ── Secret Values (from databases module) ─────────────
variable "sql_server_fqdn" {
  description = "SQL Server fully qualified domain name"
  type        = string
}

variable "sql_admin_username" {
  description = "SQL Server admin username"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}

variable "cosmos_endpoint" {
  description = "Cosmos DB endpoint URL"
  type        = string
}

variable "cosmos_primary_key" {
  description = "Cosmos DB primary access key"
  type        = string
  sensitive   = true
}

variable "redis_hostname" {
  description = "Redis Cache hostname"
  type        = string
}

variable "redis_ssl_port" {
  description = "Redis Cache SSL port"
  type        = number
}

variable "redis_primary_access_key" {
  description = "Redis Cache primary access key"
  type        = string
  sensitive   = true
}

variable "application_insights_connection_strings" {
  description = "Map of service name to Application Insights connection string — one Key Vault secret created per entry"
  type        = map(string)
  default     = {}
}

variable "network_default_action" {
  description = "Key Vault firewall default action: Allow (dev) or Deny (prod). RBAC still gates all access."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be Allow or Deny."
  }
}

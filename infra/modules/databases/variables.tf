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

variable "aks_subnet_id" {
  description = "AKS subnet ID — used to allow database access only from AKS nodes"
  type        = string
}

# ── Azure SQL ──────────────────────────────────────
variable "sql_location" {
  description = "Azure region for SQL Server — may differ from main location on free tier subscriptions where eastus SQL provisioning is disabled"
  type        = string
  default     = "eastus2"
}

variable "sql_admin_username" {
  description = "SQL Server administrator login username"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password — must be 8+ chars with uppercase, lowercase, number, symbol"
  type        = string
  sensitive   = true   # Marked sensitive — never printed in logs or plan output
}

variable "sql_sku" {
  description = "SQL Database SKU — controls compute and cost"
  type        = string
  default     = "S1"   # S1 = 20 DTUs, sufficient for dev
}

# ── Cosmos DB ──────────────────────────────────────
variable "cosmos_consistency_level" {
  description = "Cosmos DB consistency level — controls read/write consistency vs performance"
  type        = string
  default     = "Session"  # Session = default, good balance for most apps
}

# ── Redis ──────────────────────────────────────────
variable "redis_sku_name" {
  description = "Redis Cache SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"   # Standard = replicated, supports data persistence
}

variable "redis_capacity" {
  description = "Redis Cache capacity (0=250MB, 1=1GB, 2=2.5GB, 3=6GB...)"
  type        = number
  default     = 1   # C1 = 1GB — sufficient for session/cart caching in dev
}

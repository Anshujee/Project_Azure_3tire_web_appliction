variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "azureshop"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
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

variable "sql_admin_password" {
  description = "SQL Server admin password — pass via environment variable TF_VAR_sql_admin_password, never in tfvars files"
  type        = string
  sensitive   = true
}

variable "pipeline_sp_object_id" {
  description = "Object ID of the Azure DevOps Service Principal (sp-azureshop-terraform) — granted Key Vault Secrets Officer"
  type        = string
  default     = "0eaa884c-04c8-48e1-8b8b-8e18227353b3"
}

variable "log_retention_days" {
  description = "Days to retain logs in Log Analytics Workspace — 30 for dev, 60 for staging, 90 for prod"
  type        = number
  default     = 30
}

variable "keyvault_network_default_action" {
  description = "Key Vault firewall default action: Allow (dev — Terraform runs locally) or Deny (prod)"
  type        = string
  default     = "Deny"
}

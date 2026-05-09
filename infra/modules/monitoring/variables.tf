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

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace"
  type        = number
  default     = 30   # 30 days for dev, use 90 for staging/prod
}

variable "services" {
  description = "List of microservice names — one Application Insights instance is created per service"
  type        = list(string)
  default = [
    "frontend",
    "api-gateway",
    "user-service",
    "product-service",
    "cart-service",
    "order-service",
    "payment-service",
    "notification-service"
  ]
}

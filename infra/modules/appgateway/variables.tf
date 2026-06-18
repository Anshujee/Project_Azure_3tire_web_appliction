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

variable "appgw_subnet_id" {
  description = "Subnet ID for Application Gateway — from networking module"
  type        = string
}

variable "capacity" {
  description = "Number of Application Gateway instances (min 1 for dev, min 2 for prod)"
  type        = number
  default     = 1
}

variable "aks_ingress_ip" {
  description = "Private IP of the AKS ingress controller — populated after Phase 6"
  type        = string
  default     = ""   # Left empty until AKS ingress is deployed in Phase 6
}

variable "waf_mode" {
  description = "WAF mode — Detection (log only) or Prevention (block threats)"
  type        = string
  default     = "Prevention"
}

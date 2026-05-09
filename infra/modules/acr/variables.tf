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

variable "sku" {
  description = "SKU of the Container Registry (Basic, Standard, Premium)"
  type        = string
  default     = "Premium"
}

variable "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity — used to grant AcrPull role"
  type        = string
}

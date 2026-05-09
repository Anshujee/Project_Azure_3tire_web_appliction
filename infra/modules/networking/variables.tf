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

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network"
  type        = string
  default     = "10.0.0.0/8"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS nodes subnet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "db_subnet_cidr" {
  description = "CIDR block for databases subnet"
  type        = string
  default     = "10.2.0.0/24"
}

variable "appgw_subnet_cidr" {
  description = "CIDR block for Application Gateway subnet"
  type        = string
  default     = "10.3.0.0/24"
}

variable "bastion_subnet_cidr" {
  description = "CIDR block for Azure Bastion subnet (must be /26 or larger)"
  type        = string
  default     = "10.4.0.0/24"
}

# AzureShop — 3-Tier E-Commerce DevOps Project

A production-grade e-commerce platform built entirely on Azure using Azure DevOps best practices.

## Architecture
- **Frontend:** React / Next.js
- **Backend:** Node.js + Python microservices
- **Database:** Azure SQL + Cosmos DB + Redis
- **Compute:** AKS (Kubernetes)
- **IaC:** Terraform
- **CI/CD:** Azure Pipelines

## Project Structure
```
├── infra/          # Terraform infrastructure code
├── services/       # Microservices source code
├── helm/           # Helm charts for Kubernetes deployment
├── pipelines/      # Azure Pipeline YAML files
├── k8s/            # Kubernetes manifests
└── docs/           # Documentation and runbooks
```

## Environments
| Environment | Purpose |
|---|---|
| dev | Development and testing |
| staging | Pre-production validation |
| prod | Live production environment |

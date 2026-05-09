# Azure Boards Setup — Step 1.4

## Overview

| Setting | Value |
|---|---|
| Azure DevOps Org | `azureshop-org` |
| Project | `AzureShop` |
| Process Template | **Scrum** |
| Board Type | Kanban |

---

## Step 1: Configure Kanban Board Columns

Go to: **Project Settings → Boards → Team → Board Settings → Columns**

Add/rename columns in this order:

| Order | Column Name | WIP Limit | Maps To State |
|---|---|---|---|
| 1 | Backlog | — | New |
| 2 | To Do | 10 | Active |
| 3 | In Progress | 5 | Active |
| 4 | Review | 3 | Active |
| 5 | Done | — | Closed |

> **How to set columns:**
> 1. Go to your board view
> 2. Click the gear icon (⚙) at top-right
> 3. Select **Columns**
> 4. Add/rename columns to match the table above
> 5. Save

---

## Step 2: Create Epics

Go to: **Boards → Backlogs → Click dropdown → Epics**

Create the following 5 Epics:

| # | Epic Title | Area | Priority | Description |
|---|---|---|---|---|
| 1 | Infrastructure as Code | Infrastructure | 1 | Provision all Azure infrastructure using Terraform with remote state in Azure Blob Storage. Covers networking, AKS, ACR, databases, Key Vault, and Application Gateway. |
| 2 | Microservices Development | Development | 2 | Build 8 minimal microservices (frontend, api-gateway, user, product, cart, order, payment, notification) with Docker support and health endpoints. |
| 3 | CI/CD Pipelines | DevOps | 3 | Implement fully automated YAML-based Azure Pipelines for every service with multi-stage deployment across dev, staging, and prod environments. |
| 4 | Kubernetes Deployment | Infrastructure | 4 | Deploy all microservices to AKS using Helm charts with production-grade configurations: HPA, PDB, Network Policies, Workload Identity, and Key Vault CSI. |
| 5 | Monitoring & Security | Operations | 5 | Full observability via Azure Monitor, App Insights, Managed Grafana, and Defender for Cloud. Includes shift-left security via SonarCloud and Trivy. |

> **How to create an Epic:**
> 1. Backlogs → switch to Epics level
> 2. Click **+ New Work Item**
> 3. Enter title, set Area, Priority, and paste Description
> 4. Save & Close

---

## Step 3: Create Features Under Each Epic

### Epic 1 — Infrastructure as Code

| Feature Title |
|---|
| Terraform Remote State Backend |
| Networking Module (VNet, Subnets, NSGs) |
| Azure Container Registry (ACR) Module |
| AKS Cluster Module |
| Databases Module (SQL, Cosmos DB, Redis) |
| Key Vault Module |
| Application Gateway + WAF Module |
| Monitoring Infrastructure Module |
| Environment Separation (dev/staging/prod) |

### Epic 2 — Microservices Development

| Feature Title |
|---|
| User Service (Node.js + Azure SQL) |
| Product Service (Python/FastAPI + Cosmos DB) |
| Cart Service (Node.js + Redis) |
| Order Service (Node.js + Azure SQL + Service Bus) |
| Payment Service (Node.js — Mock) |
| Notification Service (Node.js + Service Bus) |
| Frontend (Next.js) |
| API Gateway (NGINX) |

### Epic 3 — CI/CD Pipelines

| Feature Title |
|---|
| Reusable Pipeline Templates |
| CI Pipelines (8 services) |
| CD Pipelines (dev / staging / prod) |
| Terraform Validate & Apply Pipelines |
| Variable Groups & Environments Setup |
| Pipeline Security Hardening |

### Epic 4 — Kubernetes Deployment

| Feature Title |
|---|
| AKS Initial Setup (namespaces, ingress) |
| Key Vault CSI Driver Setup |
| Helm Charts (8 services) |
| Kubernetes Resource Configuration |
| Ingress & TLS Configuration |
| Network Policies |
| Workload Identity (Managed Identity per pod) |

### Epic 5 — Monitoring & Security

| Feature Title |
|---|
| Application Insights Integration |
| Azure Monitor & Container Insights |
| Log Analytics KQL Queries |
| Grafana Dashboards |
| Alerts Configuration |
| Defender for Cloud Setup |
| Azure Policy & Governance |
| RBAC & Least Privilege |
| Pipeline Security (SAST + Trivy + Secret Scanning) |
| Network Security Hardening |
| Secret Management Audit |

---

## Step 4: Create Sprint 1

Go to: **Project Settings → Boards → Team → Iterations**

| Setting | Value |
|---|---|
| Sprint Name | Sprint 1 |
| Start Date | 2026-05-09 |
| End Date | 2026-05-22 |
| Duration | 2 weeks |

> **How to create a Sprint:**
> 1. Project Settings → Boards → (select your team) → Iterations
> 2. Click **+ New child iteration** under the root
> 3. Name: `Sprint 1`
> 4. Set start/end dates
> 5. Click **Save**
> 6. Go back to Boards → Backlogs and click **Set dates** if prompted

---

## Step 5: Add Phase 1 Tasks to Sprint 1

Create the following **Product Backlog Items (PBIs)** and assign to Sprint 1:

| Title | Epic | Story Points | Assignee |
|---|---|---|---|
| Create Azure free account and resource group `rg-azureshop-dev` | — (Foundation) | 1 | — |
| Enable all required Azure resource providers | — (Foundation) | 1 | — |
| Create Azure DevOps org `azureshop-org` and project `AzureShop` | — (Foundation) | 1 | — |
| Initialize monorepo and configure branch strategy | — (Foundation) | 2 | — |
| Configure branch policies on `main` and `dev` | — (Foundation) | 1 | — |
| Create Service Principal for Terraform (`sp-azureshop-terraform`) | — (Foundation) | 2 | — |
| Create Service Connection in Azure DevOps (`sc-azureshop-azure`) | — (Foundation) | 1 | — |
| Install and verify all local tools (az, terraform, kubectl, helm, docker) | — (Foundation) | 1 | — |

> **To add to Sprint 1:**
> 1. Backlogs → PBIs level
> 2. Create each item above
> 3. Right-click each item → **Move to iteration** → Sprint 1

---

## Step 6: Configure Team Settings

Go to: **Project Settings → Boards → Team**

| Setting | Value |
|---|---|
| Working days | Monday – Friday |
| Bugs managed with | Product Backlog Items |
| Default iteration | Sprint 1 |

---

## Verification Checklist

- [ ] Kanban columns match: `Backlog → To Do → In Progress → Review → Done`
- [ ] 5 Epics created with descriptions
- [ ] Features created under each Epic
- [ ] Sprint 1 created (2026-05-09 → 2026-05-22)
- [ ] Phase 1 tasks assigned to Sprint 1
- [ ] Team settings configured (working days, default iteration)
- [ ] Board visible and usable at: `https://dev.azure.com/azureshop-org/AzureShop/_boards/board/t/AzureShop%20Team/Stories`

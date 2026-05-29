# Capgemini — Senior Azure Engineer (SRE/DevOps) Interview Prep

**Role:** Senior Azure Engineer, Mumbai/Pune  
**Prepared for:** Anshu  
**Date:** 2026-05-29  
**Project reference throughout:** AzureShop (production-grade microservices on Azure)

---

## How to Use This Document

- Read all 40 Q&A from top to bottom — one full pass.
- Mark questions you are not confident in.
- Revisit those questions the next day.
- After one full revision, move to the mock interview session.

Questions are grouped into 6 sections matching the JD:

1. Platform Engineering & IaC (Q1–Q8)
2. SRE & Reliability (Q9–Q16)
3. DevOps & CI/CD (Q17–Q24)
4. Security & Compliance (Q25–Q32)
5. Operations & Incident Management (Q33–Q37)
6. Behavioral & Collaboration (Q38–Q40)

---

## Section 1 — Platform Engineering & IaC (Q1–Q8)

---

### Q1. What is Infrastructure as Code (IaC)? Why did you choose Terraform over ARM templates or Bicep?

**Answer:**

Infrastructure as Code means you define your cloud resources (VMs, networks, databases, etc.) in code files — just like you write application code. Instead of clicking through the Azure portal, you write a `.tf` file and run `terraform apply`. The infrastructure is created, updated, or destroyed based on what that file says.

**Why this matters:**
- Repeatable: run the same code 100 times, you get the same infrastructure
- Version controlled: tracked in Git — you can see who changed what and roll back
- Reviewable: changes go through a PR just like application code
- Automated: pipelines can run it without human clicks

**Why Terraform over ARM/Bicep:**

| Factor | Terraform | ARM / Bicep |
|---|---|---|
| Multi-cloud | Works on Azure, AWS, GCP | Azure only |
| Community modules | Huge registry at registry.terraform.io | Limited |
| State management | Explicit state file (powerful) | No concept of state |
| Readability | HCL is clean and readable | ARM JSON is verbose |
| Industry adoption | Most widely used IaC tool | Azure-specific shops |

In AzureShop, you used Terraform with 7 modules: networking, aks, databases, keyvault, monitoring, acr, appgateway. Remote state was stored in Azure Blob Storage so the team shares the same state file.

**Interview tip:** If they ask "why not Bicep?" say — "Bicep is excellent for Azure-native teams. I chose Terraform because it is provider-agnostic and the most in-demand skill in the market. If this team uses Bicep, I am happy to work with it — the concepts are identical."

---

### Q2. Explain Terraform modules. Why did you structure AzureShop with modules?

**Answer:**

A Terraform module is a folder containing `.tf` files that defines a reusable piece of infrastructure. Think of it like a function in programming — you define it once and call it with different parameters.

**Without modules** you would have one giant `main.tf` with 1000 lines. Impossible to maintain.

**With modules**, your root `main.tf` looks like this:

```hcl
module "networking" {
  source              = "./modules/networking"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_address_space  = var.vnet_address_space
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = var.resource_group_name
  vnet_subnet_id      = module.networking.aks_subnet_id
}
```

Clean, readable, and the `aks` module automatically gets the subnet ID output from the `networking` module.

**In AzureShop:**
- `modules/networking` — VNet, subnets, NSGs
- `modules/aks` — AKS cluster, node pools, RBAC
- `modules/databases` — Azure SQL, Redis, Cosmos DB
- `modules/keyvault` — Key Vault, access policies, secrets
- `modules/monitoring` — Log Analytics, App Insights (×8 via for_each)
- `modules/acr` — Azure Container Registry
- `modules/appgateway` — Application Gateway, WAF

Each module has `variables.tf` (inputs), `main.tf` (resources), and `outputs.tf` (values other modules need).

**Interview tip:** They may ask about module versioning. In production you would pin modules: `source = "git::https://github.com/org/terraform-modules.git//networking?ref=v1.2.0"`. Pinning prevents a module update from breaking your production infra.

---

### Q3. What is Terraform remote state? How did you configure it in AzureShop?

**Answer:**

When you run `terraform apply`, Terraform writes a `terraform.tfstate` file that records the current state of your infrastructure — every resource, its ID, its properties. This file is Terraform's memory.

**Problem with local state:** If you work in a team, everyone has their own local state file. Two people run `terraform apply` at the same time — disaster. State files get out of sync.

**Remote state:** Store the state file in a shared, central location. Everyone reads and writes from the same place. Azure Blob Storage is the standard for Azure + Terraform.

**AzureShop configuration:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}
```

**State locking:** When one person runs `terraform apply`, Azure Blob Storage automatically locks the state file. If another person tries to run at the same time, they see: "Error acquiring the state lock." This prevents corruption.

**Important gotcha from AzureShop:** Key Vault has `purge_protection_enabled = true`. After `terraform destroy`, the Key Vault goes into a 90-day soft-delete state. Running `terraform apply` again fails because Terraform thinks it needs to create a new Key Vault but the old one still occupies the name. Fix: `az keyvault recover` first, then `terraform import` to bring it back into state.

**Interview tip:** They may ask about state file security. The state file contains secrets in plaintext (connection strings, passwords). Always enable storage account encryption, use private endpoints for the storage account, and restrict access via RBAC.

---

### Q4. Explain VNet, Subnets, and NSGs. How did you use them in AzureShop?

**Answer:**

**VNet (Virtual Network):** Your private network in Azure. Nothing from the internet can enter unless you explicitly allow it. Think of it as the walls around your office building.

**Subnet:** A division inside the VNet. You separate different parts of your system into different subnets so they can have different rules. Like different floors of the building — reception (public), offices (private), server room (restricted).

**NSG (Network Security Group):** A firewall for a subnet or a single NIC. Contains inbound and outbound rules. Each rule says: allow or deny traffic on a specific port from a specific source.

**AzureShop setup:**

```
VNet: 10.0.0.0/16
├── aks-subnet:       10.0.1.0/24   ← AKS pods and nodes
├── appgw-subnet:     10.0.2.0/24   ← Application Gateway
├── db-subnet:        10.0.3.0/24   ← Azure SQL, Redis, Cosmos
└── services-subnet:  10.0.4.0/24   ← Supporting services
```

NSG on `db-subnet`: only allow traffic from `aks-subnet`. The database is never accessible from the internet — only from the AKS pods.

NSG on `appgw-subnet`: allow inbound HTTP/HTTPS from internet (0.0.0.0/0 on ports 80, 443). The Application Gateway is the only public entry point.

**Interview tip:** The question about Private Endpoints often follows this. A Private Endpoint goes one step further than NSGs — it takes a PaaS service (like Azure SQL, Key Vault, Storage) and gives it a private IP inside your VNet. Traffic never leaves your private network. Combined with `publicNetworkAccess = Disabled`, no internet access is possible at all.

---

### Q5. What is a Private Endpoint? Why is it important? Explain with a real example.

**Answer:**

## The Problem Private Endpoint Solves

When you create an Azure SQL database, Azure gives it a public URL:

```
sql-azureshop-dev.database.windows.net
```

This URL resolves to a **public IP address** — something like `52.183.x.x`. That IP is reachable from anywhere on the internet. Azure's firewall blocks unauthorised callers, but the database is still **publicly exposed**.

Think of it like this:

> Your house (database) is on a public street. Anyone can walk up to your front door and knock. You have a lock (firewall), so they cannot get in — but they can still reach the door.

---

## What Private Endpoint Does

A Private Endpoint takes that Azure SQL database — which lives on Microsoft's public infrastructure — and **gives it a private IP address inside your VNet**.

Now your database has two addresses:
- Public: `52.183.x.x` → you **disable** this
- Private: `10.0.3.5` → only reachable inside your VNet

> Your house has been moved **inside a gated community** (your VNet). There is no public street anymore. The only way to reach the front door is to already be inside the gate.

---

## Real World Analogy — Office Building

**Without Private Endpoint:**
The file room (database) has two doors:
- A back door inside the office building (your VNet)
- A front door on the public street (internet)

The front door has a security guard (firewall). Most strangers cannot get in. But the door exists — someone can try to pick the lock or find a vulnerability.

**With Private Endpoint:**
The front door on the public street is **bricked up permanently**. There is only one way in — through the back door, inside the building. If you are not already inside the building, you cannot reach the file room at all.

---

## How It Works Technically — Step by Step

**Step 1 — Azure creates a NIC in your subnet**

Azure places a Network Interface Card (NIC) with a private IP inside your `db-subnet`. This NIC represents the Azure SQL service.

```
db-subnet (10.0.3.0/24)
├── 10.0.3.4  ← Azure reserved
├── 10.0.3.5  ← Private Endpoint NIC for Azure SQL
└── ...
```

**Step 2 — Private DNS Zone overrides the public DNS**

Before Private Endpoint:
```
DNS query: sql-azureshop-dev.database.windows.net
Answer:    52.183.x.x  (public IP)
```

After Private Endpoint, a Private DNS Zone (`privatelink.database.windows.net`) is linked to your VNet:
```
DNS query: sql-azureshop-dev.database.windows.net
Answer:    10.0.3.5  (private IP — inside your VNet)
```

Same hostname — but inside your VNet it resolves to the private IP. Outside your VNet it still resolves to the public IP (which is blocked).

**Step 3 — Disable public access entirely**

```hcl
resource "azurerm_mssql_server" "main" {
  public_network_access_enabled = false  # front door bricked up
}
```

Now the database has zero public exposure — no IP to attack, no port to scan.

---

## Real AzureShop Example — Traffic Flow

Your `product-service` pod (running in `aks-subnet`) connects to Azure SQL.

**Without Private Endpoint:**
```
product-service pod (10.0.1.x)
  → DNS lookup → 52.183.x.x (public IP)
  → Traffic leaves your VNet
  → Goes through Microsoft's public backbone
  → Hits Azure SQL's public endpoint
  → Firewall checks IP allowlist → allowed in
```

Traffic touched the public internet. Multiple attack surfaces.

**With Private Endpoint:**
```
product-service pod (10.0.1.x)
  → DNS lookup → 10.0.3.5 (private IP)
  → Traffic stays inside your VNet (aks-subnet → db-subnet)
  → Hits the Private Endpoint NIC
  → Reaches Azure SQL
```

Traffic **never left your VNet**. No public IP involved.

---

## Why It Is Important — 4 Reasons

**1. Zero public attack surface**
A hacker scanning the internet cannot find your database. There is no public IP to connect to. You cannot attack what you cannot reach.

**2. Compliance requirement**
PCI-DSS, HIPAA, SOC 2, and ISO 27001 require that sensitive data must not traverse public networks. Private Endpoint satisfies this requirement.

**3. Data exfiltration protection**
Without Private Endpoint, a compromised pod could send data to any Azure SQL server on the public internet. With Private Endpoint and `publicNetworkAccess = Disabled`, data can only go to your specific database inside your VNet.

**4. Defense in depth**
NSG rules are one layer. Private Endpoint is a second independent layer — even if NSG is misconfigured, there is no public IP to reach.

---

## Service Endpoint vs Private Endpoint (Common Interview Question)

| | Service Endpoint | Private Endpoint |
|---|---|---|
| How it works | Optimised route from VNet to service's **public IP** | Service gets a **private IP inside your VNet** |
| Public IP still exists? | Yes | No (you disable it) |
| Internet traffic possible? | Yes (if firewall allows) | No |
| Private DNS needed? | No | Yes |
| Cost | Free | Small hourly charge (~$7/month) |
| Security level | Good | Better |

**Simple way to remember:**
- Service Endpoint = faster road to the same public address
- Private Endpoint = the building moves inside your fence

---

**One-line summary for the interview:**

> A Private Endpoint gives an Azure PaaS service a private IP inside your VNet so that traffic never leaves your network and the service has no public address to attack.

---

### Q6. What is the difference between Application Gateway, Azure Load Balancer, and Azure Front Door?

**Answer:**

All three distribute traffic — but at different layers and for different use cases.

| Feature | Azure Load Balancer | Application Gateway | Azure Front Door |
|---|---|---|---|
| OSI Layer | Layer 4 (TCP/UDP) | Layer 7 (HTTP/HTTPS) | Layer 7, global |
| Traffic routing | IP/port based | URL path, host header | Global, geo-routing |
| SSL termination | No | Yes | Yes |
| WAF | No | Yes (WAF v2) | Yes |
| Scope | Single region | Single region | Multi-region, global |
| Use case | Internal load balancing, TCP apps | Web apps with routing rules | CDN, global failover |

**In AzureShop:** You used Application Gateway as the public entry point. It terminates SSL (HTTPS), has WAF for web attack protection, and routes traffic to NGINX Ingress Controller inside AKS. The flow is:

```
Internet → Application Gateway (public IP, SSL, WAF) 
         → AKS NGINX Ingress (134.33.223.224, path routing) 
         → Kubernetes Services (ClusterIP) 
         → Pods
```

**Why not Front Door?** Front Door is for multi-region global apps. AzureShop is single-region (dev). In production with multiple regions, you would put Front Door in front of Application Gateway in each region.

**Interview tip:** They may ask specifically about WAF. WAF (Web Application Firewall) protects against OWASP Top 10 attacks — SQL injection, cross-site scripting, etc. Application Gateway WAF runs in two modes: Detection (log only) and Prevention (block + log). Always start with Detection to tune rules before switching to Prevention.

---

### Q7. What is GitOps? How did you implement it in AzureShop?

**Answer:**

GitOps is a practice where Git is the **single source of truth** for both application code AND infrastructure configuration. Instead of someone running `kubectl apply` manually, a GitOps controller runs inside the cluster, watches a Git repo, and automatically applies any changes it sees.

**The GitOps loop:**
1. Developer pushes a change to the Git repo
2. GitOps controller (running in the cluster) detects the change
3. Controller pulls the new configuration and applies it to the cluster
4. Cluster state matches the Git state — always

**Benefits:**
- No one has `kubectl` access to production — the controller does it
- Every change is tracked in Git with who did it and why (PR + commit message)
- Rollback = revert the Git commit. Controller automatically reverts the cluster.
- Audit trail for compliance

**AzureShop implementation (Phase 9):**

You used **Flux** (the CNCF GitOps tool). Flux was installed as an AKS extension via Terraform:

```hcl
resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = module.aks.cluster_id
  extension_type = "microsoft.flux"
}
```

Then you created **HelmRelease** CRDs in `k8s/gitops/releases/` — one per service. A HelmRelease tells Flux: "Watch this Helm chart at this version. If I push a new version, upgrade the release automatically."

```yaml
# k8s/gitops/releases/product-service.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: product-service
spec:
  chart:
    spec:
      chart: ./helm/product-service
      version: "1.0.0"
```

**Interview tip:** They may compare Flux vs Argo CD. Both are GitOps tools. Argo CD has a better UI and is more popular for teams that want visual dashboards. Flux is more lightweight and Kubernetes-native. Capgemini may use either — say you have experience with Flux and are familiar with the Argo CD concept.

---

### Q8. What is an Azure Landing Zone?

**Answer:**

A Landing Zone is a pre-configured, opinionated Azure environment that is ready to host workloads. It is like a furnished apartment — the building (Azure subscription) is built and all the standard things (networking, security, monitoring, governance) are already set up following best practices. Application teams move their workload in without worrying about the plumbing.

**What a landing zone typically includes:**
- Management groups and subscriptions (hierarchy)
- VNet with standard subnets + Private DNS zones
- Azure Policy assignments (enforce tagging, enforce SKUs, deny public IPs)
- RBAC assignments (who can do what)
- Log Analytics workspace (centralized logging)
- Key Vault for secrets
- Budget alerts and FinOps guardrails
- Defender for Cloud enabled

**Microsoft's CAF (Cloud Adoption Framework)** defines the official landing zone architecture. It has two main zones:
- **Platform landing zone** — shared services (identity, networking, monitoring) managed by the platform team
- **Application landing zone** — where individual workloads run, with guardrails from the platform

**In AzureShop context:** Your Phase 2 Terraform built a mini landing zone — VNet, Key Vault, Log Analytics, ACR, AKS, App Gateway — all connected and secured. It is not the full enterprise CAF structure (no Management Groups, no Policy initiative), but the concepts are identical.

**Interview tip:** They may ask: "How would you scale this to 50 application teams?" Answer: Management Groups, Azure Policy (deny without tags, deny public IPs), subscription vending (automation that creates a new subscription with all guardrails pre-applied), and a platform team that maintains the shared services.

---

### Q8.1. Give a deep understanding of Azure Landing Zone — real-world example, Hub-Spoke topology, Management Groups, and how it differs from Terraform.

**Answer:**

## Why Azure Landing Zone Exists — The Real Problem

Imagine a company called TechCorp decides to move to Azure. They have 20 development teams building different applications. They give everyone an Azure subscription and say "go build."

Six months later:
- Team A created a database with a public IP — no firewall
- Team B is spending $50,000/month on oversized VMs — nobody noticed
- Team C deployed an app but forgot logging — when it crashed, no one knew why
- Team D stored passwords in plain text in environment variables
- Teams are using 15 different VNet address ranges — they all overlap and cannot connect to each other
- Security audit finds 47 compliance violations
- Nobody knows which resource belongs to which team — zero tags

**This is the exact problem Azure Landing Zone solves.**

---

## What is an Azure Landing Zone?

A Landing Zone is a **pre-built, pre-configured Azure environment** with all the foundational infrastructure, security guardrails, governance rules, and networking already in place **before** the first application is deployed.

> **Landing Zone = The city's infrastructure**
>
> Before any buildings are constructed in a city, the city builds:
> - Roads and highways (networking)
> - Electricity and water supply (shared services)
> - Zoning laws — you cannot build a factory in a residential area (Azure Policy)
> - Fire codes — every building must have sprinklers (security standards)
> - Address system — every building has a unique address (tagging, naming conventions)
> - Tax system — track what each area costs (FinOps)
>
> A new company wanting to build in the city does not build their own roads. They connect to existing infrastructure and follow the city's laws.
>
> **Application teams are the builders. The Landing Zone is the city.**

---

## The Two Types of Landing Zones (CAF)

### 1. Platform Landing Zone
Built and owned by the platform team. Contains shared services used by everyone.

```
Platform Landing Zone
├── Connectivity Subscription
│   ├── Hub VNet (central network)
│   ├── Azure Firewall (all traffic inspected)
│   ├── VPN Gateway / ExpressRoute (on-premises connection)
│   ├── DNS Private Zones (shared DNS for all teams)
│   └── DDoS Protection Plan
│
├── Identity Subscription
│   ├── Azure AD / Entra ID
│   ├── PIM (Privileged Identity Management)
│   └── Domain Controllers (if hybrid)
│
└── Management Subscription
    ├── Log Analytics Workspace (central logging for all teams)
    ├── Azure Monitor
    ├── Microsoft Defender for Cloud
    └── Automation Accounts (patch management)
```

### 2. Application Landing Zone
Where each application team's workload runs. Gets networking, security, and governance **inherited** from the Platform Landing Zone.

```
Application Landing Zone — Team A (e-commerce app)
├── Spoke VNet (peered to Hub VNet)
├── AKS cluster
├── Azure SQL with Private Endpoint
├── Key Vault
└── Azure Policy inherited from management group
```

---

## The Management Group Hierarchy — The Backbone

Management Groups are containers that sit **above subscriptions**. Policies applied at a Management Group automatically apply to **all subscriptions underneath it**.

```
Root Management Group (entire company)
│
├── Platform Management Group
│   ├── Connectivity Subscription
│   ├── Identity Subscription
│   └── Management Subscription
│
└── Landing Zones Management Group
    ├── Production Management Group
    │   ├── Team A - Prod Subscription
    │   ├── Team B - Prod Subscription
    │   └── Team C - Prod Subscription
    │
    ├── Non-Production Management Group
    │   ├── Team A - Dev Subscription
    │   ├── Team B - Dev Subscription
    │   └── Team C - Dev Subscription
    │
    └── Sandbox Management Group
        └── Sandbox Subscription (devs experiment freely)
```

**Why this matters:** Apply one Azure Policy at the `Landing Zones Management Group` level — it automatically enforces on ALL team subscriptions underneath. You do not configure 50 subscriptions individually.

Example: Policy at the top — *"All resources must have an Environment tag."* Every resource created by every team in every subscription is automatically checked. Non-compliant resources are blocked at creation time.

---

## Hub-Spoke Network Topology

The standard networking pattern inside a Landing Zone.

```
                    ┌─────────────────────────────────┐
                    │     HUB VNet (10.0.0.0/16)       │
                    │  ┌─────────────────────────────┐ │
                    │  │     Azure Firewall           │ │
                    │  │  (all traffic inspected)     │ │
                    │  └─────────────────────────────┘ │
                    │  ┌──────────┐  ┌──────────────┐  │
                    │  │VPN GW    │  │ DNS Resolver │  │
                    │  └──────────┘  └──────────────┘  │
                    └──────────┬──────────────┬─────────┘
                               │  VNet Peering│
              ─────────────────┼──────────────┼──────────────────
              │                │              │                  │
   ┌──────────▼──────┐  ┌──────▼──────┐  ┌───▼──────────┐  ...
   │ Spoke VNet A    │  │ Spoke VNet B│  │ Spoke VNet C │
   │ Team A workload │  │ Team B      │  │ Team C       │
   │ (10.1.0.0/16)   │  │(10.2.0.0/16)│  │(10.3.0.0/16) │
   └─────────────────┘  └─────────────┘  └──────────────┘
```

**Hub:** Owned by platform team. Contains shared services — firewall, VPN, DNS.

**Spoke:** Each application team gets their own Spoke VNet peered to the Hub.

**Traffic flow — internet-bound:**
```
Team A pod → Spoke A VNet → Hub VNet → Azure Firewall (inspected) → Internet
```

**Spoke-to-Spoke isolation:** Team A cannot directly talk to Team B. Traffic must pass through the Hub Firewall. Central security enforcement on all cross-team communication.

---

## Azure Landing Zone vs Terraform — The Big Confusion Cleared

**They are NOT alternatives. They are completely different things.**

| | Azure Landing Zone | Terraform |
|---|---|---|
| What is it? | An **architecture pattern** — a design blueprint | A **tool** — used to build things |
| Is it a product? | No — it is a concept and best practice framework | Yes — it is software you install and run |
| Does it create resources? | No — it describes what SHOULD exist | Yes — it creates actual Azure resources |
| Relationship | Terraform is used TO BUILD a Landing Zone | Landing Zone is what you BUILD using Terraform |

> **Landing Zone is the architect's blueprint.**
> **Terraform is the construction crew and tools.**
>
> The blueprint tells you what to build. Terraform builds it.
> You need both — one without the other is useless.

In practice, Microsoft provides the Landing Zone design (blueprint) and you implement it using Terraform:

```
Azure Landing Zone (WHAT to build)           Terraform (HOW to build it)
─────────────────────────────────            ────────────────────────────
"Create a Management Group hierarchy"    →   resource "azurerm_management_group"
"Create Hub VNet with Azure Firewall"    →   module "hub_networking"
"Enforce tagging via Azure Policy"       →   resource "azurerm_policy_assignment"
"Create Log Analytics workspace"         →   resource "azurerm_log_analytics_workspace"
"Set up PIM for privileged roles"        →   resource "azurerm_pim_active_role_assignment"
```

Microsoft provides official Terraform modules for Landing Zones: `Azure/caf-enterprise-scale/azurerm` — run `terraform apply` and get a complete enterprise Landing Zone.

---

## AzureShop vs Full Enterprise Landing Zone

**AzureShop built a mini Landing Zone inside a single subscription:**

```
AzureShop (single subscription)
├── VNet with 4 subnets (mini networking)
├── NSGs (basic network security)
├── Key Vault (secrets management)
├── Log Analytics Workspace (central logging)
├── Application Gateway (edge traffic)
├── Azure Policy          ← NOT implemented (gap)
├── Management Groups     ← NOT implemented (single subscription)
└── PIM                   ← NOT implemented (gap)
```

**Full Enterprise Landing Zone (what Capgemini uses for clients):**

```
Capgemini Client (multiple subscriptions)
├── Management Group hierarchy (5 levels)
├── Platform subscriptions (connectivity, identity, management)
├── 50 application subscriptions (one per team)
├── Hub-Spoke VNet topology (Azure Firewall in hub)
├── 200+ Azure Policies enforced
├── PIM for all privileged roles
└── Automated subscription vending (new team = ready environment in 10 minutes)
```

**How to answer this honestly in the interview:**

> "In AzureShop I built the foundational components of a Landing Zone — VNet, Key Vault, Log Analytics, security controls — within a single subscription. I understand the full enterprise CAF Landing Zone design with Management Groups, Hub-Spoke networking, and Azure Policy. In a multi-team, multi-subscription environment at Capgemini, I would implement the full CAF structure using the Azure/caf-enterprise-scale Terraform module."

---

## Why Companies Use Azure Landing Zone — 5 Real Reasons

**1. Speed with safety**
New team wants to deploy an app. Without a Landing Zone: 3 weeks to set up networking, security, logging. With a Landing Zone: subscription vending gives them a ready environment in 10 minutes — all guardrails already in place.

**2. Compliance from day 1**
SOC 2, ISO 27001, PCI-DSS auditors ask: "How do you ensure all your Azure resources are compliant?" Answer: Azure Policy in the Landing Zone prevents non-compliant resources from being created at all. You do not fix violations — you prevent them.

**3. Cost control**
Budget alerts at subscription level. Tagging policy ensures every resource has a CostCenter tag. FinOps team sees exactly which team, which project, which environment is spending what. No surprise bills.

**4. Security posture**
Microsoft Defender for Cloud scores your entire environment. A central security team watches one dashboard — Secure Score — covering all 50 application subscriptions. One team's misconfiguration is visible immediately.

**5. Consistency at scale**
50 teams, 200 subscriptions — all follow the same networking pattern, naming convention, tagging standard, security baseline. Platform team updates one Policy and it propagates to all 200 subscriptions automatically.

---

**One-line summary for the interview:**

> An Azure Landing Zone is the pre-built city infrastructure — networking, security, governance, logging, and cost controls — that is in place before any application team deploys their first resource, ensuring every workload starts from a consistent, compliant, and secure foundation.

---

## Section 2 — SRE & Reliability (Q9–Q16)

---

### Q9. What are SLI, SLO, SLA, and error budgets? How do they all connect?

**Answer:**

These are the core SRE concepts for measuring and managing reliability.

**SLI — Service Level Indicator:** A specific metric you measure. It is a number. Examples:
- Request success rate: (successful requests / total requests) × 100
- Latency: P95 response time in milliseconds
- Availability: (uptime minutes / total minutes) × 100

**SLO — Service Level Objective:** The target you set for an SLI. Your promise to yourself. Examples:
- "99.9% of requests must succeed" 
- "P95 latency must be under 500ms"
- "Availability must be ≥ 99.5%"

**SLA — Service Level Agreement:** A legal contract with a customer. If you breach it, there are penalties (refunds, credits). SLA is always lower than SLO — you promise customers less than what you aim for internally.

```
SLO = 99.9%   ← internal goal
SLA = 99.5%   ← what you promise customers
Gap = 0.4%    ← buffer for unexpected incidents
```

**Error Budget:** The amount of unreliability you are allowed in a given period.

```
Error budget = 1 - SLO
For SLO = 99.9%:
Error budget = 0.1% of time per month
= 0.001 × 43,200 minutes
= 43.2 minutes of downtime per month allowed
```

If you have used 40 of those 43.2 minutes mid-month, you freeze new deployments. Why? Because the risk of a new deployment causing another outage would burn the remaining budget and breach the SLA.

**In AzureShop context:** Your Grafana dashboard tracks request rate and error rate. The PrometheusRule alert `HighErrorRate` fires when error rate > 5%. In SRE terms, that alert is your early warning that you are burning the error budget faster than expected.

**Interview tip:** They will almost certainly ask this. The key insight they are testing is: "Does this person understand that SRE is about balancing reliability vs. velocity?" The error budget is that balance. When budget is full → ship fast. When budget is low → slow down, focus on reliability.

---

### Q10. What is the difference between Application Insights, Log Analytics, and Prometheus? When do you use each?

**Answer:**

All three are observability tools but they serve different purposes.

**Application Insights:**
- Purpose: APM (Application Performance Monitoring) for your application code
- What it collects: request traces, dependencies (DB calls, API calls), exceptions, custom events, user telemetry
- How: SDK embedded in your application code (`applicationinsights` npm package, `opencensus` Python)
- Queries: KQL (Kusto Query Language) in Azure Portal
- Best for: "Why is this specific request slow?" "Which function is throwing exceptions?"

**Log Analytics Workspace:**
- Purpose: Centralized log aggregation for everything — not just your app
- What it collects: AKS node logs, pod logs, Azure resource diagnostics, security events, Windows/Linux OS logs
- How: Agents (AMA — Azure Monitor Agent) push logs from VMs and AKS
- Queries: KQL
- Best for: "Show me all logs across all services for the last hour." Infrastructure-level investigation.

**Prometheus:**
- Purpose: Time-series metrics collection for Kubernetes workloads
- What it collects: numeric metrics — CPU, memory, request rate, queue depth, custom business metrics
- How: Scrapes `/metrics` HTTP endpoints on your pods (pull model)
- Queries: PromQL
- Visualized with: Grafana
- Best for: "What is the CPU usage of the product-service pod right now?" Real-time dashboards and alerting.

**In AzureShop — all three were used together:**
- App Insights SDK on all 8 services → distributed tracing, exceptions
- Log Analytics workspace → AKS diagnostics, Terraform audit logs
- kube-prometheus-stack → pod metrics scraped every 15s, displayed in Grafana

**Interview tip:** The interviewer may say "we use Azure Monitor — is Prometheus redundant?" Answer: Azure Monitor Metrics can collect Kubernetes metrics (via Azure Monitor Agent). But Prometheus + Grafana gives much richer visualization, custom dashboards, and PromQL is far more powerful for Kubernetes-specific queries. In many production setups you have both — Prometheus for real-time cluster monitoring, Azure Monitor for long-term retention and alerting integration with Action Groups.

---

### Q11. What is distributed tracing? How did you implement it in AzureShop?

**Answer:**

In a microservices system, a single user request touches multiple services. A user clicks "place order" — it hits the API Gateway → Order Service → Payment Service → Notification Service. If something is slow or fails, how do you know which service caused it?

Distributed tracing assigns a unique **Trace ID** to every request when it enters the system. Every service that handles that request logs the same Trace ID. You can then search for that Trace ID and see the entire journey of the request across all services — with timing for each hop.

**Components:**
- **Trace:** The entire journey of one request across all services
- **Span:** One unit of work within a trace (e.g., "order-service processed the request")
- **Trace ID:** Unique ID shared across all spans of one request
- **Parent-Child:** Each span knows which span called it

**In AzureShop:**

Application Insights SDK automatically propagates the Trace ID via HTTP headers (`traceparent` header). When order-service makes an HTTP call to payment-service, the SDK injects the trace header. Payment-service picks it up and logs spans under the same trace.

```javascript
// order-service — Node.js
const appInsights = require('applicationinsights');
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
  .setAutoDependencyCorrelation(true)  // ← this enables distributed tracing
  .start();
```

In the Azure Portal, you go to Application Insights → Transaction Search → find a trace ID → see the full end-to-end map.

**Interview tip:** They may ask about OpenTelemetry. OpenTelemetry is the open standard for distributed tracing — vendor neutral. Application Insights now supports OpenTelemetry natively. If asked "would you use OpenTelemetry or Application Insights SDK?" — answer: OpenTelemetry is the modern approach (no vendor lock-in). Application Insights SDK is fine for Azure-native projects but OpenTelemetry gives you flexibility to switch backends.

---

### Q11.1. What is OpenTelemetry? Why and how do you use it? Explain with a real-world example.

**Answer:**

## The Problem Before OpenTelemetry

In AzureShop, every service uses the Application Insights SDK to send telemetry:

```javascript
// product-service — Node.js
const appInsights = require('applicationinsights');
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING).start();
```

This works — but imagine 6 months later the client says: "We are switching from Application Insights to Datadog."

Now you must:
1. Remove all `applicationinsights` code from all 8 services
2. Install `dd-trace` (Datadog SDK) in all 8 services
3. Rewrite all instrumentation code across hundreds of files
4. Test everything again

That is a **massive, expensive refactor** just because you changed your observability vendor.

Now imagine your company uses Application Insights for traces, Prometheus for metrics, and Splunk for logs. That is **three different SDKs** in every service — three different APIs to learn, three different ways things break.

**This is the exact problem OpenTelemetry solves.**

---

## What is OpenTelemetry?

OpenTelemetry (OTel) is an **open-source, vendor-neutral observability framework**. It is a CNCF project — the same organisation that maintains Kubernetes, Prometheus, and Helm.

It provides:
- A **standard API** — one way to instrument your code, regardless of vendor
- **SDKs** for every language — Node.js, Python, Java, Go, .NET
- A **Collector** — a standalone agent that receives, processes, and forwards telemetry anywhere
- **Auto-instrumentation libraries** — automatically trace HTTP requests, DB calls, message queues without writing a single line of instrumentation code

> Instrument your code ONCE with OpenTelemetry.
> Decide WHERE to send the data via configuration — not code.
> Switch vendors by changing a config file, not rewriting your application.

---

## The Three Pillars of Observability

OpenTelemetry covers all three signals that make a system observable:

```
┌──────────────────────────────────────────────────────────────────┐
│                       OBSERVABILITY                               │
│                                                                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐        │
│  │   TRACES    │     │   METRICS   │     │    LOGS     │        │
│  │             │     │             │     │             │        │
│  │ What        │     │ How much /  │     │ What        │        │
│  │ happened,   │     │ how fast /  │     │ happened    │        │
│  │ in what     │     │ how often   │     │ at a        │        │
│  │ order,      │     │             │     │ specific    │        │
│  │ how long    │     │ Numbers     │     │ moment      │        │
│  │             │     │ over time   │     │ Text events │        │
│  └─────────────┘     └─────────────┘     └─────────────┘        │
└──────────────────────────────────────────────────────────────────┘
```

Before OpenTelemetry, these three signals used completely different tools and SDKs. OpenTelemetry unifies all three under one framework.

---

## OpenTelemetry Architecture — All Components Explained

```
┌──────────────────────────────────────────────────────────────────┐
│                       YOUR APPLICATION                            │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │                   OpenTelemetry SDK                        │   │
│  │                                                            │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │   │
│  │  │  OTel API    │  │ Auto-Instr.  │  │ Manual Spans    │  │   │
│  │  │ (your code   │  │ Libraries    │  │ (your custom    │  │   │
│  │  │  calls this) │  │ (HTTP, DB,   │  │  business logic)│  │   │
│  │  └──────────────┘  │  Redis, etc) │  └─────────────────┘  │   │
│  │                    └──────────────┘                        │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │                    Exporters                         │   │   │
│  │  │  OTLP Exporter (sends via OpenTelemetry Protocol)   │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │  OTLP (OpenTelemetry Protocol)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                  OpenTelemetry Collector                           │
│                                                                   │
│  RECEIVE  ──►  PROCESS  ──►  EXPORT                               │
│                                                                   │
│  Receivers:      Processors:       Exporters:                     │
│  - OTLP          - Batch           - Azure Monitor / App Insights │
│  - Prometheus    - Filter          - Prometheus                   │
│  - Jaeger        - Sampling        - Jaeger                       │
│                  - Add k8s labels  - Datadog                      │
└──────────────────────────────────────────────────────────────────┘
         │                     │                     │
         ▼                     ▼                     ▼
  Azure Monitor /         Prometheus            Jaeger / Zipkin
  Application Insights    (metrics)             (trace UI)
```

**OTel API:** The interfaces your code calls to create spans and metrics. If OTel is not configured, these are no-ops — your app does not break.

**OTel SDK:** The implementation of the API. Handles collecting, batching, and exporting data.

**Auto-Instrumentation Libraries:** Pre-built plugins that trace popular frameworks automatically:
- `@opentelemetry/instrumentation-express` — every HTTP request in Express.js traced
- `@opentelemetry/instrumentation-pg` — every PostgreSQL query traced
- `@opentelemetry/instrumentation-redis` — every Redis command traced
- `opentelemetry-instrumentation-fastapi` — every FastAPI route traced (Python)

You add them once during SDK setup. Every HTTP call, DB query, and Redis command is automatically traced — **zero changes to your application code**.

**Exporters:** Plugins that send data to a specific backend. Swap exporters to change backends without touching application code.

**OTel Collector:** A standalone service (runs as a pod in Kubernetes) that receives telemetry from all your apps, processes it, and fans it out to multiple backends simultaneously.

---

## Traces Deep Dive — Real AzureShop Example

User clicks "Place Order." The request travels through 4 services:

```
[TraceID: abc-123-xyz]
│
├── [Span 1] api-gateway — receive POST /api/orders           0ms →   2ms
│
├── [Span 2] order-service — create order                     2ms →  45ms
│   ├── [Span 2a] SQL INSERT into orders table                5ms →  20ms
│   └── [Span 2b] Send message to Service Bus                20ms →  40ms
│
├── [Span 3] payment-service — process payment               45ms → 180ms
│   ├── [Span 3a] Call external payment gateway              50ms → 170ms  ← SLOW
│   └── [Span 3b] SQL UPDATE order status                   170ms → 178ms
│
└── [Span 4] notification-service — send email              180ms → 220ms
    └── [Span 4a] Call SendGrid API                         182ms → 218ms

Total: 220ms
```

You can immediately see: **the payment gateway call takes 120ms out of 220ms total.** That is your bottleneck. Without distributed tracing you would only see "the order endpoint is slow" with no idea why.

OpenTelemetry propagates the `traceId` automatically across services via the `traceparent` HTTP header (W3C standard). Every service picks it up and logs spans under the same trace — automatically.

---

## How to Use OpenTelemetry — Code Examples

### Node.js — order-service

**Install:**
```bash
npm install @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @azure/monitor-opentelemetry-exporter \
            @opentelemetry/exporter-prometheus
```

**Create `tracing.js` (loaded before everything else):**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { AzureMonitorTraceExporter } = require('@azure/monitor-opentelemetry-exporter');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'order-service',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV,
  }),
  // Send traces to Application Insights
  traceExporter: new AzureMonitorTraceExporter({
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  }),
  // Expose metrics on /metrics for Prometheus to scrape
  metricReader: new PrometheusExporter({ port: 9464 }),
  // Auto-instrument Express, SQL, Redis, HTTP clients
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

**Load it as the very first line of your app:**
```javascript
// index.js
require('./tracing');   // ← first line, before any other require
const express = require('express');
// ... rest of app unchanged
```

**Add manual spans for business logic:**
```javascript
const { trace, SpanStatusCode } = require('@opentelemetry/api');
const tracer = trace.getTracer('order-service');

async function createOrder(orderData) {
  return tracer.startActiveSpan('order.validate-and-create', async (span) => {
    try {
      span.setAttribute('order.customerId', orderData.customerId);
      span.setAttribute('order.totalAmount', orderData.total);

      const order = await db.createOrder(orderData);  // auto-traced by OTel

      span.setAttribute('order.id', order.id);
      span.setStatus({ code: SpanStatusCode.OK });
      return order;
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      span.recordException(error);
      throw error;
    } finally {
      span.end();  // always end the span
    }
  });
}
```

---

### Python — product-service

**Install:**
```bash
pip install opentelemetry-sdk \
            opentelemetry-instrumentation-fastapi \
            opentelemetry-instrumentation-sqlalchemy \
            azure-monitor-opentelemetry-exporter
```

**Setup in `main.py`:**
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

resource = Resource.create({"service.name": "product-service"})
provider = TracerProvider(resource=resource)
exporter = AzureMonitorTraceExporter(
    connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)   # auto-trace all routes
SQLAlchemyInstrumentor().instrument()     # auto-trace all DB queries
```

---

## OTel Collector in Kubernetes — The Power Move

Deploy the Collector as a Deployment in AKS. Apps send to Collector. Collector fans out to multiple backends simultaneously:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 10s
  k8sattributes:                        # add pod name, namespace to every span
    extract:
      metadata: [k8s.pod.name, k8s.namespace.name]
  filter:
    traces:
      exclude:
        match_type: strict
        span_names: ["GET /health", "GET /ready"]   # drop health check noise

exporters:
  azuremonitor:
    connection_string: "${APPLICATIONINSIGHTS_CONNECTION_STRING}"
  prometheus:
    endpoint: "0.0.0.0:8889"
  jaeger:
    endpoint: jaeger:14250

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, k8sattributes, filter]
      exporters: [azuremonitor, jaeger]   # fan out to two backends at once
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

Apps send to `otel-collector:4317`. To add Datadog tomorrow — add one exporter line in this config file. **Zero application code changes.**

---

## OpenTelemetry vs Application Insights SDK

| | Application Insights SDK | OpenTelemetry |
|---|---|---|
| Vendor | Microsoft only | Vendor neutral (CNCF) |
| Signals covered | Traces + some metrics | Traces + Metrics + Logs |
| Switch backends | Rewrite application code | Change Collector config |
| Auto-instrumentation | Yes (Azure-specific) | Yes (broader ecosystem) |
| Industry standard | No | Yes — Google, Microsoft, AWS all back it |
| Prometheus metrics | No | Yes (native) |
| Lock-in risk | High | None |

**When to use App Insights SDK:** Pure Azure shop, no plans to switch vendors, team already knows it.

**When to use OpenTelemetry:** Multi-cloud, mixed backends, or Prometheus + App Insights simultaneously — which is exactly the AzureShop setup.

---

**One-line summary for the interview:**

> OpenTelemetry is a vendor-neutral framework that lets you instrument your code once for traces, metrics, and logs, then send that telemetry to any backend — Application Insights, Prometheus, Datadog — by changing configuration, not application code.

---

### Q12. What is P95/P99 latency? Why is it more useful than average latency?

**Answer:**

Latency percentiles tell you about the experience of the worst-affected users — not just the average user.

**How to read percentiles:**
- P50 (median): 50% of requests are faster than this. 50% are slower.
- P95: 95% of requests are faster than this. Only 5% are slower.
- P99: 99% of requests are faster than this. Only 1% are slower.

**Why average is misleading:**

Suppose you have 100 requests:
- 99 requests take 100ms
- 1 request takes 10,000ms (10 seconds — maybe hitting a cold database)
- Average = (99 × 100 + 1 × 10,000) / 100 = 199ms

Average says 199ms. Seems fine. But one user waited 10 seconds. That is a real problem hidden by the average.

P99 = 10,000ms — this shows the truth.

**Why P95/P99 matter:**
- High-traffic systems: at 10,000 requests/minute, 1% = 100 users per minute experiencing very slow responses
- SLOs are set on percentiles: "P95 latency must be under 500ms"
- Outliers often indicate specific bugs: cold starts, unoptimized queries, timeouts

**In AzureShop:**
Your Grafana dashboard has a P95 latency panel using PromQL:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

This gives the P95 latency over the last 5 minutes, updated every 15 seconds.

**Interview tip:** They may ask "what causes high P99 latency but normal P50?" Common causes: garbage collection pauses (Java/Node.js), cold database connections, connection pool exhaustion, occasional lock contention. These are intermittent problems that average metrics hide.

---

### Q13. What are PrometheusRule alerts? How did you set them up in AzureShop?

**Answer:**

A PrometheusRule is a Kubernetes custom resource that defines alerting rules for Prometheus. When a PromQL expression evaluates to true for a defined duration, Prometheus sends an alert to Alertmanager, which routes it to your notification channel (Slack, PagerDuty, email).

**In AzureShop — 10 alerts in 3 groups:**

**Group 1: HTTP Alerts**
```yaml
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) 
        / rate(http_requests_total[5m]) > 0.05
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Error rate above 5% for 2 minutes"
```

**Group 2: Availability Alerts**
- Pod not running
- Service endpoint unreachable

**Group 3: Capacity Alerts**
- CPU usage > 80% for 5 minutes
- Memory usage > 85% for 5 minutes
- Pod restart count > 5 in 15 minutes

**The `for` field is important:** It prevents flapping. If CPU spikes for 30 seconds and recovers, no alert fires. The condition must be true for the full `for` duration before alerting.

**Alertmanager routing:** Alerts go to Alertmanager with labels (`severity: critical` vs `warning`). Alertmanager routes critical alerts to PagerDuty (immediate page) and warning alerts to Slack.

**Interview tip:** They may ask "what is the difference between Prometheus alerts and Azure Monitor alerts?" Both can alert on the same metric. Prometheus alerts are cluster-native — lower latency, richer PromQL expressions. Azure Monitor alerts integrate with Azure Action Groups (send SMS, run a Logic App, trigger an Azure Function as auto-remediation). In production you would often have both.

---

### Q14. What are Grafana dashboards? What did you build in AzureShop?

**Answer:**

Grafana is a visualization tool that connects to data sources (Prometheus, Log Analytics, SQL, etc.) and displays metrics as charts, graphs, gauges, and tables in a dashboard.

**AzureShop Grafana Dashboard — 6 Panels:**

| Panel | Metric | PromQL |
|---|---|---|
| Request Rate | Requests per second per service | `rate(http_requests_total[5m])` |
| Error Rate | % of 5xx responses | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| P95 Latency | 95th percentile response time | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` |
| Pod Count | Number of running pods per service | `kube_deployment_status_replicas_available` |
| CPU Usage | CPU per pod | `rate(container_cpu_usage_seconds_total[5m])` |
| Memory Usage | Memory per pod | `container_memory_working_set_bytes` |

**Grafana concepts:**
- **Data source:** Where Grafana fetches data (Prometheus, Azure Monitor, etc.)
- **Dashboard:** A collection of panels
- **Panel:** One visualization (one chart)
- **Variable:** Dropdown to filter — e.g., `$namespace` or `$service` so one dashboard works for all services
- **Time range selector:** Show last 1h, 6h, 24h, 7d

**Interview tip:** They may ask "how do you make dashboards consistent across teams?" Answer: Dashboard-as-code using Grafana's JSON model or **Grafonnet** (a library to generate Grafana JSON from code). Store dashboards in Git. Use the Grafana Helm chart to provision dashboards via ConfigMaps — dashboards auto-load on Grafana startup.

---

### Q15. What is chaos engineering? Give an example test you would run on AzureShop.

**Answer:**

Chaos engineering is the practice of deliberately injecting failures into your system in a controlled way to verify that it handles them gracefully. The goal is to find weaknesses before a real outage does.

**The principle:** "If we simulate this failure in a controlled test, we learn how the system responds. Then we fix it. Later when it happens for real, we are prepared."

**Famous example:** Netflix's Chaos Monkey — a tool that randomly kills production EC2 instances to ensure Netflix can survive instance failures.

**Example chaos tests for AzureShop:**

**Test 1: Kill a pod**
```bash
kubectl delete pod product-service-xxx -n dev
```
Expected: Kubernetes detects the pod is gone, schedules a replacement within 30 seconds. HPA maintains minimum replicas. Users see no downtime because other replicas handle traffic.

**Test 2: Exhaust memory**
Use a tool like Chaos Mesh or Litmus to inject a memory pressure condition on the order-service pod. Expected: OOMKilled, pod restarts. Alert fires (restart count > 5). 

**Test 3: Network partition**
Block all traffic from order-service to the Service Bus. Expected: order-service retries with exponential backoff, logs errors, eventually times out with a 503. Other services are unaffected (isolation).

**Test 4: Kill a node**
`az vmss delete-instances` on an AKS node. Expected: cluster autoscaler detects the node is gone, provisions a replacement. Pods are rescheduled on remaining nodes.

**Tools:** Azure Chaos Studio (Microsoft's managed chaos tool), Chaos Mesh (Kubernetes-native), Litmus (CNCF project).

**Interview tip:** They will not expect you to have run chaos tests in production (for a personal project). They want to know you understand the concept and can design tests. Say: "In AzureShop I validated Kubernetes self-healing manually by deleting pods. In a production SRE role I would use Azure Chaos Studio to run scheduled failure injection experiments."

---

### Q16. What is the difference between High Availability (HA) and Disaster Recovery (DR)?

**Answer:**

**High Availability (HA):**
- Goal: Keep the service running despite individual component failures
- Scope: Single region, multiple availability zones
- Mechanism: Redundancy — multiple instances, load balancers, automatic failover
- Recovery time: Seconds to minutes (automatic)
- Example: AKS with 3 nodes across 3 availability zones. One node dies → Kubernetes reschedules pods to other nodes. Users see no downtime.

**Disaster Recovery (DR):**
- Goal: Recover the service after a catastrophic event (entire region goes down)
- Scope: Multiple regions
- Mechanism: Data replication, backup and restore, failover to secondary region
- Recovery time: Minutes to hours (often manual or semi-manual)
- Key metrics:
  - **RPO (Recovery Point Objective):** Maximum data loss you can accept. "We can afford to lose up to 15 minutes of data."
  - **RTO (Recovery Time Objective):** Maximum time to restore service. "We must be back online within 2 hours."

**In AzureShop context:**
- HA: AKS with multiple nodes, PodDisruptionBudget ensuring minimum pods are always running, HPA scaling up under load
- DR would require: Azure SQL with geo-replication to a secondary region, ACR geo-replication, Terraform state backup, and a runbook for failover

**Common DR strategies:**
| Strategy | Description | Cost | RTO |
|---|---|---|---|
| Backup & Restore | Backup data, restore to new region | Low | Hours |
| Pilot Light | Secondary region with minimal resources running | Medium | 30–60 min |
| Warm Standby | Secondary region always running at reduced capacity | High | Minutes |
| Active-Active | Both regions serving traffic simultaneously | Highest | Seconds |

**Interview tip:** If asked "does AzureShop have DR?" — be honest: "The current single-region setup has HA via AKS redundancy. Full DR would require geo-replication of Azure SQL and a secondary AKS cluster. I understand the design and would implement it given the requirement."

---

### Q16.1. Give a full practical explanation of HA and DR — real examples, all four DR strategies, RPO/RTO, AzureShop mapping, and follow-up interview questions.

**Answer:**

## Why Do We Need HA and DR?

Imagine AzureShop is running in production. Real users are buying products. Two different bad things can happen:

**Scenario 1 — A single component fails:**
One of the three AKS nodes crashes at 2pm on a Tuesday. Just one node — the rest of the cluster is fine. Azure is fine.

**Scenario 2 — An entire region goes down:**
Microsoft announces: "East US Azure region is experiencing a complete outage due to a power failure. Estimated recovery: 6 hours."

These are completely different problems requiring completely different solutions:
- Scenario 1 → **High Availability** handles this. Automatic. No human needed.
- Scenario 2 → **Disaster Recovery** handles this. Deliberate plan. Human action needed.

---

## High Availability (HA) — Full Explanation

### What is HA?

High Availability means designing your system so that individual component failures do not cause downtime. The system keeps running automatically even when parts of it fail.

> **HA Analogy — The Aeroplane**
>
> A commercial aircraft has two engines. If one engine fails mid-flight, the plane does not crash. It continues flying on the second engine and lands safely. The redundancy (two engines) was built in from the start. No human decides "switch to engine 2" — it happens automatically.
>
> **HA is that second engine built into your system.**

### What HA Protects Against

| Failure Type | Example | HA Mechanism |
|---|---|---|
| Pod crash | App throws unhandled exception, process dies | Kubernetes restarts pod automatically |
| Node failure | VM running AKS node gets hardware fault | Pods rescheduled to other nodes |
| Availability Zone failure | One datacenter in a region loses power | Pods on other AZ nodes take over |
| Bad deployment | New version crashes on startup | Rolling update stops, old pods remain |
| Traffic spike | 10x normal load hits the service | HPA adds more pods |

### Key Characteristics of HA

- **Scope:** Single region, multiple availability zones
- **Recovery time:** Seconds to minutes — automatic
- **Data loss:** Zero — HA does not involve switching databases
- **Human intervention:** None — fully automated
- **Cost:** Moderate — you run multiple instances always

---

## HA in Practice — AzureShop Deep Dive

### Layer 1 — Multiple Pod Replicas

Every service in AzureShop has a minimum of 2 replicas running at all times:

```yaml
spec:
  minReplicas: 2      # always at least 2 pods running
  maxReplicas: 10
```

If Pod A crashes, Pod B is already running and serving traffic. Kubernetes schedules a replacement. Users experience zero downtime.

```
Normal state:
[Pod A ✅] [Pod B ✅]  ← both serving traffic

Pod A crashes:
[Pod A ❌] [Pod B ✅]  ← Pod B handles all traffic
           [Pod C 🔄]  ← Kubernetes starts replacement

60 seconds later:
[Pod B ✅] [Pod C ✅]  ← back to 2 healthy pods
```

### Layer 2 — PodDisruptionBudget (PDB)

PDB guarantees Kubernetes never takes down so many pods at once that your service goes offline — even during node upgrades:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1     # at least 1 pod must always be running
  selector:
    matchLabels:
      app: product-service
```

Without PDB: During a node upgrade, Kubernetes might drain a node and terminate both pods simultaneously → service down.

With PDB: Kubernetes terminates Pod A, waits for the replacement to become healthy, then terminates Pod B. Service never fully down.

### Layer 3 — Nodes Across Availability Zones

Azure regions have multiple Availability Zones — physically separate datacenters with independent power, cooling, and networking.

```
Azure East US Region
├── Availability Zone 1 (Datacenter A) → AKS Node 1 → product-service Pod A
├── Availability Zone 2 (Datacenter B) → AKS Node 2 → product-service Pod B
└── Availability Zone 3 (Datacenter C) → AKS Node 3 → order-service pods
```

If AZ1's entire datacenter loses power: Pod A dies, Pod B in AZ2 continues serving traffic, Kubernetes schedules a new pod on AZ2 or AZ3. Users: zero downtime.

```hcl
# Terraform — spread nodes across all 3 AZs
resource "azurerm_kubernetes_cluster_node_pool" "system" {
  zones = ["1", "2", "3"]
}
```

### Layer 4 — Liveness and Readiness Probes

```yaml
livenessProbe:
  httpGet:
    path: /health    # non-200 response → Kubernetes kills and restarts pod
    port: 8000
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready     # non-200 response → pod removed from load balancer (not killed)
    port: 8000
  periodSeconds: 5
```

**Liveness:** Is the pod alive? No → restart it.
**Readiness:** Is the pod ready to serve traffic? No → remove from rotation but keep running.

Real example: Order-service starts but Service Bus connection takes 15 seconds. Readiness fails during those 15 seconds — no traffic routed. Once connected, readiness passes — pod enters rotation. Users never hit a pod that cannot serve them.

### Layer 5 — Azure SQL Zone-Redundant Configuration

```hcl
resource "azurerm_mssql_database" "main" {
  zone_redundant = true    # replicas in multiple AZs
}
```

Azure SQL automatically maintains synchronous replicas across AZs. If the AZ hosting the primary fails, Azure SQL promotes a replica automatically. Downtime: seconds.

---

## Disaster Recovery (DR) — Full Explanation

### What is DR?

DR is the plan and capability to restore your service after a catastrophic event that HA cannot handle — entire region failure, data corruption, ransomware, accidental deletion.

> **DR Analogy — The Office Fire**
>
> Your office building (Azure region) burns down completely. No amount of "two servers in the building" helps. The building is gone.
>
> DR is the backup office in another city that you prepared in advance. It is not automatic — someone must activate it, systems must be brought online. But you had the plan ready, so recovery takes hours instead of months.
>
> **HA keeps you running when components fail. DR brings you back when everything fails.**

---

## The Two Most Important DR Metrics

### RPO — Recovery Point Objective

"How much data can we afford to lose?" — expressed as time.

RPO = 1 hour means you can afford to lose up to 1 hour of data. This determines **how frequently you back up or replicate data**.

```
2:00pm  → Backup taken
2:30pm  → 500 orders placed
3:00pm  → DISASTER
3:02pm  → DR activated, restored from 2:00pm backup

Result: 500 orders (30 minutes of data) lost
If RPO = 1 hour → this is within acceptable limits ✅
```

### RTO — Recovery Time Objective

"How long can the service be down before serious damage?" — expressed as time.

RTO = 2 hours means the business can survive a 2-hour outage. This determines **how sophisticated your DR strategy must be**.

```
3:00pm  → DISASTER
3:05pm  → DR team assembled
3:30pm  → Secondary region infrastructure verified
4:00pm  → DNS switched, service restored

Downtime = 1 hour → within RTO of 2 hours ✅
```

**The trade-off:**

| | Lower RPO | Lower RTO |
|---|---|---|
| Meaning | Less data loss | Less downtime |
| Cost | Higher (more frequent replication) | Higher (more standby infrastructure) |
| Complexity | Higher | Higher |

---

## The Four DR Strategies

### Strategy 1 — Backup and Restore

Cheapest and slowest. Take regular backups, restore to new infrastructure when disaster strikes.

```
Primary (East US)                Secondary (West US)
─────────────────                ───────────────────
AKS ✅                           Nothing running
Azure SQL ✅ ──backup──►         Backup in Blob Storage

DISASTER ↓

Primary: ❌                       Terraform apply → new AKS
                                  Azure SQL restored from backup
                                  DNS updated
```

- **RPO:** Hours | **RTO:** Hours | **Cost:** Lowest
- **Use case:** Dev/test, non-critical workloads

### Strategy 2 — Pilot Light

Keep a minimal core (database replica) always running in secondary region. Scale up everything else on demand.

```
Primary (East US)                Secondary (West US)
─────────────────                ───────────────────
Full AKS ✅                      No AKS (saves cost)
Azure SQL ✅ ──geo-replication──► Azure SQL replica ✅ (always in sync)
App Gateway ✅                   No App Gateway

DISASTER ↓

Primary: ❌                       Terraform apply → AKS + App Gateway
                                  SQL failover (data already there)
                                  DNS updated
```

- **RPO:** Near zero | **RTO:** 30–60 min | **Cost:** Low
- **Use case:** Important apps that can tolerate 30–60 min downtime

### Strategy 3 — Warm Standby

Secondary region always running at reduced capacity — ready to scale up quickly.

```
Primary (East US)                Secondary (West US)
─────────────────                ───────────────────
AKS: 10 nodes ✅                 AKS: 3 nodes ✅ (running, smaller)
Azure SQL ✅  ──sync──►          Azure SQL replica ✅
App Gateway ✅                   App Gateway ✅ (no live traffic)

DISASTER ↓

Primary: ❌                       Scale AKS 3 → 10 nodes (5 min)
                                  SQL failover (instant)
                                  DNS switched
```

- **RPO:** Near zero | **RTO:** 5–15 min | **Cost:** Medium
- **Use case:** Business-critical apps, SLA requires < 15 min RTO

### Strategy 4 — Active-Active

Both regions fully running and serving live traffic simultaneously. No failover needed.

```
Primary (East US)                Secondary (West US)
─────────────────                ───────────────────
AKS: 10 nodes ✅                 AKS: 10 nodes ✅
Azure SQL ✅  ←──geo-sync──►     Azure SQL ✅ (both read-write)

Azure Front Door (global load balancer)
├── 50% traffic → East US
└── 50% traffic → West US

DISASTER in East US ↓

Front Door health probe detects East US unhealthy
100% traffic automatically → West US
Users: zero downtime, zero data loss
```

- **RPO:** Zero | **RTO:** Seconds | **Cost:** Highest (double infrastructure)
- **Use case:** Mission-critical — banking, healthcare, large e-commerce

---

## HA vs DR — The Major Differences

| Factor | High Availability | Disaster Recovery |
|---|---|---|
| What it handles | Individual component failures | Catastrophic regional failures |
| Scope | Single region, multiple AZs | Multiple regions |
| Recovery trigger | Automatic | Manual or semi-manual (DR runbook) |
| Recovery time | Seconds to minutes | Minutes to hours |
| Data loss | Zero | Depends on RPO |
| Always running? | Yes — redundancy always active | Depends on strategy |
| Cost | Moderate | Low to very high |
| Who activates? | Nobody — automatic | On-call engineer + DR runbook |
| AzureShop example | HPA, PDB, multi-AZ nodes, health probes | SQL geo-replication, secondary region Terraform |

> **HA = Redundancy within the same city.**
> Two fire stations in Mumbai. If one is busy, the other responds automatically.
>
> **DR = Backup city.**
> If Mumbai is hit by a flood, operations move to Pune. Takes time to activate — but the plan was ready.

---

## AzureShop — HA Implemented, DR Designed

**HA — fully implemented:**
- Min 2 replicas per service (HPA)
- PodDisruptionBudget on all services
- Liveness and readiness probes on all pods
- Multi-AZ node pool (`zones = ["1", "2", "3"]`)
- Azure SQL with `zone_redundant = true`

**DR — designed but not implemented (honest interview answer):**

For production DR on AzureShop (Pilot Light strategy):

```
Primary: West US 2
Secondary: East US

Data replication:
├── Azure SQL → geo-replication (async, RPO ~5 seconds)
├── Redis → geo-replication
├── ACR Premium → geo-replication (images in both regions)
└── Terraform state → RA-GRS storage account (geo-redundant)

Compute (spun up on demand via Terraform):
├── Secondary AKS cluster
├── Secondary App Gateway
└── Secondary Key Vault (always running — needed for secrets)

DNS failover:
└── Azure Front Door → health probe primary region
    → if unhealthy, route 100% to secondary
```

Honest answer for interview: "AzureShop is single-region — it has full HA via AKS multi-AZ and pod redundancy. For production DR I would implement a Pilot Light strategy with Azure SQL geo-replication as the always-on component and Terraform to provision AKS on demand in the secondary region. RPO would be near-zero, RTO approximately 30 minutes."

---

## Follow-Up Interview Questions

**Q: What is the difference between RPO and RTO?**
RPO is about data — how much data loss is acceptable (drives replication frequency). RTO is about time — how long can the service be down (drives standby infrastructure complexity).

**Q: Can you have HA without DR?**
Yes. AzureShop has HA but no DR. HA only protects within the region. A complete regional failure bypasses all HA mechanisms.

**Q: Can you have DR without HA?**
Technically yes, but bad practice. If a single pod failure brings down your primary, you would trigger DR failovers for routine failures. Always implement HA first.

**Q: What is Active-Active vs Active-Passive?**
Active-Active: both regions serve live traffic simultaneously, failover is instant, zero RPO.
Active-Passive: primary serves all traffic, secondary is on standby, some RTO required to switch.

**Q: How do you test a DR plan?**
1. Tabletop exercise — walk through runbook without actual failover, find documentation gaps.
2. Partial failover test — fail over one non-critical service, verify, fail back.
3. Full DR drill — simulate complete region failure, execute full runbook, measure actual RTO/RPO vs targets.
4. Chaos Studio — inject region-level failures in staging.

Rule: An untested DR plan is not a DR plan. Test quarterly for critical systems.

**Q: What Azure services support geo-replication?**
Azure SQL (active geo-replication), Azure Cosmos DB (multi-region writes), Azure Cache for Redis (geo-replication — Premium SKU), ACR (geo-replication — Premium SKU), Azure Storage (RA-GRS, RA-GZRS), Azure Service Bus (Geo-Disaster Recovery pairing).

---

**One-line summary for the interview:**

> High Availability keeps your service running during individual component failures through automatic redundancy within a region. Disaster Recovery brings your service back after a catastrophic regional failure through a pre-planned, multi-region strategy guided by RPO (maximum data loss) and RTO (maximum downtime).

---

## Section 3 — DevOps & CI/CD (Q17–Q24)

---

### Q17. Walk me through your full CI/CD pipeline design in AzureShop.

**Answer:**

AzureShop has **13 Azure DevOps pipelines** organized in two phases.

**Phase 1 — CI (Continuous Integration): 9 pipelines**

Pipelines 1–8 are per-service CI pipelines. Pipeline 9 is Terraform validate.

Each service CI pipeline does:
1. `docker build` — build the image using multi-stage Dockerfile
2. `trivy scan` — scan the image for vulnerabilities (blocks on unfixed critical CVEs)
3. `docker push` — push to ACR with tag = `$(Build.BuildId)`
4. `helm lint` — validate the Helm chart syntax

All CI pipelines use a **reusable template** (`build-template.yaml`) — they call the template, pass the service name, and the template does the work. No code duplication.

**Phase 2 — CD (Continuous Deployment): 4 pipelines**

- `deploy-dev` (Pipeline 10): Deploys all 8 services to the dev AKS namespace. Triggered automatically on every merge to `dev` branch. Uses `deploy-template.yaml`.
- `deploy-staging` (Pipeline 11): Deploys to staging. Triggered manually or on merge to `staging`.
- `deploy-prod` (Pipeline 12): Deploys to production. Requires **manual approval** from the production approver before running. Environment gate.
- `terraform-apply` (Pipeline 13): Applies Terraform changes. Runs against dev/staging/prod based on branch.

**Variable Groups:**
- `vg-common` (ID:1) — shared across all environments: ACR name, service names
- `vg-dev` (ID:2), `vg-staging` (ID:3), `vg-prod` (ID:4) — environment-specific values

**Interview tip:** They will ask "how do you handle secrets in pipelines?" Answer: Secrets are stored in Azure Key Vault and linked to Variable Groups in Azure DevOps. Pipelines reference `$(sql-password)` — Azure DevOps fetches the value from Key Vault at runtime. The secret is never in the pipeline YAML file.

---

### Q18. What is the difference between CI and CD? What does "continuous" mean?

**Answer:**

**CI — Continuous Integration:**
- The practice of merging code changes into a shared branch frequently (multiple times per day)
- On every merge, an automated pipeline runs: build, test, scan
- Goal: Detect integration problems early. If 5 developers each work in isolation for 2 weeks then merge, conflicts and bugs are massive. If they merge daily, problems are small and caught immediately.
- Output: A verified, tested artifact (Docker image, JAR, ZIP)

**CD — Continuous Delivery (or Continuous Deployment):**
- Continuous Delivery: Every successful CI build is deployable. But deployment requires manual approval.
- Continuous Deployment: Every successful CI build is automatically deployed to production, no manual step.
- Most companies use Continuous Delivery — automated to staging, manual gate for production.

**"Continuous" means:** Automated and frequent — not once a month but multiple times per day.

**In AzureShop:**
- CI is triggered on every PR to `dev` — automatic
- CD to dev is automatic after merge
- CD to staging is manual trigger
- CD to production requires manual approval (environment gate in Azure DevOps)

This is Continuous Delivery — not full Continuous Deployment, because production needs a human approval.

**Interview tip:** They may ask "what tests run in your CI?" In AzureShop: linting, Docker build, Trivy scan, Helm lint. A mature pipeline would also include: unit tests, integration tests, DAST (dynamic security scan), load tests on staging. Frame it as "here is what we have, here is what I would add."

---

### Q19. Explain blue/green, canary, and rolling deployments. When do you use each?

**Answer:**

**Rolling Deployment (default Kubernetes behavior):**
- Replace pods one by one. Start a new pod, wait for it to be healthy, remove an old pod. Repeat.
- Zero downtime (traffic is always served by healthy pods)
- Risk: If the new version has a bug, it is gradually replacing working pods before you notice
- Rollback: `kubectl rollout undo deployment/product-service`
- Best for: Low-risk updates, internal tools

**Blue/Green Deployment:**
- You have two identical environments: Blue (current, live) and Green (new version)
- Deploy the new version to Green. Run tests on Green.
- Switch traffic from Blue to Green instantly (update the Ingress or Load Balancer)
- Blue stays running as an instant rollback target
- Risk: Requires double the infrastructure (cost). Database migrations must be backward compatible.
- Rollback: Switch traffic back to Blue — instant
- Best for: Major releases, where you need instant rollback

**Canary Deployment:**
- Send a small percentage of traffic (e.g., 5%, 10%, 20%) to the new version
- Monitor error rates, latency, business metrics for the canary
- If metrics look good, gradually increase the percentage (20% → 50% → 100%)
- If metrics degrade, route 100% back to the old version
- Best for: High-risk changes, A/B testing features, validating with real user traffic

**In AzureShop (Phase 9 — canary example):**
```yaml
# NGINX Ingress canary annotation
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "20"
```
This routes 20% of traffic to the canary Deployment, 80% to the stable Deployment.

**Interview tip:** They may ask about database migrations with blue/green. The hard problem: if Green's code expects a new DB column that Blue doesn't have, and you roll back to Blue — Blue breaks on the new column. Solution: expand/contract migrations. Add the column, deploy (both versions work), then remove old column later.

---

### Q19.1. Give a full practical explanation of Rolling, Blue/Green, and Canary deployments — how they work, real company examples, differences, and when real IT companies use each.

**Answer:**

## Why Deployment Strategies Exist

Every time you ship new code to production, you are taking a risk. The new version might crash, be slow, or break a working feature. The question is: how do you get new code to users while protecting them from that risk?

In the old days companies deployed like this:
1. Take the server offline (maintenance window at 2am Saturday)
2. Copy new code to server
3. Start server and pray it works
4. If broken — roll back manually (takes hours)

Modern companies ship code dozens of times per day with zero downtime. That is only possible because of deployment strategies.

**The core problem all three strategies solve:**

```
V1 (running, stable, users on it)  →  V2 (new, untested in production)
```

Each strategy answers differently: how do you move users from V1 to V2 safely?

---

## Strategy 1 — Rolling Deployment

### What It Is

Rolling deployment replaces instances of the old version (V1) with the new version (V2) gradually, one pod at a time — like rolling a wave across your fleet.

### How It Works — Step by Step

```
Step 0 — Before:
[Pod1:V1 ✅] [Pod2:V1 ✅] [Pod3:V1 ✅] [Pod4:V1 ✅]
All pods serving traffic on V1

Step 1 — Start new V2 pod:
[Pod1:V1 ✅] [Pod2:V1 ✅] [Pod3:V1 ✅] [Pod4:V1 ✅] [Pod5:V2 🔄]

Step 2 — V2 passes readiness probe, enters rotation:
[Pod1:V1 ✅] [Pod2:V1 ✅] [Pod3:V1 ✅] [Pod4:V1 ✅] [Pod5:V2 ✅]

Step 3 — Terminate one V1 pod:
[Pod1:V1 ✅] [Pod2:V1 ✅] [Pod3:V1 ✅] [Pod5:V2 ✅]

Step 4 — Repeat until all V1 pods replaced:
[Pod5:V2 ✅] [Pod6:V2 ✅] [Pod7:V2 ✅] [Pod8:V2 ✅]
Deployment complete — 100% on V2
```

During the rollout, V1 and V2 pods run simultaneously. Users hit both versions.

### Kubernetes Config (AzureShop Helm charts)

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1         # max 1 extra pod during rollout (4+1=5 total)
      maxUnavailable: 0   # never remove V1 until V2 is healthy = zero downtime
```

### Rollback

```bash
kubectl rollout undo deployment/product-service -n dev
# Kubernetes stores history — rollback is instant
```

### Real Company Example — Rolling

**Company:** A SaaS startup deploying a bug fix for the search filter. Low-risk change, just a small function update.

- CI pipeline runs (tests pass, Trivy scan clean)
- CD triggers rolling update
- Over 3 minutes pods gradually replace V1 → V2
- 99.9% of users never notice anything

**Why rolling here:** Fast, simple, zero extra infrastructure cost. Perfect for routine low-risk changes.

### Risks

- **Mixed-version problem:** V1 and V2 run together. If V2 has a DB schema change V1 does not understand — V1 pods start failing. Rolling requires backward-compatible changes.
- **Slow detection:** A subtle bug (memory leak, not a crash) may take time to catch while V2 gradually spreads.

### When Real Companies Use Rolling

- Day-to-day bug fixes and minor feature releases
- Internal tools and non-critical services
- Backward-compatible changes
- When you want zero extra infrastructure cost
- Default choice — no special setup needed

---

## Strategy 2 — Blue/Green Deployment

### What It Is

Blue/Green maintains two complete, identical production environments — Blue (current live version V1) and Green (new version V2). Deploy to Green, test it fully, then switch ALL traffic instantly with a single load balancer change. Like a light switch — not a dimmer.

### How It Works — Step by Step

```
BEFORE DEPLOYMENT:

Internet → Load Balancer / App Gateway
                │
                ▼ 100% traffic
         ┌──────────────────┐
         │   BLUE  (V1) ✅   │  ← live, serving all users
         │   4 replicas      │
         └──────────────────┘

         ┌──────────────────┐
         │   GREEN (V2) ✅   │  ← running but ZERO traffic
         │   4 replicas      │
         └──────────────────┘

STEP 1 — Deploy V2 to Green, test thoroughly (QA, perf tests, UAT)

STEP 2 — Flip traffic (takes seconds):
Internet → Load Balancer
                │
                ▼ 100% traffic
         ┌──────────────────┐
         │   BLUE  (V1) ✅   │  ← still running — instant rollback target
         └──────────────────┘  (kept alive 30–60 min then destroyed)

         ┌──────────────────┐
         │   GREEN (V2) ✅   │  ← now LIVE, serving all users
         └──────────────────┘
```

### Rollback — Instant

```bash
# Flip traffic back to Blue — 30 seconds
kubectl patch service product-service \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

Zero redeployment. Zero data loss. Just flip the switch back.

### Kubernetes Implementation — Two Deployments, One Service

```yaml
# Blue Deployment (V1)
metadata:
  name: product-service-blue
spec:
  template:
    metadata:
      labels:
        app: product-service
        version: blue

---
# Green Deployment (V2)
metadata:
  name: product-service-green
spec:
  template:
    metadata:
      labels:
        app: product-service
        version: green

---
# Service — switch by changing ONE selector label
kind: Service
spec:
  selector:
    app: product-service
    version: blue   # ← change to "green" to flip all traffic instantly
```

### Real Company Example — Blue/Green

**Company:** A large bank — internet banking application.

**Scenario:** Major release — completely redesigned transaction history page, new API contracts, new DB indexes. V1 and V2 are NOT compatible. Mixed versions would cause errors.

**Why Blue/Green:**
1. Breaking changes — V1 and V2 cannot run together (rolling is unsafe)
2. Compliance requires exhaustive testing before go-live
3. Need instant rollback — if 1000 customers complain in 5 minutes, flip back in 30 seconds
4. Deployed at 2am Sunday (low traffic window)

**What happens:**
- Green running V2 since Friday — QA team testing all week
- Saturday: full performance test against Green → passes
- Sunday 2am: traffic switched Blue → Green in 30 seconds
- Monday morning: 2 million customers on new UI
- Tuesday: Blue destroyed to save cost

### The Database Migration Challenge

If V2 requires a new DB column:
```sql
ALTER TABLE orders ADD COLUMN discount_code VARCHAR(50);
```
If you roll back to V1 — V1 does not know about this column and may fail.

**Solution — Expand/Contract pattern:**
- Phase 1: Add column as NULLABLE → both V1 and V2 work
- Phase 2: Switch to V2 (uses the column)
- Phase 3: Make column NOT NULL → only after V1 fully retired

### When Real Companies Use Blue/Green

- Major releases with breaking API or schema changes
- Banking, healthcare, financial services (zero user impact tolerance)
- When instant rollback is a hard requirement
- UI redesigns where mixed old/new versions look broken
- Regulatory deployments with mandatory UAT sign-off

---

## Strategy 3 — Canary Deployment

### What It Is

Send a small percentage of real production traffic (e.g., 5%, 10%, 20%) to V2 while the rest goes to V1. Observe V2's behaviour with real users. If metrics are healthy, gradually increase the percentage. If metrics degrade, route all traffic back to V1 instantly.

### Why "Canary"?

Coal miners carried canary birds into mines. If poisonous gas was present, the canary died first — warning miners before they were affected. In software: a small group of users "experiences" the new version first. If it is buggy, they are affected but the majority is protected.

### How It Works — Step by Step

```
Hour 0:  [V1][V1][V1][V1][V1]   100% on V1

Hour 1:  [V1][V1][V1][V1][V2]   80% V1 / 20% V2 (canary)
         ↓
         Monitor: error rate, latency, business metrics
         V2 looks healthy → proceed

Hour 3:  [V1][V1][V1][V2][V2]   60% V1 / 40% V2
Hour 6:  [V1][V1][V2][V2][V2]   40% V1 / 60% V2
Hour 12: [V1][V2][V2][V2][V2]   20% V1 / 80% V2
Hour 24: [V2][V2][V2][V2][V2]   100% V2 — rollout complete

IF BUG DETECTED at Hour 1:
V2 error rate spikes to 8% → Set canary weight to 0%
Only 20% of users were affected. 80% never saw the bug.
```

### Canary in Kubernetes — NGINX Ingress (AzureShop Phase 9)

```yaml
# Stable Ingress (V1 — always exists)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: product-service-stable
spec:
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /api/products
        backend:
          service:
            name: product-service-v1
            port: 8000

---
# Canary Ingress (V2 — gets percentage of traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: product-service-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"    # 20% to V2
spec:
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /api/products
        backend:
          service:
            name: product-service-v2
            port: 8000
```

Increase canary weight:
```bash
kubectl annotate ingress product-service-canary \
  nginx.ingress.kubernetes.io/canary-weight="50" --overwrite
```

Abort canary (set to 0%):
```bash
kubectl annotate ingress product-service-canary \
  nginx.ingress.kubernetes.io/canary-weight="0" --overwrite
```

### Advanced — User-Based Routing

Route specific users to canary instead of random percentage:

```yaml
# Only users with header X-Beta-User: true go to V2
nginx.ingress.kubernetes.io/canary-by-header: "X-Beta-User"
nginx.ingress.kubernetes.io/canary-by-header-value: "true"
```

Use cases: route your own employees first, route beta opt-in users, route users from a specific geography.

### Automated Canary — Flagger

In mature companies, canary promotion is fully automated using Flagger:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
spec:
  analysis:
    interval: 1m          # check metrics every minute
    threshold: 5          # abort after 5 failed checks
    maxWeight: 50         # max 50% canary traffic
    stepWeight: 10        # increase by 10% each interval
    metrics:
    - name: request-success-rate
      threshold: 99       # must be > 99% success rate
    - name: request-duration
      threshold: 500      # must be < 500ms P99
```

Flagger automatically shifts traffic, checks metrics, promotes on success, rolls back on failure — zero human intervention after deployment.

### Real Company Example — Canary

**Company:** Flipkart — product recommendation engine.

**Scenario:** New ML model for recommendations. Better model in theory — but will real users click more? You cannot test this in staging with fake users.

**Why Canary:**
1. Impact is unknown — only real users clicking real products gives real data
2. Want to limit blast radius — if model is terrible, only 5% of users affected
3. Need real A/B data — compare conversion rate V1 users vs V2 users

**What happens:**
- 5% traffic to new recommendation model
- Monitor: click-through rate, cart additions, purchase completion
- After 1 hour: V2 shows 12% higher click-through rate → increase to 20%
- After 6 hours: V2 shows 8% higher revenue → increase to 50% → 100%
- **The canary was the data.** Without it, they would never know if the model was better.

### When Real Companies Use Canary

- New features where user behaviour is uncertain
- ML model upgrades (impact is data-driven)
- Performance improvements (validate with real traffic)
- High-risk changes on high-traffic services
- A/B testing product features
- Any time you need real production validation before full rollout

---

## The Difference Between All Three — Complete Comparison

| Factor | Rolling | Blue/Green | Canary |
|---|---|---|---|
| How traffic switches | Gradually, pod by pod | Instantly, all at once | Gradually, by percentage |
| Mixed versions in prod | Yes (during rollout) | No (one at a time) | Yes (intentional) |
| Rollback speed | Minutes | Seconds | Seconds (set weight to 0%) |
| Extra infrastructure | Minimal (maxSurge pods) | Double (full second env) | Minimal (few extra pods) |
| User exposure to V2 | All users, gradually | Zero until switch, then all | Small % first |
| Best for | Low-risk, frequent changes | Major/breaking releases | Risky, data-driven changes |
| Cost | Lowest | Highest | Low |
| Used by | All companies, daily deploys | Banks, healthcare | Netflix, Amazon, Google |
| AzureShop | Default Helm charts | Not implemented | Phase 9 NGINX annotation |

---

## Visual Traffic Flow Comparison

```
ROLLING (over time):
Time 0:  V1  V1  V1  V1         100% V1
Time 1:  V1  V1  V1  V2         75% V1, 25% V2
Time 2:  V1  V1  V2  V2         50%/50%
Time 3:  V1  V2  V2  V2         25% V1, 75% V2
Time 4:  V2  V2  V2  V2         100% V2
(users hit both versions during rollout)

BLUE/GREEN (instant switch):
Before:  B   B   B   B          100% Blue/V1
[Green tested in parallel with zero user traffic]
After:   G   G   G   G          100% Green/V2
(never mixed — instant switch)

CANARY (deliberate, monitored, over hours/days):
Hour 0:  V1  V1  V1  V1  V1    100% V1
Hour 1:  V1  V1  V1  V1  V2    80% V1 / 20% V2
Hour 6:  V1  V1  V2  V2  V2    40% V1 / 60% V2
Hour 24: V2  V2  V2  V2  V2    100% V2
(deliberate, data-driven progression)
```

---

## How Real IT Companies Decide Which Strategy

```
Is this a critical service with breaking changes
or zero tolerance for user impact?
│
├── YES → Blue/Green
│         (banking app, payment service, core auth, major release)
│
└── NO → Is this a high-risk change where real user
          behaviour needs validation?
          │
          ├── YES → Canary
          │         (ML model, major UI change, pricing logic,
          │          recommendation engine, A/B feature test)
          │
          └── NO → Routine, low-risk, backward-compatible change?
                    │
                    └── YES → Rolling
                              (bug fix, dependency update,
                               minor feature, config change)
```

**Capgemini in practice:**
- Enterprise banking/insurance clients → Blue/Green for major releases, Rolling for daily patches
- Digital/cloud-native projects → Canary via Flagger or NGINX weights
- Azure DevOps release pipelines → environment gates (manual approval + monitoring window) implement all three strategies

---

**One-line summary for each:**

> **Rolling:** Replace old pods one by one — simple, cheap, zero downtime, good for daily low-risk changes.
>
> **Blue/Green:** Two full environments, instant switch — expensive, instant rollback, perfect for major releases with zero user impact during transition.
>
> **Canary:** Small % of real traffic to new version, watch metrics, promote gradually — best for risky or data-driven changes that need real user validation before full rollout.

---

### Q20. What is HPA vs VPA in Kubernetes? Which did you use?

**Answer:**

Both HPA and VPA automatically scale your application — but in different dimensions.

**HPA — Horizontal Pod Autoscaler:**
- Scales by adding or removing **pods** (horizontal = more instances)
- Triggered by: CPU usage, memory usage, or custom metrics (request rate, queue depth)
- Example: Product-service normally runs 2 pods. Traffic spikes → CPU goes to 80%. HPA adds pods until CPU drops below 70%. Traffic drops → HPA removes extra pods.

```yaml
# AzureShop HPA (in each Helm chart)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**VPA — Vertical Pod Autoscaler:**
- Scales by changing **CPU and memory limits** of existing pods (vertical = bigger instance)
- VPA watches actual resource usage, then recommends (or applies) new `requests` and `limits`
- Problem: VPA must restart pods to change their resource requests — causes brief disruption
- In Kubernetes, you generally cannot combine HPA (CPU-based) and VPA on the same pod

**What you used in AzureShop:** HPA — horizontal scaling is standard for stateless microservices. VPA is used for batch jobs, databases (stateful workloads), or to right-size resource requests.

**Cluster Autoscaler (different from both):** Scales the nodes (VMs) in AKS. If all nodes are full and a new pod cannot be scheduled, Cluster Autoscaler adds a new node. If nodes are underutilized, it removes them. HPA and Cluster Autoscaler work together: HPA adds pods → CA adds nodes if needed.

**Interview tip:** They may ask about KEDA (Kubernetes Event-Driven Autoscaling). KEDA extends HPA to scale based on external events — queue length in Service Bus, number of messages in Event Hub. Perfect for the order-processing flow in AzureShop: scale order-service based on Service Bus queue depth.

---

### Q21. What is a Helm chart? Why use it instead of raw Kubernetes YAML?

**Answer:**

A Helm chart is a package of Kubernetes YAML templates with variables. Helm is like a package manager for Kubernetes — similar to `apt`, `npm`, or `pip`.

**Problem with raw YAML:**
You have 8 services. Each needs a Deployment, Service, HPA, PDB, NetworkPolicy, ServiceAccount — about 6 YAML files per service. That is 48 YAML files. They are almost identical except for the service name, image, and port. If you want to change the resource limits, you edit 8 files. If you make a typo in one, it is hard to catch.

**Helm solution:**
Write the YAML once as a template with `{{ .Values.xxx }}` variables:

```yaml
# templates/deployment.yaml
containers:
- name: {{ .Values.service.name }}
  image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
  ports:
  - containerPort: {{ .Values.service.port }}
```

Then a `values.yaml` per service:
```yaml
# product-service/values.yaml
service:
  name: product-service
  port: 8000
image:
  repository: acrazureshopdev.azurecr.io/product-service
  tag: "1.0.0"
```

Now to deploy: `helm upgrade --install product-service ./helm/product-service -f values.yaml`

**AzureShop Helm charts (per service, in each chart):**
- `Deployment` — pod spec, image, env vars, security context
- `Service` — ClusterIP service for internal routing
- `HPA` — autoscaling rules
- `PDB` — PodDisruptionBudget (minimum 1 pod always available)
- `NetworkPolicy` — zero-trust firewall rules
- `ServiceAccount` — pod identity

**Rollback:** `helm rollback product-service 1` — instantly reverts to the previous release.

**Interview tip:** They may ask about Helm vs Kustomize. Kustomize uses base YAML + patch overlays (no templating, just JSON merge patches). Kustomize is built into `kubectl apply -k`. Helm is more powerful for complex apps. Many teams use both: Kustomize for environment-specific overrides, Helm for third-party app installs (Prometheus, NGINX).

---

### Q22. What is an Ingress Controller? How did you configure it in AzureShop?

**Answer:**

An Ingress Controller is a reverse proxy (like NGINX) running inside your Kubernetes cluster that routes external HTTP/HTTPS traffic to the correct internal service based on the request URL or hostname.

**Without Ingress:** Every service needs its own `LoadBalancer` Service, which creates a public IP. 8 services = 8 public IPs. Expensive, unmanageable, no SSL termination, no path routing.

**With Ingress:** One public IP (the NGINX Ingress Controller's external IP). All traffic enters there. NGINX reads the path and routes internally.

**AzureShop NGINX Ingress routing:**

```yaml
rules:
- host: shop.example.com
  http:
    paths:
    - path: /api/products
      backend:
        service:
          name: product-service
          port: 8000
    - path: /api/orders
      backend:
        service:
          name: order-service
          port: 3003
    - path: /
      backend:
        service:
          name: frontend
          port: 3000
```

External IP: `134.33.223.224` (NGINX Ingress Controller's LoadBalancer IP)

**Traffic flow:**
```
Internet → Application Gateway (WAF, SSL termination) 
         → NGINX Ingress (134.33.223.224, path routing) 
         → ClusterIP Service 
         → Pods
```

**SSL:** TLS termination at Application Gateway. Traffic from App Gateway to NGINX is HTTP (inside private VNet — acceptable). For strict end-to-end TLS, you would also configure TLS on the Ingress using cert-manager + Let's Encrypt.

**Interview tip:** They may ask about AGIC (Application Gateway Ingress Controller). AGIC replaces NGINX — it makes Application Gateway itself act as the Kubernetes Ingress Controller. Traffic goes directly from App Gateway to pods — no intermediate NGINX hop. Lower latency, one less component. The trade-off: AGIC is Azure-specific (NGINX is portable) and has some Helm chart limitations.

---

### Q23. What is Azure Container Registry (ACR)? Why did you use Premium SKU?

**Answer:**

ACR is Azure's private Docker container image registry. Instead of pushing images to Docker Hub (public), you push to ACR. Your AKS cluster pulls images from ACR using the cluster's managed identity — no username/password.

**Basic workflow:**
```bash
# Build and push
docker build -t acrazureshopdev.azurecr.io/product-service:1.0.0 .
docker push acrazureshopdev.azurecr.io/product-service:1.0.0

# AKS pulls automatically using managed identity
```

**ACR SKUs:**

| Feature | Basic | Standard | Premium |
|---|---|---|---|
| Storage | 10 GB | 100 GB | 500 GB |
| Geo-replication | No | No | Yes |
| Private Link | No | No | Yes |
| Image quarantine | No | No | Yes |
| Customer-managed keys | No | No | Yes |
| Price (approx) | $0.17/day | $0.67/day | $1.67/day |

**Why AzureShop uses Premium:**
1. **Private Link** — ACR is accessible only from inside the VNet via private endpoint. Public access disabled.
2. **Geo-replication** — In multi-region production, images are replicated to secondary region. AKS in that region pulls locally (faster pull, no cross-region bandwidth cost).
3. **Image quarantine** — New images are quarantined until security scan passes. Only clean images are available for pull.

**AKS pulling from ACR:** AKS is granted `AcrPull` role on ACR. No credentials in Kubernetes Secrets. The kubelet uses the AKS managed identity to authenticate.

**Interview tip:** They may ask "how do you manage image tags?" Answer: Semantic versioning for releases (`v1.2.3`), Build ID for CI builds (`$(Build.BuildId)`). Never use `latest` in production — it is non-deterministic (pull at different times gets different images). Tag immutability (ACR Premium feature) prevents overwriting a tag once pushed.

---

### Q24. What are reusable pipeline templates? How did you implement them?

**Answer:**

In Azure DevOps, a pipeline template is a YAML file that defines steps, jobs, or stages that can be called from multiple pipeline files. It prevents copy-paste duplication.

**Without templates:** 8 service CI pipelines, each with identical steps (docker build, trivy scan, docker push, helm lint). If you want to add a new step (e.g., SAST scan), you edit 8 files. Risk of inconsistency.

**With templates:** Write the steps once in `build-template.yaml`. Each service pipeline calls the template with one parameter.

**AzureShop build-template.yaml (simplified):**
```yaml
# templates/build-template.yaml
parameters:
- name: serviceName
  type: string
- name: dockerfilePath
  type: string

steps:
- task: Docker@2
  displayName: 'Build image'
  inputs:
    containerRegistry: sc-azureshop-azure
    repository: $(ACR_NAME)/$({{ parameters.serviceName }})
    command: build
    dockerfile: $({{ parameters.dockerfilePath }})
    tags: $(Build.BuildId)

- script: |
    trivy image --exit-code 1 --ignore-unfixed \
      $(ACR_LOGIN_SERVER)/{{ parameters.serviceName }}:$(Build.BuildId)
  displayName: 'Trivy security scan'

- task: Docker@2
  displayName: 'Push image'
  inputs:
    command: push
```

**Each service pipeline simply calls:**
```yaml
# pipelines/product-service-ci.yaml
stages:
- template: templates/build-template.yaml
  parameters:
    serviceName: product-service
    dockerfilePath: services/product-service/Dockerfile
```

**Benefits:**
- Change the template once → all 8 pipelines updated
- Consistent quality gates across all services
- New service onboarding: just create a 5-line YAML that calls the template

**Interview tip:** They may ask about **pipeline as code** governance. Templates should be stored in a separate repository that is access-controlled. Application teams cannot modify the build template — only the platform team can. This enforces consistent security scanning and quality gates across all teams.

---

## Section 4 — Security & Compliance (Q25–Q32)

---

### Q25. What is Azure RBAC? How is it different from Kubernetes RBAC?

**Answer:**

**Azure RBAC (Role-Based Access Control):**
Controls who can do what at the **Azure resource level** — create/delete VMs, read Key Vault secrets, push to ACR, modify AKS cluster settings.

Built-in roles: Owner, Contributor, Reader, and many specific roles (AcrPull, Key Vault Secrets User, etc.)

```
User/Group/Service Principal
  → Role Assignment
    → Role Definition (what actions are allowed)
      → Scope (subscription, resource group, or specific resource)
```

Example: AKS cluster's managed identity is assigned `AcrPull` role on ACR. This lets the kubelet pull images from ACR.

**Kubernetes RBAC:**
Controls who can do what **inside the Kubernetes cluster** — create pods, read secrets, access namespaces.

```yaml
# Kubernetes Role (what actions)
kind: Role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# Kubernetes RoleBinding (who gets the role)
kind: RoleBinding
subjects:
- kind: User
  name: developer@company.com
roleRef:
  kind: Role
  name: pod-reader
```

**Key difference:**
- Azure RBAC: "Can this person create or delete the AKS cluster itself?"
- Kubernetes RBAC: "Can this person deploy pods or read secrets inside the cluster?"

Both are needed. You can have Azure Contributor on the AKS resource (can modify the cluster) but no Kubernetes RBAC (cannot do anything inside the cluster) — or vice versa.

**In AzureShop:** Your user was assigned `Azure Kubernetes Service RBAC Cluster Admin` role (Azure RBAC) which grants full access inside the cluster. In production, developers would get only `Azure Kubernetes Service RBAC Reader` — can view but not modify.

---

### Q26. What is Key Vault CSI Driver? How did you use it in AzureShop?

**Answer:**

The Key Vault CSI Driver (officially: Secrets Store CSI Driver for Azure Key Vault) is a Kubernetes extension that mounts Key Vault secrets as files or environment variables inside pods — automatically, without storing secrets in Kubernetes Secrets or in your code.

**The problem it solves:**
Normally, you would create a Kubernetes Secret (`kubectl create secret`), then mount it in pods. But Kubernetes Secrets are base64-encoded (not encrypted) by default. They can be read by anyone with cluster access. They are also a static copy — if the Key Vault secret rotates, the Kubernetes Secret is stale.

**How CSI Driver works:**
1. Pod starts
2. CSI Driver sees the pod has a `SecretProviderClass` annotation
3. CSI Driver authenticates to Key Vault using the pod's managed identity (Workload Identity)
4. CSI Driver fetches the secrets from Key Vault
5. Secrets are mounted as files inside the pod OR synced to Kubernetes environment variables
6. Pod's app reads them via environment variables

**AzureShop SecretProviderClass:**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: product-service-secrets
spec:
  provider: azure
  parameters:
    keyvaultName: kv-azureshop-6a6c-dev
    objects: |
      - objectName: sql-connection-string
        objectType: secret
      - objectName: redis-connection-string
        objectType: secret
  secretObjects:
  - secretName: product-service-env
    type: Opaque
    data:
    - key: SQL_CONNECTION_STRING
      objectName: sql-connection-string
```

Pods reference `product-service-env` Secret → which is populated from Key Vault at pod start time.

**Interview tip:** They may ask about secret rotation. CSI Driver can be configured with `rotationPollInterval`. It polls Key Vault and updates the mounted secret. But the app must re-read the environment variable (most apps require a restart). Solution: use file mounts + inotify (watch for file changes) instead of env vars for zero-restart secret rotation.

---

### Q27. What is Workload Identity? Why is it better than using client secrets?

**Answer:**

Workload Identity (formerly AAD Pod Identity) allows a Kubernetes pod to authenticate to Azure services (Key Vault, Storage, Service Bus) using a **Managed Identity** — without any client ID, client secret, or certificate stored anywhere.

**Old approach (bad):**
```yaml
env:
- name: AZURE_CLIENT_ID
  value: "abc123"
- name: AZURE_CLIENT_SECRET
  value: "super-secret-value"  # ← stored in Kubernetes Secret, risky
```
Problems: Secret can be leaked, must be rotated manually, anyone with cluster access can read it.

**Workload Identity approach:**
1. Create an Azure Managed Identity for the service (e.g., `mi-notification-service`)
2. Grant this managed identity permissions (e.g., "Key Vault Secrets User" on Key Vault)
3. Create a Kubernetes ServiceAccount linked to this managed identity via federated credentials
4. Pod uses this ServiceAccount
5. When the pod calls Key Vault SDK, it automatically gets a token from the Azure IMDS endpoint — no credentials needed

```python
# Python code — no credentials anywhere
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()  # ← picks up Workload Identity automatically
client = SecretClient(vault_url="https://kv-azureshop-dev.vault.azure.net/", 
                      credential=credential)
secret = client.get_secret("service-bus-connection-string")
```

**In AzureShop:** Notification-service used Workload Identity to connect to Azure Service Bus.
- Managed Identity Client ID: `2e5e41cb-dd6c-46a5-8420-165c463fe974`
- No credentials anywhere in code or Kubernetes Secrets

**Interview tip:** This is a key security concept. The phrase to know: **"eliminate long-lived credentials."** Service accounts, passwords, and API keys are long-lived — they work until manually rotated. Managed Identities use short-lived tokens (valid for 1 hour) issued by Azure AD automatically. If a token is stolen, it expires quickly.

---

### Q28. What is Pod Security Admission? Explain the restricted profile.

**Answer:**

Pod Security Admission (PSA) is a built-in Kubernetes admission controller that enforces security standards on pods when they are created. If a pod violates the policy, it is either warned or rejected.

**Three profiles:**

| Profile | Description |
|---|---|
| privileged | No restrictions. Allows root, privileged containers, host networking. |
| baseline | Prevents known privilege escalations. Allows running as root. |
| restricted | Highest security. Requires non-root, read-only filesystem, no privilege escalation. |

**Three modes per profile:**

| Mode | Action |
|---|---|
| enforce | Reject the pod if it violates the policy |
| audit | Allow the pod but log the violation |
| warn | Allow the pod but show a warning to the user |

**In AzureShop:**
```yaml
# Namespace labels
labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/warn: restricted
```

**What restricted requires (and what you implemented):**
```yaml
securityContext:
  runAsNonRoot: true          # ← cannot run as root
  runAsUser: 1001             # ← specific UID
  runAsGroup: 1001
  readOnlyRootFilesystem: true  # ← cannot write to container filesystem
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]             # ← drop all Linux capabilities
```

**The readOnlyRootFilesystem challenge:** If the app needs to write temp files, you mount an `emptyDir` volume at `/tmp`. The root filesystem is read-only, but `/tmp` is writable. This is what you did for all Node.js and Python services.

**Interview tip:** They may ask "what happens if a third-party container (e.g., Redis) doesn't meet the restricted profile?" Answer: You apply namespace-level policy but use a separate namespace or less strict profile for third-party workloads. Or you set `enforce: baseline` on the namespace and `enforce: restricted` using a separate OPA/Gatekeeper policy on only your own pods.

---

### Q29. What is Trivy? How did you integrate it into CI?

**Answer:**

Trivy is an open-source container security scanner by Aqua Security. It scans Docker images (and filesystems, IaC files, Git repos) for:
- OS package vulnerabilities (CVEs)
- Application dependency vulnerabilities (npm packages, Python packages, Java JARs)
- Misconfigurations
- Exposed secrets

**Why it matters:** Your application code may be secure, but if your base image (`node:18-alpine`) has a known vulnerability (e.g., CVE-2023-xxxx in OpenSSL), your container is at risk. Trivy catches this before deployment.

**AzureShop CI integration:**

```yaml
# In build-template.yaml
- script: |
    # Install trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

    # Generate SARIF report (always — non-blocking, goes to GitHub Advanced Security)
    trivy image --format sarif --output trivy-report.sarif \
      $(ACR_LOGIN_SERVER)/$(serviceName):$(Build.BuildId)

    # Blocking gate — fail build if unfixed CRITICAL CVEs exist
    trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed \
      $(ACR_LOGIN_SERVER)/$(serviceName):$(Build.BuildId)
  displayName: 'Trivy security scan'
```

**`--ignore-unfixed`:** Only block on CVEs where a fix is available. CVEs with no fix available do not block — there is nothing you can do about them right now.

**`.trivyignore` file:** For known, accepted CVEs (e.g., a CVE in a package you must use, no fix available yet, accepted as a risk):
```
# .trivyignore
CVE-2023-12345  # accepted risk: no fix available, low exploitability
```

**SARIF output:** Security findings are uploaded to the pipeline and can integrate with security dashboards (GitHub Advanced Security, Azure Defender for DevOps).

**Interview tip:** They may ask "how do you handle base image vulnerabilities?" Answer: Use minimal base images (`distroless`, `alpine`) which have fewer packages = fewer CVEs. Rebuild images regularly (weekly automated rebuild) to pick up patched base images. Use ACR's image vulnerability scanning (built-in for Premium SKU) as a second layer.

---

### Q30. What is a NetworkPolicy in Kubernetes? What is zero-trust?

**Answer:**

By default in Kubernetes, every pod can talk to every other pod in the cluster — no restrictions. NetworkPolicy is a Kubernetes resource that defines firewall rules at the pod level.

**Zero-trust network model:** "Never trust, always verify." No pod is allowed to communicate with any other pod by default. Explicit allow rules must be created for every allowed connection. If a pod is compromised, it cannot spread laterally to other services.

**AzureShop NetworkPolicy approach:**

Every service has a NetworkPolicy that:
1. **Denies all ingress** by default
2. **Allows ingress only from specific pods** (by label selector)
3. **Allows egress only to specific pods** (and external services like Key Vault, Service Bus)

```yaml
# product-service NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: product-service-netpol
spec:
  podSelector:
    matchLabels:
      app: product-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway  # ← ONLY api-gateway can talk to product-service
    ports:
    - port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: redis  # ← product-service can talk to redis
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53  # ← DNS (always needed)
```

**Important:** NetworkPolicy requires the CNI (Container Network Interface) plugin to support it. Azure CNI and Calico support NetworkPolicy. Kubenet does not.

**Interview tip:** They may ask about Service Mesh (Istio, Linkerd). A service mesh provides network policies + mutual TLS (all pod-to-pod traffic encrypted) + traffic management (retries, circuit breaker) at the application layer. NetworkPolicy works at layer 3/4 (IP/port). Istio works at layer 7 (HTTP, gRPC). For very strict security requirements, both are used together.

---

### Q31. What is Azure Policy? Give a real-world example.

**Answer:**

Azure Policy is a governance tool that enforces rules on your Azure resources. It continuously scans resources, reports compliance, and can automatically deny, modify, or remediate non-compliant resources.

**How it works:**
- A **Policy Definition** is a rule: "All storage accounts must have HTTPS-only enabled"
- A **Policy Assignment** applies that rule to a scope (subscription, resource group)
- A **Policy Initiative** (Policy Set) is a collection of related policies — e.g., all CIS Benchmark policies grouped together

**Modes:**
| Mode | Description |
|---|---|
| Audit | Log non-compliant resources but don't block |
| Deny | Block resource creation if it violates the policy |
| Modify | Automatically fix the resource (add a tag, enable HTTPS) |
| DeployIfNotExists | Deploy a related resource if it doesn't exist (e.g., deploy Defender for every new VM) |

**Real-world examples:**

1. **"Require tags on all resources"**
   ```json
   "if": { "field": "tags['Environment']", "exists": "false" },
   "then": { "effect": "deny" }
   ```
   No resource can be created without the `Environment` tag. Enforces FinOps tagging.

2. **"No public IP addresses"**
   Deny creation of any resource with a public IP. Forces use of Private Endpoints.

3. **"Allowed VM SKUs"**
   Only allow `Standard_D2s_v3` and `Standard_D4s_v3`. Prevents engineers from spinning up expensive SKUs.

4. **"AKS must have Azure Policy add-on enabled"**
   Ensures all AKS clusters have policy enforcement inside Kubernetes (OPA/Gatekeeper).

**AzureShop gap:** Azure Policy was not explicitly implemented in AzureShop. In an enterprise landing zone, you would assign the built-in "CIS Microsoft Azure Foundations Benchmark" initiative — 100+ policies covering encryption, networking, identity, logging.

**Interview tip:** Be honest about this gap. Say: "In AzureShop I focused on pod-level security and network policies. In a production enterprise setup, Azure Policy would be the first thing I implement — it is the guardrail that prevents misconfigurations from being deployed at all."

---

### Q32. What is PIM (Privileged Identity Management)?

**Answer:**

PIM is an Azure AD (Entra ID) feature that manages, controls, and monitors access to privileged roles — just-in-time, for limited time, with approval and audit.

**The problem without PIM:**
A DBA is permanently assigned the `Contributor` role on the production database. If their account is compromised, the attacker has permanent access. Even when the DBA is on vacation, the access exists.

**With PIM — Just-in-Time (JIT) access:**
1. DBA normally has **no standing access** to production
2. When they need to do maintenance, they request activation of the `Contributor` role
3. Request goes to a manager for approval
4. If approved, the role is activated for **4 hours** (configurable)
5. After 4 hours, access automatically expires
6. The activation request, approval, and all actions during the window are fully audited in Azure AD audit logs

**PIM features:**
- **Eligible vs Active:** "Eligible" means you can activate. "Active" means you have the access right now.
- **Time-bound activation:** Set a max duration (1 hour, 8 hours, etc.)
- **Approval workflow:** Multi-level approvals
- **MFA on activation:** Even if your account is compromised, attacker cannot activate PIM role without your phone
- **Access reviews:** Quarterly review — "Does this person still need this role?" Remove if not.

**Real-world importance:** Required for SOC 2, ISO 27001, PCI-DSS compliance. Auditors want to see that privileged access is time-bound and reviewed.

**Interview tip:** Connect to least privilege principle. "PIM is the mechanism that enforces least privilege dynamically. Without PIM, the only way to restrict access is to permanently remove roles — but then engineers cannot do their jobs when needed. PIM gives them access exactly when needed, for exactly as long as needed, with full audit trail."

---

## Section 5 — Operations & Incident Management (Q33–Q37)

---

### Q33. Walk me through how you would handle a production incident.

**Answer:**

A production incident needs a structured response. The process:

**Step 1 — Detect (0–5 minutes)**
Alerting fires: Prometheus alert "HighErrorRate > 5% for 2 minutes" pages on-call via PagerDuty. On-call engineer acknowledges the alert.

**Step 2 — Communicate (first 5 minutes)**
Create a war room (Slack channel: `#incident-2026-05-29`). Post the initial status to the status page: "We are investigating elevated error rates on the checkout service."

**Step 3 — Triage (5–15 minutes)**
Find the scope: Is it one service or many? One region or all regions?
```bash
kubectl get pods -n prod          # Are pods running?
kubectl logs order-service-xxx -n prod  # What are the logs saying?
kubectl top pods -n prod          # Is CPU/memory spiking?
```
Check Grafana: Which service has the error rate spike? When did it start?

**Step 4 — Contain (15–30 minutes)**
Stop the bleeding. If a bad deployment caused it:
```bash
helm rollback order-service 2 -n prod
```
If a downstream dependency is failing, implement a feature flag or circuit breaker.

**Step 5 — Resolve**
Fix root cause, deploy fix through normal CI/CD pipeline with emergency approval.

**Step 6 — Communicate resolution**
Update status page: "Issue resolved at 14:35 UTC. All services operating normally."

**Step 7 — Post-Incident Review (within 48 hours)**
Write an RCA document. No blame. Focus on systems and processes.

**Interview tip:** The key phrase interviewers look for is **"blameless post-mortem."** The SRE culture (from Google SRE book) holds that incidents are caused by system failures, not individual mistakes. The goal is to improve the system, not to punish people. Capgemini as a large enterprise operates 24x7 on-call — showing you understand this process is critical.

---

### Q34. What is an RCA? Give me a real example from your work.

**Answer:**

An RCA (Root Cause Analysis) is a structured document written after an incident that identifies the true root cause — not just the symptom — and defines action items to prevent recurrence.

**The 5 Whys technique:**
Start with the symptom and ask "why" five times until you reach the root cause.

**Real example from AzureShop (Issue #3 — CSI Driver error):**

**Symptom:** All pods in dev namespace were crashing with `MountVolume.SetUp failed`.

Why 1: The CSI volume mount was failing.
Why 2: The CSI Driver could not authenticate to Key Vault.
Why 3: The CSI Addon Identity Client ID in the SecretProviderClass YAML was wrong.
Why 4: The correct Client ID is output by Terraform, but the YAML was hardcoded with an old value.
Why 5: **Root cause:** There was no automation linking the Terraform output to the Kubernetes manifest. The Client ID was manually copied and it was the wrong value.

**Fix applied:**
Updated the Helm chart to use the CSI Addon Identity Client ID as a Helm value, injected by the CD pipeline using `terraform output -raw csi_identity_client_id`.

**Prevention (action items):**
- All Azure resource IDs in Kubernetes manifests must come from Terraform outputs via the pipeline — no manual copy-paste
- Added a post-deployment validation step: `kubectl describe secretproviderclass` to verify secrets mounted

**Other real AzureShop examples you can use:**
- Issue #11: Docker Compose failing — missing environment variables because `docker-compose.yml` referenced Key Vault but Key Vault was not running locally. Fix: Added mock environment variable fallbacks.
- Issue #1: AKS node pool autoscaler not working — missing `cluster_autoscaler_profile` block in Terraform. Fix: Added the block with correct parameters.

**Interview tip:** Having real examples is enormously powerful. Most candidates say "we follow the 5-whys process." You can say "here is an actual incident, the root cause, and what we changed to prevent it." That is an SRE answer.

---

### Q35. What is FinOps? How did you optimize cost in AzureShop?

**Answer:**

FinOps (Financial Operations) is the practice of managing and optimizing cloud spending. It is where finance, engineering, and operations collaborate to make cost-conscious architecture decisions.

**Core FinOps principles:**
- **Visibility:** Everyone can see what they are spending and on what (cost allocation by tag, by team, by service)
- **Accountability:** Teams own their cloud costs, not just ops
- **Optimization:** Continuously right-size, eliminate waste, use commitment discounts

**Cost optimization techniques:**

**1. Reserved Instances / Savings Plans**
Commit to 1 or 3 years of usage in exchange for 30–70% discount. For baseline workloads (always-on AKS system node pool), reserved instances make sense.

**2. Spot Instances (implemented in AzureShop Phase 9)**
Use Azure Spot VMs (unused Azure capacity at up to 90% discount) for batch workloads or fault-tolerant services:
```hcl
# Spot node pool in Terraform
priority        = "Spot"
eviction_policy = "Delete"
spot_max_price  = -1  # pay up to on-demand price
```
Taint: `kubernetes.azure.com/scalesetpriority=spot:NoSchedule` — only pods that tolerate this taint are scheduled on spot nodes. Notification-service (event-driven, restartable) runs on spot.

**3. Resource Quotas (implemented in AzureShop Phase 9)**
Prevent runaway resource consumption:
```yaml
# LimitRange — default and max per pod
default:
  cpu: "250m"
  memory: "256Mi"
max:
  cpu: "2"
  memory: "2Gi"
```

**4. Destroy dev infra when not in use**
AzureShop infra was destroyed on 2026-05-16 to save cost. `terraform destroy` removes all resources. Recreate in 20 minutes with `terraform apply`. For dev environments, this alone can save 70% of cost.

**5. Tagging for cost allocation**
```hcl
tags = {
  Environment = "dev"
  Project     = "azureshop"
  Team        = "platform"
  CostCenter  = "cc-1234"
}
```
Azure Cost Management groups spending by tag. You see exactly which service, team, and environment is spending what.

**6. Auto-shutdown schedules**
Dev AKS clusters can be stopped on a schedule (nights and weekends). `az aks stop` — control plane charges stop, node VMs stop.

---

### Q36. What is a runbook? Give an example.

**Answer:**

A runbook is a documented procedure for a specific operational task. It is a step-by-step guide that anyone on the team can follow — not just the person who originally set something up. In SRE, runbooks are critical: when a 2am incident wakes you up, you need to follow a runbook, not improvise while sleep-deprived.

**Good runbook contains:**
- **Title:** What this runbook covers
- **Trigger:** When to use it (which alert, which scenario)
- **Symptoms:** What you will observe
- **Diagnosis steps:** Commands to run, what to look for
- **Remediation steps:** Exact commands to fix
- **Escalation:** Who to call if this runbook doesn't fix it

**Real AzureShop runbook — Key Vault Recovery (from your project state):**

**Title:** Key Vault Soft-Delete Recovery After Terraform Destroy

**Trigger:** Running `terraform apply` fails with "Key Vault name is already in use" after a `terraform destroy`.

**Cause:** Key Vault has `purge_protection_enabled = true`. After destroy, it enters 90-day soft-delete state occupying the name.

**Steps:**
```bash
# Step 1: Recover the soft-deleted Key Vault
az keyvault recover --name kv-azureshop-6a6c-dev

# Step 2: Import the recovered Key Vault into Terraform state
terraform import -var-file="environments/dev/terraform.tfvars" \
  module.keyvault.azurerm_key_vault.main \
  /subscriptions/6a6cb5d4-9c05-4211-b604-b4a53fed3284/resourceGroups/rg-azureshop-dev/providers/Microsoft.KeyVault/vaults/kv-azureshop-6a6c-dev

# Step 3: Resume terraform apply
export TF_VAR_sql_admin_password="..."
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

**Escalation:** If recovery fails (Key Vault purge protection expired), contact Azure Support.

**Interview tip:** Runbooks are a sign of operational maturity. Say: "Our team's rule is: if you do something manually more than once, write a runbook. If a runbook is executed more than 3 times, automate it." This shows you understand the progression from chaos → documentation → automation.

---

### Q37. What are Resource Quotas and LimitRange in Kubernetes?

**Answer:**

Both are Kubernetes mechanisms to control resource consumption in a namespace — but they operate at different levels.

**ResourceQuota — namespace-level cap:**
Sets a hard limit on the total resources (CPU, memory, pod count, etc.) that can be consumed by all pods in a namespace combined.

```yaml
# AzureShop — k8s/namespaces/dev-resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"        # total CPU requests across all pods ≤ 4 cores
    requests.memory: "8Gi"   # total memory requests ≤ 8GB
    limits.cpu: "8"
    limits.memory: "16Gi"
    count/pods: "20"         # max 20 pods in this namespace
```

If an engineer tries to deploy a 21st pod, Kubernetes rejects it: "exceeded quota."

**LimitRange — per-pod defaults and maximums:**
Sets default resource requests/limits for pods that don't specify them, and enforces maximums per pod.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  - type: Container
    default:          # applied if pod doesn't specify limits
      cpu: "250m"
      memory: "256Mi"
    defaultRequest:   # applied if pod doesn't specify requests
      cpu: "100m"
      memory: "128Mi"
    max:              # pod cannot request more than this
      cpu: "2"
      memory: "2Gi"
```

**Why this matters:**
- Without LimitRange, a pod with no limits can consume all CPU on a node, starving other pods
- Without ResourceQuota, one team's namespace can consume all cluster capacity
- Both together ensure fair sharing and prevent runaway costs

**Interview tip:** Connect this to FinOps. In a multi-team cluster (common at Capgemini — many app teams on a shared AKS cluster), ResourceQuota is the budget guardrail. Each namespace gets a quota that maps to the team's cost allocation. If they want more, they make a request and justify the need.

---

## Section 6 — Behavioral & Collaboration (Q38–Q40)

---

### Q38. Tell me about yourself and why you are applying for this role.

**Answer (your version — adapt and make it yours):**

"I have a background in tech support where I built strong troubleshooting and systems thinking skills — understanding how systems fail and how to diagnose problems under pressure. Over the past year I have been deliberately transitioning into DevOps and cloud engineering.

To make that transition real, I built AzureShop — a production-grade e-commerce microservices platform on Azure, from scratch. It covers exactly the stack in this JD: Terraform IaC with 7 modules, AKS with full Helm chart deployments, Azure DevOps CI/CD pipelines, security hardening with Pod Security Admission and Trivy scanning, observability with Prometheus, Grafana, and Application Insights, and GitOps with Flux.

The project is not theoretical — I hit 16 real bugs during deployment, diagnosed each one, wrote post-mortems, and fixed them. That process gave me practical SRE experience: incident triage, root cause analysis, and building runbooks.

I am applying because Capgemini operates at scale on Azure, and this role is exactly where I want to grow — building reliable, secure, automated platforms for engineering teams. The rotational shift model and on-call responsibility align with the operational depth I want to develop."

**Key elements in this answer:**
- Transition story (honest about background, not apologetic)
- Concrete project with specific technologies from the JD
- Real incidents = real SRE experience
- Connects your goal to the company's need

---

### Q39. Describe a time you solved a complex technical problem.

**Answer — use AzureShop Issue #3 (CSI Driver crash):**

"During the AKS deployment phase of AzureShop, all 8 services crashed simultaneously with `MountVolume.SetUp failed`. Every pod was in CrashLoopBackOff.

I started with `kubectl describe pod product-service-xxx` which showed the error was in mounting the CSI volume. I checked the CSI driver logs: `kubectl logs -n kube-system -l app=secrets-store-csi-driver`. The error was: 'failed to get keyvault token: unauthorized.'

Working backwards through the authentication chain: CSI Driver → authenticates via Managed Identity → Client ID is specified in the SecretProviderClass YAML. I compared the Client ID in my YAML with the actual CSI Addon Identity Client ID from the Azure portal — they were different. I had hardcoded the wrong value.

The root cause was manual copy-paste of a Client ID that Terraform outputs dynamically. My fix had two parts: first, update the SecretProviderClass with the correct Client ID to restore service. Second, modify the CD pipeline to inject the Client ID automatically from `terraform output -raw csi_identity_client_id` — removing the manual step entirely.

After the fix, I wrote a post-mortem and added the rule: any Azure resource ID referenced in Kubernetes must come from Terraform outputs via the pipeline, never from manual copy-paste.

Within 20 minutes all pods were running. The real win was the systemic fix — that class of error cannot happen again."

**STAR structure:**
- **Situation:** All pods crashed, CSI mount failure
- **Task:** Diagnose and fix
- **Action:** Systematic debugging through authentication chain, root cause identification
- **Result:** Service restored in 20 minutes, systemic fix prevents recurrence

---

### Q40. How would you onboard a new application team to the platform?

**Answer:**

Onboarding a new team to a shared AKS platform needs to be structured — if every team sets up their own way, you end up with inconsistency, security gaps, and cost overruns. Here is how I would structure it:

**Step 1 — Namespace and quotas**
Create a dedicated Kubernetes namespace for the team. Apply ResourceQuota (CPU, memory, pod count based on their expected workload) and LimitRange (defaults and maximums per pod).

**Step 2 — RBAC**
Create Kubernetes RBAC Role/RoleBinding giving the team `edit` access in their namespace — they can deploy pods, view logs. They cannot touch other namespaces or cluster-level resources.

Azure RBAC: grant them `Azure Kubernetes Service RBAC Writer` role scoped to their namespace (not full cluster access).

**Step 3 — CI/CD pipeline template**
Give them the reusable build template (`build-template.yaml`) and deploy template. They create a `values.yaml` and a 5-line pipeline YAML that calls the template. They do not write pipeline infrastructure from scratch — they inherit the platform standards (Trivy scanning, image naming conventions, ACR push).

**Step 4 — Networking policy baseline**
Apply a default deny-all NetworkPolicy in their namespace. Guide them to define explicit allow rules for their services. This enforces zero-trust from day one.

**Step 5 — Secrets management**
Show them how to store secrets in Key Vault and reference them via CSI Driver or Workload Identity. Document it in a runbook. They never put secrets in YAML or environment variables directly.

**Step 6 — Observability onboarding**
Add Application Insights connection string to their Key Vault. Give them the standard SDK setup for their language (Node.js/Python code snippets). Show them the shared Grafana instance where they can add their own dashboard.

**Step 7 — Documentation and review**
1-hour live walkthrough. Written runbook for common tasks (how to deploy, rollback, read logs, rotate secrets). First 2 deployments reviewed by the platform team.

**Interview tip:** They are looking for "platform engineering mindset" — you build the scaffolding once (reusable templates, NetworkPolicy baseline, RBAC model) so every team benefits consistently. This is exactly what the JD means by "create reusable modules, pipelines, and golden patterns for app teams."

---

## Quick Reference — Gap Topics

Topics not in AzureShop but in the JD. Learn these conceptually:

| Topic | One-line summary | Your honest answer |
|---|---|---|
| Azure Policy | Governance rules that enforce compliance at resource creation | "Understand the concept, implemented pod-level policies, next step is Azure Policy initiatives" |
| PIM | Just-in-time privileged access with approval and audit | "Understand the requirement, would implement for all production access" |
| APIM | API gateway for exposing and managing APIs externally | "Know the concept — NGINX in AzureShop covers internal routing; APIM for external API monetization" |
| Chaos Engineering | Deliberate failure injection to test resilience | "Validated Kubernetes self-healing manually; would use Azure Chaos Studio in production" |
| Formal SLI/SLO | Defined targets with error budget math | "Grafana tracks error rate and P95 latency; would formalize SLOs and error budget burn alerts" |
| On-call experience | Rotational shift, paging, incident response | "Tech support gave me incident triage experience under pressure; ready for on-call rotation" |

---

*Total: 40 questions across 6 JD sections. Review all 40, mark uncertain ones, revisit before the mock interview.*

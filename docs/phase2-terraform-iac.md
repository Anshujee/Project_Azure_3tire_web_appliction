# Phase 2 — Infrastructure as Code with Terraform
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In Phase 1 we created resources by clicking buttons in the Azure Portal. In Phase 2 we threw that approach away and rewrote everything as code — using Terraform. By the end of this phase, our entire Azure infrastructure (networking, Kubernetes cluster, databases, security, monitoring) is described in `.tf` files that can be version-controlled, reviewed, and re-deployed at any time with a single command.

This is called **Infrastructure as Code (IaC)** and it is one of the most important skills in modern DevOps.

---

## Table of Contents

1. [What is Infrastructure as Code?](#1-what-is-infrastructure-as-code)
2. [What is Terraform?](#2-what-is-terraform)
3. [How Terraform Works — The Core Loop](#3-how-terraform-works--the-core-loop)
4. [Terraform State — The Most Important Concept](#4-terraform-state--the-most-important-concept)
5. [Remote State with Azure Blob Storage](#5-remote-state-with-azure-blob-storage)
6. [Providers and the AzureRM Provider](#6-providers-and-the-azurerm-provider)
7. [Variables, Locals, and Outputs](#7-variables-locals-and-outputs)
8. [Sensitive Variables — Never Store Passwords in Code](#8-sensitive-variables--never-store-passwords-in-code)
9. [Modules — Splitting Infrastructure into Layers](#9-modules--splitting-infrastructure-into-layers)
10. [The Module We Built — Full Structure](#10-the-module-we-built--full-structure)
11. [Module 1 — Networking](#11-module-1--networking)
12. [Module 2 — ACR (Azure Container Registry)](#12-module-2--acr-azure-container-registry)
13. [Module 3 — AKS (Azure Kubernetes Service)](#13-module-3--aks-azure-kubernetes-service)
14. [Module 4 — Databases (SQL, Cosmos DB, Redis)](#14-module-4--databases-sql-cosmos-db-redis)
15. [Module 5 — Key Vault](#15-module-5--key-vault)
16. [Module 6 — Application Gateway and WAF](#16-module-6--application-gateway-and-waf)
17. [Module 7 — Monitoring](#17-module-7--monitoring)
18. [How Modules Talk to Each Other](#18-how-modules-talk-to-each-other)
19. [The Circular Dependency Problem We Solved](#19-the-circular-dependency-problem-we-solved)
20. [Multi-Environment Strategy — Dev, Staging, Prod](#20-multi-environment-strategy--dev-staging-prod)
21. [Key Terraform Patterns Used](#21-key-terraform-patterns-used)
22. [Resource Naming Conventions](#22-resource-naming-conventions)
23. [How to Run Terraform](#23-how-to-run-terraform)
24. [Common Errors and Fixes](#24-common-errors-and-fixes)
25. [Interview Questions and Answers](#25-interview-questions-and-answers)

---

## 1. What is Infrastructure as Code?

### The Problem Without IaC

Before IaC, teams created infrastructure by clicking through the Azure Portal. This led to a series of real problems:

```
Problem 1 — It cannot be reproduced
  Alice creates a server with specific settings.
  Bob creates a "similar" server for staging.
  The two servers are slightly different. Bugs appear in prod that never showed in staging.

Problem 2 — It cannot be audited
  Someone changed a firewall rule three months ago.
  Nobody wrote it down. Nobody knows who did it or why.
  The audit log says "portal user clicked something."

Problem 3 — Disaster recovery is slow
  The production database server crashes.
  It takes 3 days to recreate everything from memory and screenshots.

Problem 4 — Environments drift
  Dev, staging, and prod slowly become different from each other
  as people make small manual changes. Nobody tracks it.
```

### The Solution — Infrastructure as Code

IaC means you write your infrastructure as code files, exactly like application code:

```
✅ Version-controlled in git — see every change, who made it, why
✅ Reviewable — someone else checks your infra change before it applies
✅ Reproducible — run the same command → get the exact same infrastructure
✅ Auditable — the git history IS the audit log
✅ Fast disaster recovery — a pipeline re-creates everything in 20 minutes
✅ No environment drift — all environments come from the same code
```

IaC is not optional in modern DevOps. Every serious company uses it.

---

## 2. What is Terraform?

Terraform is the most widely used IaC tool. It was created by HashiCorp and works with virtually every cloud provider (Azure, AWS, GCP, and hundreds more).

### How Terraform Thinks

Terraform uses a **declarative** model. You describe the desired state, not the steps to get there.

```
Imperative (how most people think):
  1. Create a virtual network
  2. Create a subnet inside it
  3. Create a security group
  4. Attach the security group to the subnet

Declarative (how Terraform works):
  "I want a VNet with a subnet that has a security group attached."
  Terraform figures out the steps itself.
```

This matters because on the second run, Terraform compares what exists to what you want. If they match, it does nothing. If they differ, it only changes what needs to change. This is called **idempotency** — running it 100 times gives the same result as running it once.

### Terraform vs ARM Templates / Bicep

Azure has its own IaC tools: ARM (Azure Resource Manager) templates and Bicep. Why use Terraform instead?

| | Terraform | ARM / Bicep |
|---|---|---|
| Works with | Azure + AWS + GCP + 100s of providers | Azure only |
| Language | HCL (readable, concise) | JSON (ARM) or Bicep DSL |
| State management | Yes — tracks everything | No built-in state |
| Community | Massive, huge module library | Smaller |
| Multi-cloud | Yes | No |

For a company using only Azure, Bicep is a valid choice. For multi-cloud or if you want portability, Terraform wins.

---

## 3. How Terraform Works — The Core Loop

Every Terraform workflow follows the same three steps:

```
Step 1: terraform init
  Downloads the AzureRM provider plugin.
  Connects to the remote backend (Azure Blob Storage).
  Must be run once before anything else.

Step 2: terraform plan
  Reads your .tf files (desired state).
  Reads the current state file (what exists).
  Reads the actual Azure resources (reality check).
  Shows you exactly what will be CREATED (+), CHANGED (~), or DESTROYED (-).
  Does NOT make any changes.

Step 3: terraform apply
  Runs the same diff as plan.
  Shows you the plan and asks "Do you want to apply these changes? yes/no"
  If you type "yes", it calls Azure APIs to make the changes.
  Updates the state file with the new reality.
```

```
Your .tf files
     ↓
terraform plan  →  shows diff
     ↓
terraform apply →  makes changes → updates state
     ↓
Azure (real resources)
```

### The Destroy Command

```bash
terraform destroy
```

The reverse of apply — deletes everything tracked in the state file. We used this at the end of Phase 6 to stop Azure billing.

---

## 4. Terraform State — The Most Important Concept

### What Is State?

Terraform keeps a file called `terraform.tfstate`. This file is a JSON record of every resource Terraform has created — their IDs, properties, and relationships.

```json
{
  "resources": [
    {
      "type": "azurerm_virtual_network",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "/subscriptions/6a6cb.../virtualNetworks/vnet-azureshop-dev",
            "name": "vnet-azureshop-dev",
            "address_space": ["10.0.0.0/8"]
          }
        }
      ]
    }
  ]
}
```

Terraform uses this file to answer the question: "What do I already manage, and what are their current values?"

### Why State Is Critical

Without the state file, Terraform cannot know:
- Whether a resource already exists (it would try to create it again)
- The resource's Azure ID (needed to update or delete it)
- The relationships between resources (which subnet belongs to which VNet)

**Think of it as Terraform's memory.** Lose the state file = Terraform forgets everything it built.

### What Happens If State Gets Out of Sync?

If someone deletes a resource manually in the Azure Portal (not through Terraform), the state file still thinks it exists. The next `terraform plan` will show a diff. The next `terraform apply` will try to re-create it.

You can fix drift using:
```bash
terraform refresh    # Update state to match actual Azure resources
terraform import     # Bring an existing resource into state management
```

We used `terraform import` in Phase 6 when we needed to bring the manually-created ACR into Terraform's control.

---

## 5. Remote State with Azure Blob Storage

### The Problem with Local State

The default behavior stores `terraform.tfstate` on your local machine. Problems:
- Two developers run `apply` at the same time → state file corrupts
- Your laptop dies → state file is gone
- No audit trail of who ran what

### Our Solution — Azure Blob Storage

We store the state file in Azure Blob Storage. Blob Storage provides:
- **Automatic locking** — when one person runs `apply`, the blob is leased (locked). Nobody else can run `apply` until the first one finishes.
- **Durability** — 99.999999999% (11 nines) durability. Effectively never lost.
- **History** — blob versioning keeps all previous state versions.

```
Developer 1: terraform apply
  → Acquires blob lease (lock)
  → Creates resources
  → Updates state file
  → Releases lease

Developer 2: terraform apply (at the same time)
  → Tries to acquire lease
  → Gets "state blob is already locked"
  → Waits or fails
  → No corruption
```

### How We Set It Up

The backend configuration is split into two parts intentionally:

```hcl
# infra/backend.tf — partial config (no "key" here)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-azureshop-dev"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    # key is NOT here — passed at init time
  }
}
```

```hcl
# infra/environments/dev/backend.hcl
key = "dev.tfstate"
```

```hcl
# infra/environments/staging/backend.hcl
key = "staging.tfstate"
```

The `key` is the filename inside the blob container. Each environment has its own file:
```
tfstate container in Azure Blob Storage
├── dev.tfstate       ← dev resources
├── staging.tfstate   ← staging resources
└── prod.tfstate      ← prod resources
```

This is the critical design: destroying dev never touches staging or prod state.

```bash
# Init for dev
terraform init -backend-config="environments/dev/backend.hcl"

# Init for staging (run in a fresh directory or after terraform init -reconfigure)
terraform init -backend-config="environments/staging/backend.hcl" -reconfigure
```

### Why "myprojectazshoptfstate"?

Azure Storage Account names must be:
- Globally unique across all Azure subscriptions worldwide
- 3–24 characters
- Lowercase letters and numbers only (no hyphens)

`myprojectazshoptfstate` satisfies all three constraints. We created this storage account manually in Phase 1 — it is NOT managed by Terraform (Terraform cannot store its state in something that Terraform itself creates — a chicken-and-egg problem).

---

## 6. Providers and the AzureRM Provider

A **provider** is a plugin that tells Terraform how to talk to a specific cloud or service. For Azure, we use the `azurerm` provider maintained by Microsoft.

```hcl
# infra/providers.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

### The `~>` Version Constraint

`~> 3.110.0` means: use any version `>= 3.110.0` but `< 3.111.0`. This locks the minor version. It prevents surprise breaking changes when HashiCorp releases a new provider version, while still allowing bug-fix patches.

### How Authentication Works

When you run `terraform apply` locally, the AzureRM provider uses your current `az login` session. It reads the credentials from `~/.azure/`. No username/password in code.

When a CI/CD pipeline runs Terraform, it uses a Service Principal (`sp-azureshop-terraform`) whose credentials are stored as secret environment variables in Azure DevOps — never in code.

---

## 7. Variables, Locals, and Outputs

### Variables — Inputs to Your Configuration

Variables make your Terraform reusable. Instead of hardcoding `"dev"` everywhere, you define a variable and pass the value at runtime.

```hcl
# variables.tf
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"   # used if not provided
}
```

Variables are set in several ways (in order of priority, last wins):
1. Default value in `variable` block
2. Environment variable: `export TF_VAR_environment=dev`
3. `.tfvars` file: `-var-file="environments/dev/terraform.tfvars"`
4. Command line: `-var="environment=dev"`

### terraform.tfvars — Environment Configuration

```hcl
# environments/dev/terraform.tfvars
project             = "azureshop"
environment         = "dev"
location            = "eastus"
resource_group_name = "rg-azureshop-dev"
log_retention_days  = 30
keyvault_network_default_action = "Allow"
sql_location        = "westus2"
```

This file contains non-sensitive configuration. It is committed to git. Sensitive values like `sql_admin_password` are never in this file.

### Locals — Computed Values

Locals are like variables but computed inside the configuration. They are not set from outside.

```hcl
# main.tf
locals {
  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  })
}
```

`merge()` combines two maps. The `local.tags` value contains base tags from `var.tags` plus three standard tags added automatically to every resource. This ensures every Azure resource has consistent tags without repeating them in every module.

### Outputs — What Modules Expose

Outputs are values a module makes available to whoever calls it. They are how modules communicate.

```hcl
# modules/networking/outputs.tf
output "aks_subnet_id" {
  description = "Subnet ID for AKS node pool"
  value       = azurerm_subnet.aks.id
}
```

The root `main.tf` then uses this:
```hcl
module "aks" {
  subnet_id = module.networking.aks_subnet_id  # ← reading the output
}
```

---

## 8. Sensitive Variables — Never Store Passwords in Code

### The Wrong Way (NEVER DO THIS)

```hcl
# WRONG — password visible in git history forever
sql_admin_password = "MyPassword123!"
```

Once committed to git, a secret is compromised — even if you delete the file later, it remains in git history and anyone who ever cloned the repo may have it.

### Our Approach — Environment Variables

The `sql_admin_password` variable is declared as sensitive:

```hcl
variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true   # Terraform will never print this in plan/apply output
}
```

Set it before running Terraform:
```bash
export TF_VAR_sql_admin_password="YourStr0ng@Password"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Terraform automatically picks up any environment variable named `TF_VAR_<variable_name>`.

In Azure DevOps pipelines (Phase 5), this is stored as a secret variable in the `vg-common` variable group — encrypted at rest, never visible in logs.

### sensitive = true in Practice

When `sensitive = true` is set:
- `terraform plan` shows `(sensitive value)` instead of the actual value
- `terraform output` refuses to print it without `-json` or explicit override
- It is still stored in the state file (encrypted if you use Azure Blob Storage with encryption)

---

## 9. Modules — Splitting Infrastructure into Layers

### Why Modules?

Without modules, `main.tf` would be 3,000+ lines of code. Nobody can read or maintain that. Modules split infrastructure into logical units — exactly like functions in application code.

A Terraform module is just a directory with `.tf` files. Every module has the same three files:

```
modules/networking/
├── variables.tf   ← what the module needs as input
├── main.tf        ← the resources it creates
└── outputs.tf     ← what it gives back
```

### Module Benefits

```
1. Separation of concerns
   The networking team owns modules/networking/.
   The database team owns modules/databases/.
   They can work independently.

2. Reusability
   The same AKS module can be called three times with different variables
   to create dev, staging, and prod clusters.

3. Readability
   Root main.tf is a clean list of 7 module calls — easy to understand.
   Details are hidden inside each module.

4. Testing
   Each module can be tested independently without deploying everything.
```

---

## 10. The Module We Built — Full Structure

```
infra/
├── backend.tf                  ← remote state config
├── providers.tf                ← azurerm ~> 3.110.0
├── variables.tf                ← all input variables
├── main.tf                     ← wires all 7 modules together
├── outputs.tf                  ← exposes resource group name, location
│
├── environments/
│   ├── dev/
│   │   ├── backend.hcl         ← key = "dev.tfstate"
│   │   └── terraform.tfvars    ← dev-specific values
│   ├── staging/
│   │   ├── backend.hcl         ← key = "staging.tfstate"
│   │   └── terraform.tfvars
│   └── prod/
│       ├── backend.hcl         ← key = "prod.tfstate"
│       └── terraform.tfvars
│
└── modules/
    ├── networking/     ← VNet, subnets, NSGs, Bastion
    ├── acr/            ← Azure Container Registry, AcrPull role
    ├── aks/            ← Kubernetes cluster, node pools, identity
    ├── databases/      ← SQL Server, Cosmos DB, Redis Cache
    ├── keyvault/       ← Key Vault, secrets, role assignments
    ├── appgateway/     ← Application Gateway, WAF Policy
    └── monitoring/     ← Log Analytics, App Insights ×8, Grafana
```

**Total resources created:** 56 Azure resources from a single `terraform apply`.

---

## 11. Module 1 — Networking

The networking module is always created first. Everything else depends on it — AKS needs a subnet, databases need a subnet, the Application Gateway needs a subnet.

### What It Creates

```
Virtual Network: vnet-azureshop-dev (10.0.0.0/8)
├── subnet-aks      (10.1.0.0/16)  ← AKS nodes and pods
├── subnet-db       (10.2.0.0/16)  ← databases
├── subnet-appgw    (10.3.0.0/16)  ← Application Gateway
└── AzureBastionSubnet (10.4.0.0/26) ← Azure Bastion (name is fixed by Azure)

Network Security Groups (one per subnet):
├── nsg-aks-dev     ← allows HTTPS, VNet traffic; denies all else
├── nsg-db-dev      ← allows SQL(1433), Redis(6380), HTTPS only from AKS subnet
├── nsg-appgw-dev   ← allows HTTP/HTTPS from internet, AppGW management ports
└── nsg-bastion-dev ← allows HTTPS from internet, SSH/RDP outbound to VNet

Azure Bastion: bastion-azureshop-dev
Public IP: pip-bastion-azureshop-dev
```

### What is a VNet?

A Virtual Network (VNet) is your private network in Azure. Think of it like buying a plot of land and dividing it into sections (subnets). Resources inside the VNet can talk to each other privately. Nothing outside can get in unless you explicitly allow it.

### What is a Subnet?

A subnet is a subdivision of the VNet. It has its own IP address range. We create separate subnets for different layers of the architecture:
- `subnet-aks` for the Kubernetes nodes and pods
- `subnet-db` for databases
- `subnet-appgw` for the Application Gateway
- `AzureBastionSubnet` for the Bastion service

Separation matters for security — a NSG on `subnet-db` can block all traffic except from `subnet-aks`. Databases are never directly reachable from the internet.

### What is an NSG?

A Network Security Group is a firewall at the subnet level. It has rules that allow or deny traffic based on source IP, destination port, and protocol.

```
NSG rules evaluate from lowest priority number to highest.
First matching rule wins.

nsg-db-dev rules:
Priority 100: Allow TCP from 10.1.0.0/16 (AKS subnet) → port 1433 (SQL)
Priority 200: Allow TCP from 10.1.0.0/16 (AKS subnet) → port 6380 (Redis)
Priority 300: Allow TCP from 10.1.0.0/16 (AKS subnet) → port 443 (HTTPS/Cosmos)
Priority 4096: DENY ALL inbound
```

This means: only AKS pods can reach the databases. No other source (internet, other subnets) can get through.

### What is Azure Bastion?

Normally to connect to a VM (virtual machine) over SSH, you need to expose port 22 to the internet. That is a security risk.

Azure Bastion is a jump host — a managed service that lets you SSH or RDP to a private VM through your browser, without exposing port 22. You connect to Bastion over HTTPS (port 443), and Bastion connects to your VM over the private network.

```
Your Browser → HTTPS 443 → Azure Bastion → SSH 22 → Private VM
                                         (no internet exposure)
```

### Service Endpoints

```hcl
resource "azurerm_subnet" "aks" {
  service_endpoints = [
    "Microsoft.AzureCosmosDB",
    "Microsoft.Sql"
  ]
}
```

Service endpoints tell Azure to route traffic to Cosmos DB and SQL directly through the Azure backbone network (not the internet), and to allow these services to identify that traffic comes from this specific subnet. This is required for VNet firewall rules on Cosmos DB and SQL — without service endpoints, the VNet rule is rejected.

---

## 12. Module 2 — ACR (Azure Container Registry)

ACR is the private Docker image registry where we store our container images. Think of it as a private version of Docker Hub that lives inside your Azure subscription.

### What It Creates

```
Azure Container Registry: acrazureshopdev (Premium SKU)
Role Assignment: AKS kubelet identity → AcrPull role on the registry
```

### AcrPull Role — The Security Design

AKS nodes need to pull Docker images from ACR when starting a pod. The question is: how do the nodes authenticate to ACR?

**Wrong approach:** Enable admin account on ACR (a shared username/password) and put those credentials in a Kubernetes Secret. This password needs to be rotated, can be accidentally leaked, and is shared across all users.

**Our approach:** Managed Identity + Role Assignment.

```hcl
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = var.aks_kubelet_identity_object_id  # AKS node identity
  role_definition_name = "AcrPull"                           # read-only access
  scope                = azurerm_container_registry.main.id  # only this ACR
}
```

The AKS kubelet identity is a Managed Identity that Azure creates automatically for AKS nodes. We grant it `AcrPull` (read-only) on our ACR. Now AKS nodes can pull images automatically — no password, no rotation, no leakage risk.

### admin_enabled = false

```hcl
resource "azurerm_container_registry" "main" {
  admin_enabled = false   # Disable shared username/password account
}
```

With `admin_enabled = false`, the only way to authenticate to ACR is via Azure AD (Managed Identity or Service Principal). This removes an entire class of credential-based attacks.

---

## 13. Module 3 — AKS (Azure Kubernetes Service)

The AKS module creates the Kubernetes cluster. This is the biggest and most complex module. The full explanation of AKS concepts is in the Phase 6 document — here we focus on the Terraform configuration decisions.

### What It Creates

```
AKS Cluster: aks-azureshop-dev
├── System Node Pool: "system"
│   └── Standard_D2s_v3 VMs, runs only system components
└── User Node Pool: "user"
    └── Standard_D2s_v3 VMs, autoscaling 1–5 nodes, runs app workloads
Identity: SystemAssigned Managed Identity
Key Vault Secrets Provider Addon: enabled, rotation every 2 minutes
Azure Policy Addon: enabled
Container Insights (OMS Agent): connected to Log Analytics Workspace
```

### System Identity

```hcl
identity {
  type = "SystemAssigned"
}
```

`SystemAssigned` means Azure creates and manages the identity automatically. When the cluster is deleted, the identity is deleted too. There is no service principal to rotate, no certificate to manage. This is the recommended approach for AKS.

### Azure AD RBAC Integration

```hcl
azure_active_directory_role_based_access_control {
  tenant_id          = data.azurerm_client_config.current.tenant_id
  azure_rbac_enabled = true
}
```

This ties AKS authentication into Azure AD. Users who want to run `kubectl` commands must have an Azure role assignment on the AKS cluster. The same identity system used for everything else in Azure — consistent, auditable, no separate user management.

### lifecycle ignore_changes — The Autoscaler Problem

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  node_count = var.user_node_count   # e.g. 2

  lifecycle {
    ignore_changes = [node_count]
  }
}
```

The Kubernetes Cluster Autoscaler changes `node_count` automatically based on pod scheduling needs. If Terraform stored `node_count = 2` in the tfvars file, the next `terraform apply` would reset the count to 2 — undoing the autoscaler's work and potentially evicting running pods.

`ignore_changes = [node_count]` tells Terraform: manage everything about this node pool EXCEPT the count. The autoscaler owns that field.

### Key Vault Secrets Provider Addon

```hcl
key_vault_secrets_provider {
  secret_rotation_enabled  = true
  secret_rotation_interval = "2m"
}
```

This installs the CSI Driver on every node. `secret_rotation_enabled = true` means when a secret is updated in Key Vault, the mounted files inside pods are updated automatically within 2 minutes — without restarting the pod. This is how secret rotation works in production: update Key Vault, CSI driver propagates it to running pods.

---

## 14. Module 4 — Databases (SQL, Cosmos DB, Redis)

Our application uses three different databases, each optimized for a different type of data.

```
Azure SQL     → relational data: users, orders (structured, ACID transactions)
Cosmos DB     → document data: products, cart (flexible JSON, fast reads)
Redis Cache   → session/cache data: cart state, session tokens (in-memory, fast)
```

### Azure SQL

```
SQL Server: sql-azureshop-dev.database.windows.net
├── db-users   ← user accounts and authentication
└── db-orders  ← order history and transactions
```

**Why SQL for users and orders?** User accounts and orders have a fixed structure with strict consistency requirements. A user's balance cannot be slightly wrong. SQL's ACID (Atomicity, Consistency, Isolation, Durability) transactions guarantee data integrity. A payment that debits one account and credits another either fully completes or fully rolls back — never partially.

**Minimum TLS 1.2:**
```hcl
minimum_tls_version = "1.2"
```
Rejects connections using older TLS versions (1.0, 1.1) which have known vulnerabilities. All application clients must support TLS 1.2 or newer.

**Firewall Rules:**
```hcl
# Only AKS pods can reach SQL
resource "azurerm_mssql_firewall_rule" "allow_aks" {
  start_ip_address = "10.1.0.0"
  end_ip_address   = "10.1.255.255"
}

# Special 0.0.0.0 rule = allow Azure internal services (pipelines, Monitor)
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
```

The `0.0.0.0` to `0.0.0.0` rule is an Azure-specific convention meaning "allow all Azure datacenter IPs." This is needed for Azure DevOps pipelines (which run on Azure infrastructure) to run database migrations.

**Azure Defender for SQL:**
```hcl
threat_detection_policy {
  state = "Enabled"
}
```
Azure Defender monitors all SQL queries and detects SQL injection attempts, brute-force login attacks, and anomalous access patterns. It sends email alerts to the subscription admin.

### Cosmos DB

Cosmos DB is a globally distributed NoSQL database. It stores data as JSON documents.

```
Cosmos DB Account: cosmos-azureshop-dev
└── Database: azureshop-db
    ├── Container: products (partition key: /categoryId)
    └── Container: cart     (partition key: /userId, TTL: 7 days)
```

**Why Cosmos for products and cart?** Products have varying attributes — a shirt has a size, a laptop has RAM and CPU. SQL tables have fixed columns. Cosmos stores flexible JSON, so each product document can have different fields without schema migration.

**Consistency Levels — One of the Most Important Cosmos Concepts:**

Cosmos DB offers 5 consistency levels. The tradeoff is between consistency (correctness) and performance (speed):

```
Strong         → Every read sees the latest write. Slowest.
                 Use for: financial transactions, counters
                 
Bounded Staleness → Reads may lag behind writes by a configured amount.
                   Use for: leaderboards with slight delay OK

Session        → Within a session, reads always see your own writes.
                 Other sessions may see slightly stale data.
                 Use for: most apps ← WE USE THIS
                 
Consistent Prefix → Reads never see out-of-order writes.
                    Use for: social feeds

Eventual       → Highest throughput, lowest latency. Reads may be stale.
                 Use for: likes counts, view counts
```

We use **Session** consistency — the best balance for an e-commerce app. When a user adds a product to their cart, they immediately see it in their cart (their session is consistent). Other users may see a slightly older version of the catalog — acceptable.

**Partition Keys — Critical for Performance:**

```hcl
# products container
partition_key_paths = ["/categoryId"]

# cart container
partition_key_paths = ["/userId"]
```

Cosmos DB partitions data across physical nodes using the partition key. A good partition key:
- Has many distinct values (high cardinality)
- Distributes data evenly — no "hot" partitions
- Matches the most common query filter

`/categoryId` for products: most queries are "show all products in electronics" — Cosmos retrieves them from one partition.

`/userId` for cart: every cart operation is for one user — all their data is in one partition, making reads and writes fast.

**Cart TTL — Automatic Expiry:**

```hcl
default_ttl = 604800   # 7 days in seconds
```

Cart items automatically expire after 7 days. Cosmos deletes them without any application code or cleanup job. This prevents the cart database from growing indefinitely with abandoned carts.

**VNet Integration:**

```hcl
virtual_network_rule {
  id = var.aks_subnet_id
}
public_network_access_enabled = false
```

Cosmos DB is only accessible from inside the AKS subnet. No public internet access. This requires service endpoints on the subnet (set in the networking module).

### Redis Cache

Redis is an in-memory key-value store. It is extremely fast (sub-millisecond responses) because data lives in RAM.

```hcl
resource "azurerm_redis_cache" "main" {
  non_ssl_port_enabled = false   # Force TLS only (port 6380)
  minimum_tls_version  = "1.2"

  redis_configuration {
    maxmemory_policy = "volatile-lru"
    # When Redis runs out of memory, evict least recently used keys
    # that have a TTL set. Session tokens have TTLs, so they are
    # evicted before permanent data.
  }
}
```

**Why TLS for Redis?** Redis transmits data unencrypted over the wire by default. In a cloud environment, all internal traffic should be encrypted in transit. We disable port 6379 (unencrypted) and force port 6380 (TLS). Our microservices connect with `REDIS_TLS=true`.

**volatile-lru eviction policy:** When Redis memory is full, it needs to evict (delete) some keys to make room. `volatile-lru` evicts the least recently used keys that have an expiration time (TTL) set. This is perfect for a session cache — temporary session data (with TTL) gets evicted before any permanent data without TTL.

---

## 15. Module 5 — Key Vault

Key Vault is Azure's secrets manager. All sensitive credentials (database passwords, connection strings, API keys) are stored here, not in environment variables or Kubernetes Secrets.

### What It Creates

```
Key Vault: kv-azureshop-6a6c-dev   (name uses first 4 chars of subscription ID for uniqueness)
├── Role Assignment: Terraform executor → Key Vault Secrets Officer
├── Role Assignment: AKS kubelet identity → Key Vault Secrets User
├── Role Assignment: Azure DevOps SP → Key Vault Secrets Officer
└── Secrets:
    ├── sql-server-fqdn
    ├── sql-admin-username
    ├── sql-admin-password
    ├── cosmos-endpoint
    ├── cosmos-primary-key
    ├── redis-hostname
    ├── redis-ssl-port
    └── redis-primary-access-key
```

### RBAC Authorization vs Access Policies

Azure Key Vault has two access control models:

```
Legacy: Access Policies
  → Configured directly on the vault
  → Separate from Azure RBAC
  → Cannot be managed through Azure Policy
  → Harder to audit

Modern: RBAC Authorization (what we use)
  rbac_authorization_enabled = true
  → Uses standard Azure RBAC roles
  → Same system as all other Azure resources
  → Auditable via Azure Monitor
  → Manageable via Azure Policy
```

Always use RBAC authorization for new Key Vaults. Access Policies are legacy.

### The Two Key Vault Roles

```
Key Vault Secrets User   → Read secrets only
  Used by: AKS pods (via CSI Driver) to read DB passwords at runtime

Key Vault Secrets Officer → Read + Write + Delete secrets
  Used by: Terraform (to create secrets during apply)
            Azure DevOps pipelines (to update secrets during deployment)
```

### Naming: Why kv-azureshop-6a6c-dev?

Key Vault names must be globally unique across all Azure subscriptions. To guarantee uniqueness without a random suffix, we take the first 4 characters of the subscription ID (`6a6c`):

```hcl
name = "kv-${var.project}-${substr(data.azurerm_client_config.current.subscription_id, 0, 4)}-${var.environment}"
# = "kv-azureshop-6a6c-dev"
```

### Soft Delete and Purge Protection

```hcl
soft_delete_retention_days = 90
purge_protection_enabled   = true
```

**Soft delete:** When you delete a Key Vault or a secret, it is not immediately gone. It enters a soft-deleted state for 90 days. During this period it can be recovered. This protects against accidental deletion.

**Purge protection:** Even during the soft-delete period, nobody can permanently purge (hard-delete) the vault — not even an administrator. The vault must expire naturally after 90 days. This prevents attackers (or a rogue admin) from permanently destroying the vault and its secrets.

### The depends_on Pattern for Secrets

```hcl
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
}
```

Azure RBAC role assignments take a few seconds to propagate after creation. Without `depends_on`, Terraform might try to write the secret immediately after creating the role assignment — before Azure has actually activated the permission. The result: `403 Forbidden`.

`depends_on` tells Terraform: do not attempt to write this secret until the role assignment resource is in `Succeeded` state. This adds a small wait but prevents a frustrating intermittent failure.

---

## 16. Module 6 — Application Gateway and WAF

The Application Gateway is the entry point for all traffic into the AzureShop application from the internet. It sits in front of AKS and handles SSL termination, load balancing, and — most importantly — web application firewall protection.

### What It Creates

```
WAF Policy: waf-policy-azureshop-dev
  └── OWASP 3.2 Core Rule Set
  └── Microsoft Bot Manager Rule Set 1.0
  └── Mode: Prevention

Application Gateway: appgw-azureshop-dev (WAF_v2 SKU)
└── Public IP: pip-appgw-azureshop-dev (static, Standard SKU)
└── Backend pool → AKS Ingress Controller IP (populated in Phase 6)
└── Listeners: HTTP on port 80
└── Routing: HTTP → AKS backend
```

### Why WAF_v2 SKU?

WAF_v2 (Web Application Firewall version 2) includes:
- Built-in WAF engine (no separate resource needed for the engine)
- Autoscaling (scales automatically based on traffic)
- Zone redundancy
- Faster processing than v1

### OWASP Core Rule Set

OWASP (Open Web Application Security Project) publishes a standard set of firewall rules that protect against the most common web attacks. We use version 3.2:

```
SQL Injection:     SELECT * FROM users WHERE id=1 OR '1'='1'  ← BLOCKED
XSS:              <script>document.cookie</script>             ← BLOCKED
Command Injection: ; rm -rf /                                  ← BLOCKED
Path Traversal:   ../../etc/passwd                             ← BLOCKED
```

### Prevention vs Detection Mode

```hcl
policy_settings {
  mode = var.waf_mode   # "Prevention" or "Detection"
}
```

**Detection mode:** WAF inspects all traffic and logs matches, but allows everything through. No requests are blocked. Use when first enabling WAF — lets you see what would be blocked without affecting users.

**Prevention mode:** WAF actively blocks matched requests and returns HTTP 403 to the client. Use in production. We use Prevention for all our environments.

### SSL Termination

The Application Gateway terminates SSL. This means:
- The client connects to AppGW over HTTPS (encrypted)
- AppGW decrypts the traffic
- AppGW forwards to AKS over HTTP internally (inside the trusted VNet)

The benefit: AKS does not need to manage SSL certificates. Certificate management happens at the AppGW level only. In Phase 6 (Step 6.5), we add a real certificate from Azure Key Vault.

### The WAF Policy Separation Pattern

Azure Application Gateway WAF v2 requires the WAF policy to be a separate resource:

```hcl
# Separate resource (NOT embedded in appgw)
resource "azurerm_web_application_firewall_policy" "main" {
  ...
}

resource "azurerm_application_gateway" "main" {
  firewall_policy_id = azurerm_web_application_firewall_policy.main.id
}
```

This allows the same WAF policy to be shared across multiple Application Gateways, and allows the policy to be updated independently without modifying the gateway resource.

---

## 17. Module 7 — Monitoring

Monitoring is not optional in production. Without it, you cannot answer: "Is the app healthy? How fast are queries running? Which requests are failing?"

### What It Creates

```
Log Analytics Workspace: law-azureshop-dev
  └── Retention: 30 days (dev), 90 days (prod)

Application Insights (×8 — one per microservice):
  ├── appi-user-service-dev
  ├── appi-product-service-dev
  ├── appi-cart-service-dev
  ├── appi-order-service-dev
  ├── appi-payment-service-dev
  ├── appi-notification-service-dev
  ├── appi-frontend-dev
  └── appi-api-gateway-dev

Azure Managed Grafana: grafana-azureshop-dev
Role Assignment: Grafana → Monitoring Reader on resource group
```

### Log Analytics Workspace

Log Analytics is the central store for all logs and metrics. Everything flows into it:
- AKS control plane logs (from the diagnostic setting in main.tf)
- Container logs from AKS nodes
- Application Insights telemetry
- Azure resource metrics

Once in Log Analytics, you query with KQL (Kusto Query Language):

```kusto
// Find all errors in the last hour
ContainerLog
| where TimeGenerated > ago(1h)
| where LogEntry contains "ERROR"
| project TimeGenerated, ContainerName, LogEntry
| order by TimeGenerated desc
```

### for_each — Creating 8 App Insights from One Block

This is one of Terraform's most powerful patterns:

```hcl
variable "services" {
  default = [
    "frontend", "api-gateway", "user-service", "product-service",
    "cart-service", "order-service", "payment-service", "notification-service"
  ]
}

resource "azurerm_application_insights" "services" {
  for_each = toset(var.services)   # Convert list to set

  name             = "appi-${each.key}-${var.environment}"
  application_type = each.key == "product-service" ? "other" : "web"
}
```

`for_each = toset(var.services)` creates one resource for each item. `each.key` is the current item's value (`"user-service"`, `"product-service"`, etc.). `toset()` converts the list to a set — sets have no duplicates and are sorted consistently, which makes the Terraform state predictable.

Terraform tracks each instance separately in state:
```
azurerm_application_insights.services["user-service"]
azurerm_application_insights.services["product-service"]
...
```

If you remove `"notification-service"` from the list, only that one App Insights is destroyed — the other 7 are untouched.

### Azure Managed Grafana

Grafana is the industry-standard tool for dashboards and visualization. Azure Managed Grafana is a fully managed Grafana instance — no server to maintain, automatic updates, and native integration with Azure Monitor.

```hcl
resource "azurerm_dashboard_grafana" "main" {
  identity {
    type = "SystemAssigned"   # Grafana gets its own managed identity
  }
}

# Grant Grafana read access to all Azure metrics
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}
```

Grafana reads metrics from Azure Monitor using its managed identity. No API keys or passwords — the same pattern we use everywhere.

---

## 18. How Modules Talk to Each Other

This is the most important design pattern in our Terraform code. Modules are independent, but they need each other's outputs.

```
The flow of dependencies:

monitoring → outputs: log_analytics_workspace_id
    ↓
aks → needs: log_analytics_workspace_id (for Container Insights)
aks → outputs: kubelet_identity_object_id, addon_identity_object_id, aks_cluster_id
    ↓
networking → outputs: aks_subnet_id, appgw_subnet_id, db_subnet_id
    ↓
acr → needs: aks_kubelet_identity_object_id (to grant AcrPull)
databases → needs: aks_subnet_id (for SQL/Cosmos firewall rules)
keyvault → needs: aks_identity_id (to grant Secrets User)
           needs: SQL, Cosmos, Redis outputs (to store as secrets)
appgateway → needs: appgw_subnet_id
```

In `main.tf`, this looks like:

```hcl
module "aks" {
  subnet_id                  = module.networking.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

module "keyvault" {
  aks_identity_id       = module.aks.kubelet_identity_object_id
  sql_server_fqdn       = module.databases.sql_server_fqdn
  cosmos_primary_key    = module.databases.cosmos_primary_key
  redis_primary_access_key = module.databases.redis_primary_access_key
}
```

Terraform builds an internal dependency graph from these references. It runs independent modules in parallel (monitoring and networking have no dependencies on each other, so they create simultaneously) and waits for dependencies before creating dependent resources.

---

## 19. The Circular Dependency Problem We Solved

### The Problem

Our first instinct was to put the AKS diagnostic setting inside the monitoring module:

```
monitoring module:
  → Log Analytics Workspace
  → AKS Diagnostic Setting  ← This needs module.aks.aks_cluster_id

aks module:
  → AKS Cluster  ← This needs module.monitoring.log_analytics_workspace_id
```

Terraform detects the cycle and refuses to plan:
```
Error: Cycle: module.monitoring, module.aks
```

Module A needs output from Module B. Module B needs output from Module A. Neither can be created first.

### The Fix — Move to main.tf

The solution: remove the diagnostic setting from the monitoring module entirely. Place it in `main.tf` after both module blocks.

```hcl
# main.tf — AFTER both module blocks
resource "azurerm_monitor_diagnostic_setting" "aks" {
  target_resource_id         = module.aks.aks_cluster_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}
```

Terraform's dependency resolution:
1. Creates `module.monitoring` (Log Analytics Workspace) — no dependencies on AKS
2. Creates `module.aks` (uses `module.monitoring.log_analytics_workspace_id`) — depends on step 1
3. Creates `azurerm_monitor_diagnostic_setting.aks` (uses both outputs) — depends on steps 1 and 2

No cycle. The root `main.tf` acts as the orchestrator that can see all module outputs simultaneously.

**General rule:** When two modules have circular dependencies, the resource causing the cycle should be moved to the module that calls both of them (usually root `main.tf`).

---

## 20. Multi-Environment Strategy — Dev, Staging, Prod

### The Problem

Dev, staging, and prod need different configurations:
- Dev: 1 replica, small VMs, 30-day log retention, relaxed firewall
- Staging: 2 replicas, medium VMs, 60-day retention, strict firewall
- Prod: 3+ replicas, large VMs, 90-day retention, strict firewall, alerts

### Our Approach — Same Code, Different Values

The Terraform code in `infra/modules/` is identical for all environments. Only the values change, passed via `terraform.tfvars`:

```
infra/environments/
├── dev/
│   ├── backend.hcl          ← state goes to dev.tfstate
│   └── terraform.tfvars     ← dev-specific values
├── staging/
│   ├── backend.hcl          ← state goes to staging.tfstate
│   └── terraform.tfvars     ← staging-specific values
└── prod/
    ├── backend.hcl          ← state goes to prod.tfstate
    └── terraform.tfvars     ← prod-specific values
```

```bash
# Deploy dev
terraform init -backend-config="environments/dev/backend.hcl"
terraform apply -var-file="environments/dev/terraform.tfvars"

# Deploy staging (same code, different values)
terraform init -backend-config="environments/staging/backend.hcl" -reconfigure
terraform apply -var-file="environments/staging/terraform.tfvars"
```

This guarantees all environments come from the same tested code. No manual differences. No drift.

### Key Differences Per Environment

| Setting | Dev | Staging | Prod |
|---|---|---|---|
| log_retention_days | 30 | 60 | 90 |
| keyvault_network_default_action | Allow | Deny | Deny |
| sql_location | westus2 | eastus | eastus |
| Backend state key | dev.tfstate | staging.tfstate | prod.tfstate |

---

## 21. Key Terraform Patterns Used

### Pattern 1 — Dynamic Blocks for Optional Configuration

```hcl
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

dynamic "oms_agent" {
  for_each = var.log_analytics_workspace_id != null ? [1] : []
  content {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
```

`for_each = [1]` → create the block once (enabled).
`for_each = []` → create the block zero times (disabled).
This is the standard Terraform pattern for optional nested blocks that cannot be simply omitted.

### Pattern 2 — data Sources for Reading Existing Resources

```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  tenant_id = data.azurerm_client_config.current.tenant_id
  name      = "kv-${substr(data.azurerm_client_config.current.subscription_id, 0, 4)}-dev"
}
```

A `data` block reads an existing resource without managing it. `azurerm_client_config.current` reads the identity currently running Terraform — the subscription ID, tenant ID, and object ID of the current user or service principal.

### Pattern 3 — Locals for DRY Configuration

```hcl
locals {
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_virtual_network" "main" {
  tags = local.tags   # used everywhere
}
```

DRY = Don't Repeat Yourself. Without `locals`, you would write the tag merge logic in every resource block.

### Pattern 4 — Ternary Expressions

```hcl
application_type = each.key == "product-service" ? "other" : "web"
```

Same as a ternary in most languages: `condition ? value_if_true : value_if_false`. Product service uses Python/FastAPI, which needs `"other"`. All other services use Node.js/React, which needs `"web"`.

### Pattern 5 — terraform import for Existing Resources

When a resource exists in Azure but is not in Terraform state, use `import`:

```bash
terraform import \
  -var-file="environments/dev/terraform.tfvars" \
  module.acr.azurerm_container_registry.main \
  /subscriptions/.../resourceGroups/.../registries/acrazureshopdev
```

Terraform reads the resource from Azure and writes it into the state file. Future `plan` and `apply` operations manage it normally. We used this in Phase 6 to bring the manually-created ACR into Terraform's control.

---

## 22. Resource Naming Conventions

Consistent naming makes resources identifiable at a glance — in the Azure Portal, in logs, in alerts.

### Our Pattern

```
<resource-type-prefix>-<project>-<environment>
```

| Resource | Name | Prefix |
|---|---|---|
| Virtual Network | `vnet-azureshop-dev` | `vnet-` |
| Subnet | `subnet-aks` | `subnet-` |
| NSG | `nsg-aks-dev` | `nsg-` |
| AKS Cluster | `aks-azureshop-dev` | `aks-` |
| SQL Server | `sql-azureshop-dev` | `sql-` |
| Cosmos DB | `cosmos-azureshop-dev` | `cosmos-` |
| Redis | `redis-azureshop-dev` | `redis-` |
| Key Vault | `kv-azureshop-6a6c-dev` | `kv-` |
| App Gateway | `appgw-azureshop-dev` | `appgw-` |
| Log Analytics | `law-azureshop-dev` | `law-` |
| App Insights | `appi-user-service-dev` | `appi-` |
| Grafana | `grafana-azureshop-dev` | `grafana-` |
| Public IP | `pip-appgw-azureshop-dev` | `pip-` |
| Bastion | `bastion-azureshop-dev` | `bastion-` |
| ACR | `acrazureshopdev` | `acr` (no hyphens — Azure requirement) |

### Why Consistent Naming Matters

When you see an alert at 3 AM that says `appgw-azureshop-prod failed`, you immediately know it is the Application Gateway in production for the AzureShop project. Without conventions, you might see `gateway1` and have to investigate what it is before you can respond.

---

## 23. How to Run Terraform

### Prerequisites

```bash
# 1. Install Terraform
brew install terraform

# 2. Login to Azure
az login
az account set --subscription "6a6cb5d4-9c05-4211-b604-b4a53fed3284"

# 3. Verify the TF state storage account exists
az storage account show --name myprojectazshoptfstate --resource-group rg-azureshop-dev
```

### Full Workflow

```bash
cd /Users/anshujee/Projects/AzureShop/AzureShop/infra

# Step 1: Set sensitive variable
export TF_VAR_sql_admin_password="YourStr0ng@Password"

# Step 2: Initialize — downloads providers, connects to remote state
terraform init -backend-config="environments/dev/backend.hcl"

# Step 3: Validate — checks syntax and internal consistency
terraform validate

# Step 4: Plan — preview what will be created/changed/destroyed
terraform plan -var-file="environments/dev/terraform.tfvars"

# Step 5: Apply — make the changes
terraform apply -var-file="environments/dev/terraform.tfvars"

# Step 6 (when done): Destroy — delete all resources to stop billing
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

### Useful Commands

```bash
# See what is currently in state
terraform state list

# See details of a specific resource in state
terraform state show module.networking.azurerm_virtual_network.main

# Remove a resource from state (without deleting it in Azure)
terraform state rm module.acr.azurerm_container_registry.main

# Import an existing Azure resource into state
terraform import module.acr.azurerm_container_registry.main <azure-resource-id>

# Force-unlock state if a previous run crashed and left the lock
terraform force-unlock <lock-id>

# Format all .tf files consistently
terraform fmt -recursive

# Show all outputs
terraform output
```

---

## 24. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `Error: state blob is already locked` | Another `apply` is running, or a previous run crashed | Wait for it to finish, or `terraform force-unlock <lock-id>` |
| `Error acquiring the state lock` | Same as above | Check if a process is still running; force-unlock if it crashed |
| `Error: circular dependency detected` | Module A needs output from Module B and vice versa | Move the resource causing the cycle to `main.tf` |
| `Error: 403 Forbidden` when writing Key Vault secret | RBAC propagation not complete | Add `depends_on` pointing to the role assignment |
| `Error: resource already exists` | Resource exists in Azure but not in Terraform state | Use `terraform import` |
| `Error: storage account name already taken` | Account names must be globally unique | Use a unique suffix (subscription ID chars) |
| `Error: No value for required variable` | Variable not set and no default | Add `-var-file=` or `export TF_VAR_` before running |
| `node_count reset by Terraform` | Autoscaler changed count; Terraform reverts it | Add `lifecycle { ignore_changes = [node_count] }` |
| `Error: Key Vault name already exists` | Soft-deleted vault with same name still exists | Wait 90 days OR purge it: `az keyvault purge --name <name>` |
| `Error: sql location not available` | eastus/eastus2 restricted on free tier for SQL | Use `sql_location = "westus2"` in tfvars |

---

## 25. Interview Questions and Answers

### Infrastructure as Code

**Q: What is Infrastructure as Code and why is it important?**

A: Infrastructure as Code means managing infrastructure through machine-readable code files instead of manual processes. It is important because it makes infrastructure reproducible (same command gives same result), auditable (git history tracks every change), reviewable (code review for infra changes), and fast to recover (rebuild everything from code in minutes after a disaster). The alternative — clicking through a portal — cannot be version-controlled, cannot be reviewed, and produces environments that gradually drift from each other.

---

**Q: What is the difference between declarative and imperative IaC?**

A: **Imperative** IaC describes the steps to perform: "create a VNet, then create a subnet in it, then attach an NSG." Scripts (Bash, PowerShell) are imperative. **Declarative** IaC describes the desired end state: "I want a VNet with a subnet with an NSG attached." Terraform is declarative. You do not write the steps — Terraform figures out the order from the dependency graph. The advantage of declarative: you can run it multiple times safely (idempotent). Running an imperative script twice might try to create the same resource twice and fail.

---

### Terraform Core Concepts

**Q: What is Terraform state and why is it needed?**

A: Terraform state is a JSON file that maps your Terraform resources to real Azure resources. It stores resource IDs, attributes, and dependencies. Without state, Terraform cannot know whether a resource already exists (it would try to create it again), cannot find the resource's Azure ID to update it, and cannot determine what to delete. State is Terraform's memory of what it has created. Losing the state file means Terraform has amnesia — it can no longer manage the resources it created.

---

**Q: What problems does remote state solve?**

A: Local state (on one developer's laptop) has three problems: (1) two people cannot safely run `apply` at the same time — their state files would conflict; (2) if the laptop is lost or broken, the state is gone; (3) there is no audit trail of who ran what. Remote state in Azure Blob Storage solves all three: (1) Blob Storage provides automatic locking — only one `apply` can run at a time; (2) Blob Storage is highly durable — 11 nines of durability; (3) blob versioning keeps all previous state versions.

---

**Q: What is `terraform plan` and why should you always run it before `apply`?**

A: `terraform plan` computes and displays the diff between your desired state (`.tf` files) and the current state (state file + actual Azure resources). It shows what will be created (`+`), modified (`~`), and destroyed (`-`). Running plan before apply is a safety check — you review the planned changes and confirm there are nothing unexpected before any real changes happen. It is especially important when making changes that might destroy and re-create resources (for example, changing an immutable property like a storage account name forces Terraform to destroy and recreate it).

---

**Q: What is the `lifecycle` block in Terraform and when do you use it?**

A: The `lifecycle` block customizes how Terraform handles resource creation, update, and deletion. Common use cases: (1) `ignore_changes = [node_count]` — tells Terraform to never change this field after initial creation, used for AKS node count managed by the autoscaler; (2) `create_before_destroy = true` — creates the replacement resource before destroying the old one, important for zero-downtime; (3) `prevent_destroy = true` — makes Terraform error if anything tries to destroy this resource, used to protect production databases.

---

**Q: What is `terraform import` and when do you use it?**

A: `terraform import` brings an existing Azure resource under Terraform management by writing it into the state file. You use it when: (1) a resource was created manually (outside Terraform) and you want Terraform to manage it going forward; (2) you are migrating an existing infrastructure to Terraform management; (3) a resource was removed from state by mistake. After import, you must write the matching Terraform resource block in your `.tf` files — `import` only updates state, it does not generate code.

---

**Q: What is the difference between `count` and `for_each`?**

A: Both create multiple instances of a resource. `count` uses an integer and references instances by index: `resource["0"]`, `resource["1"]`. `for_each` uses a set or map and references by key: `resource["user-service"]`. The critical difference: if you remove item from the middle of a `count` list, all subsequent indexes shift — Terraform destroys and recreates them. With `for_each`, removing one item only destroys that one item. Always prefer `for_each` when working with a list of named resources (like our 8 Application Insights instances).

---

### Modules

**Q: What is a Terraform module and why do we use them?**

A: A Terraform module is a directory of `.tf` files that encapsulates a set of related resources. You call it from a parent using `module "name" { source = "./path" }`. We use modules to: (1) split a large configuration into manageable pieces — 7 modules instead of one 3,000-line file; (2) enforce separation of concerns — the networking module manages networking, the database module manages databases; (3) enable reuse — the same module can be called with different variables for dev, staging, and prod; (4) hide complexity — the caller only sees the module's inputs and outputs, not its internal implementation.

---

**Q: How do modules communicate with each other in Terraform?**

A: Modules communicate through outputs. A module declares `output "subnet_id" { value = azurerm_subnet.aks.id }` which exposes the subnet ID to whoever calls the module. The calling module reads it as `module.networking.aks_subnet_id`. Terraform builds a dependency graph from these references — if module B uses output from module A, Terraform knows A must be created first. You cannot pass data between sibling modules directly — only through the parent (root `main.tf`).

---

### Azure-Specific Concepts

**Q: What is the difference between SQL, Cosmos DB, and Redis, and when would you use each?**

A: **Azure SQL** is a relational database. Use it for structured data with strict consistency requirements — user accounts, financial transactions, orders. ACID transactions ensure data integrity. **Cosmos DB** is a globally distributed NoSQL document database. Use it for flexible schema data at global scale — product catalogs (each product has different attributes), user activity feeds. Choose the right consistency level (Session is best for most apps). **Redis** is an in-memory key-value store. Use it for data that needs sub-millisecond access — session tokens, caches, real-time leaderboards. Redis is not persistent by default — it is a cache, not a source of truth.

---

**Q: What is a Service Endpoint in Azure networking?**

A: A Service Endpoint is a configuration on an Azure subnet that routes traffic to specific Azure PaaS services (like Azure SQL or Cosmos DB) through the Azure backbone network instead of the public internet. It also tells the PaaS service to recognize traffic from that subnet, enabling VNet firewall rules. Without service endpoints enabled on the subnet, you cannot create a VNet rule on Azure SQL or Cosmos DB restricting access to that subnet — Azure will reject the firewall rule with a validation error.

---

**Q: What is the difference between Key Vault Access Policies and RBAC authorization?**

A: **Access Policies** are Key Vault's legacy access control model — configured directly on the vault, separate from Azure RBAC, not subject to Azure Policy, harder to audit. **RBAC authorization** (`rbac_authorization_enabled = true`) uses standard Azure roles — the same `az role assignment create` command and the same `Access Control (IAM)` blade used for all other Azure resources. RBAC is auditable through Azure Monitor, manageable through Azure Policy, and consistent with the rest of Azure's access control. Always use RBAC for new Key Vaults.

---

**Q: What is Cosmos DB partition key and why does it matter?**

A: The partition key is the field Cosmos DB uses to distribute data across physical storage partitions. Cosmos DB scales horizontally — data is spread across many servers. The partition key determines which server a document lives on. A good partition key has high cardinality (many distinct values), distributes reads and writes evenly (no hot partitions), and matches the most common query filter. A bad partition key (like a boolean field with only `true`/`false`) would put all data in two partitions, creating a bottleneck. In our project: `/categoryId` for products (queries filter by category) and `/userId` for cart (all cart operations are per-user).

---

**Q: What is soft delete and purge protection in Azure Key Vault?**

A: **Soft delete** means when you delete a Key Vault or a secret, it enters a soft-deleted state for a retention period (90 days in our config) rather than being immediately deleted. During this period it can be recovered. **Purge protection** goes further: during the soft-delete period, nobody — not even a subscription owner — can permanently delete (purge) the vault. It must expire naturally. Together they protect against: accidental deletion (soft delete allows recovery), insider threats (purge protection prevents a rogue admin from permanently destroying secrets), and ransomware (an attacker who gains access cannot permanently destroy your secrets within the retention period).

---

**Q: What is WAF and what attacks does OWASP 3.2 protect against?**

A: WAF (Web Application Firewall) inspects incoming HTTP/HTTPS requests and blocks known attack patterns before they reach the application. OWASP Core Rule Set 3.2 protects against: SQL Injection (inserting SQL code in form fields), Cross-Site Scripting/XSS (injecting JavaScript into responses), Command Injection (executing shell commands via input), Path Traversal (accessing files outside the web root using `../../`), Remote File Inclusion, and many more. We use Prevention mode in all environments — it actively blocks matched requests rather than just logging them.

---

**Q: What is the `depends_on` argument and when is it necessary?**

A: `depends_on` is an explicit dependency declaration. Terraform normally infers dependencies from resource references — if resource B uses resource A's ID, Terraform knows A must be created first. But sometimes there are non-obvious dependencies that Terraform cannot infer. For example, an Azure RBAC role assignment and a Key Vault secret: Terraform does not know that writing a secret requires the role assignment to have propagated through Azure AD. Adding `depends_on = [azurerm_role_assignment.terraform_secrets_officer]` to the secret resource tells Terraform to wait for the role assignment to be in `Succeeded` state before attempting to write the secret. Use `depends_on` sparingly — it reduces parallelism and can hide design issues.

---

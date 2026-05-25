# Phase 2 — Terraform IaC: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Terraform state, locking, variables, locals, sensitive values, NSG, ASG, Bastion, Service Endpoints, Service Principal, Managed Identity, ACR Pull Role.

---

## Table of Contents

1. [What Happens If State Gets Out of Sync?](#q1-what-happens-if-state-gets-out-of-sync)
2. [What is Terraform State Locking?](#q2-what-is-terraform-state-locking)
3. [Why is Backend Configuration Split Into Two Parts?](#q3-why-is-backend-configuration-split-into-two-parts)
4. [Variable Priority Order](#q4-variable-priority-order)
5. [What Are Terraform Locals?](#q5-what-are-terraform-locals)
6. [How Are Sensitive Variables Handled?](#q6-how-are-sensitive-variables-handled)
7. [What is the Difference Between NSG and ASG?](#q7-what-is-the-difference-between-nsg-and-asg)
8. [What is Azure Bastion?](#q8-what-is-azure-bastion)
9. [What is a Service Endpoint?](#q9-what-is-a-service-endpoint)
10. [ACR Pull Role, Service Principal and Managed Identity](#q10-acr-pull-role-service-principal-and-managed-identity)
11. [How Do You Design a High Availability Architecture?](#q11-how-do-you-design-a-high-availability-architecture)
12. [What is Azure Active Directory (Azure AD)?](#q12-what-is-azure-active-directory-azure-ad)
13. [How Are Secrets Managed — Terraform and Key Vault?](#q13-how-are-secrets-managed--terraform-and-key-vault)
14. [What is RBAC?](#q14-what-is-rbac)
15. [Difference Between for_each and for in Terraform](#q15-difference-between-for_each-and-for-in-terraform)
16. [How Does Log Analytics Work? How is it Different From Prometheus?](#q16-how-does-log-analytics-work-how-is-it-different-from-prometheus)
17. [What is lifecycle ignore_changes and Why Do We Use It on the AKS Node Pool?](#q17-what-is-lifecycle-ignore_changes-and-why-do-we-use-it-on-the-aks-node-pool)

---

## Q1. What Happens If State Gets Out of Sync?

### What is Terraform State?

Think of Terraform state like a **notebook** that Terraform keeps to remember what it has already created in Azure.

When you run `terraform apply`, Terraform:
1. Creates resources in Azure (VNet, AKS, SQL, etc.)
2. Writes down every detail about those resources into `dev.tfstate` — IDs, names, IPs, everything

Next time you run `terraform plan`, Terraform:
1. Reads its notebook (`dev.tfstate`) — "here's what I think exists"
2. Reads your `.tf` files — "here's what you want"
3. Reads actual Azure — "here's what actually exists"
4. Compares all three and shows you the difference

### What is Drift?

**Drift** = the notebook (state file) no longer matches reality (what's actually in Azure).

**Analogy:** You have a shopping list notebook where you wrote "I bought milk, eggs, bread." But someone else used the last of the milk. Your notebook still says milk is there — but reality says it's gone. Your notebook is **out of sync** with reality.

### How Does Drift Happen?

| Scenario | What Happened |
|---|---|
| Someone deleted a resource manually in Azure Portal | State says it exists, Azure says it doesn't |
| Someone created a resource manually in Azure Portal | State doesn't know about it, Azure has it |
| Someone changed a setting manually (e.g., VM size in Portal) | State says B2s, Azure says B4ms |
| `terraform destroy` was interrupted mid-way | Some resources deleted, some not — state is half-updated |
| Two people ran `terraform apply` at the same time | State got corrupted or partially written |

### What Symptoms Do You See?

**"Resource already exists" error:**
```
Error: A resource with the ID "/subscriptions/.../aks-azureshop-dev" already exists
```

**"Resource not found" error:**
```
Error: retrieving AKS Cluster: cluster not found
```

**Plan shows unexpected changes:**
```
~ resource "azurerm_kubernetes_cluster" "aks" {
  ~ node_count = 2 -> 1   # someone manually scaled down
}
```

### How to Detect Drift

```bash
terraform plan -refresh-only
```

The `-refresh-only` flag tells Terraform: "Don't plan any changes — just check if reality matches the state and show me the differences." This does NOT make any changes.

### How to Fix Drift — Step by Step

**Fix 1 — Azure was changed manually, keep those changes:**
```bash
terraform plan -refresh-only     # see what drifted
terraform apply -refresh-only    # update state to match Azure (no Azure changes made)
```

**Fix 2 — Resource deleted from Azure, remove from state:**
```bash
terraform state list             # find the resource address
terraform state rm azurerm_kubernetes_cluster.aks  # remove from state
# Next terraform apply will recreate it
```

**Fix 3 — Resource created manually in Azure, add to state:**
```bash
# Get the full Azure resource ID
az acr show --name acrazureshopdev --query id -o tsv

# Import it into Terraform state
terraform import azurerm_container_registry.acr /subscriptions/6a6cb5d4.../resourceGroups/rg-azureshop-dev/providers/Microsoft.ContainerRegistry/registries/acrazureshopdev
```

**Fix 4 — Total state corruption (nuclear option):**
Delete state file + re-import every resource, or destroy everything and run `terraform apply` from scratch.

### Summary

| Situation | Fix Command |
|---|---|
| Azure was changed manually, keep those changes | `terraform apply -refresh-only` |
| Resource deleted from Azure, remove from state | `terraform state rm <address>` |
| Resource created manually in Azure, add to state | `terraform import <address> <azure-id>` |
| Want to see what drifted without changing anything | `terraform plan -refresh-only` |
| State totally broken | Delete state + re-import or destroy + re-apply |

**Key rule:** Terraform's state is its memory. If the memory doesn't match reality, Terraform will try to make reality match the memory — which can cause unexpected deletions or recreations. Always check with `terraform plan` before applying.

---

## Q2. What is Terraform State Locking?

### The Problem

Your `dev.tfstate` file is stored in Azure Blob Storage — accessible to everyone on the team and to CI/CD pipelines.

If two people run `terraform apply` at the same time, both read the same state, both write changes back. Result: **state file gets corrupted** — resources created twice, half-created, or state ends up with conflicting data. This is called a **race condition**.

**State Locking = putting a padlock on the state file while someone is using it.**

### How It Works

When Person A runs `terraform apply`:
1. Terraform puts a lock on the state file — "I'm using this, nobody else can touch it"
2. If Person B tries to run `terraform apply` at the same time, they get:
```
Error: Error acquiring the state lock

Lock Info:
  ID: 12345-abcd-...
  Who: person-a@company.com
  Operation: apply
  Created: 2026-05-13 10:00:00
```
3. Person B must wait until Person A is done and the lock is released

### How Azure Implements State Locking

Azure uses **Blob Lease** — like a library book checkout system. When Terraform starts, it requests a 60-second lease on the `.tfstate` blob in Azure Storage. Azure grants it. Terraform auto-renews every 60 seconds while running. Any other Terraform command trying to touch that blob gets "Blob is leased — cannot modify."

**Setup in our project (automatic with `backend "azurerm"`):**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-azureshop-dev"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}
```

By using `backend "azurerm"`, state locking is enabled automatically — no extra configuration needed.

### What If the Lock Gets Stuck?

If Terraform crashes mid-apply (like what happened in our project when the destroy process was killed), the lease may not be released. You'll see:
```
Error: Error acquiring the state lock
Lock Info:
  ID: abc-123-def
```

**Force-unlock:**
```bash
terraform force-unlock abc-123-def
```

> **Warning:** Only do this when you are 100% sure no other apply is actually running. Force-unlocking during an active apply WILL corrupt the state.

### Summary

| Concept | Explanation |
|---|---|
| State Lock | Padlock on state file — only one apply runs at a time |
| Why needed | Prevents two applies corrupting the state simultaneously |
| How Azure does it | Blob Lease on the `.tfstate` file in Storage Account |
| Auto-renews | Every 60 seconds while apply is running |
| Released | Automatically when apply finishes |
| Stuck lock | Use `terraform force-unlock <lock-id>` — only when safe |

---

## Q3. Why is Backend Configuration Split Into Two Parts?

### The Two Parts

**Part 1 — `infra/backend.tf` (Static — same for ALL environments):**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-azureshop-dev"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    # key is NOT here — intentionally missing
  }
}
```

**Part 2 — `infra/environments/dev/backend.hcl` (Dynamic — different per environment):**
```hcl
key = "dev.tfstate"     # dev
key = "staging.tfstate" # staging
key = "prod.tfstate"    # prod
```

### Why Split?

If you hardcoded `key = "dev.tfstate"` directly in `backend.tf`, you'd have to **edit the code file** every time you switch environments. That's dangerous — you could accidentally commit the wrong key and mess up the wrong environment's state.

Instead, you pass the key at `terraform init` time:
```bash
terraform init -backend-config="environments/dev/backend.hcl"
terraform init -backend-config="environments/staging/backend.hcl" -reconfigure
```

The code file (`backend.tf`) never changes. Only the command changes.

### The Result — Three Completely Isolated State Files

```
Azure Blob Storage → tfstate container
├── dev.tfstate       ← ONLY dev resources tracked here
├── staging.tfstate   ← ONLY staging resources tracked here
└── prod.tfstate      ← ONLY prod resources tracked here
```

**Critical safety guarantee:** Running `terraform destroy` for dev reads `dev.tfstate` and destroys only dev resources. It has zero knowledge of staging or prod.

### Analogy

Think of the storage account as a **filing cabinet** and the container as a **drawer**:
- `backend.tf` says: "My files are in the blue filing cabinet, second drawer"
- `backend.hcl` says: "The specific folder inside that drawer is called dev"

When you switch to staging, you don't buy a new cabinet. You just look in a different folder.

### Summary

| Part | File | What It Contains | Changes? |
|---|---|---|---|
| Part 1 | `backend.tf` | Storage account + container location | Never — same for all envs |
| Part 2 | `environments/*/backend.hcl` | The `key` = which state file to use | Yes — different per env |
| Why split | Safety | Prevents hardcoding wrong env's state file | Destroying dev never touches staging/prod |

---

## Q4. Variable Priority Order

### The Four Levels (Lowest to Highest)

**Level 1 — Default value in variable block (Lowest Priority):**
```hcl
variable "environment" {
  type    = string
  default = "dev"   # fallback — used when nobody provides a value
}
```
Good for values that are almost always the same. Like a pre-filled form field.

**Level 2 — Environment variable `TF_VAR_` (Second Priority):**
```bash
export TF_VAR_environment=staging
terraform plan   # Terraform sees environment = "staging"
```
Perfect for CI/CD pipelines. Set it once in the pipeline environment — every Terraform command picks it up automatically. In our Azure DevOps pipelines:
```yaml
env:
  TF_VAR_sql_admin_password: $(SQL_ADMIN_PASSWORD)  # from Variable Group
```

**Level 3 — `.tfvars` file (Third Priority):**
```hcl
# environments/dev/terraform.tfvars
environment    = "dev"
aks_node_count = 2
sql_sku        = "Basic"
```
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```
Standard way to handle multiple environments. Each environment gets its own `.tfvars` file. Same Terraform code, different values.

**Level 4 — Command line `-var=` (Highest Priority — always wins):**
```bash
terraform apply -var-file="environments/dev/terraform.tfvars" -var="aks_node_count=5"
# .tfvars says 2, -var says 5 → 5 wins
```
For one-off overrides. Temporary change without editing any file.

### Priority in Action

```
default (2) → TF_VAR_ (4) → .tfvars (6) → -var (8)
                                              ↑ WINS
```

### Why Different Approaches?

| Approach | Solves This Problem | Used By |
|---|---|---|
| `default` in block | Don't want to force people to always specify this | Developer writing the module |
| `TF_VAR_` env var | Set values automatically in a pipeline session | CI/CD pipeline, shell scripts |
| `.tfvars` file | Different configs for dev/staging/prod in version control | Team |
| `-var=` flag | Quick one-time override without editing files | Developer testing locally |

**Rule:** More specific = higher priority.

---

## Q5. What Are Terraform Locals?

### Variables vs Locals

| | Variables | Locals |
|---|---|---|
| Value comes from | Outside — user, pipeline, .tfvars | Inside — computed in the config |
| Can be overridden | Yes — by -var, TF_VAR_, .tfvars | No — nobody can set from outside |
| Purpose | Accept input | Compute reusable expressions |

**Analogy:**
- Variable = a form field someone fills in
- Local = a formula in a spreadsheet that calculates based on other cells

### Why We Need Locals

Without locals — repeat the naming pattern everywhere:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-${var.project}-${var.environment}"  # repeated
}
resource "azurerm_sql_server" "sql" {
  name = "sql-${var.project}-${var.environment}"  # repeated in 50 places
}
```

With locals — define once, use everywhere:
```hcl
locals {
  name_suffix = "${var.project}-${var.environment}"  # "azureshop-dev"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-${local.name_suffix}"   # clean
}
resource "azurerm_sql_server" "sql" {
  name = "sql-${local.name_suffix}"   # clean
}
```

Change `name_suffix` in one place — all 50 resources update automatically.

### Real Examples From AzureShop

**Name suffix:**
```hcl
locals {
  name_suffix = "${var.project}-${var.environment}"
  # result: "azureshop-dev"
}
```

**Common tags (applied to every resource):**
```hcl
locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

**Conditional logic:**
```hcl
locals {
  aks_node_count = var.environment == "prod" ? 3 : 1
  storage_sku    = var.environment == "prod" ? "Premium_LRS" : "Standard_LRS"
}
```

**Locals can reference other locals:**
```hcl
locals {
  name_suffix   = "${var.project}-${var.environment}"
  aks_name      = "aks-${local.name_suffix}"
  keyvault_name = "kv-${local.name_suffix}"
}
```

### What Locals CANNOT Do

- Cannot be passed from outside (`-local=` does not exist)
- Cannot reference variables that don't exist

### Summary

| Concept | Explanation |
|---|---|
| What locals are | Computed values inside config — not settable from outside |
| Why use them | Avoid repeating the same expression in 50 places |
| Common uses | Name suffixes, common tags, conditional logic, derived values |
| Keyword | `local.name` (singular) to reference, `locals {}` (plural) to define |

---

## Q6. How Are Sensitive Variables Handled?

### The Golden Rule

**A secret that touches a file or a log is no longer a secret.**

### In AzureShop Project

**Step 1 — Mark as sensitive in variables.tf:**
```hcl
variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true   # Terraform prints (sensitive value) instead of actual value
}
```

Without `sensitive = true`, `terraform plan` prints:
```
+ sql_admin_password = "MyP@ssword123!"   # DANGEROUS
```
With `sensitive = true`:
```
+ sql_admin_password = (sensitive value)  # SAFE
```

**Step 2 — Never put it in .tfvars:**

`dev/terraform.tfvars` has a comment but no value:
```hcl
# Before running, set sensitive variables via environment variables:
#   export TF_VAR_sql_admin_password="YourStr0ng@Password"
```

**Step 3 — Locally, use environment variable:**
```bash
export TF_VAR_sql_admin_password="YourStr0ng@Password"
terraform apply -var-file="environments/dev/terraform.tfvars"
# Password lives only in shell memory — never written to disk
```

**Step 4 — In CI/CD pipeline, use Azure DevOps Variable Group:**
```yaml
# pipelines/cd/terraform-apply.yaml
env:
  TF_VAR_sql_admin_password: $(TF_VAR_SQL_ADMIN_PASSWORD)  # from Variable Group
```

In Azure DevOps, when a variable is marked as secret:
- Encrypted at rest
- Masked in all pipeline logs (shown as `***`)
- Cannot be read back through the UI after saving
- Only the pipeline agent can access it at runtime

### The Full Journey of the Password

```
Developer sets it      Pipeline Variable Group    Pipeline env var    Terraform      Azure SQL
(export TF_VAR_...)    (encrypted, masked)        (TF_VAR_...)        (sensitive)    (created)

NEVER in: Git / Azure Repos, .tfvars files, pipeline logs, terraform plan output
```

### In Real Companies

| Approach | Used By | Security Level |
|---|---|---|
| `sensitive = true` | Terraform | Masks in logs/plan output |
| TF_VAR_ env var | Local dev | Never written to disk |
| ADO Variable Group (secret) | CI/CD pipelines | Encrypted, masked in logs |
| HashiCorp Vault | Large enterprise | Encrypted, audited, auto-rotating |
| Azure Key Vault + Managed Identity | Azure-native teams | No password needed at all |
| SOPS | GitOps teams | Encrypted secrets committed to Git |

---

## Q7. What is the Difference Between NSG and ASG?

### The Big Picture

When you create resources in Azure, by default everything can talk to everything. NSG and ASG are firewalls that control who can talk to what, on which port, using which protocol.

**Analogy:** Azure VNet = an office building. NSG = bouncer at the entrance of a neighbourhood (subnet). ASG = staff badge that identifies who someone is.

### NSG — Network Security Group

An NSG is a **firewall attached to a subnet or NIC**. It contains allow/deny rules.

**Every rule has 6 parts:**

| Priority | Direction | Protocol | Source | Destination | Port | Action |
|---|---|---|---|---|---|---|
| 100 | Inbound | TCP | Internet | * | 443 | Allow |
| 200 | Inbound | TCP | 10.0.1.0/24 | * | 1433 | Allow |
| 4096 | Inbound | * | * | * | * | Deny |

- **Lower number = checked first** — first matching rule wins
- **4096 = deny-all fallback** — always last

### NSGs in AzureShop

4 NSGs — one per subnet:

**NSG for AKS subnet:**
```
Rule 100:  Allow HTTPS (443) inbound from anywhere    → AKS API server
Rule 200:  Allow all traffic within VNet              → pod-to-pod communication
Rule 300:  Allow Azure Load Balancer probes           → health checks
Rule 4096: DENY everything else inbound               → nothing else gets in
```

**NSG for Database subnet:**
```
Rule 100:  Allow SQL (1433) ONLY from AKS subnet      → only AKS reaches SQL
Rule 200:  Allow Redis (6380) ONLY from AKS subnet    → only AKS reaches Redis
Rule 300:  Allow HTTPS (443) ONLY from AKS subnet     → only AKS reaches Cosmos DB
Rule 4096: DENY everything else                       → internet CANNOT reach databases
```

The database subnet is completely invisible to the internet — even if an attacker finds the SQL server's IP, NSG blocks them at the network level.

### ASG — Application Security Group

ASG is a **logical tag/label** attached to resources. It lets you write NSG rules using group names instead of IP addresses.

**The problem ASG solves:**

Without ASG — rules use IP addresses:
```
Allow TCP from 10.0.1.5 to port 1433   # backend VM 1
Allow TCP from 10.0.1.6 to port 1433   # backend VM 2
Allow TCP from 10.0.1.7 to port 1433   # backend VM 3
# 10 VMs = 10 rules. IPs change. Unreadable.
```

With ASG:
```
ASG "backend-servers" ← attach to VM1, VM2, VM3
ASG "database-servers" ← attach to SQL, Redis

# ONE readable rule:
Allow TCP from ASG:backend-servers to ASG:database-servers on port 1433
```

Add VM4 to `backend-servers` ASG → it automatically gets access. No new rule needed.

### NSG vs ASG

| Feature | NSG | ASG |
|---|---|---|
| What it is | Firewall rule set | Logical grouping label |
| Attached to | Subnet or NIC | Individual resources |
| Contains | Allow/Deny rules | Nothing — just a label |
| Works alone? | Yes | No — only works inside NSG rules |
| In AzureShop | ✅ 4 NSGs (one per subnet) | ❌ Not used (PaaS services, not VMs) |

**Why no ASG in AzureShop?** Our resources are PaaS services (AKS, Azure SQL, Redis, Cosmos DB) — not individual VMs. ASGs are designed for VM NICs. Subnet-level NSGs with CIDR ranges are the right tool here.

---

## Q8. What is Azure Bastion?

### The Problem

To connect to a VM inside your Azure VNet (to debug, run commands, check logs), old options were:

**Option 1 — Give the VM a Public IP:**
- VM directly exposed to internet
- Port 22 (SSH) open to the entire world
- Bots constantly scan for open SSH ports and brute force passwords

**Option 2 — Set up a VPN:**
- Complex to set up and maintain
- VPN gateway costs money 24/7
- Every developer needs VPN client software

**Azure Bastion solves both problems** — no public IP on VMs, no VPN needed.

### What is Azure Bastion?

A **managed jump server** inside your VNet. You connect to it via browser (HTTPS 443), it connects to your VM via SSH/RDP — your laptop never directly touches the VM.

**Analogy:** Your VNet = a secure government building. VMs = offices with no public entrance. Bastion = reception desk at the front door. Visitors come to reception (HTTPS), reception verifies identity (Azure AD), reception escorts you to the office (VM) you need.

### How Bastion Works — Step by Step

```
1. Open Azure Portal in browser (no VPN, no SSH client)
2. Navigate to VM → Connect → Bastion
3. Browser connects to Bastion's Public IP over HTTPS (port 443)
4. Azure authenticates you using Azure AD identity
5. Bastion opens SSH/RDP to your VM's PRIVATE IP (inside VNet)
6. Terminal appears in your browser tab
7. Traffic: Browser ←→ HTTPS ←→ Bastion ←→ SSH/RDP ←→ VM
```

### Network Traffic Flow

```
            INTERNET
               │ HTTPS:443
          ┌────▼─────┐
          │  Bastion │ ← has Public IP, lives in AzureBastionSubnet
          └────┬─────┘
               │ VNet (private)
    ┌──────────┼──────────┐
    │SSH:22    │          │RDP:3389
    ▼          ▼          ▼
Linux VM   AKS Node  Windows VM
(NO public IP)  (NO public IP)  (NO public IP)
```

### Our AzureShop Bastion Setup

**Special subnet name — hard requirement:**
```hcl
resource "azurerm_subnet" "bastion" {
  name = "AzureBastionSubnet"  # MUST be exactly this — capital A, B, S
  # Must be /26 or larger
}
```

**NSG Rules:**

Inbound:
- Rule 100: Allow HTTPS (443) from Internet → you connecting via browser
- Rule 200: Allow 443 from GatewayManager → Azure's internal control plane

Outbound:
- Rule 100: Allow SSH (22) to VirtualNetwork → Bastion → Linux VMs
- Rule 200: Allow RDP (3389) to VirtualNetwork → Bastion → Windows VMs
- Rule 300: Allow HTTPS (443) to AzureCloud → Bastion calls Azure APIs

**Public IP requirements:**
```hcl
resource "azurerm_public_ip" "bastion" {
  allocation_method = "Static"   # IP never changes
  sku               = "Standard" # Basic SKU does NOT support Bastion
}
```

### Why We Use Bastion in AzureShop

AKS nodes are in a private subnet with no public IPs. If a node has issues, we need a way in. Without Bastion we'd have to give nodes public IPs (security risk) or set up VPN (complex). With Bastion: browser → Azure Portal → AKS node → Connect → done.

### Bastion vs Jump VM

| | Azure Bastion | Jump VM |
|---|---|---|
| Management | Fully managed by Microsoft | You manage OS, patches |
| Access method | Browser (HTTPS 443) | SSH client required |
| Cost | ~$140/month (Basic SKU) | ~$15/month (small VM) |
| Security | Azure AD auth, no keys needed | You manage SSH keys |
| Open ports on VMs | None | Port 22 open to jump VM IP |

---

## Q9. What is a Service Endpoint?

### The Problem

Azure services like SQL Server, Cosmos DB, Storage live on the Azure backbone but have **public endpoints** (accessible from anywhere on the internet).

Default traffic path:
```
AKS Pod → leaves VNet → internet → Cosmos DB public endpoint
```

Problems:
1. Traffic leaves your private VNet and travels over public internet
2. Cosmos DB sees source IP as your NAT gateway's public IP — cannot identify your specific subnet, so VNet firewall rules cannot work

### What is a Service Endpoint?

A **direct private route from your subnet to a specific Azure service**, staying entirely within the Azure backbone — never touching the public internet.

**Analogy:**
- Without endpoint: Go outside through public streets to reach the government building
- With endpoint: Private corridor built directly between your office and the government building — you never go outside

### How It Works

**Step 1 — Enable on the subnet:**
```hcl
resource "azurerm_subnet" "aks" {
  service_endpoints = [
    "Microsoft.AzureCosmosDB",
    "Microsoft.Sql"
  ]
}
```

Azure automatically:
1. Adds a route: CosmosDB public IP range → Azure backbone (not internet)
2. Gives the subnet a **service endpoint identity token** — proof of "I am subnet 10.0.1.0/24 in vnet-azureshop-dev"

**Step 2 — Configure VNet rule on the service:**
```hcl
resource "azurerm_cosmosdb_account" "main" {
  virtual_network_rule {
    id = var.aks_subnet_id   # only this subnet can access
  }
  is_virtual_network_filter_enabled = true
  public_network_access_enabled     = false  # internet blocked completely
}
```

### What Happens at Traffic Time

**Before Service Endpoint:**
```
AKS Pod → internet → Cosmos DB
Cosmos DB sees: 52.x.x.x (NAT gateway IP) → cannot match VNet rule
```

**After Service Endpoint:**
```
AKS Pod → Azure backbone → Cosmos DB
Cosmos DB sees: 10.0.1.5 + subnet identity token → matches VNet rule → allowed
```

### Two Things Service Endpoint Does Together

1. **Routing change** — traffic stays on Azure backbone, never hits internet
2. **Identity injection** — subnet sends identity token so service can verify "this came from my AKS subnet"

### Our AzureShop Setup

```
subnet-aks (10.0.1.0/24)
  service_endpoints: Microsoft.Sql, Microsoft.AzureCosmosDB

Result:
- AKS → SQL Server:   private Azure backbone route ✅
- AKS → Cosmos DB:    private Azure backbone route ✅
- Internet → SQL:     BLOCKED (public_network_access_enabled = false) ✅
- Internet → Cosmos:  BLOCKED ✅
```

Without the service endpoint on the subnet, the VNet rule on Cosmos DB is rejected by Azure with:
```
Error: Subnet subnet-aks does not have service endpoint Microsoft.AzureCosmosDB enabled
```

### Service Endpoint vs Private Endpoint

| | Service Endpoint | Private Endpoint |
|---|---|---|
| Service still has public IP? | Yes | No — private IP only |
| Traffic path | VNet → backbone → service's public IP | VNet → private IP directly |
| Cost | Free | ~$7/month per endpoint |
| DNS change needed? | No | Yes — private DNS zone required |
| Security level | High | Highest |
| Used in AzureShop? | ✅ Yes | ❌ No |

---

## Q10. ACR Pull Role, Service Principal and Managed Identity

### The Core Problem — Authentication for Automated Processes

Every time something accesses an Azure resource, Azure asks: **"Who are you, and are you allowed to do this?"**

A human logs in with username + password. But automated processes — pipelines, AKS pods, CSI drivers — can't type a password. Azure has two solutions.

### Service Principal — "An App's Identity"

A Service Principal is like a **user account for an application** — not a human, but a piece of software.

- Has an **App ID (Client ID)** — like a username
- Has a **Client Secret or Certificate** — like a password
- Has permissions assigned via Azure RBAC roles

**Analogy:** A delivery driver who gets a temporary access badge — "Can enter the loading dock only." That badge = Service Principal.

**How it works:**
```
Application → "I am App ID: abc123, my secret: xyz789" → Azure AD
Azure AD → verifies credentials → issues access token
Application → sends token to Azure resource → access granted
```

**The problem:** You must manage the secret — rotate it before expiry, store it securely, risk of leaking.

### Managed Identity — "Azure Manages the Identity For You"

An identity that **Azure automatically creates, manages, and rotates**. No password, no secret, no certificate.

**Analogy:** Instead of a temporary badge, hire the person as a full employee. HR (Azure AD) automatically manages their access — creates badge, renews it, revokes when they leave.

**How it works:**
```
AKS Cluster → "I am AKS cluster aks-azureshop-dev" (no password — Azure AD trusts me because I live in Azure)
Azure AD → issues token (auto-renewed)
AKS Cluster → sends token to ACR → access granted
```

**Two types:**

| | System-Assigned | User-Assigned |
|---|---|---|
| Created | Automatically when resource is created | Manually, independently |
| Lifecycle | Deleted when resource is deleted | Survives resource deletion |
| Shared? | One resource only | Can attach to multiple resources |

### When to Use Which

| Situation | Use |
|---|---|
| Pipeline agent (temporary, not a permanent Azure resource) | Service Principal |
| Terraform running from your laptop | Service Principal |
| AKS cluster managing Azure resources | Managed Identity (System-Assigned) |
| AKS pods pulling images from ACR | Managed Identity (Kubelet) |
| AKS pods reading secrets from Key Vault | Managed Identity (CSI addon) |
| Grafana querying Azure Monitor | Managed Identity (System-Assigned) |

**Rule of thumb:** Permanent Azure resource → Managed Identity. External or temporary → Service Principal.

### ACR Pull Role — How It Works

```hcl
# infra/modules/acr/main.tf
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = var.aks_kubelet_identity_object_id  # Managed Identity
  role_definition_name = "AcrPull"                           # read-only pull
  scope                = azurerm_container_registry.main.id
}
```

`AcrPull` = read-only access to pull images. Cannot push, cannot delete.

**Full image pull flow:**
```
kubectl apply deployment.yaml
    ↓
Kubernetes schedules pod to Node X
    ↓
Node's kubelet: "I need image acrazureshopdev.azurecr.io/user-service:v1.0.0"
    ↓
Kubelet uses its Managed Identity → gets token from Azure AD
    ↓
Kubelet sends token to ACR: "Give me user-service:v1.0.0"
    ↓
ACR checks: does this identity have AcrPull role? YES
    ↓
ACR sends image layers to node → pod starts running
```

No passwords. No secrets stored anywhere. Pure identity-based authentication.

**Why `admin_enabled = false` on ACR:**
```hcl
admin_enabled = false  # Disable shared username/password
```
ACR has an admin account with a shared username/password. We disable it completely — Managed Identity is the only way to authenticate.

### All Identities Used in AzureShop

| Identity | Type | What It Does | Role |
|---|---|---|---|
| `sp-azureshop-terraform` | Service Principal | Terraform + Azure Pipelines | Contributor + KV Secrets Officer |
| AKS system identity | System-Assigned MI | AKS control plane manages VNet/LB | Network Contributor |
| AKS kubelet identity | System-Assigned MI | Nodes pull images from ACR | AcrPull on ACR |
| CSI addon identity | System-Assigned MI | CSI driver reads secrets from Key Vault | Key Vault Secrets User |
| Grafana identity | System-Assigned MI | Grafana queries Azure Monitor | Monitoring Reader |

### Full Identity Map

```
AZURE DEVOPS PIPELINES
sp-azureshop-terraform (Service Principal)
Roles: Contributor + KV Secrets Officer
      │
      │ terraform apply
      ▼
 AKS Cluster
 ├── System Identity      → manages VNet/LB in Azure
 ├── Kubelet Identity     → AcrPull → pulls images from ACR (no password)
 └── CSI Addon Identity   → KV Secrets User → reads secrets from Key Vault
                                    │ mounts as files
                                    ▼
                             Pod containers
                             (get DB password, Redis key etc. as files)

Grafana (System Identity) → Monitoring Reader → reads Azure Monitor
```

### What `skip_service_principal_aad_check = true` Means

Managed Identities take a few seconds to propagate in Azure AD after creation. Without this flag, Terraform would fail trying to assign a role before the identity fully exists. This flag tells Terraform: "Skip the AAD verification check — just assign the role, trust that the identity exists."

---

## Q11. How Do You Design a High Availability Architecture?

### What is High Availability?

High Availability (HA) means the system keeps running even when individual components fail. It is measured as uptime percentage:

| Availability | Downtime per year |
|---|---|
| 99% | 3.65 days |
| 99.9% ("three nines") | 8.7 hours |
| 99.99% ("four nines") | 52 minutes |
| 99.999% ("five nines") | 5 minutes |

The goal: **eliminate single points of failure** — any one component that, if it fails, brings the whole system down.

**Core principle:** Assume everything will fail eventually. Design so that when it does, the system keeps running.

---

### Pillar 1 — Redundancy (Multiple Copies of Everything)

Never run a single instance of anything critical.

**In AzureShop — Pod replicas:**
```yaml
# helm/values/prod.yaml
replicaCount: 3       # 3 pods always running in prod
hpa:
  minReplicas: 3      # never go below 3
  maxReplicas: 10     # scale up to 10 under load

# helm/values/staging.yaml
replicaCount: 2       # basic redundancy for testing

# helm/values/dev.yaml
replicaCount: 1       # cost saving — no HA needed in dev
```

If one pod dies, 2 are still serving traffic. Kubernetes restarts the dead pod in the background. Zero user impact.

**AKS node pools:**
```hcl
node_count = var.system_node_count   # dev=1, prod=3
```

If one node dies, pods reschedule to surviving nodes automatically.

---

### Pillar 2 — Fault Domain Isolation (Availability Zones)

A single data centre is a single point of failure — power outage, flood, fire. Azure Availability Zones are **physically separate data centres** within the same region.

**AKS nodes spread across zones in prod:**
```hcl
default_node_pool {
  zones = ["1", "2", "3"]  # spread nodes across 3 data centres
  # removed in our dev setup — free tier limitation
}
```

If Zone 1 has a power failure, nodes in Zone 2 and 3 keep running. Your 3 pod replicas (one per zone) means losing any zone still leaves 2 pods serving traffic.

**Cosmos DB geo-replication:**
```hcl
resource "azurerm_cosmosdb_account" "main" {
  automatic_failover_enabled = true
  geo_location {
    location          = "eastus"   # primary
    failover_priority = 0
  }
  # prod: add secondary region
  # geo_location { location = "westus2", failover_priority = 1 }
}
```

If the entire East US region goes down, Cosmos DB automatically promotes the West US replica.

---

### Pillar 3 — Health Checks and Automatic Recovery

**Liveness and Readiness probes:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  # If fails 3 times → Kubernetes RESTARTS the pod

readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  # If fails → pod REMOVED from load balancer (no traffic sent to it)
```

- **Liveness** = "Is this pod alive?" — NO → restart it
- **Readiness** = "Is this pod ready for traffic?" — NO → remove from LB, don't kill it

**Warn-and-continue pattern (all 8 services):**
```javascript
try {
  await connectToSQL();
} catch (err) {
  console.warn("SQL unavailable — starting in degraded mode");
  // service starts anyway — prevents cascade failures
}
```

---

### Pillar 4 — Auto-Scaling

```yaml
# helm/charts/product-service/templates/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70   # scale up when CPU > 70%
```

Normal load: 3 pods. Traffic spike: CPU hits 70% → HPA adds pods up to 10. Spike over: scales back to 3. All automatic, zero human intervention.

---

### Pillar 5 — Zero-Downtime Deployments

**PodDisruptionBudget:**
```yaml
kind: PodDisruptionBudget
spec:
  minAvailable: 1   # at least 1 pod must always be running
```

Prevents all pods being evicted at once during node maintenance.

**RollingUpdate strategy:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # create 1 new pod before killing old ones
    maxUnavailable: 0  # never have fewer pods than desired count
```

At every step, at least the desired number of pods is serving traffic. Zero downtime during deployments.

---

### HA Summary Table

| Layer | HA Mechanism | AzureShop Config |
|---|---|---|
| Compute | Multiple pod replicas + HPA | prod: 3 min → 10 max |
| Node | Multi-node pools + zone spreading | system pool + user pool |
| Deployment | RollingUpdate + PDB | maxUnavailable=0, minAvailable=1 |
| Database | Cosmos DB auto-failover + geo-replication | automatic_failover_enabled=true |
| Health | Liveness + readiness probes | all 8 services have /health |
| Startup | Warn-and-continue pattern | services start in degraded mode |

### Interview Answer Formula

> "HA means eliminating single points of failure. I approach it at every layer — compute, data, networking, and deployment. In AzureShop, we run 3 pod replicas in prod with HPA scaling from 3 to 10 on CPU>70%. AKS nodes spread across availability zones. Cosmos DB has automatic failover. Every service has liveness and readiness probes, and uses a warn-and-continue startup pattern so one dependency outage doesn't cascade. RollingUpdate with maxUnavailable=0 gives zero-downtime deployments."

---

## Q12. What is Azure Active Directory (Azure AD)?

### The Simplest Explanation

Azure AD (now called **Microsoft Entra ID**) is the **security guard and receptionist for everything in Azure**. Every time anything tries to access any Azure resource, Azure AD answers:

1. **Who are you?** (Authentication — verify identity)
2. **Are you allowed to do this?** (Authorization — check permissions via RBAC)

Without Azure AD, there is no security in Azure.

**Analogy:** Azure AD = HR department + security office combined. HR keeps a register of everyone. Security checks the register before letting anyone through any door. Every door in the building = an Azure resource.

---

### Traditional AD vs Azure AD

| | Traditional Active Directory | Azure Active Directory |
|---|---|---|
| Where it runs | On-premises (your own servers) | Cloud (Microsoft's servers) |
| What it manages | Windows computers, printers, file shares | Cloud apps, Azure resources, Microsoft 365 |
| Protocol | Kerberos, LDAP | OAuth 2.0, OpenID Connect, SAML |
| Internet access? | No — internal network only | Yes — designed for internet |

Traditional AD = guard for the office building's internal network. Azure AD = guard for everything in the cloud.

---

### Key Concepts

**Tenant:** Your organisation's private isolated space in Azure AD.
```
Microsoft's Azure AD (global)
├── Tenant: AzureShop (4c135936-...) ← YOUR space
│     ├── Your users
│     ├── Your Service Principals
│     ├── Your Managed Identities
│     └── Your groups and roles
└── Tenant: Other companies (completely isolated)
```

**Identity Types:**

| Identity | Example in AzureShop |
|---|---|
| User | Anshu (object ID: df0cac37-...) |
| Service Principal | sp-azureshop-terraform |
| Managed Identity | AKS kubelet identity, Grafana identity |
| Group | "DevOps Team" |

---

### Authentication vs Authorization

**Authentication** — "Who are you?"
- Human: username + password + MFA
- Service Principal: Client ID + Secret → Azure AD verifies → issues JWT token
- Managed Identity: "I am AKS node" → Azure AD trusts (no password) → issues token

**JWT Token** = a signed ticket proving identity. Valid for ~1 hour. Used for every API call instead of re-authenticating each time.

**Authorization** — "Are you allowed to do this?" (handled by RBAC — see Q14)

---

### Azure AD in AzureShop — Every Usage

**1. AKS kubectl access:**
```hcl
azure_active_directory_role_based_access_control {
  tenant_id          = data.azurerm_client_config.current.tenant_id
  azure_rbac_enabled = true
}
```
Every `kubectl` command goes through Azure AD. Only users with `Azure Kubernetes Service RBAC Cluster Admin` role can run kubectl.

**Why kubelogin?** Kubernetes normally uses its own username/password. With `azure_rbac_enabled = true`, it uses Azure AD instead. `kubelogin` bridges the gap — converts kubeconfig to use your `az login` session.

**2. Azure SQL Azure AD Admin:**
```hcl
azuread_administrator {
  login_username              = "AzureAD Admin"
  object_id                   = var.sql_admin_object_id
  azuread_authentication_only = false
}
```
You can log into SQL Server using your Azure AD identity instead of SQL username/password.

**3. Key Vault RBAC:**
```hcl
rbac_authorization_enabled = true
```
Key Vault uses Azure AD RBAC instead of its legacy Access Policies. One consistent permission system across everything.

**4. All Managed Identities** are registered in Azure AD automatically when created.

---

### Why Azure AD Instead of Passwords Everywhere?

| Problem | Azure AD Solution |
|---|---|
| Passwords can be leaked | Managed Identities have no password |
| Passwords expire and must be rotated | Tokens auto-renew |
| Different auth systems per service | One identity system for everything |
| No audit trail | Azure AD logs every authentication |
| Hard to revoke access | Disable identity in Azure AD → revoked everywhere instantly |

---

## Q13. How Are Secrets Managed — Terraform and Key Vault?

### The Golden Rule

**A secret that touches a file or a log is no longer a secret.**

### Three Stages

---

### Stage 1 — Terraform Creates Key Vault and Writes Secrets IN

**Key Vault creation:**
```hcl
resource "azurerm_key_vault" "main" {
  name                       = "kv-azureshop-6a6c-dev"
  rbac_authorization_enabled = true    # Azure AD RBAC (not legacy access policies)
  soft_delete_retention_days = 90      # secrets recoverable for 90 days after deletion
  purge_protection_enabled   = true    # even admins cannot permanently delete during 90 days

  network_acls {
    default_action = "Allow"           # dev: open; prod: "Deny" (VNet only)
    bypass         = "AzureServices"   # Azure Monitor, Pipelines always allowed
  }
}
```

**`soft_delete_retention_days = 90`** — accidental deletion lands in a recycle bin, recoverable for 90 days. This is why our Key Vault survived when we destroyed all infra — it went into soft-delete, not permanent deletion.

**Terraform grants itself write permission:**
```hcl
data "azurerm_client_config" "current" {}   # who is running terraform right now?

resource "azurerm_role_assignment" "terraform_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"   # read + write + delete
  principal_id         = data.azurerm_client_config.current.object_id
}
```

`data "azurerm_client_config" "current"` — reads whoever is authenticated. Whether you run Terraform locally (your user) or via pipeline (service principal), this picks up the right identity automatically.

**Terraform writes secrets:**
```hcl
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password    # came from TF_VAR_ env var
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.terraform_secrets_officer]
  # CRITICAL — wait for role propagation in Azure AD before writing
  # Without this: "permission denied" timing error during apply
}
```

**All 8 secrets written:**
```
Key Vault: kv-azureshop-6a6c-dev
├── sql-server-fqdn
├── sql-admin-username
├── sql-admin-password       ← came from TF_VAR_sql_admin_password
├── cosmos-endpoint
├── cosmos-primary-key
├── redis-hostname
├── redis-ssl-port
└── redis-primary-access-key
```

---

### Stage 2 — Key Vault Stores Secrets Securely

```
Encryption at rest:    Every secret encrypted by Microsoft-managed keys
Encryption in transit: HTTPS only
Access logging:        Every read/write logged in Azure Monitor
RBAC gating:          Must have correct role — anonymous access impossible
Soft delete:          90 day recovery window
Purge protection:     Cannot permanently delete during retention period
```

**Three roles on Key Vault:**

| Identity | Role | What They Can Do |
|---|---|---|
| Terraform SP | Secrets Officer | Write secrets during apply |
| Azure DevOps SP | Secrets Officer | Update secrets from pipelines |
| AKS CSI Identity | Secrets User (read-only) | Pods can only read — never write |

---

### Stage 3 — Pods Read Secrets OUT via CSI Driver

**SecretProviderClass (the bridge):**
```yaml
# k8s/secret-provider-classes/user-service.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
spec:
  provider: azure
  parameters:
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "4e3f0c0a-..."   # CSI addon Managed Identity
    keyvaultName: "kv-azureshop-6a6c-dev"
    objects: |
      array:
        - objectName: sql-server-fqdn
          objectType: secret
        - objectName: sql-admin-password
          objectType: secret
  secretObjects:
    - secretName: user-service-secrets     # creates a Kubernetes Secret
      data:
        - objectName: sql-server-fqdn
          key: SQL_SERVER                  # env var name inside pod
        - objectName: sql-admin-password
          key: SQL_PASSWORD
```

**Helm Deployment mounts it:**
```yaml
containers:
  - name: user-service
    envFrom:
      - secretRef:
          name: user-service-secrets   # all env vars from K8s Secret
    volumeMounts:
      - name: secrets-store
        mountPath: /mnt/secrets-store
        readOnly: true
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      volumeAttributes:
        secretProviderClass: user-service-secrets
```

**Complete secret journey:**
```
TF_VAR_sql_admin_password (env var, never in file)
    ↓ terraform apply
Key Vault (encrypted, RBAC-gated)
    ↓ CSI Driver (Managed Identity — no password)
Kubernetes Secret "user-service-secrets"
    ↓ envFrom
Pod environment variable SQL_PASSWORD
    ↓ process.env.SQL_PASSWORD
SQL Server connection
```

The password **never** appeared in any code file, Git commit, pipeline log, or was typed by a human after initial setup.

---

## Q14. What is RBAC?

### The Formula

```
WHO  +  WHAT ROLE  +  WHERE SCOPE  =  PERMISSION
```

**Analogy:** A hospital. Doctor = read + write patient records. Nurse = read only. Receptionist = see appointments only. Same building, different roles, different access.

---

### The Three Components

**1. Security Principal — WHO:**
User, Group, Service Principal, Managed Identity

**2. Role Definition — WHAT:**

| Role | Permissions |
|---|---|
| Owner | Everything + manage access |
| Contributor | Create/modify/delete — cannot manage access |
| Reader | View only |
| AcrPull | Pull images from ACR only |
| Key Vault Secrets User | Read secret values only |
| Key Vault Secrets Officer | Read + write + delete secrets |
| Monitoring Reader | Read metrics and logs only |
| AKS RBAC Cluster Admin | Full kubectl access |

**3. Scope — WHERE:**
```
Subscription  (everything below inherits)
    └── Resource Group
            └── Resource  (narrowest — most specific)
```

Role at subscription level = applies to ALL resources below it.
Role at one specific resource = applies only to that resource.

---

### Every RBAC Assignment in AzureShop

| Principal | Role | Scope | Why |
|---|---|---|---|
| sp-azureshop-terraform | Contributor | Subscription | Terraform creates all resources |
| sp-azureshop-terraform | Key Vault Secrets Officer | kv-azureshop-6a6c-dev | Writes secrets during apply |
| AKS kubelet identity | AcrPull | acrazureshopdev | Nodes pull Docker images |
| AKS CSI addon identity | Key Vault Secrets User | kv-azureshop-6a6c-dev | CSI reads secrets (read-only) |
| Azure DevOps SP | Key Vault Secrets Officer | kv-azureshop-6a6c-dev | Pipelines update secrets |
| Grafana identity | Monitoring Reader | Subscription | Read metrics across all resources |
| Anshu (user) | AKS RBAC Cluster Admin | aks-azureshop-dev | Run kubectl commands |

---

### Key Vault Special Rule

**Contributor does NOT give access to Key Vault secrets.** Key Vault has its own RBAC plane.
- Contributor = manage the vault resource itself (create/delete the vault)
- Key Vault Secrets Officer = read/write/delete secrets inside the vault
- Both assignments are needed separately

---

### AKS — Two Levels of RBAC

**Level 1 — Azure RBAC (who can use kubectl):**
```hcl
azure_active_directory_role_based_access_control {
  azure_rbac_enabled = true
}
```
Controls who can run `kubectl` commands at all. Managed by Azure AD.

**Level 2 — Kubernetes RBAC (what kubectl can do inside cluster):**
`Role`, `ClusterRole`, `RoleBinding`, `ClusterRoleBinding` Kubernetes objects.
Controls what Kubernetes operations are allowed inside the cluster.

---

### Principle of Least Privilege

Give minimum permission at narrowest scope:
```
❌ WRONG: AKS kubelet identity → Owner → Subscription
          (nodes could delete the entire subscription)

✅ CORRECT: AKS kubelet identity → AcrPull → specific ACR only
            (nodes can only pull from one registry)
```

---

## Q15. Difference Between for_each and for in Terraform

### One-Line Summary

| | `for_each` | `for` |
|---|---|---|
| What it does | Creates multiple Azure **resources** | Transforms a collection into a new **value** |
| Where it lives | On a resource/dynamic block | Inside a `value =` expression |
| Analogy | Photocopier — copies template per item | Spreadsheet formula — transforms data |

---

### `for_each` — Creates Multiple Resources

**Without `for_each` — 8 identical blocks:**
```hcl
resource "azurerm_application_insights" "frontend"       { name = "appi-frontend-dev"      ... }
resource "azurerm_application_insights" "user_service"   { name = "appi-user-service-dev"  ... }
resource "azurerm_application_insights" "cart_service"   { name = "appi-cart-service-dev"  ... }
# ...5 more identical blocks
```

**With `for_each` — one block creates 8 resources:**
```hcl
# infra/modules/monitoring/main.tf — ACTUAL PROJECT CODE
resource "azurerm_application_insights" "services" {
  for_each = toset(var.services)   # var.services = list of 8 service names

  name             = "appi-${each.key}-${var.environment}"
  application_type = each.key == "product-service" ? "other" : "web"
  workspace_id     = azurerm_log_analytics_workspace.main.id
}
```

**`var.services`:**
```hcl
default = ["frontend", "api-gateway", "user-service", "product-service",
           "cart-service", "order-service", "payment-service", "notification-service"]
```

**What Terraform creates:**
```
azurerm_application_insights.services["frontend"]           → appi-frontend-dev
azurerm_application_insights.services["user-service"]       → appi-user-service-dev
azurerm_application_insights.services["product-service"]    → appi-product-service-dev
# ... 5 more
```

8 real Azure resources from 1 resource block.

**`each.key` and `each.value`:**
- When input is a set: `each.key = each.value = the item` ("user-service")
- When input is a map: `each.key = map key`, `each.value = map value`

**`toset()` — Why needed?**
`for_each` requires a set or map — NOT a plain list. `toset()` converts list → set, removes duplicates, sorts alphabetically.

**`for_each` on dynamic blocks (conditional include):**
```hcl
# infra/modules/aks/main.tf
dynamic "oms_agent" {
  for_each = var.log_analytics_workspace_id != null ? [1] : []
  # [1] = include this block once
  # []  = skip this block entirely (conditional)
  content {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
```

---

### `for` — Transforms Values

**Real example from our project:**
```hcl
# infra/modules/monitoring/outputs.tf
output "application_insights_keys" {
  value = { for svc, appi in azurerm_application_insights.services : svc => appi.instrumentation_key }
}
```

Breaking it down:
```
{ for svc,   appi   in azurerm_application_insights.services : svc  =>  appi.instrumentation_key }
       ↑      ↑                    ↑                            ↑              ↑
    key var  val var          the 8 resources                output key    output value
```

**What this produces:**
```hcl
{
  "frontend"             = "abc123-key"
  "user-service"         = "def456-key"
  "product-service"      = "ghi789-key"
  # ...5 more
}
```

A single map output with all 8 keys. Without `for`, you'd need 8 separate output blocks.

**Other `for` patterns:**
```hcl
# Transform a list
[for env in var.environments : "env-${env}"]
# ["dev"] → ["env-dev"]

# Filter with if
[for svc in var.all_names : svc if strcontains(svc, "service")]
# → ["user-service", "product-service", ...]

# Transform a map
{ for env, loc in var.env_locations : env => upper(loc) }
# { "dev" = "eastus" } → { "dev" = "EASTUS" }
```

---

### When to Use Which

| Use Case | Tool |
|---|---|
| Create one Azure resource per item | `for_each` on resource |
| Conditionally include/skip a config block | `for_each` on dynamic block |
| Transform a list into a new list | `for` expression |
| Build a map from multiple resources | `for` expression |
| Filter items from a collection | `for` with `if` |

---

## Q16. How Does Log Analytics Work? How is it Different From Prometheus?

### What is Log Analytics?

Log Analytics (part of **Azure Monitor**) is the **central brain for all your logs and metrics**. Every Azure resource generates logs and metrics. Log Analytics pulls all of them into one place where you can search, analyse, and alert.

**Analogy:** 50 employees in 10 departments each keep their own records. Log Analytics = central HR system where every department automatically sends their records. Query one system, get the full picture.

---

### Mind Map

```
                    ┌─────────────────────────────────────┐
                    │       LOG ANALYTICS WORKSPACE        │
                    │         (law-azureshop-dev)          │
                    │   Central store for logs + metrics   │
                    └──────────────┬──────────────────────┘
                                   │
       ┌──────────────┬────────────┼────────────┬──────────────┐
       │              │            │            │              │
 ┌─────▼─────┐  ┌─────▼────┐ ┌────▼──────┐ ┌───▼──────┐ ┌────▼──────┐
 │    AKS    │  │   App    │ │Diagnostic │ │ Grafana  │ │   KQL     │
 │ Container │  │ Insights │ │ Settings  │ │Dashboard │ │  Query    │
 │ Insights  │  │  (x8)    │ │(AKS logs) │ │          │ │ Language  │
 └─────┬─────┘  └─────┬────┘ └────┬──────┘ └───┬──────┘ └────┬──────┘
       │               │           │             │              │
 Node CPU/Mem    Req traces   API server    Dashboards    ContainerLog
 Pod restarts    Error rates  Audit logs    Alerts        | where "ERROR"
 Container logs  Custom events Scheduler   Visualise      Perf | summarize
```

---

### Three Ways Data Gets INTO Log Analytics

**Way 1 — Container Insights (OMS Agent DaemonSet):**
```hcl
# infra/modules/aks/main.tf
dynamic "oms_agent" {
  for_each = var.log_analytics_workspace_id != null ? [1] : []
  content {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
```

Installs a **DaemonSet** (pod on every node) that auto-collects:
```
From every node:   CPU, memory, disk I/O, network
From every pod:    CPU, memory, restart count, stdout/stderr logs
From Kubernetes:   Pod status, deployment health, node status
```
Zero code changes in your application needed.

**Way 2 — Diagnostic Settings (Azure Platform Logs):**
```hcl
# infra/main.tf
resource "azurerm_monitor_diagnostic_setting" "aks" {
  target_resource_id         = module.aks.aks_cluster_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log { category = "kube-apiserver" }          # API server requests
  enabled_log { category = "kube-controller-manager" } # deployment reconciliation
  enabled_log { category = "kube-scheduler" }          # pod scheduling decisions
  enabled_log { category = "kube-audit" }              # every kubectl command ever run
  enabled_log { category = "cluster-autoscaler" }      # scale up/down decisions

  metric { category = "AllMetrics" enabled = true }    # CPU, memory, pod counts
}
```

`kube-audit` logs every `kubectl` command — who ran it, when, from which IP. Critical for security auditing.

**Why in `main.tf` not AKS module?** Circular dependency — monitoring module creates workspace, AKS module creates cluster, diagnostic setting links both. Placing it in root `main.tf` breaks the circular dependency.

**Way 3 — Application Insights (App-Level Telemetry):**
```hcl
# infra/modules/monitoring/main.tf
resource "azurerm_application_insights" "services" {
  for_each     = toset(var.services)   # one per each of 8 services
  workspace_id = azurerm_log_analytics_workspace.main.id  # sends data here
}
```

Collects:
```
HTTP request tracing:    Every request, status code, duration, slow requests
Dependency tracking:     Every SQL query, Redis call, inter-service HTTP call
Custom events:           "User placed order", "Payment failed"
Exceptions:              Full stack trace of every unhandled error
```

All 8 App Insights instances feed the **same** Log Analytics workspace — one KQL query can join app logs with infrastructure logs.

---

### KQL — Querying Log Analytics

KQL (Kusto Query Language) = like SQL but designed for log data.

```kql
// Find all pod restarts in the last hour
KubePodInventory
| where TimeGenerated > ago(1h)
| where PodRestartCount > 0
| project PodName, Namespace, PodRestartCount
| order by PodRestartCount desc

// Find ERROR logs from user-service
ContainerLog
| where TimeGenerated > ago(24h)
| where ContainerName contains "user-service"
| where LogEntry contains "ERROR"
| project TimeGenerated, ContainerName, LogEntry

// Average CPU per node (last 6 hours)
Perf
| where TimeGenerated > ago(6h)
| where ObjectName == "K8SNode"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

---

### Grafana + Log Analytics

```hcl
resource "azurerm_dashboard_grafana" "main" {
  identity { type = "SystemAssigned" }
}

resource "azurerm_role_assignment" "grafana_monitor_reader" {
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}
```

Grafana uses its Managed Identity (Monitoring Reader role) to query Log Analytics. No password or API key needed — pure identity-based auth.

---

### Log Analytics vs Prometheus

**Prometheus — The Pull Model (Open Source):**
```
Prometheus ──scrapes every 15s──► Pod /metrics endpoint
Stores in own TSDB (time-series database on disk)
Query with PromQL
Need Alertmanager separately for alerts
Collects metrics ONLY — no logs
```

**Log Analytics — The Push Model (Azure-Native):**
```
AKS + App Insights + Diagnostic Settings ──push──► Log Analytics
Microsoft-managed storage (unlimited retention)
Query with KQL
Built-in alerts via Azure Monitor
Collects logs AND metrics AND traces
```

**Head-to-Head:**

| Feature | Log Analytics | Prometheus |
|---|---|---|
| Model | Push — resources send data in | Pull — scrapes /metrics endpoint |
| Data types | Logs + Metrics + Traces | Metrics only |
| Query language | KQL | PromQL |
| Storage | Microsoft-managed | Self-managed TSDB |
| Cost | Pay per GB ingested | Free (you pay for infra) |
| Azure integration | Native — built into every Azure service | Manual — need exporters |
| Log collection | Yes — container stdout/stderr | No — need Loki separately |
| Who manages it | Microsoft | You |
| Multi-cloud | Azure only | Cloud-agnostic |

**When to use which:**

| Situation | Use |
|---|---|
| Azure-native infra, want zero-ops | Log Analytics |
| Need logs + metrics + traces in one place | Log Analytics + App Insights |
| Multi-cloud (Azure + AWS + GCP) | Prometheus |
| Kubernetes-native tooling (Helm operators) | Prometheus (kube-prometheus-stack) |
| Compliance, long-term log retention | Log Analytics |

In AzureShop we use Log Analytics — everything is Azure-native, zero Prometheus setup needed.

---

## Q17. What is lifecycle ignore_changes and Why Do We Use It on the AKS Node Pool?

### The Problem — Two Systems Fighting Over the Same Value

Imagine you have a whiteboard in an office. Two people can write on it.

```
Person 1 = Kubernetes Cluster Autoscaler (lives inside AKS)
Person 2 = Terraform (runs from your laptop or pipeline)
```

Both of them write the same thing on the whiteboard: **node_count**.

---

### What Each One Does

**The Cluster Autoscaler** watches your pods constantly:

```
Normal time (few users):
  Only 4 pods scheduled → 1 node is enough → autoscaler sets node_count = 1

Peak time (many users):
  20 pods need to run → 1 node is full → autoscaler sets node_count = 3
```

It increases and decreases `node_count` automatically based on real traffic. This is the whole point of autoscaling — you don't pay for 3 nodes at 3am when traffic is low.

**Terraform** also has `node_count` in your tfvars:

```hcl
user_node_count = 2
```

Every time `terraform apply` runs (during a pipeline, or manually), Terraform looks at the real Azure state and compares it to what your code says:

```
Terraform sees:    node_count = 2  (in your tfvars)
Azure has:         node_count = 3  (autoscaler scaled up for traffic)

Terraform thinks:  "Someone changed this! I need to fix it."
Terraform does:    Scales node_count back down to 2
```

---

### What Happens Without `ignore_changes`

Exact sequence of events that breaks your cluster:

```
Step 1 — Monday 9am
  Traffic is low → autoscaler sets node_count = 1
  Your code says node_count = 2

Step 2 — Monday 10am — pipeline runs terraform apply
  Terraform sees: Azure has 1, code says 2
  Terraform scales UP to 2 ← harmless this time

Step 3 — Monday 2pm
  Black Friday traffic hits
  Autoscaler detects pods are pending (not enough nodes)
  Autoscaler scales UP → node_count = 5
  All 8 services running fine across 5 nodes

Step 4 — Monday 3pm — pipeline runs terraform apply
  Terraform sees: Azure has 5, code says 2
  Terraform says: "Drift detected. Fixing."
  Terraform scales DOWN to 2

Step 5 — Immediate consequence
  3 nodes are drained and deleted
  All pods on those 3 nodes are EVICTED
  Kubernetes tries to reschedule evicted pods on 2 remaining nodes
  Not enough capacity → some pods stay Pending → services are DOWN
```

**Your pipeline just caused an outage during peak traffic.** And it did it silently — the pipeline shows green because Terraform successfully applied the change.

---

### What `ignore_changes` Does

```hcl
lifecycle {
  ignore_changes = [node_count]
}
```

This tells Terraform one simple rule:

> "You created this node pool. You own everything about it — VM size, OS disk, labels, taints. But `node_count`? That field belongs to the autoscaler. Never touch it again after creation."

```
Step 3 (same scenario) — Autoscaler sets node_count = 5

Step 4 — Pipeline runs terraform apply
  Terraform sees: Azure has 5, code says 2
  Terraform checks lifecycle block
  Terraform says: "node_count is in ignore_changes — skip it"
  Terraform applies NOTHING for this field

Step 5 — Cluster stays at 5 nodes
  All pods keep running
  No outage
```

---

### The Simple Mental Model — The Parking Valet

Think of it like this. You hire a parking valet (Terraform) to manage your car park.

- Terraform's job: set up the car park, paint the lines, install the barriers.
- The autoscaler's job: decide how many cars are parked at any given moment.

**Without `ignore_changes`:**
Every morning Terraform walks in and says "There should be exactly 2 cars here" and tows away all the extra cars — even if the car park is legitimately full of customers.

**With `ignore_changes`:**
Terraform sets up the car park once and says "The autoscaler owns the car count. I will not interfere."

---

### In AzureShop — Exactly Where This Is Used

```hcl
# infra/modules/aks/main.tf

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size
  node_count            = var.user_node_count     # initial count only — autoscaler takes over after this
  min_count             = var.user_min_count
  max_count             = var.user_max_count
  enable_auto_scaling   = true

  lifecycle {
    ignore_changes = [node_count]   # autoscaler owns this field after creation
  }
}
```

`node_count` here is the **initial count** — how many nodes to start with when the pool is first created. After that, the autoscaler takes over and Terraform steps back.

---

### When to Use vs When NOT to Use

| Situation | What to do |
|---|---|
| `enable_auto_scaling = true` | Use `ignore_changes = [node_count]` — autoscaler owns it |
| `enable_auto_scaling = false` | Do NOT use it — Terraform owns the count |

If autoscaling is off, Terraform is the only thing changing `node_count` and you want it to enforce the value you set in tfvars.

---

### Summary Table

| | Without `ignore_changes` | With `ignore_changes` |
|---|---|---|
| Autoscaler scales to 5 | Next `terraform apply` resets to 2 | Terraform leaves it at 5 |
| Pipeline runs at peak traffic | Can cause pod evictions and outage | Safe — nothing happens |
| Who owns `node_count` | Terraform (overrides autoscaler) | Autoscaler (Terraform steps back) |
| When to use | Autoscaling disabled | Autoscaling enabled |

---

### Interview Answer

**Q: Why do you use `lifecycle ignore_changes = [node_count]` on the AKS node pool?**

> "Because the Kubernetes Cluster Autoscaler modifies `node_count` dynamically based on pod scheduling needs. If Terraform also manages that field, every `terraform apply` would reset the count to the value in tfvars — overriding the autoscaler's decisions and potentially evicting pods during peak traffic. `ignore_changes` tells Terraform to own the initial creation of the node pool but hand off `node_count` to the autoscaler permanently. Without it, your CI/CD pipeline could silently cause an outage by scaling down nodes that are actively running production pods."

---

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

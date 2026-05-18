# AzureShop — Real Implementation Issues & Lessons Learned

This file documents every real bug and blocker we hit during the live execution of this project.
It is written in simple language so that even a beginner can read, understand, and learn from it.

For each issue you will find:
- What happened (the story)
- The concept explained (so you understand the background)
- Why it happened (root cause)
- The exact error message (so you recognise it next time)
- How to fix it (exact commands with explanation)
- How to prevent it in the future (best practices)

> **Total Issues Documented:** 10 real bugs across Phase 6 deployment
> **Purpose:** Learning, revision, and interview preparation

---

## Table of Contents

**Phase 6 — Terraform & Infrastructure**
1. [Issue #2 — Key Vault Purge Protection Blocked Re-creation](#issue-2--key-vault-purge-protection-blocked-re-creation)
2. [Issue #3 — Stale Terraform State Lock](#issue-3--stale-terraform-state-lock)
3. [Issue #4 — Stale Terraform State After Manual Resource Deletion](#issue-4--stale-terraform-state-after-manual-resource-deletion)
4. [Issue #5 — ACR Was Deleted But Terraform Expected It to Exist](#issue-5--acr-was-deleted-but-terraform-expected-it-to-exist)

**Phase 6 — AKS & RBAC**

5. [Issue #6 — AKS RBAC Role Assignment Lost After Cluster Recreation](#issue-6--aks-rbac-role-assignment-lost-after-cluster-recreation)

**Phase 6.4 — Deploying Services to AKS**

6. [Issue #1 — ARM64 vs AMD64 Image Mismatch](#issue-1--arm64-vs-amd64-image-mismatch)
7. [Issue #7 — api-gateway CrashLoopBackOff (nginx chown error)](#issue-7--api-gateway-crashloopbackoff-nginx-chown-error)
8. [Issue #8 — SecretProviderClass Using Old CSI Identity After AKS Recreation](#issue-8--secretproviderclass-using-old-csi-identity-after-aks-recreation)
9. [Issue #9 — api-gateway nginx PID File Permission Denied](#issue-9--api-gateway-nginx-pid-file-permission-denied)
10. [Issue #10 — Frontend Readiness Probe 404 and Cached Image Not Updated](#issue-10--frontend-readiness-probe-404-and-cached-image-not-updated)

**Summary**
- [Quick Reference Table](#quick-reference-table)

---

## Phase 6 — Terraform & Infrastructure

---

### Issue #2 — Key Vault Purge Protection Blocked Re-creation

#### What Happened

After we ran `terraform destroy` to tear down our infrastructure, the Azure Key Vault did not
get permanently deleted. It went into a "soft-deleted" state — meaning it still exists in
Azure's system but is hidden and not usable. We expected it to be fully gone so we could
recreate it fresh. When Terraform tried to create a new Key Vault with the same name, Azure
blocked it and threw an error.

#### Concept Explained — What is Soft Delete and Purge Protection?

Think of it like the Recycle Bin on your computer.

- When you delete a file normally, it goes to the Recycle Bin. It is not permanently gone —
  you can restore it within a time limit.
- **Soft Delete** in Azure Key Vault works the same way. When you "delete" a Key Vault,
  it actually moves to a soft-deleted state for 90 days. You can still recover it.
- **Purge Protection** goes one step further. It means that even YOU (the admin) cannot
  permanently delete (purge) the vault before the 90-day retention period ends.
  This is a security feature to prevent accidental or malicious permanent deletion of secrets.

We had enabled `purge_protection_enabled = true` in our own Terraform config because it is
good security practice. But this same setting blocked us from cleaning up during re-provisioning.

#### Why It Happened

Our Terraform config had:
```hcl
purge_protection_enabled = true
```

When `terraform destroy` ran, the vault went into soft-deleted state. Terraform then tried
to recreate a vault with the same name. Azure said: "A vault with this name already exists
in soft-deleted state and purge protection is on — I cannot allow you to overwrite or purge it."

#### The Exact Error

```
ERROR: (MethodNotAllowed) Operation 'DeletedVaultPurge' is not allowed.
Reason: This vault has been deleted and purge protection is enabled.
```

#### How to Fix It

Instead of trying to purge (permanently delete) the vault, we recover it back to active
state and then tell Terraform to use the existing vault instead of creating a new one.

**Step 1 — Recover the soft-deleted vault:**
```bash
az keyvault recover \
  --name kv-azureshop-6a6c-dev \
  --resource-group rg-azureshop-dev
```
What this does: Brings the vault back from soft-deleted state to active state.

**Step 2 — Import the recovered vault into Terraform state:**
```bash
terraform import module.keyvault.azurerm_key_vault.main \
  /subscriptions/<your-subscription-id>/resourceGroups/rg-azureshop-dev/providers/Microsoft.KeyVault/vaults/kv-azureshop-6a6c-dev
```
What this does: Tells Terraform "this vault already exists, don't try to create it again —
just manage it going forward."

**Step 3 — Run terraform apply as normal:**
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

#### How to Prevent It in Future

1. **If you are building a learning/dev environment** — consider setting
   `purge_protection_enabled = false` and `soft_delete_retention_days = 7` (minimum).
   This gives you a shorter retention window and allows you to purge if needed.

2. **If you must use purge protection (production)** — document that re-provisioning
   requires the recover + import approach. Never assume `terraform destroy` fully cleans up.

3. **Always check for soft-deleted vaults before re-applying:**
   ```bash
   az keyvault list-deleted --query "[].name"
   ```

4. **Use a unique vault name per environment + run** (e.g., include a timestamp or random
   suffix) so you never collide with a soft-deleted vault on re-provisioning.

---

### Issue #3 — Stale Terraform State Lock

#### What Happened

We ran `terraform apply` but the terminal was closed or the process was killed before it
finished. The next time we tried to run any Terraform command, it immediately failed with
a "state is locked" error. Terraform completely refused to do anything.

#### Concept Explained — What is a Terraform State Lock?

Imagine two people editing the same Google Doc at the same time. Things could go wrong —
one person's changes could overwrite the other's. To prevent this, Terraform uses a lock.

- Before Terraform modifies the state file, it puts a **lock** on it. This is like saying
  "I am working on this — no one else touch it."
- The lock is stored in Azure Blob Storage (where our Terraform state file lives).
- When Terraform finishes, it releases the lock.
- **The problem:** If Terraform is killed mid-run (Ctrl+C, crash, power cut, terminal close),
  it never gets a chance to release the lock. The lock stays there forever until manually removed.
- **There is no auto-expiry.** Azure will not automatically remove it.

#### Why It Happened

During a previous session, the `terraform apply` command was interrupted before it could
complete and release its lock. The lock remained stuck in Azure Blob Storage.

#### The Exact Error

```
Error acquiring the state lock
state blob is already locked

Lock Info:
  ID:        64747e86-fdd8-9ebf-77ef-788b03d5349a
  Path:      tfstate/dev.tfstate
  Operation: OperationTypeApply
  Who:       user@machine
  Version:   1.x.x
  Created:   2026-05-12 10:05:11 +0000 UTC
```

#### How to Fix It

Use the `force-unlock` command with the Lock ID shown in the error message:

```bash
terraform force-unlock -force 64747e86-fdd8-9ebf-77ef-788b03d5349a
```

What this does: Manually removes the lock from Azure Blob Storage so Terraform can run again.

**Important:** The Lock ID in the command must match exactly what is shown in the error.
Do not guess the ID — copy it directly from the error message.

After unlocking, verify it worked by running:
```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
```

#### How to Prevent It in Future

1. **Never kill a running `terraform apply` with Ctrl+C.** If something looks wrong, let
   it finish or wait — interrupting mid-run is what causes stale locks.

2. **If you must interrupt,** immediately run `terraform force-unlock` before doing anything else.

3. **Check for existing locks before running Terraform** if you are resuming after a crash:
   ```bash
   # Check if the state blob has a lease on it
   az storage blob show \
     --account-name myprojectazshoptfstate \
     --container-name tfstate \
     --name dev.tfstate \
     --query "properties.lease"
   ```

4. **In CI/CD pipelines,** configure timeout limits and ensure pipelines always run cleanup
   steps even on failure.

---

### Issue #4 — Stale Terraform State After Manual Resource Deletion

#### What Happened

Our `terraform destroy` only partially worked — some resources failed to delete. To move on,
we manually deleted the remaining resources using `az` CLI commands directly in Azure.
When we later ran `terraform plan`, Terraform was confused — it still thought those resources
existed (because they were in its state file) but they were actually gone from Azure.

#### Concept Explained — What is Terraform State?

Terraform keeps a record of everything it has created. This record is called the **state file**
(stored as `dev.tfstate` in Azure Blob Storage).

Think of it like a shopping receipt. The receipt records what you bought. But if someone
returns an item to the store without giving you back the receipt, your receipt still shows
the item even though it is no longer yours.

Terraform state works the same way:
- Terraform creates a resource → records it in the state file
- You manually delete the resource in Azure → Azure is updated, but Terraform's receipt is NOT
- Now Terraform thinks the resource still exists, but Azure knows it is gone
- This mismatch is called **state drift**

#### Why It Happened

`terraform destroy` failed halfway. We used `az aks delete`, `az network vnet delete`, etc.
to clean up manually. These commands talk directly to Azure but do not touch Terraform's
state file. Terraform was left with a state file that described resources that no longer existed.

#### The Exact Error

There was no hard error — but `terraform plan` showed unexpected output like:
```
# module.aks.azurerm_kubernetes_cluster.main must be replaced
# (because it no longer exists in Azure — will be re-created)
```
Terraform detected drift and planned to recreate everything.

#### How to Fix It

In this case, the fix was simple — **just run `terraform apply`.**

Terraform automatically does a **refresh** at the start of every plan. It compares its state
file against the real state in Azure. When it finds resources in the state file that no longer
exist in Azure, it marks them as needing to be created. Running `terraform apply` then recreates
them correctly.

```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

**If you want to remove a resource from state WITHOUT recreating it:**
```bash
terraform state rm module.aks.azurerm_kubernetes_cluster.main
```
What this does: Removes the resource from Terraform's state file so Terraform forgets about it.
Use this only if you deliberately deleted something and do not want Terraform to recreate it.

#### How to Prevent It in Future

1. **Never manually delete resources that Terraform manages.** If you need to delete something,
   always use `terraform destroy` or `terraform destroy -target=<resource>`.

2. **If you must delete manually,** immediately run `terraform state rm <resource>` to keep
   the state file in sync.

3. **To clean up a specific resource only:**
   ```bash
   terraform destroy -target=module.aks.azurerm_kubernetes_cluster.main
   ```
   This destroys only that one resource and keeps the state file in sync.

4. **After any manual changes in Azure,** always run `terraform plan` first to understand
   the drift before running `terraform apply`.

---

### Issue #5 — ACR Was Deleted But Terraform Expected It to Exist

#### What Happened

Between sessions, the Azure Container Registry (ACR) was deleted — either manually or by
Azure during cleanup. When we came back to resume the project, we assumed it still existed.
Pre-flight checks revealed it was gone.

#### Concept Explained — What is ACR?

Azure Container Registry (ACR) is like a private Docker Hub. It stores your Docker images
so that AKS can pull them when deploying your services. Without ACR, your services cannot
be deployed to Kubernetes.

#### Why It Happened

The original ACR was created manually (Basic SKU) during early phases. When we later
switched to Terraform-managed ACR (Premium SKU), the old one was likely cleaned up.
Between sessions, neither was tracked consistently.

#### The Exact Issue

No hard error — but the pre-flight check showed:
```bash
az acr show --name acrazureshopdev --resource-group rg-azureshop-dev
# ResourceNotFound: The Resource 'Microsoft.ContainerRegistry/registries/acrazureshopdev'
# under resource group 'rg-azureshop-dev' was not found.
```

#### How to Fix It

Since the ACR was not in Terraform state and not in Azure, `terraform apply` simply
created it fresh with no conflict:

```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

No special steps were needed — Terraform handled it automatically.

#### How to Prevent It in Future

1. **Always verify actual Azure resource state with `az` CLI before starting a session.**
   Do not rely on memory or notes — things change between sessions.

   Quick pre-flight checks to run at the start of each session:
   ```bash
   # Check AKS
   az aks show --resource-group rg-azureshop-dev --name aks-azureshop-dev --query provisioningState

   # Check ACR
   az acr show --name acrazureshopdev --query provisioningState

   # Check Key Vault
   az keyvault show --name kv-azureshop-6a6c-dev --query properties.provisioningState
   ```

2. **Manage ALL resources through Terraform from the start.** Mixing manual + Terraform
   resources leads to confusion about what exists and who is responsible for it.

3. **Write a pre-flight checklist** and run it before every session when working on
   infrastructure that can be torn down.

---

## Phase 6 — AKS & RBAC

---

### Issue #6 — AKS RBAC Role Assignment Lost After Cluster Recreation

#### What Happened

After Terraform recreated the AKS cluster, we ran `kubectl get nodes` to verify the cluster
was working — and got a Forbidden error. Our user account, which had full admin access before,
suddenly had zero access to the cluster.

#### Concept Explained — What is RBAC and Why Do Role Assignments Get Lost?

**RBAC** stands for Role-Based Access Control. It is the system Azure uses to control who
can do what to which resource.

Think of it like a building's access card system:
- The building (AKS cluster) has an address (resource ID)
- Your access card (role assignment) is programmed for that specific address
- If the building is demolished and rebuilt at a new address, your card no longer works
  — you need to reprogram it for the new address

When Terraform destroys and recreates an AKS cluster:
- The new cluster gets a **brand new resource ID** (a new address)
- All old role assignments were scoped to the OLD resource ID
- Those assignments are now pointing to a resource that no longer exists
- Result: You have zero access to the new cluster

#### Why It Happened

Terraform destroyed the old AKS cluster and created a new one. The new cluster has a
different resource ID. Our role assignment (`Azure Kubernetes Service RBAC Cluster Admin`)
was scoped to the old resource ID and therefore became invalid.

#### The Exact Error

```
Error from server (Forbidden): nodes is forbidden:
User "df0cac37-4e4b-4338-875d-a01366185bd3" cannot list resource "nodes"
in API group "" at the cluster scope

User does not have access to the resource in Azure.
Update role assignment to allow access.
```

#### How to Fix It

**Step 1 — Get the new cluster's resource ID:**
```bash
AKS_ID=$(az aks show \
  --resource-group rg-azureshop-dev \
  --name aks-azureshop-dev \
  --query id -o tsv)

echo $AKS_ID
```
What this does: Fetches the new cluster's unique ID from Azure.

**Step 2 — Re-assign the admin role to your user on the new cluster:**
```bash
az role assignment create \
  --assignee df0cac37-4e4b-4338-875d-a01366185bd3 \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "$AKS_ID"
```
What this does: Gives your user account full admin access on the new cluster.

**Step 3 — Wait 2 minutes for RBAC to propagate, then verify:**
```bash
kubectl get nodes
```

#### How to Prevent It in Future

1. **Treat RBAC role re-assignment as a mandatory post-provisioning step** every time
   AKS is recreated. Add it to your runbook or checklist.

2. **Document your user Object ID** so you do not have to look it up every time:
   ```bash
   az ad signed-in-user show --query id -o tsv
   ```

3. **Consider managing user RBAC through Terraform** so it is applied automatically
   on every `terraform apply`. Add this to your Terraform config:
   ```hcl
   resource "azurerm_role_assignment" "aks_admin" {
     scope                = module.aks.cluster_id
     role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
     principal_id         = var.admin_user_object_id
   }
   ```

4. **Understand the difference:**
   - Terraform manages **infrastructure RBAC** (AcrPull for kubelet, Key Vault Secrets User for pods)
   - **User admin access** is a manual one-time step per environment unless you explicitly
     add it to Terraform.

---

## Phase 6.4 — Deploying Services to AKS

---

### Issue #1 — ARM64 vs AMD64 Image Mismatch

#### What Happened

We built all 8 Docker images on a Mac with Apple Silicon (M1/M2/M3 chip) and pushed them
to ACR. When Kubernetes tried to run the containers on AKS, every single pod immediately
crashed with `exec format error`. Nothing worked.

#### Concept Explained — What is ARM64 vs AMD64?

A CPU (processor) has an **architecture** — essentially the instruction language it speaks.
Two major architectures exist:

| Architecture | Also called | Used in |
|---|---|---|
| AMD64 | x86_64 | Intel/AMD chips — most servers, most cloud VMs |
| ARM64 | aarch64 | Apple Silicon (M1/M2/M3), AWS Graviton, some phones |

A Docker image built for ARM64 contains instructions in the ARM language.
If you try to run it on an AMD64 server, the server says "I don't understand this language"
and immediately crashes — this is the `exec format error`.

**The problem:** When you run `docker build` on a Mac with Apple Silicon, Docker
automatically builds for ARM64 (the native chip). AKS nodes run AMD64 by default.
So every image we built was in the wrong language for AKS.

#### Why It Happened

Apple Silicon Macs use ARM64 architecture. `docker build` without a platform flag builds
for the host machine's architecture by default. We did not specify `--platform linux/amd64`
so Docker built ARM64 images. AKS nodes are AMD64.

#### The Exact Error

```
exec format error
```

In Kubernetes pod events:
```
Error: failed to create containerd task: failed to create shim task:
OCI runtime create failed: runc create failed:
unable to start container process: exec: ... exec format error: unknown
```

#### How to Fix It

Use Docker Buildx with an explicit platform flag to force AMD64 builds on your Mac:

**First, create a multi-architecture builder (one-time setup):**
```bash
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```
What this does: Creates a special Docker builder that can build for any platform regardless
of what chip your Mac has.

**Then build each image with the platform flag:**
```bash
docker buildx build \
  --builder multiarch \
  --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/user-service:v1.0.0 \
  --push \
  services/user-service/
```

Repeat for all 8 services (user-service, product-service, cart-service, order-service,
payment-service, notification-service, frontend, api-gateway).

What `--platform linux/amd64` does: Forces Docker to build an AMD64 image even though
your Mac uses ARM64. The `--push` flag builds and pushes to ACR in one step.

#### How to Prevent It in Future

1. **Always use `--platform linux/amd64`** in every `docker buildx build` command when
   building for AKS from a Mac with Apple Silicon. Never skip this flag.

2. **Add the platform to your docker-compose.yml** for consistency:
   ```yaml
   services:
     user-service:
       build:
         context: ./services/user-service
         platforms:
           - linux/amd64
   ```

3. **Verify the image architecture before deploying:**
   ```bash
   docker manifest inspect acrazureshopdev.azurecr.io/user-service:v1.0.0 | grep architecture
   ```
   You should see `"architecture": "amd64"`. If you see `"architecture": "arm64"`, the image
   will fail on AKS.

4. **Use CI/CD pipelines for building** — Azure DevOps agents are AMD64, so images built
   there are automatically the correct architecture. This completely eliminates the problem.

---

### Issue #7 — api-gateway CrashLoopBackOff (nginx chown error)

#### What Happened

After fixing the ARM64 issue, the api-gateway pod started but immediately crashed in a loop.
`CrashLoopBackOff` means Kubernetes is repeatedly trying to start the container, it keeps
dying, and Kubernetes is waiting longer between each retry.

#### Concept Explained — What is CrashLoopBackOff and Linux Capabilities?

**CrashLoopBackOff** is Kubernetes telling you: "I have tried to start this container
multiple times and it keeps crashing. I will keep retrying but with increasing delays."
It is not a permanent failure — it means the container IS starting but dying very quickly.

**Linux Capabilities** are fine-grained permissions for processes running on Linux.
Normally, root (admin) processes can do anything. But in Kubernetes, we run containers
with restricted security settings for safety. We can grant or remove specific capabilities.

One capability is `CHOWN` — the ability to change file ownership on the system.
The standard `nginx` image needs `CHOWN` to set up its cache directories when it starts.
Our Helm security context had `capabilities: drop: - ALL` — this removes ALL capabilities
including `CHOWN`. So nginx could not start properly.

> **Note:** This issue was hidden behind Issue #1. In the previous session, the container
> was crashing at the OS level (exec format error) before nginx even had a chance to start.
> Fixing Issue #1 revealed this issue.

#### Why It Happened

Our Kubernetes security settings (in the Helm chart) deliberately drop all Linux capabilities
for security. The standard `nginx:alpine` image requires the `CHOWN` capability to change
ownership of its cache directories during startup. With `CHOWN` dropped, nginx fails immediately.

#### The Exact Error

```
nginx: [emerg] chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
```

In Kubernetes pod events:
```
Back-off restarting failed container api-gateway in pod api-gateway-xxx
```

#### How to Fix It

Switch from the standard `nginx` image to `nginxinc/nginx-unprivileged` — an official
nginx image specifically built to run without root permissions and without any Linux capabilities.

**Change the Dockerfile:**
```dockerfile
# Before (standard nginx — requires root capabilities)
FROM nginx:1.27-alpine

# After (unprivileged nginx — designed for Kubernetes security contexts)
FROM nginxinc/nginx-unprivileged:1.27-alpine
```

The unprivileged image pre-configures all its directories with correct permissions so it
does not need to `chown` anything at startup. It is designed specifically for environments
like Kubernetes where containers run as non-root with dropped capabilities.

**Rebuild and push after changing the Dockerfile:**
```bash
docker buildx build \
  --builder multiarch \
  --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/api-gateway:v1.0.0 \
  --push \
  services/api-gateway/
```

#### How to Prevent It in Future

1. **For any container running nginx in Kubernetes, always use `nginxinc/nginx-unprivileged`**
   instead of `nginx`. This is especially true if your security context drops capabilities or
   runs as non-root.

2. **Understand your security context settings.** If your Helm chart or Pod spec has:
   ```yaml
   securityContext:
     capabilities:
       drop:
         - ALL
     runAsNonRoot: true
   ```
   Then every image you use must be designed for non-root, zero-capability operation.

3. **Test locally with the same security restrictions** before deploying to Kubernetes:
   ```bash
   docker run --user 1000 --cap-drop ALL nginxinc/nginx-unprivileged:1.27-alpine
   ```

---

### Issue #8 — SecretProviderClass Using Old CSI Identity After AKS Recreation

#### What Happened

After AKS was recreated, most services deployed fine but 5 pods kept failing to start.
They could not mount their secrets from Key Vault. The error said the managed identity
was not found or not assigned.

#### Concept Explained — What is a SecretProviderClass and CSI Identity?

When a pod in AKS needs to read a secret from Key Vault, it uses the **Key Vault CSI driver**.
This is a component installed on AKS that fetches secrets from Key Vault and mounts them
inside the pod as files or environment variables.

To talk to Key Vault, the CSI driver uses a **Managed Identity** — an automatically managed
credential that Azure creates. Think of it like a staff badge that the CSI driver uses to
show Azure who it is and what it is allowed to access.

A **SecretProviderClass** is a Kubernetes manifest (YAML file) that tells the CSI driver:
- Which Key Vault to connect to
- Which secrets to fetch
- Which identity (badge) to use — identified by a `clientId`

**The problem:** When AKS is recreated, Azure creates a brand new Managed Identity with a
brand new `clientId`. Our SecretProviderClass files had the OLD `clientId` hardcoded.
The old identity no longer exists — so Key Vault refused access.

#### Why It Happened

When we first set up Key Vault integration in Phase 6.2, we ran a command to get the CSI
addon identity's `clientId` and hardcoded it into all 5 SecretProviderClass YAML files.
This was fine as long as the same AKS cluster was running. But when we destroyed and
recreated the cluster, Azure assigned a new identity with a completely different `clientId`.
Our files still had the old one.

#### The Exact Error

```
ManagedIdentityCredential authentication failed.
The requested identity isn't assigned to this resource.
Identity not found

Warning  FailedMount  Unable to mount volumes for pod "cart-service-xxx":
timeout expired waiting for volumes to be ready after 4 minutes
```

#### How to Fix It

**Step 1 — Get the new CSI addon identity Client ID:**
```bash
az aks show \
  --resource-group rg-azureshop-dev \
  --name aks-azureshop-dev \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" \
  -o tsv
```
What this does: Fetches the new identity's `clientId` from Azure.
Copy this value — you will need it in the next step.

**Step 2 — Update all SecretProviderClass files** with the new `clientId`.
Open each file in `k8s/secret-provider-classes/` and replace the old `clientId` value
with the new one you just copied.

**Step 3 — Re-apply the updated SecretProviderClass files:**
```bash
kubectl apply -f k8s/secret-provider-classes/
```

**Step 4 — Restart the affected deployments** so they pick up the new SecretProviderClass:
```bash
kubectl rollout restart deployment/cart-service \
  deployment/order-service \
  deployment/payment-service \
  deployment/product-service \
  deployment/user-service \
  -n dev
```

**Step 5 — Verify pods are running:**
```bash
kubectl get pods -n dev
```

#### How to Prevent It in Future

1. **Never hardcode the CSI addon `clientId` in manifests.** It changes every time AKS
   is recreated.

2. **Always fetch the new `clientId` as the first step after any AKS recreation:**
   ```bash
   az aks show \
     --resource-group rg-azureshop-dev \
     --name aks-azureshop-dev \
     --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" \
     -o tsv
   ```

3. **Use Helm templating to inject the value dynamically** so you never hardcode it.
   In `values.yaml`:
   ```yaml
   csiClientId: ""   # set at deploy time
   ```
   In the SecretProviderClass template:
   ```yaml
   userAssignedIdentityID: {{ .Values.csiClientId }}
   ```
   Then deploy with:
   ```bash
   helm upgrade --install myapp ./helm/charts/myapp \
     --set csiClientId=$(az aks show ... --query "..." -o tsv)
   ```

4. **Add CSI `clientId` update to your post-provisioning checklist** alongside RBAC
   role re-assignment (Issue #6).

---

### Issue #9 — api-gateway nginx PID File Permission Denied

#### What Happened

After switching to `nginx-unprivileged` to fix Issue #7, the api-gateway crashed again.
This time with a different error — nginx could not write its PID file. A PID file is a
small file where nginx records its own process ID number when it starts.

#### Concept Explained — What is a PID File and Why Does Location Matter?

When nginx starts, it writes its **Process ID** (a number that identifies the running process)
to a file. This PID file is used by nginx to manage itself — for example, when you send a
signal to reload nginx, it reads the PID file to know which process to signal.

By default, nginx tries to write the PID file to `/run/nginx.pid`. This directory (`/run`)
is owned by root and a non-root user cannot write to it.

The `nginx-unprivileged` image works around this by defaulting to `/tmp/nginx.pid` in its
**built-in config**. However, we completely replaced the default config with our custom
`nginx.conf`. When you do that, you lose all the non-root-friendly settings from the base
image — including the custom PID file path. nginx then falls back to the system default
`/run/nginx.pid` which our non-root user cannot write to.

#### Why It Happened

We used `COPY nginx.conf /etc/nginx/nginx.conf` in our Dockerfile. This replaced the
entire default nginx configuration. Our custom `nginx.conf` did not include a `pid`
directive, so nginx defaulted to `/run/nginx.pid`. A non-root user cannot write there.

#### The Exact Error

```
nginx: [emerg] open() "/run/nginx.pid" failed (13: Permission denied)
```

#### How to Fix It

Add the correct non-root-friendly directives to the top of your `nginx.conf`:

```nginx
# Tell nginx to write its PID file to /tmp where non-root users can write
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    # Redirect all temp/cache paths to /tmp where non-root users can write
    client_body_temp_path /tmp/client_temp;
    proxy_temp_path       /tmp/proxy_temp;
    fastcgi_temp_path     /tmp/fastcgi_temp;
    uwsgi_temp_path       /tmp/uwsgi_temp;
    scgi_temp_path        /tmp/scgi_temp;

    # ... rest of your config ...
}
```

What each line does:
- `pid /tmp/nginx.pid` — moves the PID file to `/tmp` where any user can write
- `*_temp_path /tmp/*` — moves all nginx temp/cache directories to `/tmp`

After updating `nginx.conf`, rebuild and push with a new image tag:
```bash
docker buildx build \
  --builder multiarch \
  --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/api-gateway:v1.0.2 \
  --push \
  services/api-gateway/
```

#### How to Prevent It in Future

1. **Whenever you use `nginx-unprivileged` with a custom `nginx.conf`,** always include
   `pid /tmp/nginx.pid` and all the `*_temp_path /tmp/*` directives. These are mandatory.

2. **Think of it this way:** The `nginx-unprivileged` base image works around root restrictions
   in its own built-in config. When you replace that config entirely, you take on the
   responsibility of including those same workarounds yourself.

3. **Test your nginx config locally in non-root mode** before building:
   ```bash
   docker run --user 1000 --cap-drop ALL \
     -v $(pwd)/services/api-gateway/nginx.conf:/etc/nginx/nginx.conf \
     nginxinc/nginx-unprivileged:1.27-alpine
   ```
   If it starts without errors, it will work in Kubernetes.

---

### Issue #10 — Frontend Readiness Probe 404 and Cached Image Not Updated

#### What Happened

This issue had two separate problems that happened one after the other.

**Problem A:** The frontend pod kept failing readiness checks even though the Next.js app
was actually running and serving pages correctly. Kubernetes thought the pod was not ready
and never sent traffic to it.

**Problem B:** When we added a fix and rebuilt the Docker image, Kubernetes still ran the
broken version. Our fix was completely ignored.

#### Concept Explained — What is a Readiness Probe?

A **Readiness Probe** is Kubernetes checking: "Is this pod ready to receive traffic?"

Kubernetes periodically sends an HTTP request to a specific path on your pod. If the pod
returns HTTP 200 (success), Kubernetes marks it as Ready and sends user traffic to it.
If the pod returns anything else (like 404 Not Found), Kubernetes marks it as Not Ready
and does not send traffic to it — even if the app is actually working fine.

Think of it like a security guard who checks a specific door to see if a store is open.
If that door is locked (404), the guard tells customers the store is closed — even if
every other door is open and people are shopping inside.

**Our problem:** The Helm chart had `probes.path: /health`. Next.js does not have a
`/health` route by default, so every probe returned 404. The app was running perfectly
but Kubernetes never knew — it kept marking the pod as Not Ready.

#### Concept Explained — What is Image Pull Policy and Why Was Our Fix Ignored?

When Kubernetes starts a container, it needs the Docker image. It checks if the image is
already on the node (server) or if it needs to download it from ACR.

The `pullPolicy` setting controls this behaviour:
- `Always` — Always download the image from the registry, even if you already have it
- `IfNotPresent` — Only download if the image tag is NOT already on this node
- `Never` — Never download; always use what is on the node

We had `pullPolicy: IfNotPresent`. The node already had `frontend:v1.0.0` cached from
the previous deploy. When we pushed a fixed image with the same tag `v1.0.0`, Kubernetes
saw "I already have v1.0.0" and did NOT pull the new image. Our fix was never deployed —
Kubernetes just kept running the old broken version from cache.

#### Why It Happened

- **Problem A:** The Helm chart probe path `/health` was copied from backend services.
  Backend services have a `/health` route. Next.js does not — it serves pages via its
  router and has no automatic health endpoint.

- **Problem B:** We pushed a bug fix using the same image tag `v1.0.0`. With
  `pullPolicy: IfNotPresent`, Kubernetes never downloaded the new image because it
  already had a cached version with that tag.

#### The Exact Errors

```
Warning  Unhealthy  Startup probe failed:
HTTP probe failed with statuscode: 404
GET http://10.244.1.5:3000/health => 404 Not Found
```

```
Normal  Pulled  Container image
"acrazureshopdev.azurecr.io/frontend:v1.0.0" already present on machine
```

#### How to Fix It

**Fix for Problem A — Add a real health endpoint to Next.js:**

Create the file `services/frontend/src/pages/api/health.js`:
```javascript
export default function handler(req, res) {
  res.status(200).json({ status: 'ok' });
}
```

This creates the route `/api/health` in Next.js that returns HTTP 200. Simple and effective.

Update the Helm chart probe path from `/health` to `/api/health`:
```yaml
# In helm/values/dev.yaml for frontend
probes:
  path: /api/health   # was /health — Next.js has no /health route by default
```

**Fix for Problem B — Always bump the image tag when pushing a fix:**

Push the fixed image with a NEW tag:
```bash
docker buildx build \
  --builder multiarch \
  --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/frontend:v1.0.1 \
  --push \
  services/frontend/
```

Update the Helm chart to use the new tag:
```yaml
# In helm/values/dev.yaml for frontend
image:
  tag: v1.0.1   # bumped from v1.0.0
```

Redeploy:
```bash
helm upgrade frontend ./helm/charts/frontend \
  -f helm/values/dev.yaml \
  -n dev
```

#### How to Prevent It in Future

1. **For health probes:**
   - Always verify the probe path actually exists in your app before deploying
   - For Next.js, always add an explicit `/api/health` route — it does not exist by default
   - For Express (Node.js), always add `app.get('/health', ...)` explicitly
   - For FastAPI (Python), the auto-generated `/health` or use `@app.get("/health")`

2. **For image tags — NEVER reuse a tag for a new image.** This is one of the most common
   beginner mistakes in Kubernetes. With `pullPolicy: IfNotPresent`, the same tag = cached image = your fix never runs.

   **Best practices for image tagging:**
   ```
   v1.0.0          ← first release
   v1.0.1          ← bug fix (always bump for any change)
   v1.1.0          ← new feature
   ```
   
   In production, use the git commit SHA as the tag so every build is unique:
   ```bash
   TAG=$(git rev-parse --short HEAD)
   docker buildx build ... -t acrazureshopdev.azurecr.io/frontend:$TAG --push ...
   ```

3. **Consider using `pullPolicy: Always` in development** so you never have to worry
   about cached images:
   ```yaml
   image:
     pullPolicy: Always  # use IfNotPresent in production for performance
   ```

---

## Quick Reference Table

| # | Phase | Issue | Root Cause | Key Fix |
|---|---|---|---|---|
| 1 | 6.4 | `exec format error` | ARM64 image on AMD64 AKS nodes | `docker buildx --platform linux/amd64` |
| 2 | 6 | Key Vault cannot be purged | `purge_protection_enabled = true` | `az keyvault recover` + `terraform import` |
| 3 | 6 | Terraform state locked | `terraform apply` was killed mid-run | `terraform force-unlock <lock-id>` |
| 4 | 6 | Terraform state drift | Resources manually deleted without `terraform destroy` | Run `terraform apply` — it auto-detects drift |
| 5 | 6 | ACR not found | ACR deleted between sessions | `terraform apply` recreated it fresh |
| 6 | 6 | kubectl Forbidden after AKS recreation | Role assignment scoped to old cluster ID | Re-assign `RBAC Cluster Admin` role to new cluster |
| 7 | 6.4 | nginx chown `Operation not permitted` | Standard nginx needs `CHOWN` capability, our security drops all caps | Switch to `nginxinc/nginx-unprivileged` |
| 8 | 6.4 | Key Vault CSI identity not found | Old CSI `clientId` hardcoded after AKS recreation | Fetch new `clientId`, update all SecretProviderClasses |
| 9 | 6.4 | nginx PID `Permission denied` | Custom `nginx.conf` lost non-root path settings | Add `pid /tmp/nginx.pid` and temp paths to config |
| 10 | 6.4 | Readiness probe 404 + fix ignored | Wrong probe path + same image tag with `IfNotPresent` | Add `/api/health` route + always bump image tag |

---

## Top 5 Lessons Every DevOps Engineer Must Remember

1. **On Apple Silicon Mac, always build Docker images with `--platform linux/amd64` for AKS.**
   ARM64 images silently build and push but fail the moment Kubernetes tries to run them.

2. **Never reuse an image tag for a changed image when `pullPolicy: IfNotPresent` is set.**
   Kubernetes will silently ignore your fix. Always bump the tag.

3. **Never manually delete Terraform-managed resources.**
   Manual deletions break state sync. Always use `terraform destroy` or `terraform state rm`.

4. **After every AKS recreation, do these two things immediately:**
   - Re-assign RBAC admin role (cluster gets a new resource ID)
   - Update CSI addon `clientId` in all SecretProviderClasses (cluster gets a new identity)

5. **Use images designed for non-root Kubernetes security contexts.**
   If your Helm chart drops all capabilities (`drop: ALL`), the standard `nginx` image will
   crash. Use `nginxinc/nginx-unprivileged` instead.

---

*Last updated: 2026-05-18 · All 9 phases complete · 10 real issues documented*

# Phase 9 — Advanced DevOps Patterns

## Overview

Phase 9 adds three production-grade operational patterns on top of the AzureShop AKS cluster:

| Step | What | Files |
|---|---|---|
| 9.1 | GitOps with Flux v2 | `k8s/gitops/`, `infra/modules/aks/main.tf` |
| 9.2 | Cost Optimisation (spot nodes + quotas) | `infra/modules/aks/main.tf`, `k8s/namespaces/dev-resource-quota.yaml` |
| 9.3 | Canary Deployment Pattern | `k8s/ingress/canary-example.yaml` |

---

## Step 9.1 — GitOps with Flux v2

### What is GitOps?

GitOps is an operating model where **git is the single source of truth** for the desired state of your cluster. Instead of running `kubectl apply` or `helm upgrade` manually, you commit changes to git and an operator running inside the cluster syncs those changes automatically.

**Traditional push-based deployment:**
```
Developer → CI Pipeline → kubectl apply → Cluster
```

**GitOps pull-based deployment:**
```
Developer → git commit → Cluster (Flux polls + applies)
```

The cluster continuously reconciles itself toward the git state. If someone runs a rogue `kubectl delete`, Flux detects the drift and recreates the resource within 60 seconds.

### Why Flux v2 (not Argo CD)?

Both are excellent. The choice:

| | Flux v2 | Argo CD |
|---|---|---|
| UI | None (CLI / Grafana dashboard) | Full web UI |
| Model | Kustomize + HelmRelease CRDs | App CRD with sync waves |
| Azure integration | AKS managed extension (no helm install needed) | Helm install into cluster |
| Auth | Git credentials in Secret | Git credentials in Secret |
| Best for | CLI-first, automated pipelines | Visual debugging, teams needing a GUI |

We chose Flux because it has a **Microsoft-managed AKS extension** — one Terraform resource installs and upgrades it, no manual helm install.

### Flux Architecture (4 Controllers)

```
┌─────────────────────────────────────────────────────────┐
│ flux-system namespace                                     │
│                                                           │
│  source-controller     ── polls git, produces Artifacts  │
│  kustomize-controller  ── applies Kustomization CRDs     │
│  helm-controller       ── reconciles HelmRelease CRDs    │
│  notification-controller ── sends alerts (Slack, Teams)  │
└─────────────────────────────────────────────────────────┘
```

**source-controller** fetches the git repo every 60 seconds and produces a versioned tar archive (Artifact). The other controllers consume this artifact — they never call git directly.

**kustomize-controller** reads `Kustomization` CRDs and applies the YAML files at the specified path using kustomize.

**helm-controller** reads `HelmRelease` CRDs, installs/upgrades Helm charts from the git source, and retries failed releases automatically.

### Key CRDs

```
source.toolkit.fluxcd.io/v1
  GitRepository    — where to pull manifests from

kustomize.toolkit.fluxcd.io/v1
  Kustomization    — which path to apply, interval, pruning

helm.toolkit.fluxcd.io/v2
  HelmRelease      — declares a Helm chart + values, managed by helm-controller
```

### File Structure

```
k8s/gitops/
  sources/
    git-repository.yaml        # GitRepository CRD (reference — created by Terraform)
  releases/
    kustomization.yaml         # kustomize manifest listing all HelmRelease files
    user-service.yaml          # HelmRelease for user-service
    cart-service.yaml
    order-service.yaml
    payment-service.yaml
    product-service.yaml
    notification-service.yaml
    api-gateway.yaml
    frontend.yaml
```

### HelmRelease Anatomy

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: user-service
  namespace: dev           # namespace where the Helm release is installed
spec:
  interval: 5m             # how often to check for value changes
  chart:
    spec:
      chart: ./helm/charts/user-service   # path in git repo
      sourceRef:
        kind: GitRepository
        name: azureshop
        namespace: flux-system
      interval: 1m         # how often to check for chart file changes
  install:
    remediation:
      retries: 3           # retry failed installs 3 times before giving up
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true  # rollback to last successful if upgrade fails
```

**Key insight — `install.remediation` vs `upgrade.remediation`:**
- `install.remediation` triggers on the first-ever install of a release (no previous state).
- `upgrade.remediation` triggers on upgrades. `remediateLastFailure: true` tells the helm-controller to rollback to the previous successful release if the upgrade fails, rather than leaving the cluster in a broken state.

### Terraform Implementation

Two resources added to `infra/modules/aks/main.tf`:

**1. AKS Cluster Extension (installs Flux controllers):**
```hcl
resource "azurerm_kubernetes_cluster_extension" "flux" {
  count          = var.enable_flux ? 1 : 0
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
  release_train  = "Stable"

  configuration_settings = {
    "helm-controller.enabled"              = "true"
    "source-controller.enabled"            = "true"
    "kustomize-controller.enabled"         = "true"
    "notification-controller.enabled"      = "true"
    "image-automation-controller.enabled"  = "false"
    "image-reflector-controller.enabled"   = "false"
  }
}
```

**2. Flux Configuration (creates GitRepository + Kustomization):**
```hcl
resource "azurerm_kubernetes_flux_configuration" "main" {
  count      = var.enable_flux ? 1 : 0
  name       = "azureshop"
  cluster_id = azurerm_kubernetes_cluster.main.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = var.git_repository_url
    reference_type           = "branch"
    reference_value          = var.git_branch
    sync_interval_in_seconds = 60
    https_user               = var.git_https_user
    https_key_base64         = base64encode(var.git_https_pat)
  }

  kustomizations {
    name                       = "releases"
    path                       = "./k8s/gitops/releases"
    sync_interval_in_seconds   = 60
    retry_interval_in_seconds  = 30
    garbage_collection_enabled = true
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}
```

`garbage_collection_enabled = true` — if you delete a HelmRelease YAML from git, Flux deletes the corresponding Helm release from the cluster. This prevents orphaned resources.

### Activating Flux

Flux is disabled by default (`enable_flux = false`). To activate:

```bash
# Set the PAT as an environment variable (never in tfvars)
export TF_VAR_git_https_pat="<YOUR_AZURE_DEVOPS_PAT>"

# Enable Flux in tfvars (or via TF_VAR)
export TF_VAR_enable_flux=true

terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

The PAT needs **Code (Read)** permission in Azure DevOps.

### Verifying Flux Sync

```bash
# Check all Flux resources in the cluster
kubectl get gitrepository,kustomization,helmrelease -A

# Check sync status
kubectl describe kustomization releases -n flux-system

# Watch Flux logs for errors
kubectl logs -n flux-system -l app=kustomize-controller -f

# Force an immediate sync (don't wait 60 seconds)
flux reconcile kustomization releases --with-source
```

### GitOps Workflow After Flux Is Active

Before Flux:
```
1. Make code change
2. Push to feature branch → PR → dev
3. Run: helm upgrade user-service ./helm/charts/user-service ...
```

After Flux:
```
1. Make code change (e.g. update image tag in values.yaml)
2. Push to feature branch → PR → dev
3. Flux detects the change within 60 seconds → applies automatically
```

Deployments become a git operation. No kubectl/helm commands needed after the initial setup.

---

## Step 9.2 — Cost Optimisation

### Spot Node Pool

Spot VMs are surplus Azure capacity sold at up to **90% discount** compared to on-demand prices. The trade-off: Azure can reclaim them with **30 seconds notice** (eviction).

**When to use spot nodes:**
- Batch jobs (nightly ETL, report generation)
- Queue workers
- CI/CD job runners
- Stateless burst compute

**When NOT to use spot nodes:**
- Stateful services (databases, Redis)
- Services where sudden termination is unacceptable (payment processing)
- System-critical pods (CoreDNS, metrics-server)

### Spot Node Taint and Toleration

The spot node pool is tainted automatically by Azure:
```
kubernetes.azure.com/scalesetpriority=spot:NoSchedule
```

This taint prevents ordinary pods from being scheduled on spot nodes. Only pods that **explicitly tolerate** the taint can land there:

```yaml
# Add this to a Pod spec to allow scheduling on spot nodes
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"

# Add this to prefer spot nodes (not required)
nodeSelector:
  kubernetes.azure.com/scalesetpriority: spot
```

### Spot Node Pool Terraform Config

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                 = var.enable_spot_node_pool ? 1 : 0
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.spot_node_vm_size
  mode                  = "User"

  priority        = "Spot"
  eviction_policy = "Delete"   # Delete VMs on eviction (vs Deallocate which costs disk)
  spot_max_price  = -1         # -1 = cap at on-demand price; no billing surprises
}
```

`spot_max_price = -1` is the recommended default. Setting a low price (e.g. `0.05`) means your node gets evicted more often (whenever spot price exceeds your bid). At `-1` you only get evicted when Azure needs the capacity back, not when the spot price fluctuates.

### Resource Quotas

Two Kubernetes objects that limit resource consumption at the namespace level:

**ResourceQuota** — total hard ceiling for the namespace:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "8"       # total CPU requests across all pods
    limits.cpu: "16"        # total CPU limits across all pods
    requests.memory: "8Gi"
    limits.memory: "16Gi"
    pods: "50"
    services: "20"
```

**LimitRange** — per-container defaults and maximums:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limit-range
  namespace: dev
spec:
  limits:
    - type: Container
      default:            # applied when container omits limits
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:     # applied when container omits requests
        cpu: "100m"
        memory: "128Mi"
      max:                # hard ceiling per container
        cpu: "2"
        memory: "2Gi"
```

**Why LimitRange is needed alongside ResourceQuota:**
ResourceQuota only enforces limits that are already set. A container with no requests/limits completely bypasses quota accounting. LimitRange fills in the gap by injecting defaults, ensuring every container participates in quota enforcement.

### Difference: ResourceQuota vs LimitRange

| | ResourceQuota | LimitRange |
|---|---|---|
| Scope | Namespace total | Individual container |
| What it controls | Sum of all pods' resources | Per-container defaults + max |
| Effect if exceeded | Pod creation rejected | Container injection (for defaults) or rejection (for max) |
| Requires | requests/limits to be set | Sets them if missing |

---

## Step 9.3 — Canary Deployment Pattern

### What is a Canary Deployment?

Named after the canary-in-a-coal-mine metaphor: send a small percentage of real traffic to the new version first. If it behaves correctly, gradually increase the percentage. If it fails, route 100% back to stable instantly.

```
Users
  │
  ├── 80% → Stable service (current production)
  └── 20% → Canary service (new version being validated)
```

Compare to other strategies:

| Strategy | Description | Risk | Rollback |
|---|---|---|---|
| Recreate | Stop old, start new | Full downtime | Redeploy old version |
| Rolling update | Gradually replace pods | Brief mixed-version period | `kubectl rollout undo` |
| Blue/Green | Two full environments, switch DNS | Zero downtime but 2× resource cost | Switch DNS back |
| **Canary** | Small % to new version | Minimal — most traffic still on stable | Delete canary ingress |

### NGINX Canary Implementation

NGINX Ingress Controller supports canary routing via annotations. Two Ingress objects share the same path, and NGINX splits traffic between their backends.

**Stable Ingress** (no canary annotations — this is the default):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: user-service-stable
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - http:
        paths:
          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: user-service    # current production service
                port:
                  number: 3001
```

**Canary Ingress** (marked as canary + weight):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: user-service-canary
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"       # marks this as the canary
    nginx.ingress.kubernetes.io/canary-weight: "20"  # 20% of traffic
spec:
  rules:
    - http:
        paths:
          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: user-service-canary   # new version service
                port:
                  number: 3001
```

NGINX matches both rules on `/api/users`. It routes requests randomly in proportion to the weight. No session affinity — each request is independently weighted.

### Three Canary Routing Strategies

**1. Weight-based (most common):**
```yaml
nginx.ingress.kubernetes.io/canary-weight: "20"
```
Random 20% of all requests go to canary. Stateless, simple.

**2. Header-based (for internal testing):**
```yaml
nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
nginx.ingress.kubernetes.io/canary-by-header-value: "true"
```
Only requests with `X-Canary: true` header go to canary. Lets testers explicitly target the new version without affecting normal users.

**3. Cookie-based (for user cohort testing):**
```yaml
nginx.ingress.kubernetes.io/canary-by-cookie: "canary_user"
```
Requests with the `canary_user` cookie (set to `always`) go to canary. Same user consistently sees either stable or canary — better UX for A/B testing where consistency matters.

### Canary Lifecycle

```
Phase 1: Deploy canary
  kubectl apply -f k8s/ingress/canary-example.yaml
  → 20% traffic to new version

Phase 2: Monitor (watch error rate, latency, alerts)
  kubectl get ingress -n dev
  # Check Grafana dashboard / App Insights for error spikes

Phase 3a: Success → promote
  # Update stable image tag
  # Increase canary-weight: "100" (or delete canary + update stable)
  kubectl delete ingress user-service-canary -n dev

Phase 3b: Failure → rollback
  kubectl delete ingress user-service-canary -n dev
  # 100% traffic instantly returns to stable
```

---

## Interview Questions — Phase 9

**Q1: What is GitOps and how does it differ from traditional CI/CD?**

GitOps is an operating model where git is the single source of truth for the desired cluster state. A reconciliation loop running inside the cluster continuously compares desired state (git) against actual state (cluster) and corrects any drift.

Traditional CI/CD is push-based: the pipeline runs `kubectl apply` to push changes into the cluster. GitOps is pull-based: the cluster pulls its desired state from git. Key differences: (1) git becomes the audit log — every change is a commit, (2) drift is automatically corrected, (3) no cluster credentials are needed in the pipeline since deployments happen from inside the cluster.

**Q2: What is Flux v2? What are its four controllers?**

Flux v2 is a set of Kubernetes controllers that implement GitOps. The four controllers:
- **source-controller**: polls git (or OCI registries) and produces versioned Artifacts consumed by other controllers
- **kustomize-controller**: applies `Kustomization` CRDs — runs kustomize on a path from a source and applies the resulting manifests
- **helm-controller**: reconciles `HelmRelease` CRDs — installs/upgrades Helm charts and performs automated rollback on failure
- **notification-controller**: sends alerts to external systems (Slack, Teams, GitHub commit status) when resources change state

**Q3: How does Flux authenticate to a private Azure DevOps repository?**

Flux's source-controller reads a Kubernetes Secret containing the git credentials. For Azure DevOps HTTPS authentication, the Secret holds a username (any value) and a Personal Access Token (PAT) with Code (Read) permission. When using `azurerm_kubernetes_flux_configuration` in Terraform, the PAT is base64-encoded and passed via `https_key_base64`. The Terraform `sensitive = true` flag on the variable prevents it from appearing in `terraform plan` output.

**Q4: What is the difference between `install.remediation.retries` and `upgrade.remediation.remediateLastFailure` in a HelmRelease?**

`install.remediation.retries` controls how many times the helm-controller retries a first-time installation before marking the release as failed. There is no previous state to roll back to.

`upgrade.remediation.remediateLastFailure: true` tells the helm-controller to automatically rollback to the last successful release when an upgrade fails. This is critical for production — without it, a failed upgrade leaves the cluster in a partially-upgraded broken state. With it, the controller rolls back automatically and the service continues running on the previous version while engineers investigate.

**Q5: What are Azure Spot VMs and when should you use them in AKS?**

Spot VMs are unused Azure capacity offered at up to 90% discount. The trade-off: Azure can reclaim them with 30 seconds notice when capacity is needed. They are safe for batch workloads, queue consumers, and stateless burst compute that can tolerate sudden termination. They are not suitable for stateful workloads (databases), services requiring guaranteed uptime, or Kubernetes system components.

In AKS, spot nodes are tainted with `kubernetes.azure.com/scalesetpriority=spot:NoSchedule`, preventing regular pods from being scheduled there. Only pods that explicitly declare a toleration for that taint can run on spot nodes.

**Q6: What is the difference between ResourceQuota and LimitRange?**

**ResourceQuota** enforces a hard ceiling on the total resources consumed by all objects in a namespace (e.g. total CPU requests, total memory limits, number of pods). If a new pod would exceed the quota, it is rejected at admission.

**LimitRange** operates at the container level — it injects default requests/limits into containers that don't specify them and enforces per-container maximums. The critical relationship: ResourceQuota only counts resources for containers that have requests/limits set. Without a LimitRange, a container with no requests/limits bypasses quota enforcement entirely.

**Q7: Explain the three canary routing strategies supported by NGINX Ingress.**

1. **Weight-based** (`canary-weight: "20"`): routes a random percentage of all traffic to the canary. Simple, stateless. Each request is independently assigned — the same user may see both versions across multiple requests.

2. **Header-based** (`canary-by-header: "X-Canary"`): routes only requests carrying a specific HTTP header to the canary. Used for internal testing — engineers explicitly add the header to target the new version without affecting normal users.

3. **Cookie-based** (`canary-by-cookie: "canary_user"`): routes based on the presence of a cookie. Provides user-level consistency — once a user has the cookie, they always see the canary. Better for A/B testing where inconsistent experiences between requests would confuse users.

**Q8: How does a canary deployment differ from a blue/green deployment?**

Canary: one new version running alongside production, receiving a small % of traffic. Low resource cost (just a few extra pods), gradual validation, easy rollback (delete the canary ingress). Risk exposure is proportional to the canary weight.

Blue/Green: two full environments running simultaneously. A DNS or load balancer switch flips 100% of traffic at once. Zero downtime during the switch, but doubles the resource cost and there's no gradual validation — if something is wrong, all users are affected instantly before rollback.

Canary is better when you want gradual validation with minimal blast radius. Blue/green is better when you need zero-downtime cutover with the ability to instantly revert.

**Q9: What does `garbage_collection_enabled: true` do in a Flux Kustomization?**

When `garbage_collection_enabled` (or `prune: true` in the Flux CLI) is set, Flux tracks all resources it has applied and compares the live cluster state against the desired git state. If a resource exists in the cluster but has been removed from git, Flux deletes it.

Without this, removing a HelmRelease YAML from git would leave the Helm release running in the cluster indefinitely. With garbage collection, the cluster's actual state always converges to git's desired state — removing from git truly removes from the cluster.

**Q10: How does Flux handle drift (manual changes made with kubectl)?**

Flux continuously reconciles on the `interval` cadence (60 seconds in our config). If an engineer manually runs `kubectl delete deployment user-service -n dev`, Flux detects within 60 seconds that the cluster state diverges from git (deployment missing) and re-creates it. This is both a strength (guarantees desired state is maintained) and a risk (manual hotfixes are overwritten). The recommended approach for emergency changes is to commit to git first — Flux will apply within 60 seconds — or temporarily suspend the Kustomization with `flux suspend kustomization releases` to apply manual changes without them being reverted.

---

## Commands Reference

```bash
# Check Flux resource status
kubectl get gitrepository,kustomization,helmrelease -A

# Watch a specific HelmRelease
kubectl describe helmrelease user-service -n dev

# Force immediate reconciliation
flux reconcile kustomization releases --with-source

# Suspend Flux for a namespace (emergency manual changes)
flux suspend kustomization releases

# Resume Flux
flux resume kustomization releases

# Check spot node pool status
kubectl get nodes -l kubernetes.azure.com/scalesetpriority=spot

# Check resource quota usage
kubectl describe resourcequota dev-quota -n dev

# Apply canary ingress
kubectl apply -f k8s/ingress/canary-example.yaml

# Check canary ingress
kubectl get ingress -n dev

# Rollback canary (instant — all traffic back to stable)
kubectl delete ingress user-service-canary -n dev

# Enable spot node pool (Terraform)
# Set in tfvars: enable_spot_node_pool = true
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve

# Enable Flux (Terraform)
# export TF_VAR_git_https_pat="<PAT>"
# export TF_VAR_enable_flux=true
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

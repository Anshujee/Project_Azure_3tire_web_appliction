# Phase 9 — Advanced DevOps Patterns: Question Bank

All questions asked during revision, with full detailed answers.
Covers: GitOps, Flux v2, push vs pull deployment, drift reconciliation, Flux controllers, Azure DevOps PAT auth, HelmRelease remediation, spot VMs, spot taints and tolerations, ResourceQuota vs LimitRange, canary deployment, NGINX canary strategies, blue/green vs canary.

---

## Table of Contents

1. [What is GitOps and How Does It Differ from Traditional CI/CD?](#q1-what-is-gitops-and-how-does-it-differ-from-traditional-cicd)
2. [What is Flux v2? What Are Its Four Controllers?](#q2-what-is-flux-v2-what-are-its-four-controllers)
3. [How Does Flux Authenticate to a Private Azure DevOps Repository?](#q3-how-does-flux-authenticate-to-a-private-azure-devops-repository)
4. [What is the Difference Between install.remediation.retries and upgrade.remediation.remediateLastFailure?](#q4-what-is-the-difference-between-installremediationretries-and-upgraderemediationremediatelastfailure)
5. [What Are Azure Spot VMs and When Should You Use Them in AKS?](#q5-what-are-azure-spot-vms-and-when-should-you-use-them-in-aks)
6. [What is the Difference Between ResourceQuota and LimitRange?](#q6-what-is-the-difference-between-resourcequota-and-limitrange)
7. [Explain the Three Canary Routing Strategies Supported by NGINX Ingress](#q7-explain-the-three-canary-routing-strategies-supported-by-nginx-ingress)
8. [How Does a Canary Deployment Differ from a Blue/Green Deployment?](#q8-how-does-a-canary-deployment-differ-from-a-bluegreen-deployment)
9. [What Does garbage_collection_enabled: true Do in a Flux Kustomization?](#q9-what-does-garbage_collection_enabled-true-do-in-a-flux-kustomization)
10. [How Does Flux Handle Drift (Manual Changes Made with kubectl)?](#q10-how-does-flux-handle-drift-manual-changes-made-with-kubectl)

---

## Q1. What is GitOps and How Does It Differ from Traditional CI/CD?

### The Core Idea

GitOps is an operating model where **git is the single source of truth** for the desired state of your cluster. Instead of a pipeline running `kubectl apply`, an operator running *inside* the cluster watches git and continuously reconciles the cluster toward whatever is in git.

### Push vs Pull

| | Traditional CI/CD (Push) | GitOps (Pull) |
|---|---|---|
| Who deploys | Pipeline (external) pushes to cluster | Operator (inside cluster) pulls from git |
| Trigger | Pipeline run | Git commit |
| Credentials | Pipeline needs kubectl/kubeconfig | Cluster needs git read access only |
| Audit log | Pipeline logs | Git commit history |
| Drift correction | Manual (nobody notices until it breaks) | Automatic (operator re-applies on every interval) |

### The Flow

**Traditional push:**
```
Developer → CI Pipeline → kubectl apply → Cluster
```

**GitOps pull:**
```
Developer → git commit → Cluster (Flux polls git + applies automatically)
```

### Three Guarantees GitOps Gives You

1. **Every live change is in git** — if it's not in git, it doesn't exist on the cluster for long. The operator will revert it.
2. **Drift is self-correcting** — if someone deletes a pod manually, Flux re-creates it within the reconciliation interval (60 seconds in AzureShop).
3. **Rollback is a git revert** — reverting a commit in git triggers a rollback in the cluster automatically. No special runbook needed.

### In AzureShop

Our pipeline (Azure Pipelines) builds images and pushes them to ACR. Updating the image tag in a HelmRelease YAML and merging to `dev` is all that's needed — Flux picks it up and runs `helm upgrade` inside the cluster without the pipeline needing any `kubectl` credentials.

---

## Q2. What is Flux v2? What Are Its Four Controllers?

### What Flux Is

Flux v2 is a set of Kubernetes controllers (installed in the `flux-system` namespace) that implement GitOps. It is CNCF-graduated and has a Microsoft-managed AKS extension, meaning you can install it with a single Terraform resource instead of running `helm install`.

### The Four Controllers

```
┌─────────────────────────────────────────────────────────────┐
│ flux-system namespace                                         │
│                                                               │
│  source-controller       ── fetches git / OCI → Artifacts    │
│  kustomize-controller    ── applies Kustomization CRDs        │
│  helm-controller         ── reconciles HelmRelease CRDs       │
│  notification-controller ── sends alerts (Slack, Teams, etc) │
└─────────────────────────────────────────────────────────────┘
```

**source-controller**
Polls git every 60 seconds (our interval). Produces a versioned tar archive called an **Artifact** from the repo contents. All other controllers consume this Artifact — they never call git directly. This means even if git is temporarily unreachable, the last fetched Artifact is still available.

**kustomize-controller**
Reads `Kustomization` CRDs (not to be confused with a `kustomization.yaml` file). Runs kustomize on the path specified by the Kustomization, then applies the result to the cluster. In AzureShop, it applies all the `HelmRelease` YAML files under `k8s/gitops/releases/`.

**helm-controller**
Reads `HelmRelease` CRDs. Installs or upgrades the specified Helm chart from the git source. Retries failed installs and rolls back failed upgrades when configured to do so. This is the controller that actually runs `helm install` / `helm upgrade` inside the cluster.

**notification-controller**
Watches events from the other three controllers and forwards them to external systems (Slack webhooks, Microsoft Teams, GitHub commit status, Azure DevOps). Not wired up in AzureShop yet but enabled in the extension.

### Key CRDs

```
source.toolkit.fluxcd.io/v1    → GitRepository, HelmRepository, OCIRepository
kustomize.toolkit.fluxcd.io/v1 → Kustomization
helm.toolkit.fluxcd.io/v2      → HelmRelease
```

### How They Connect in AzureShop

```
Terraform creates:
  GitRepository (azureshop) → points to Azure Repos, branch: dev
  Kustomization (releases)  → path: ./k8s/gitops/releases

kustomize-controller reads the Kustomization and applies:
  HelmRelease (user-service)
  HelmRelease (cart-service)
  ... (8 total)

helm-controller reads each HelmRelease and runs:
  helm install/upgrade user-service ./helm/charts/user-service
```

---

## Q3. How Does Flux Authenticate to a Private Azure DevOps Repository?

### The Mechanism

Flux's source-controller reads a **Kubernetes Secret** in the `flux-system` namespace that contains git credentials. The Secret must exist before the `GitRepository` resource is created.

### For Azure DevOps HTTPS

```bash
kubectl create secret generic azureshop-git-credentials \
  --namespace flux-system \
  --from-literal=username=anything \
  --from-literal=password=<AZURE_DEVOPS_PAT>
```

The username can be any non-empty string — Azure DevOps ignores it and uses the PAT as the credential. The PAT needs **Code (Read)** permission only (Flux never writes to git).

The `GitRepository` then references the Secret:
```yaml
spec:
  secretRef:
    name: azureshop-git-credentials
```

### In Terraform (azurerm_kubernetes_flux_configuration)

When using the Terraform resource, credentials are passed directly:
```hcl
git_repository {
  https_user       = var.git_https_user        # any string
  https_key_base64 = base64encode(var.git_https_pat)  # PAT base64-encoded
}
```

Terraform base64-encodes it (the API requires this format). The `git_https_pat` variable is marked `sensitive = true` so it never appears in `terraform plan` output.

### Security Rule

The PAT is never committed to git or stored in tfvars. It is always injected via environment variable:
```bash
export TF_VAR_git_https_pat="<your-pat-here>"
terraform apply ...
```

Same principle as the SQL password — sensitive values live only in the shell environment.

---

## Q4. What is the Difference Between install.remediation.retries and upgrade.remediation.remediateLastFailure?

### Context

Both are settings on a `HelmRelease` that control what the helm-controller does when a Helm operation fails. They cover two different scenarios: first-time install vs upgrade.

### install.remediation.retries

```yaml
install:
  remediation:
    retries: 3
```

Controls what happens when the **first-time installation** of a Helm release fails (the chart has never been successfully installed before).

- The controller retries `helm install` up to 3 times.
- After 3 failures, the HelmRelease is marked as `Failed` and no more retries happen.
- There is **no previous state to roll back to** — this is a brand-new install.

### upgrade.remediation.remediateLastFailure

```yaml
upgrade:
  remediation:
    retries: 3
    remediateLastFailure: true
```

Controls what happens when **upgrading an existing release** fails.

- `retries: 3` — retry the upgrade 3 times.
- `remediateLastFailure: true` — if all retries fail, **automatically roll back to the last successful release**.

Without `remediateLastFailure: true`, a failed upgrade leaves the cluster in a partially-upgraded broken state. The old pods might be gone, the new pods might be crash-looping, and the service is down until an engineer manually intervenes.

With it, the helm-controller rolls back automatically. The service continues running on the previous version while engineers investigate the failure at their own pace.

### Summary Table

| Setting | Scenario | Rollback possible? |
|---|---|---|
| `install.remediation.retries` | First-ever install fails | No — nothing to roll back to |
| `upgrade.remediation.remediateLastFailure: true` | Upgrade fails | Yes — rolls back to last successful release |

---

## Q5. What Are Azure Spot VMs and When Should You Use Them in AKS?

### What Spot VMs Are

Spot VMs are **unused Azure capacity** sold at discount (up to 90% cheaper than on-demand). The trade-off: Azure can **evict** them with 30 seconds notice whenever it needs the capacity back for regular on-demand customers.

### The Eviction Risk

30 seconds is not enough time to gracefully migrate a stateful workload. When Azure evicts a spot node:
1. Azure sends a 30-second warning (via the Instance Metadata Service)
2. After 30 seconds, the VM is deleted (`eviction_policy = "Delete"`)
3. Kubernetes marks the node as `NotReady` and reschedules pods elsewhere
4. Any in-flight work on that node is lost

### When to Use Spot Nodes

**Safe workloads (can tolerate sudden termination):**
- Batch data processing jobs
- Queue consumers (pick up the next message after eviction)
- CI/CD job runners
- Stateless burst compute (extra API replicas during peak)
- ML training jobs that checkpoint progress

**Unsafe workloads (never put on spot):**
- Databases (data loss, replication disruption)
- Redis / Kafka (cluster quorum disruption)
- Payment processing (in-flight transactions lost)
- Kubernetes system components (CoreDNS, metrics-server)

### Taint and Toleration Pattern

Azure automatically taints spot nodes:
```
kubernetes.azure.com/scalesetpriority=spot:NoSchedule
```

This `NoSchedule` taint prevents any regular pod from landing on spot nodes. Only pods that explicitly tolerate the taint can be scheduled there:

```yaml
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
nodeSelector:
  kubernetes.azure.com/scalesetpriority: spot
```

This is a safety gate — you cannot accidentally put a critical service on spot nodes without an intentional code change.

### Terraform Config (AzureShop)

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count           = var.enable_spot_node_pool ? 1 : 0
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1   # -1 = cap at on-demand price, no billing surprise
  node_taints     = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
}
```

`spot_max_price = -1` means: evict when Azure needs capacity, but never pay more than the on-demand price. Setting a low fixed price (e.g. `0.05`) increases eviction frequency whenever the spot market price rises above your bid — `-1` is always safer.

---

## Q6. What is the Difference Between ResourceQuota and LimitRange?

### The Problem They Solve

Without limits, one runaway service (e.g. a memory leak) can consume all cluster resources and starve other services. ResourceQuota and LimitRange are the two Kubernetes primitives that prevent this at the namespace level.

### ResourceQuota — Namespace-Level Ceiling

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "8"        # total CPU requests across all pods
    limits.cpu: "16"         # total CPU limits across all pods
    requests.memory: "8Gi"
    limits.memory: "16Gi"
    pods: "50"
```

When a new pod is created, Kubernetes checks if adding it would push any quota value over the `hard` limit. If yes, the pod is rejected at admission — it never starts.

**The catch:** ResourceQuota only counts resources for containers that have requests/limits explicitly set. A container with no requests/limits is invisible to quota enforcement.

### LimitRange — Container-Level Defaults and Maximums

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limit-range
  namespace: dev
spec:
  limits:
    - type: Container
      defaultRequest:    # injected when container omits requests
        cpu: "100m"
        memory: "128Mi"
      default:           # injected when container omits limits
        cpu: "500m"
        memory: "512Mi"
      max:               # hard ceiling per container
        cpu: "2"
        memory: "2Gi"
```

If a container has no requests/limits → LimitRange injects the `default` and `defaultRequest` values, making the container visible to ResourceQuota.

### Why You Need Both Together

```
Without LimitRange:
  Container omits limits → invisible to ResourceQuota → can consume unlimited resources

With LimitRange:
  Container omits limits → LimitRange injects defaults → now visible to ResourceQuota
```

LimitRange makes ResourceQuota actually work for containers that don't set their own values.

### Key Difference Table

| | ResourceQuota | LimitRange |
|---|---|---|
| **Scope** | Entire namespace (sum of all pods) | Individual container |
| **What it controls** | Cumulative totals + object counts | Per-container defaults, min, max |
| **Enforcement** | Reject pod if namespace total would exceed | Inject defaults; reject if container exceeds max |
| **Requires limits set?** | Yes — containers with no limits bypass it | No — it *sets* the limits if missing |

---

## Q7. Explain the Three Canary Routing Strategies Supported by NGINX Ingress

### Background

When deploying a canary with NGINX Ingress, you create two Ingress objects for the same path. NGINX decides which backend to route a request to based on annotations on the canary Ingress.

### Strategy 1 — Weight-Based (Most Common)

```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "20"
```

Routes a random **20% of all requests** to the canary backend. Each request is independently assigned — stateless, simple. The same user may hit stable on one request and canary on the next.

**Best for:** Gradually validating a new version under real production traffic.

### Strategy 2 — Header-Based

```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
  nginx.ingress.kubernetes.io/canary-by-header-value: "true"
```

Routes only requests that carry the `X-Canary: true` HTTP header to the canary. Normal users without the header always go to stable.

**Best for:** Internal testing — QA engineers or developers explicitly add the header to target the new version without affecting production users.

### Strategy 3 — Cookie-Based

```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-by-cookie: "canary_user"
```

Routes requests with the `canary_user` cookie (value must be `always`) to the canary. Once a user has the cookie, they consistently see the canary on every request.

**Best for:** A/B testing where user experience consistency matters. Without session affinity, a user might see the old UI on one click and the new UI on the next, which is confusing.

### Combining Strategies

Header and cookie take priority over weight. If the header/cookie matches, the request goes to canary regardless of weight. If neither matches, the weight percentage applies.

### Full Canary Lifecycle

```bash
# Deploy canary at 20%
kubectl apply -f k8s/ingress/canary-example.yaml

# Monitor in Grafana — watch error rate and P95 latency

# Success: promote (update stable image, delete canary ingress)
kubectl delete ingress user-service-canary -n dev

# Failure: rollback (all traffic instantly returns to stable)
kubectl delete ingress user-service-canary -n dev
```

---

## Q8. How Does a Canary Deployment Differ from a Blue/Green Deployment?

### Canary Deployment

One new version running alongside production, receiving a **small percentage of traffic**.

```
Users (100%)
  ├── 80% → Stable (v1.0.0)   ← most traffic stays here
  └── 20% → Canary (v1.0.1)   ← new version under validation
```

- **Resource cost:** Low — just a few extra pods for the canary version
- **Rollback:** Delete the canary Ingress — all traffic instantly returns to stable
- **Blast radius:** Proportional to canary weight (20% weight = at most 20% of users see a bug)
- **Validation:** Gradual — you need enough traffic through the canary to be confident

### Blue/Green Deployment

Two **full environments** running simultaneously. Traffic switches 100% at once via a DNS or load balancer change.

```
Users
  │
  ▼
[Load Balancer]
  ├── Blue (v1.0.0)  ← currently receiving 100% (or 0%)
  └── Green (v1.0.1) ← idle (or receiving 100%)
```

- **Resource cost:** High — two full environments, double the compute
- **Rollback:** Switch the load balancer back — instant but affects 100% of users simultaneously
- **Blast radius:** When you switch, 100% of users immediately hit the new version
- **Validation:** None during rollout — the switch is the test

### Comparison Table

| | Canary | Blue/Green |
|---|---|---|
| Traffic split | Gradual % increase | All-at-once switch |
| Resource cost | Low (extra pods only) | High (double environments) |
| Blast radius | Low (limited by weight) | High (full traffic on switch) |
| Rollback | Delete canary ingress | Switch load balancer |
| Validation | Gradual, real traffic | None — switch is the test |
| Best for | Gradual confidence building | Hard cutovers, scheduled releases |

**Interview answer:** Use canary when you want gradual validation with minimal risk exposure. Use blue/green when you need a guaranteed instant cutover (e.g. a compliance deadline) or when a complex database migration makes gradual rollout impossible.

---

## Q9. What Does garbage_collection_enabled: true Do in a Flux Kustomization?

### The Problem It Solves

When Flux applies resources from git, it creates Kubernetes objects (HelmReleases, Deployments, etc.). But what happens when you **delete a file from git**? Without garbage collection, the Kubernetes object stays running forever — Flux only creates and updates, never deletes.

### What garbage_collection_enabled Does

```hcl
kustomizations {
  name                       = "releases"
  garbage_collection_enabled = true
}
```

Flux tracks every resource it has ever applied (stored in the `Kustomization` status). On each reconciliation loop:
1. Fetch the current git state → generate the desired set of resources
2. Compare against the set Flux previously applied
3. **Delete any resources in the "previously applied" set that are no longer in the "desired" set**

In Flux CLI YAML this becomes `prune: true`.

### Concrete Example

```
Before: k8s/gitops/releases/ contains user-service.yaml
Flux creates: HelmRelease/user-service in dev namespace

You delete user-service.yaml from git and merge to dev.

Without garbage collection:
  HelmRelease/user-service keeps running forever
  user-service Helm release stays deployed
  Nobody notices until they look at the cluster directly

With garbage collection:
  Flux sees user-service.yaml is gone from git
  Flux runs helm uninstall user-service
  HelmRelease is deleted
  Cluster matches git state exactly
```

### Why It Matters for GitOps

Garbage collection is what makes git the *true* source of truth. Without it, git only controls what *exists* — you can add resources by adding files, but you can never remove resources by deleting files. With it, the cluster state is always a direct reflection of the git state.

---

## Q10. How Does Flux Handle Drift (Manual Changes Made with kubectl)?

### What is Drift?

Drift is when the **actual cluster state diverges from the desired git state**. This happens when someone runs `kubectl` commands directly on the cluster without going through git:

```bash
kubectl delete deployment user-service -n dev          # drift: deletion
kubectl scale deployment user-service --replicas=10 -n dev  # drift: scale change
kubectl set image deployment/user-service user-service=acr/user-service:v1.0.5  # drift: image change
```

### How Flux Detects and Corrects Drift

Flux's controllers reconcile on a timer — every 60 seconds in AzureShop. On each reconciliation:

1. Fetch the latest Artifact from source-controller (the git snapshot)
2. Compute the desired state from the git files
3. Compare against the live cluster state
4. Apply any differences (re-create missing resources, revert changed values)

If `kubectl delete deployment user-service` was run, Flux detects within 60 seconds that the deployment is missing and re-creates it by running `helm upgrade user-service` again.

### The Two Sides of Drift Correction

**Strength:** Production clusters are self-healing. Accidental changes, config drift from manual debugging, or rogue scripts are all automatically reverted. No manual cleanup needed.

**Risk:** Emergency hotfixes applied via kubectl are reverted on the next reconciliation cycle. A developer who patches a bug directly on the cluster will see their change undone within 60 seconds.

### Correct Approach for Emergency Changes

**Option 1 — Fast commit (preferred):**
```bash
# Fix the bug in git, push to dev
# Flux applies within 60 seconds — same speed as kubectl
```

**Option 2 — Suspend Flux temporarily:**
```bash
# Pause reconciliation so manual changes are not reverted
flux suspend kustomization releases

# Apply the fix manually
kubectl set image deployment/user-service ...

# Resume when the proper fix is merged to git
flux resume kustomization releases
```

Suspending is the escape hatch for genuine emergencies. But the manual change must be followed by a git commit — once Flux resumes, it will revert anything not in git.

### In AzureShop

Reconciliation interval: 60 seconds (both `git_repository.sync_interval_in_seconds` and `kustomizations.sync_interval_in_seconds`). Any kubectl change on the cluster is corrected within one minute.

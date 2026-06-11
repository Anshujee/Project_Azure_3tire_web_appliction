# Phase 6 — AKS Kubernetes: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Pod vs Deployment vs Service, liveness vs readiness probes, namespaces, PodDisruptionBudget, Azure CNI vs Kubenet, kubelogin, Key Vault CSI Driver, kubelet identity vs CSI addon identity, system vs user node pools, Helm vs kubectl apply, HPA, NetworkPolicy zero trust, Kubernetes Secret vs SecretProviderClass, Workload Identity, Kubernetes Nodes and Cluster architecture, Node Pools and types, Zero Downtime deployments, ConfigMap and Secret, Azure CNI deep dive, Azure AD and Azure RBAC for AKS, Managed Identity vs Service Principal, k8s folder structure, Azure VNet Service Endpoints vs Kubernetes Endpoints, Service Endpoint vs Service Principal, Kubernetes Controllers (built-in vs managed), Reconciliation Loop, Cloud Controller Manager, Custom Controllers / Operator Pattern.

---

## Table of Contents

1. [What is the Difference Between a Pod, a Deployment, and a Service?](#q1-what-is-the-difference-between-a-pod-a-deployment-and-a-service)
2. [What is the Difference Between Liveness and Readiness Probes?](#q2-what-is-the-difference-between-liveness-and-readiness-probes)
3. [What is a Namespace and Why Do We Use Multiple Namespaces?](#q3-what-is-a-namespace-and-why-do-we-use-multiple-namespaces)
4. [What is a PodDisruptionBudget and When Does It Matter?](#q4-what-is-a-poddisruptionbudget-and-when-does-it-matter)
5. [What is the Difference Between Azure CNI and Kubenet?](#q5-what-is-the-difference-between-azure-cni-and-kubenet)
6. [What is kubelogin and Why is it Needed for AKS?](#q6-what-is-kubelogin-and-why-is-it-needed-for-aks)
7. [What is the Key Vault CSI Driver and How Does It Work?](#q7-what-is-the-key-vault-csi-driver-and-how-does-it-work)
8. [What is the Difference Between the Kubelet Identity and the CSI Addon Identity?](#q8-what-is-the-difference-between-the-kubelet-identity-and-the-csi-addon-identity)
9. [What is Helm and How is it Different from kubectl apply?](#q9-what-is-helm-and-how-is-it-different-from-kubectl-apply)
10. [What is Workload Identity and Why is it Better Than Mounting Service Principal Credentials?](#q10-what-is-workload-identity-and-why-is-it-better-than-mounting-service-principal-credentials)
11. [What is a Kubernetes Node and Kubernetes Cluster? What are the Components of K8s Architecture?](#q11-what-is-a-kubernetes-node-and-kubernetes-cluster-what-are-the-components-of-k8s-architecture)
12. [What is a Node Pool and Its Types? Is a Node Pool the Same as a Worker Node?](#q12-what-is-a-node-pool-and-its-types-is-a-node-pool-the-same-as-a-worker-node)
13. [What is Zero Downtime and How is it Implemented in AzureShop?](#q13-what-is-zero-downtime-and-how-is-it-implemented-in-azureshop)
14. [What is a ConfigMap and a Secret? How are They Implemented in AzureShop?](#q14-what-is-a-configmap-and-a-secret-how-are-they-implemented-in-azureshop)
15. [What is Azure CNI? How Does it Work and Why Does AzureShop Use it?](#q15-what-is-azure-cni-how-does-it-work-and-why-does-azureshop-use-it)
16. [What is Azure AD and Azure RBAC? How are They Used in AzureShop?](#q16-what-is-azure-ad-and-azure-rbac-how-are-they-used-in-azureshop)
17. [What is the Difference Between a Managed Identity and a Service Principal?](#q17-what-is-the-difference-between-a-managed-identity-and-a-service-principal)
18. [What is the Purpose of Every Folder and File Inside the k8s/ Directory?](#q18-what-is-the-purpose-of-every-folder-and-file-inside-the-k8s-directory)
19. [What are Service Endpoints? (Azure VNet Service Endpoints vs Kubernetes Endpoints)](#q19-what-are-service-endpoints-azure-vnet-service-endpoints-vs-kubernetes-endpoints)
20. [What is the Difference Between a Service Endpoint and a Service Principal?](#q20-what-is-the-difference-between-a-service-endpoint-and-a-service-principal)
21. [What is a Kubernetes Controller? How are Default Controllers Different from Managed Kubernetes Controllers?](#q21-what-is-a-kubernetes-controller-how-are-default-controllers-different-from-managed-kubernetes-controllers)
22. [What is a Kubernetes Service? Full Working, Types, and How AzureShop Uses It?](#q22-what-is-a-kubernetes-service-full-working-types-and-how-azureshop-uses-it)

---

## Q1. What is the Difference Between a Pod, a Deployment, and a Service?

### Pod — The Smallest Unit

A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers that share a network namespace (same IP) and storage volumes.

```
Pod: user-service-7d4f9b-xk2p9
  └── container: user-service (Node.js, port 3001)
```

You almost never create pods directly — they are ephemeral and have no self-healing. If a pod crashes, nothing recreates it.

### Deployment — The Manager

A Deployment manages a set of identical pods. It:
- Ensures the desired number of replicas are always running
- Replaces crashed pods automatically
- Handles rolling updates (replace old pods with new ones gradually)
- Enables rollbacks (`kubectl rollout undo`)

```yaml
spec:
  replicas: 2          # always keep 2 pods running
  selector:
    matchLabels:
      app: user-service
  template:            # pod template — all pods look like this
    spec:
      containers:
        - name: user-service
          image: acrazureshopdev.azurecr.io/user-service:v1.0.0
```

### Service — The Stable Network Address

Pod IPs change every time a pod is restarted. A Service provides a **stable ClusterIP** (virtual IP) that stays the same regardless of pod restarts. It load-balances incoming traffic across all healthy pods matching its `selector`.

```
Caller → ClusterIP (10.0.12.5) — never changes
              ↓ (round-robin)
    ├── pod 10.240.0.7 (healthy)
    └── pod 10.240.0.8 (healthy)
```

### How They Relate

```
You create:  Deployment (user-service, replicas: 2)
    ↓
Kubernetes creates: 2 Pods (user-service-xxx-aaa, user-service-xxx-bbb)
    ↓
Service: ClusterIP points to both pods, load-balances between them
```

In practice: you create a Deployment and a Service. You never touch pods directly.

---

## Q2. What is the Difference Between Liveness and Readiness Probes?

### Liveness Probe — "Is the container alive?"

A liveness failure means the container is stuck, deadlocked, or broken beyond recovery. Kubernetes **restarts the container**.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

If `/health` returns non-2xx three consecutive times, Kubernetes kills and restarts the container. The pod stays in the Deployment but gets a fresh container.

### Readiness Probe — "Should traffic be sent here?"

A readiness failure means the container is alive but temporarily not ready for traffic (initialising, Redis is unavailable, under heavy load). Kubernetes **removes the pod from the Service's endpoint list** — no new requests are sent to it. The container is NOT restarted.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

When readiness recovers, Kubernetes adds the pod back to the endpoint list automatically.

### Startup Probe — "Has the container finished starting?"

A startup probe disables liveness and readiness probes until the container first becomes healthy. Prevents Kubernetes from killing a slow-starting container before it has had a chance to start.

### Summary Table

| | Liveness | Readiness | Startup |
|---|---|---|---|
| Question | Is it alive? | Is it ready for traffic? | Has it started yet? |
| On failure | Restart container | Remove from load balancer | Keep waiting (up to limit) |
| After recovery | N/A (was restarted) | Re-add to load balancer | Enable liveness/readiness |
| Use for | Deadlocks, hung processes | Temporary unavailability, startup | Slow-starting apps |

### In AzureShop

All 8 services expose `GET /health`. It returns HTTP 200 even in degraded state (warn-and-continue pattern) so readiness stays healthy for non-dependent endpoints. All Helm charts configure both probes pointing at `/health`.

---

## Q3. What is a Namespace and Why Do We Use Multiple Namespaces?

### What a Namespace Is

A Namespace is a **virtual partition** inside one Kubernetes cluster. Resources in different namespaces:
- Have isolated names (two services named `user-service` can coexist in different namespaces)
- Have separate Secrets, ConfigMaps, and RBAC permissions
- Can have separate NetworkPolicies and ResourceQuotas

### Why Multiple Namespaces?

**Multi-environment on one cluster** (what AzureShop uses):
```
cluster: aks-azureshop-dev
  namespace: dev       ← all AzureShop services run here
  namespace: monitoring ← kube-prometheus-stack, Grafana, Alertmanager
  namespace: ingress-nginx ← NGINX Ingress Controller
  namespace: kube-system ← Kubernetes system components
```

Benefit: one cluster instead of three (dev/staging/prod each). Cost saving. Risk: misconfigured NetworkPolicy could allow cross-namespace access.

**Team isolation** (not used in AzureShop but common in enterprises): team-a and team-b each get their own namespace with separate RBAC permissions. Team-a cannot accidentally delete team-b's resources.

### Resource Isolation per Namespace

```bash
# Secrets are namespace-scoped
kubectl get secret -n dev          # only dev secrets
kubectl get secret -n monitoring   # only monitoring secrets

# RBAC is namespace-scoped
# A user with get/list on pods in dev cannot see pods in monitoring
```

### In AzureShop

The `dev` namespace has:
- Pod Security Admission labels (`enforce: restricted`) — enforces the restricted pod security standard
- All 8 application Helm releases
- SecretProviderClasses that mount Key Vault secrets

The `monitoring` namespace (created by kube-prometheus-stack) has:
- Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics
- Completely separate from application namespace — no cross-namespace access by default

---

## Q4. What is a PodDisruptionBudget and When Does It Matter?

### The Problem It Solves

During node drains (maintenance, upgrades, scaling down), Kubernetes evicts pods to move them elsewhere. Without a PDB, Kubernetes might evict all replicas of a Deployment at once:

```
Deployment: user-service, replicas: 2
Node drain starts → evicts pod 1 → evicts pod 2 (immediately)
Result: zero user-service pods running → complete outage
```

### What a PDB Does

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: user-service
```

`minAvailable: 1` tells the eviction API: "you may only evict a pod from this group if at least 1 other pod is already running and healthy." The drain waits for a replacement pod to be running and ready before evicting the next one.

```
Node drain starts
  → tries to evict pod 1
  → PDB check: will 1 pod remain? YES → evict pod 1
  → Kubernetes schedules pod 1 replacement on another node
  → waits for replacement to be Ready
  → tries to evict pod 2
  → PDB check: will 1 pod remain? YES → evict pod 2
Result: at least 1 pod always running → no downtime
```

### Important Limitation

PDBs only protect against **voluntary disruptions** (planned: drain, scale-down, upgrade). They do NOT protect against **involuntary disruptions** (node crash, hardware failure). For involuntary disruptions, multiple replicas across nodes is the only protection.

### In AzureShop

All 8 Helm charts include a PDB with `minAvailable: 1`. This means AKS node upgrades (which drain nodes one at a time) will not cause service outages as long as we have at least 2 replicas.

---

## Q5. What is the Difference Between Azure CNI and Kubenet?

### Kubenet — Simple, Limited

Pods get IPs from a **private range** outside the VNet (e.g. 10.244.0.0/16). The AKS node NATs (translates) pod traffic to its own VNet IP when communicating externally.

```
Pod IP: 10.244.0.5  (non-VNet, private)
Node IP: 10.0.1.4   (VNet IP)

External Azure service sees traffic from 10.0.1.4 (node IP), not pod IP
```

Problems: Azure services (NSGs, SQL VNet rules, firewalls) cannot target individual pod IPs. Network monitoring is harder — you see node IPs, not pod IPs.

### Azure CNI — Enterprise Grade

Every pod gets a **real VNet IP** from the VNet's address space.

```
Pod IP: 10.0.2.7  (real VNet IP — directly routable)
Node IP: 10.0.1.4  (VNet IP)

External Azure service sees traffic from 10.0.2.7 (pod IP directly)
```

Benefits:
- NSGs can target individual pod IPs
- VNet firewall rules work on pod traffic
- SQL and Cosmos DB VNet service endpoints accept connections from pod IPs directly
- Direct peering — pod IPs are reachable from on-premises via ExpressRoute

Trade-off: every pod consumes one real VNet IP address. A VNet subnet must be large enough for all pods (nodes × max_pods_per_node).

### In AzureShop

We use **Azure CNI** because cart-service connects to Redis, user-service connects to Azure SQL — these Azure PaaS services have VNet rules that filter by source IP. With Kubenet, SQL would see the node IP (shared by all pods on that node) and we'd lose pod-level network isolation. With Azure CNI, each pod has its own VNet IP.

---

## Q6. What is kubelogin and Why is it Needed for AKS?

### The Problem

AKS with Azure AD RBAC requires Azure AD tokens for `kubectl` authentication. Regular `kubectl` does not know how to fetch Azure AD tokens — it only supports certificate-based auth, static bearer tokens, and username/password.

### What kubelogin Does

`kubelogin` is a credential plugin that extends `kubectl` with Azure AD authentication. It hooks into kubectl's exec-based auth mechanism:

```bash
# Rewrite the kubeconfig to use kubelogin
kubelogin convert-kubeconfig -l azurecli

# After this, every kubectl command:
kubectl get pods -n dev
  → kubectl calls kubelogin
  → kubelogin calls Azure CLI to get a fresh Azure AD token
  → passes token to the AKS API server
  → AKS validates token against Azure AD
  → returns results
```

### Authentication Flow

```
kubectl → kubelogin → Azure CLI (already logged in)
                         ↓
                      Azure AD → returns short-lived token
                         ↓
           AKS API server validates token
                         ↓
              Azure RBAC determines what you can do
              (Cluster Admin role → full access)
```

### Login Modes

| Mode | Command | Use case |
|---|---|---|
| Azure CLI (`azurecli`) | `kubelogin convert-kubeconfig -l azurecli` | Local developer, already logged in via `az login` |
| Service Principal | `kubelogin convert-kubeconfig -l spn` | CI/CD pipelines (non-interactive) |
| Managed Identity | `kubelogin convert-kubeconfig -l msi` | Azure VMs / AKS nodes authenticating to themselves |

In AzureShop local development we use `azurecli` mode — `az login` is done once, kubelogin handles token refresh transparently.

---

## Q7. What is the Key Vault CSI Driver and How Does It Work?

### The Problem It Solves

Secrets (SQL passwords, Redis passwords) must not be stored in:
- Docker images (visible to anyone with pull access)
- Kubernetes Secrets without encryption at rest (stored as base64 in etcd)
- Application code or config files (version-controlled, visible in git)

### How the CSI Driver Works

```
Pod scheduled on node
  ↓
kubelet asks CSI driver: "mount this SecretProviderClass for this pod"
  ↓
CSI driver authenticates to Key Vault using AKS addon Managed Identity
  ↓
CSI driver fetches specified secrets from Key Vault
  ↓
CSI driver writes secrets as files to a tmpfs volume inside the pod
  ↓
CSI driver creates a Kubernetes Secret from the fetched values
  ↓
Pod reads the Kubernetes Secret as environment variables
```

The pod never calls Key Vault directly. The CSI driver handles authentication and secret retrieval. Secrets are fetched fresh every time a pod starts (and refreshed every 2 minutes with `secret_rotation_enabled = true`).

### The SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: user-service-secrets
  namespace: dev
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "d755c00c-..."         # CSI addon identity client ID
    keyvaultName: "kv-azureshop-6a6c-dev"
    objects: |
      - objectName: sql-server
        objectType: secret
      - objectName: sql-password
        objectType: secret
  secretObjects:
    - secretName: user-service-secrets
      type: Opaque
      data:
        - objectName: sql-server
          key: SQL_SERVER
        - objectName: sql-password
          key: SQL_PASSWORD
```

### Secret Rotation

With `secret_rotation_enabled = true` and `secret_rotation_interval = "2m"`, the CSI driver re-fetches secrets from Key Vault every 2 minutes. If you rotate a password in Key Vault, the running pods pick it up within 2 minutes — no pod restart required.

---

## Q8. What is the Difference Between the Kubelet Identity and the CSI Addon Identity?

### AKS Has Two Separate Managed Identities

| | Kubelet Identity | CSI Addon Identity |
|---|---|---|
| Also called | Node identity | Secrets Provider identity |
| Used by | AKS nodes (the VMs) | Key Vault CSI Driver addon |
| Purpose | Pull images from ACR, write logs to Azure Monitor | Fetch secrets from Key Vault |
| How to get ID | `module.aks.kubelet_identity_object_id` | `module.aks.addon_identity_object_id` |
| Role needed | `AcrPull` on ACR | `Key Vault Secrets User` on Key Vault |

### Why They Are Separate

Security principle of least privilege. The kubelet identity needs ACR pull access — giving it Key Vault access would be unnecessary. The CSI addon identity needs Key Vault access — giving it ACR or Azure Monitor write access would be unnecessary.

If a node is compromised, the attacker gets the kubelet identity. If they could use it to access Key Vault, all secrets are exposed. Separating the identities limits the blast radius.

### The Common Mistake

**Assigning `Key Vault Secrets User` to the kubelet identity does not help the CSI driver.** The CSI driver only uses its own addon identity. This is a very common misconfiguration that results in "access denied" errors from the CSI driver even though the "right" identity appears to have the role.

In AzureShop Terraform:
```hcl
# CORRECT — grant the addon identity (not kubelet) to Key Vault
resource "azurerm_role_assignment" "csi_keyvault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.addon_identity_object_id  # ← addon, not kubelet
}
```

---

## Q9. What is Helm and How is it Different from kubectl apply?

### kubectl apply — Static Files

```bash
kubectl apply -f user-service-deployment.yaml
kubectl apply -f user-service-service.yaml
kubectl apply -f user-service-hpa.yaml
```

Fixed values in YAML. To change the image tag, edit the file. To deploy the same app to staging with different replicas, maintain a separate copy of the YAML. With 8 services × 6 files each = 48 YAML files with duplicated structure.

### Helm — Templated Package Manager

Helm treats related Kubernetes resources as one unit called a **release** and uses Go templates to parameterise values.

```
helm/charts/user-service/
  Chart.yaml            ← chart metadata
  values.yaml           ← default values (image tag, replicas, ports)
  templates/
    deployment.yaml     ← template with {{ .Values.image.tag }}
    service.yaml
    hpa.yaml
    pdb.yaml
    networkpolicy.yaml
    serviceaccount.yaml
```

Deploy with:
```bash
helm upgrade --install user-service ./helm/charts/user-service \
  --namespace dev \
  --set image.tag=v1.0.2
```

One chart works for dev, staging, and prod — only the values change.

### Key Helm Advantages

| Feature | kubectl apply | Helm |
|---|---|---|
| Parameterisation | None — hardcoded values | Go templates with values.yaml |
| Release tracking | None | `helm list` shows all releases, versions, status |
| Rollback | Manual — reapply old YAML | `helm rollback user-service 2` — one command |
| Atomic updates | Partial — applies files independently | Transactional — all succeed or all roll back |
| Install vs upgrade | Separate create/apply logic | `helm upgrade --install` handles both |

### Values Override Priority (Low → High)

1. `values.yaml` in the chart (defaults)
2. `-f override.yaml` flag (environment-specific overrides)
3. `--set key=value` flag (one-off overrides)

In AzureShop we use `--set image.tag=$(imageTag)` in deploy pipelines to inject the CI build ID as the image tag, overriding the `values.yaml` default.

---

## Q10. What is Workload Identity and Why is it Better Than Mounting Service Principal Credentials?

### The Old Way — Service Principal Credentials in Pods

```
1. Create Service Principal → get client ID + secret
2. Store secret in Kubernetes Secret
3. Mount Secret as env vars into pod
4. Pod uses client ID + secret to get Azure AD token
5. Use token to call Azure Key Vault / Service Bus
```

Problems:
- Secret has to be **manually rotated** (often forgotten → outage)
- Stored in Kubernetes etcd — without encryption at rest, base64 is trivially decoded
- Could be accidentally logged or printed
- If pod is compromised, attacker has a **long-lived credential** that works until rotated

### Workload Identity — No Credentials Stored Anywhere

Workload Identity binds a Kubernetes ServiceAccount to an Azure Managed Identity. The pod proves its identity using a short-lived Kubernetes-issued token (not a password).

### The Five Components

**1. OIDC Issuer on AKS** (`oidc_issuer_enabled = true`)
AKS exposes a public OIDC endpoint so Azure AD can verify tokens the cluster signed.

**2. Workload Identity Webhook** (`workload_identity_enabled = true`)
A mutating webhook that automatically injects env vars and a projected token into any pod labeled `azure.workload.identity/use: "true"`.

**3. User Assigned Managed Identity**
The Azure identity the pod will impersonate (e.g. `id-notification-service-dev`). Has role assignments that control what it can access.

**4. Federated Identity Credential**
The trust bridge — tells Azure AD: "If you see a token signed by AKS's OIDC issuer with subject `system:serviceaccount:dev:notification-service`, issue a token for this Managed Identity."

**5. ServiceAccount Annotation + Pod Label**
```yaml
# ServiceAccount
annotations:
  azure.workload.identity/client-id: "2e5e41cb-..."

# Pod
labels:
  azure.workload.identity/use: "true"
```

### The Token Exchange Flow

```
Pod starts with label azure.workload.identity/use: "true"
  ↓
Webhook injects projected ServiceAccount token (scoped to api://AzureADTokenExchange)
  ↓
App calls Azure SDK (e.g. KeyVaultClient)
  ↓
SDK reads AZURE_CLIENT_ID env var + reads projected token from file
  ↓
SDK sends token exchange request to Azure AD
  ↓
Azure AD validates: correct OIDC issuer? correct subject? federated credential exists?
  ↓
Azure AD issues short-lived (1 hour) access token for the Managed Identity
  ↓
App calls Key Vault / Service Bus using the access token
```

### Comparison

| | Service Principal Secret | Workload Identity |
|---|---|---|
| Credential stored | Yes — in Kubernetes Secret | No — no secret anywhere |
| Expiry | Long-lived (until rotated) | Short-lived (1 hour, auto-refreshed) |
| Rotation | Manual | Automatic |
| Exposure risk | etcd, logs, env vars | None — projected token not the final credential |
| Audit | Shared — all pods use same SP | Per-identity — each service has its own MI |

In AzureShop, notification-service uses Workload Identity to authenticate to Service Bus without any credentials stored in the pod or in Kubernetes Secrets.

---

## Q11. What is a Kubernetes Node and Kubernetes Cluster? What are the Components of K8s Architecture?

### The Analogy — A City

Think of a Kubernetes Cluster as a city:

```
┌─────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER                   │
│                                                          │
│  ┌──────────────────────┐                                │
│  │   CONTROL PLANE       │  ← City Hall (makes decisions)│
│  │   (the brain)         │                               │
│  └──────────────────────┘                                │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │  NODE 1  │  │  NODE 2  │  │  NODE 3  │  ← Buildings  │
│  │ (worker) │  │ (worker) │  │ (worker) │  (do the work)│
│  └──────────┘  └──────────┘  └──────────┘               │
└─────────────────────────────────────────────────────────┘
```

- **Cluster** = the entire city (everything together)
- **Control Plane** = City Hall (decides what runs where, watches for problems)
- **Worker Nodes** = office buildings (where actual containers run)
- **Pods** = offices inside buildings (where your app lives)

### What is a Cluster?

A Cluster is the complete Kubernetes environment — the control plane + all worker nodes together. When you ran `az aks create` in Phase 6, Azure created one complete cluster:

```
Cluster: aks-azureshop-dev
  ├── Control Plane (managed by Azure — you never touch it)
  └── Node Pool: system (2 nodes) + user (2 nodes)
```

### What is a Node?

A Node is a virtual machine (VM) that is part of the cluster. Your containers actually run on nodes.

```
Node = Azure VM running Linux
  ├── kubelet        (agent that talks to control plane)
  ├── kube-proxy     (handles network routing)
  ├── containerd     (runs the containers)
  └── Your Pods      (user-service, cart-service, etc.)
```

**Cluster vs Node in one line:**
> A cluster is the whole city. A node is one building inside that city.

### Full K8s Architecture — Every Component

```
┌──────────────────────────────────────────────────────────────────┐
│                        CONTROL PLANE                              │
│  ┌─────────────┐  ┌──────┐  ┌────────────────┐  ┌────────────┐  │
│  │  API Server  │  │ etcd │  │   Scheduler    │  │ Controller │  │
│  │             │  │      │  │                │  │  Manager   │  │
│  └─────────────┘  └──────┘  └────────────────┘  └────────────┘  │
└──────────────────────────────────────────────────────────────────┘
         ▲  ▼
┌────────────────────────────────────────────────────────────────────┐
│                        WORKER NODE                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                    │
│  │  kubelet   │  │ kube-proxy │  │ containerd │                    │
│  └────────────┘  └────────────┘  └────────────┘                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                          │
│  │  Pod     │  │  Pod     │  │  Pod     │                          │
│  └──────────┘  └──────────┘  └──────────┘                          │
└────────────────────────────────────────────────────────────────────┘
```

### Control Plane Components

**1. API Server (`kube-apiserver`)**
The front door to the entire cluster. Every operation goes through it — kubectl, scheduler, kubelet all talk to the API Server. In AKS it lives at `aks-azureshop-dev.hcp.eastus.azmk8s.io:443`.

**2. etcd**
The cluster's database. Stores ALL state — what Deployments exist, what pods are running, all ConfigMaps, Secrets, RBAC rules. If etcd is lost, the cluster loses all its memory. Azure backs it up automatically in AKS.

**3. Scheduler (`kube-scheduler`)**
Decides which node a new pod should run on. Checks available CPU/memory, nodeSelectors, taints, and affinity rules. Writes the decision back to API Server.

**4. Controller Manager (`kube-controller-manager`)**
The reconciliation engine. Continuously watches "what IS" vs "what SHOULD BE" and fixes the gap.

| Controller | What It Does |
|---|---|
| Deployment Controller | Creates/deletes ReplicaSets |
| ReplicaSet Controller | Creates/deletes Pods to match replica count |
| Node Controller | Marks nodes unhealthy if they stop reporting |

Real example: Pod crashes at 3am → ReplicaSet Controller detects gap → Scheduler picks a node → kubelet starts new pod. Fully automatic.

**5. Cloud Controller Manager**
Bridges Kubernetes and Azure. When you create a Service of type LoadBalancer, it calls the Azure API to provision a Public Load Balancer and assign an IP. In AzureShop, NGINX Ingress got its external IP `134.33.223.224` this way.

### Worker Node Components

**6. kubelet**
Node agent running on every worker node. Watches the API Server for pods assigned to its node, tells containerd to pull and start containers, runs health probes, reports pod status back to control plane.

**7. kube-proxy**
Maintains iptables rules on the node. Every time a ClusterIP Service is created, kube-proxy updates routing rules so traffic to the virtual ClusterIP gets load-balanced to the correct pod IPs.

**8. containerd**
The actual engine that runs containers. kubelet tells containerd: "start this image." containerd pulls from ACR and runs it. Note: Docker was removed in Kubernetes 1.24+. AKS uses containerd directly. Docker-built images still work (OCI standard).

### What Happens When You Deploy

```
kubectl apply -f deployment.yaml

1. kubectl → API Server: "Create this Deployment"
2. API Server → saves to etcd
3. Deployment Controller → creates ReplicaSet
4. ReplicaSet Controller → creates Pod objects (no node yet)
5. Scheduler → picks nodes → updates etcd
6. kubelet on node → tells containerd to pull image → container starts
7. kube-proxy → updates iptables on all nodes
8. kubectl get pods → API Server reads etcd → shows Running
```

### In AzureShop Context

| Component | AzureShop Reality |
|---|---|
| API Server | Azure managed — never touched directly |
| etcd | Azure managed, auto-backed up |
| Scheduler | Placed system pods on system pool, app pods on user pool |
| Controller Manager | Kept all 9 services running, handles rolling updates |
| Cloud Controller Manager | Gave NGINX Ingress its external IP `134.33.223.224` |
| kubelet | Pulled images from `acrazureshopdev.azurecr.io`, ran health probes |
| kube-proxy | Handled ClusterIP routing between all 8 services |
| containerd | Actually ran all containers |

### Interview Prep

1. **What is the difference between a cluster and a node?** — Cluster is the complete environment (control plane + all nodes). A node is one VM inside the cluster where pods run.
2. **What does etcd store and why is it critical?** — All cluster state. If lost, cluster doesn't know what exists. Source of truth.
3. **What is the difference between kubelet and the API Server?** — API Server is the control plane's front door. kubelet is a node-level agent that receives instructions and actually starts/stops containers.
4. **What happens when a pod crashes at 3am?** — ReplicaSet Controller detects gap → Scheduler picks a node → kubelet starts the new container. Automatic.
5. **Why was Docker removed as a container runtime?** — Docker added an extra layer (dockershim). Kubernetes removed the middleman and uses containerd directly. OCI-standard images still work.

---

## Q12. What is a Node Pool and Its Types? Is a Node Pool the Same as a Worker Node?

### The Short Answer

> **A Node Pool is NOT the same as a Worker Node.**
> A Node Pool is a **group of worker nodes** that share the same configuration.

### The Analogy — A Company With Departments

```
Company = Kubernetes Cluster
  │
  ├── Department: Engineering  ← Node Pool 1 (System)
  │     ├── Employee 1         ← Worker Node (VM)
  │     └── Employee 2         ← Worker Node (VM)
  │
  └── Department: Operations   ← Node Pool 2 (User)
        ├── Employee 3         ← Worker Node (VM)
        └── Employee 4         ← Worker Node (VM)
```

Every employee in the same department has the same desk setup and tools → same VM size, OS, config. You scale the whole department, not individual employees.

### What is a Node Pool?

A Node Pool is a group of worker nodes (VMs) that all share the same VM size, OS, Kubernetes version, taints, labels, and auto-scaling config. When you scale from 2 → 4 nodes, Azure spins up 2 more VMs with identical config automatically.

### Node Pool vs Worker Node

| | Worker Node | Node Pool |
|---|---|---|
| **What it is** | One individual VM | A group of VMs |
| **Level** | Instance level | Group/configuration level |
| **You manage** | Never directly | Yes — size, count, type |
| **Analogy** | One employee | The whole department |
| **Scale unit** | 1 VM | Many VMs at once |

### Types of Node Pools in AKS

**Type 1 — System Node Pool**
```
Purpose: Run Kubernetes internal (system) components
Required: YES — every AKS cluster must have at least one
Taint:    CriticalAddonsOnly=true:NoSchedule
```
Runs: CoreDNS, metrics-server, CSI driver pods, kube-proxy. The taint prevents app pods from landing here. Separation prevents app pods from starving system components.

**Type 2 — User Node Pool**
```
Purpose: Run YOUR application workloads
Required: NO — but strongly recommended
```
In AzureShop: user-service, product-service, cart-service, order-service, payment-service, notification-service, frontend, api-gateway all run here. You can have multiple user pools with different VM sizes for different workload types.

**Type 3 — Spot Node Pool**
```
Purpose:  Cost saving — use Azure's unused capacity
Cost:     Up to 90% cheaper than regular VMs
Risk:     Azure can evict nodes with 30 seconds notice
Use for:  Non-critical, fault-tolerant workloads only
```
Built in Phase 9 with `priority = "Spot"` and `eviction_policy = "Delete"`. A taint ensures only pods that tolerate eviction land on spot nodes. Critical services never run here.

### In AzureShop

```
Cluster: aks-azureshop-dev
│
├── System Node Pool (2 VMs — Standard_D2s_v3)
│     ├── Node: aks-system-vmss000000 → CoreDNS, CSI driver
│     └── Node: aks-system-vmss000001 → CoreDNS replica, metrics-server
│
└── User Node Pool (2 VMs — Standard_D2s_v3)
      ├── Node: aks-user-vmss000000 → user-service, product-service, cart-service
      └── Node: aks-user-vmss000001 → order-service, payment-service, frontend
```

### Interview Prep

1. **What is the difference between a node pool and a worker node?** — A worker node is one VM. A node pool is a group of VMs with identical configuration. You manage node pools; AKS manages individual VMs inside them.
2. **Why does AKS require a system node pool?** — System components like CoreDNS must always run. The system pool is dedicated with a taint that prevents app pods from consuming its resources.
3. **When would you use a Spot node pool?** — Non-critical, fault-tolerant workloads where cost matters more than availability — batch jobs, dev environments. Never for stateful or user-facing services.
4. **Can one cluster have multiple user node pools?** — Yes. Common pattern: one pool for CPU-heavy, one for memory-heavy, one for GPU. Use `nodeSelector` to target the right pool.

---

## Q13. What is Zero Downtime and How is it Implemented in AzureShop?

### WHY Zero Downtime Matters

Without Zero Downtime: Old pods stop → new pods start → 20-second gap → all requests fail → users see errors → business loses revenue.

With Zero Downtime: New pods start alongside old pods → new pod passes health check → gets traffic → old pod finishes current requests → shuts down. Users never see a single error.

### The 5 Mechanisms That Together Give Zero Downtime

**Mechanism 1 — Multiple Replicas**

The foundation. With 1 replica there is always a gap when old pod dies and new one starts. With 2+ replicas, pods are replaced one at a time — never a gap.

In AzureShop: All 8 services run with `replicas: 2` minimum. HPA scales more under load.

**Mechanism 2 — Rolling Update Strategy**

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0    # never go below desired replica count
    maxSurge: 1          # allow 1 extra pod during update
```

Step by step with replicas: 2:
```
Start:   [v1-A ✅]  [v1-B ✅]
Step 1:  [v1-A ✅]  [v1-B ✅]  [v2-C 🔄 starting]   ← maxSurge=1
Step 2:  [v1-A ✅]  [v1-B ✅]  [v2-C ✅ ready]       ← passes readiness probe
Step 3:  [v1-A ✅]  [v1-B terminating]  [v2-C ✅]    ← old removed AFTER new ready
Step 4:  [v2-D ✅]  [v2-C ✅]                        ← update complete
```
At every step at least 2 pods serve traffic. No gap.

**Mechanism 3 — Readiness Probe (The Traffic Gate)**

Without readiness probe: new pod added to load balancer immediately on start — app still initialising → 502 errors.

With readiness probe: pod only gets traffic after `/health` returns 200 three times. Acts as the bouncer — pod does not get customers until it proves it is ready.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

**Mechanism 4 — Graceful Shutdown**

```
Step 1: Pod removed from Service endpoints (no new requests)
Step 2: SIGTERM sent to container
Step 3: App has 30s to finish current requests + close DB connections
Step 4: After 30s → SIGKILL
```

In AzureShop Node.js services:
```javascript
process.on('SIGTERM', async () => {
  await pool.close();
  server.close();
  process.exit(0);
});
```

**Mechanism 5 — PodDisruptionBudget**

Protects against voluntary disruptions (node drain during AKS upgrades). `minAvailable: 1` means: drain can only evict a pod if at least 1 other replica is already running. Drain waits for replacement before evicting next pod. Always at least 1 pod running.

### In AzureShop Helm Chart

```yaml
# Deployment
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
terminationGracePeriodSeconds: 30

# PDB
spec:
  minAvailable: 1

# Pipeline
helm upgrade --install user-service ./helm/charts/user-service \
  --wait --timeout 5m --atomic
```

`--atomic`: if new pods fail readiness probes, Helm auto-rolls back. Old version keeps serving throughout.

### Bonus — Canary Deployment (Phase 9)

20% of traffic routed to new version while 80% goes to stable:
```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "20"
```
Test on real traffic with small blast radius. If errors appear → set weight to 0% instantly.

### Interview Prep

1. **What is the difference between `maxUnavailable` and `maxSurge`?** — `maxUnavailable`: how many pods can be unavailable during update. `maxSurge`: how many extra pods above desired can exist. Setting `maxUnavailable: 0, maxSurge: 1` gives true zero downtime.
2. **What does `--atomic` do in Helm?** — If deployment fails (pods don't become ready within timeout), Helm auto-rolls back to previous release.
3. **What is graceful shutdown?** — Gives container time to finish in-flight requests before dying. Without it, a pod killed mid-request returns a broken response.
4. **What is a canary deployment?** — Routing a small % of real traffic to new version while stable version handles the rest. Test in production with limited blast radius.

---

## Q14. What is a ConfigMap and a Secret? How are They Implemented in AzureShop?

### The Problem They Solve

Hardcoding config in Docker images means rebuilding for every environment. Hardcoding passwords in images means anyone with pull access can read them.

**The fix:** Separate configuration from the image entirely.
```
Image      = app code only  (same image for all environments)
ConfigMap  = non-sensitive config  (different per environment)
Secret     = sensitive config      (protected)
```

### What is a ConfigMap?

Stores non-sensitive key-value configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-service-config
  namespace: dev
data:
  PORT: "3001"
  DB_NAME: "db-users"
  SERVICE_BUS_ORDERS_TOPIC: "orders"
```

What goes in: port numbers, database names, feature flags, log levels, topic names.
What does NOT go in: passwords, API keys, connection strings with credentials.

> ConfigMap is like a notice board — everyone can see it, nothing sensitive goes on it.

### What is a Secret?

Stores sensitive data. Values are base64 encoded (NOT encrypted). Kubernetes handles them more carefully — not written to disk, only sent to nodes that need them.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: user-service-secrets
type: Opaque
data:
  DB_PASSWORD: TXlTZWNyZXQxMjM=    # base64 — NOT encryption
  JWT_SECRET: c3VwZXJzZWNyZXQ=
```

**Important:** base64 is trivially decoded. Raw Kubernetes Secrets are not production-grade security alone. Combine with RBAC + etcd encryption, or better — use Key Vault CSI Driver (what AzureShop does).

### Two Ways to Inject Into a Pod

**Option A — `envFrom` (inject all keys at once):**
```yaml
envFrom:
  - configMapRef:
      name: user-service-config
  - secretRef:
      name: user-service-secrets
```

**Option B — Mounted as files:**
```yaml
volumeMounts:
  - name: config-volume
    mountPath: /etc/config
volumes:
  - name: config-volume
    configMap:
      name: user-service-config
```

### How AzureShop Implements This — Three Layers

**Layer 1 — ConfigMap (Helm template):** PORT, DB_NAME, topic names. Values from `values.yaml`, different per environment.

**Layer 2 — Secrets live in Azure Key Vault:** sql-admin-password, cosmos-key, redis-key. Never written to YAML files or Docker images.

**Layer 3 — CSI Driver bridges Key Vault → K8s Secret:**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
spec:
  provider: azure
  parameters:
    clientID: "d755c00c-..."
    keyvaultName: "kv-azureshop-6a6c-dev"
    objects: |
      - objectName: sql-admin-password
        objectType: secret
  secretObjects:
    - secretName: user-service-secrets
      type: Opaque
      data:
        - objectName: sql-admin-password
          key: DB_PASSWORD
```

CSI Driver fetches from Key Vault → creates K8s Secret automatically → pod reads it as env var. Secret rotates every 2 minutes without pod restart.

### ConfigMap vs Secret

| | ConfigMap | Secret |
|---|---|---|
| Purpose | Non-sensitive config | Sensitive data |
| Storage | Plain text | Base64 |
| Encryption | No | Only with etcd encryption |
| In AzureShop | Helm creates it | CSI Driver creates from Key Vault |
| Rotation | Manual redeploy | CSI Driver: auto every 2 min |

### Interview Prep

1. **What is the difference between ConfigMap and Secret?** — ConfigMap stores non-sensitive config (port, db name). Secret stores sensitive data (passwords). Both inject as env vars but Secret values are base64 encoded and RBAC-protected.
2. **Is a Kubernetes Secret secure?** — Not by itself. base64 is not encryption. Combine with etcd encryption at rest, strict RBAC, or use Azure Key Vault CSI Driver.
3. **What is `envFrom` vs `env`?** — `envFrom` injects ALL keys from a ConfigMap or Secret at once. `env` with `valueFrom` injects one key at a time.
4. **Why not store secrets in ConfigMaps?** — ConfigMaps have no separate RBAC controls. Anyone who can read the namespace can read all ConfigMaps.

---

## Q15. What is Azure CNI? How Does it Work and Why Does AzureShop Use it?

### What is CNI?

CNI = Container Network Interface. It is a standard/specification defining how networking plugins assign IPs to pods. Azure CNI is Microsoft's implementation that integrates pod networking directly with Azure VNet.

```
CNI standard (like a plug socket standard)
  └── Implementations:
        ├── Azure CNI    (Microsoft — gives pods real VNet IPs)
        ├── Kubenet      (Kubernetes default — pods get internal-only IPs)
        └── Calico/Cilium (open source alternatives)
```

### The Analogy — Two Types of Cities

**Kubenet City (old system):**
Buildings (nodes) have official addresses. Rooms (pods) inside have internal-only addresses unknown to the outside city. When a pod communicates externally, the building manager (NAT) replaces the pod IP with the node IP. Azure only sees the node IP.

**Azure CNI City (new system):**
Every room (pod) has its own official city address — a real VNet IP. Mail is delivered directly. No building manager intercepting it. Azure sees the exact pod IP.

### Kubenet vs Azure CNI

| | Kubenet | Azure CNI |
|---|---|---|
| Pod IP source | Private internal range — NOT in VNet | Real VNet subnet IPs |
| NAT required | YES | NO |
| Azure sees | Node IP (all pods share it) | Individual pod IP |
| NSG rules | Can only target node IPs | Can target individual pod IPs |
| SQL/Redis VNet rules | Cannot distinguish which pod | Full pod-level control |
| Network logs | Shows node IP — hard to trace | Shows pod IP — easy to trace |
| IP usage | Efficient | Higher — every pod uses a VNet IP |

### How Azure CNI Works

1. When AKS adds a node, Azure pre-assigns a block of real VNet IPs to that node's NIC as secondary IP configurations
2. When a pod is scheduled, the Azure CNI plugin assigns one pre-allocated IP to the pod's network namespace
3. Since these are real VNet IPs, the pod communicates directly — no NAT

```
Node VM NIC:
  Primary IP:    10.1.0.4   ← the node
  Secondary IPs: 10.1.0.5   ← pod 1 (user-service)
                 10.1.0.6   ← pod 2 (cart-service)
                 10.1.0.7   ← pod 3 (order-service)
```

### Why AzureShop Uses Azure CNI

AzureShop has three Azure PaaS services with VNet firewall rules:
- Azure SQL: allow `10.1.0.0 – 10.1.255.255`
- Cosmos DB: VNet filter on `aks_subnet_id`
- Redis: VNet restricted, TLS only

With Kubenet: all pods share the node IP → SQL cannot distinguish cart-service from user-service → no pod-level network isolation.

With Azure CNI: each pod has its own VNet IP → SQL sees `10.1.1.7` (cart-service exactly) → our zero-trust NetworkPolicy works at the IP level.

### Two IP Ranges — Don't Confuse Them

```
subnet-aks:    10.1.0.0/16   ← REAL VNet IPs — pods + nodes
service_cidr:  10.0.0.0/16   ← VIRTUAL K8s-only IPs — ClusterIPs
```

ClusterIPs are virtual — they only exist inside Kubernetes iptables rules. Pod IPs are real — Azure allocates and routes them.

### In AzureShop Terraform

```hcl
network_profile {
  network_plugin = "azure"           # Azure CNI
  service_cidr   = "10.0.0.0/16"    # virtual ClusterIP range
  dns_service_ip = "10.0.0.10"      # CoreDNS IP
}

default_node_pool {
  vnet_subnet_id = var.aks_subnet_id  # 10.1.0.0/16 — real pod IPs from here
}
```

### Interview Prep

1. **What is CNI?** — Container Network Interface. A standard for how networking plugins assign IPs to pods. Azure CNI gives pods real VNet IPs.
2. **Main difference between Azure CNI and Kubenet?** — Kubenet pods have internal-only IPs and communicate through NAT. Azure CNI pods have real VNet IPs — no NAT, directly routable.
3. **Why did AzureShop choose Azure CNI?** — Azure SQL, Redis, and Cosmos DB have VNet firewall rules filtering by source IP. With Kubenet all pods share node IP. With Azure CNI each pod has its own VNet IP — SQL and Redis can allow specific pod ranges.
4. **Trade-off of Azure CNI?** — Higher IP address consumption. Subnet must be large enough for all nodes × max pods per node.
5. **What are the two IP ranges in AKS?** — `subnet-aks` (real VNet IPs for pods/nodes) and `service_cidr` (virtual Kubernetes-only IPs for ClusterIP Services).

---

## Q16. What is Azure AD and Azure RBAC? How are They Used in AzureShop?

### What is Azure AD?

Azure AD (Azure Active Directory / Microsoft Entra ID) is Azure's identity and access management service. Think of it as the company HR department — it knows WHO everyone is, and when something tries to access a resource, security checks with HR: "Is this person authorised?"

Every time anything accesses Azure — a user, a pipeline, a pod — Azure AD is involved.

### The Four Identity Types in Azure AD

**1. User** — A real human with username and password.
**2. Group** — A collection of users. Assign role to group → all members inherit it. Add/remove members without changing role assignments.
**3. Service Principal** — An identity for applications, scripts, and pipelines. Like a user account for a program. Has Client ID + Client Secret. Used by: Terraform (`sp-azureshop-terraform`), Azure DevOps pipelines.
**4. Managed Identity** — A Service Principal automatically managed by Azure. No password to create, store, or rotate. Used by: AKS kubelet (pulls ACR images), CSI addon (fetches Key Vault secrets), notification-service (Workload Identity for Service Bus).

> Managed Identity is the most secure — no credentials anywhere. Azure handles everything.

### What is Azure RBAC?

RBAC = Role-Based Access Control. Instead of username/password per resource, assign a ROLE to an IDENTITY at a SCOPE.

```
RBAC = WHO + WHAT + WHERE

WHO:   Identity (user / SP / managed identity)
WHAT:  Role (what actions are allowed)
WHERE: Scope (subscription / resource group / specific resource)
```

**The Analogy — Key Cards:**
Old way: give everyone a master key. Developer leaves → change all locks. RBAC way: each person has a key card for specific areas. Developer leaves → deactivate their card. No locks changed.

### Built-in Azure Roles Used in AzureShop

| Role | What It Allows | Assigned To |
|---|---|---|
| AKS RBAC Cluster Admin | Full kubectl access | Anshu (developer) |
| Contributor | Create/modify all Azure resources | Terraform SP |
| Key Vault Secrets User | Read secrets only | CSI addon identity |
| Key Vault Secrets Officer | Read + write secrets | Terraform SP, ADO pipeline SP |
| AcrPull | Pull images from ACR | AKS kubelet identity |
| Service Bus Data Receiver | Receive messages | notification-service MI |

### Azure RBAC for AKS — Two Questions AKS Answers

```
Question 1 — Authentication: WHO are you?
  → Azure AD verifies identity → issues token

Question 2 — Authorization: WHAT can you do?
  → Azure RBAC checks role on AKS resource
```

AzureShop uses Azure RBAC (not Kubernetes RBAC) because:
- Same identity system as the rest of Azure — no separate user management
- Adding a developer = add to Azure AD group → instant cluster access
- All access logged in Azure Monitor

### How We Enabled Azure RBAC in Terraform

```hcl
azure_active_directory_role_based_access_control {
  managed            = true
  azure_rbac_enabled = true
}

resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.current_user_object_id
}
```

### Connecting to the Cluster

```bash
az aks get-credentials --resource-group rg-azureshop-dev --name aks-azureshop-dev
kubelogin convert-kubeconfig -l azurecli
kubectl get pods -n dev
# → kubelogin fetches Azure AD token → AKS validates → RBAC allows → returns pods
```

### All RBAC Assignments in AzureShop

```
┌─────────────────────────┬──────────────────────────┬─────────────────┐
│ WHO                     │ WHAT (Role)               │ WHERE (Scope)   │
├─────────────────────────┼──────────────────────────┼─────────────────┤
│ Anshu (user)            │ AKS RBAC Cluster Admin    │ AKS cluster     │
│ Terraform SP            │ Contributor               │ Subscription    │
│ Terraform SP            │ Key Vault Secrets Officer │ Key Vault       │
│ ADO Pipeline SP         │ Key Vault Secrets Officer │ Key Vault       │
│ AKS kubelet MI          │ AcrPull                   │ ACR             │
│ CSI addon MI            │ Key Vault Secrets User    │ Key Vault       │
│ notification-service MI │ Service Bus Data Receiver │ Service Bus     │
└─────────────────────────┴──────────────────────────┴─────────────────┘
```

### Why Azure RBAC + Managed Identity is Production-Grade

Without: Pipeline connects using stored password → if compromised attacker has long-lived credential → rotating password means updating every script.

With: Pipeline uses Azure AD token (short-lived, auto-refreshed) → no stored password → token expires in 1 hour → revoke access by removing role assignment → every action logged with identity + timestamp.

### Interview Prep

1. **What is Azure AD?** — Azure's identity service. Every user, app, and service authenticates through it. Provides centralized identity for pipelines, Kubernetes access, and service-to-service authentication without managing passwords per resource.
2. **What are the three parts of an RBAC assignment?** — WHO (identity), WHAT (role), WHERE (scope). Example: CSI addon identity gets Key Vault Secrets User on the specific Key Vault.
3. **Difference between Azure RBAC for AKS vs Kubernetes RBAC?** — Azure RBAC uses Azure AD identities and Azure role assignments. Kubernetes RBAC uses cluster-internal users managed via YAML. Azure RBAC is easier at scale — add to AD group = instant cluster access.
4. **What is a Managed Identity and why is it better than a Service Principal password?** — Managed Identity has no credentials to manage. Azure handles token issuance and rotation. Tokens are short-lived (1 hour). No password in code, configs, or pipelines.
5. **Why does CSI addon get Secrets User and not Secrets Officer?** — Least privilege. CSI driver only needs to READ secrets. Secrets Officer also allows writing — unnecessary. If compromised, attacker can only read, not modify secrets.

---

## Q17. What is the Difference Between a Managed Identity and a Service Principal?

### WHY This Matters

In AzureShop, both a Managed Identity and a Service Principal are used. Interviewers often ask you to compare them because they look similar on the surface — both authenticate to Azure, both get RBAC roles — but the key differences are critical for production security.

### The Analogy — Employee Badge vs Contractor Badge

Think of accessing a secure office building:

```
Service Principal = Contractor Badge
  - You create it yourself
  - You set the expiry date (can be years)
  - You are responsible for keeping it safe
  - If it's stolen, attacker uses it until you notice and revoke it
  - You must remember to renew it before it expires

Managed Identity = Permanent Employee Badge
  - The building (Azure) issues it automatically
  - No expiry date you manage — Azure handles token refresh
  - Badge only works on the specific floor/building it was issued for
  - Stored inside the system — you can never "take it home" (no exportable secret)
  - Cannot be stolen because there is nothing to steal
```

### What is a Service Principal?

A Service Principal is an identity for applications, scripts, and automation. You create it manually in Azure AD and receive a **Client ID + Client Secret** (or certificate).

```bash
# You create it
az ad sp create-for-rbac --name sp-azureshop-terraform

# You get back
{
  "appId": "0eaa884c-...",     ← Client ID (public — who am I)
  "password": "abc123xyz...",  ← Client Secret (private — prove it)
  "tenant": "4c135936-..."
}
```

The Client Secret is a **password**. It has an expiry date (up to 2 years). You must store it somewhere (Key Vault, pipeline variable group), rotate it before it expires, and update everywhere it is stored.

### What is a Managed Identity?

A Managed Identity is also a Service Principal under the hood — but Azure creates and manages it automatically. There is **no Client Secret**. Azure handles everything.

```
You enable Managed Identity on an Azure resource (VM, AKS, App Service)
  ↓
Azure creates a Service Principal in Azure AD on your behalf
  ↓
Azure stores and rotates the credential internally — you never see it
  ↓
Resource authenticates by asking Azure's Instance Metadata Service (IMDS):
  "Give me a token for this identity"
  ↓
Azure returns a short-lived token (1 hour) — no password needed
```

### System-Assigned vs User-Assigned Managed Identity

There are two types of Managed Identity:

**System-Assigned:**
- Created and tied to one specific Azure resource
- When the resource is deleted, the identity is deleted automatically
- One resource → one identity
- Example: turning on identity for an App Service

**User-Assigned:**
- Created as a standalone Azure resource
- Can be attached to MULTIPLE resources
- Survives resource deletion — you delete it separately
- Example: `id-notification-service-dev` in AzureShop

```hcl
# System-Assigned — just enable it on the resource
resource "azurerm_linux_virtual_machine" "example" {
  identity {
    type = "SystemAssigned"
  }
}

# User-Assigned — create it first, then attach it
resource "azurerm_user_assigned_identity" "notification_service" {
  name                = "id-notification-service-dev"
  resource_group_name = var.resource_group_name
  location            = var.location
}
```

### Point-to-Point Comparison

| | Service Principal | Managed Identity |
|---|---|---|
| **Who creates it** | You (manual `az ad sp create`) | Azure (automatic) |
| **Credentials** | Client ID + Client Secret (or cert) | No secret — Azure manages it |
| **Credential storage** | You must store in Key Vault / pipeline vars | Nothing to store |
| **Rotation** | Manual — you must rotate before expiry | Automatic — Azure handles it |
| **Expiry** | 1–2 years (you set it) | No expiry — token is short-lived (1h) |
| **What can use it** | Any app anywhere — code, scripts, pipelines | Only Azure-hosted resources (VMs, AKS, App Service) |
| **Risk if leaked** | Long-lived secret — valid until rotated | Nothing to leak — no exportable credential |
| **Cost** | Free | Free |
| **Complexity** | More setup — store + rotate + update | Less setup — enable and assign role |
| **Use for** | External tools (Terraform, GitHub Actions), CI/CD pipelines | Azure-hosted services talking to other Azure services |

### When to Use Which

**Use Service Principal when:**
- The caller is NOT hosted in Azure (your local machine running Terraform, GitHub Actions, external scripts)
- You need one identity used across multiple unrelated services or subscriptions
- The tool doesn't support Managed Identity

**Use Managed Identity when:**
- The caller IS hosted in Azure (VM, AKS pod, App Service, Function App)
- Always prefer it over Service Principal for Azure-to-Azure communication
- You want to eliminate credential management entirely

> Rule of thumb: If the thing that needs to authenticate lives in Azure, use Managed Identity. If it lives outside Azure, use Service Principal.

### How AzureShop Uses Both

```
┌──────────────────────────────────────────────────────────────────┐
│                         AzureShop Identity Map                    │
├──────────────────────────┬───────────────────────────────────────┤
│ Identity                 │ Type                  │ Used For       │
├──────────────────────────┼───────────────────────┼───────────────┤
│ sp-azureshop-terraform   │ Service Principal     │ Terraform runs │
│                          │ (external — your Mac) │ locally + ADO  │
├──────────────────────────┼───────────────────────┼───────────────┤
│ ADO Pipeline identity    │ Service Principal     │ Azure DevOps   │
│ (sc-azureshop-azure)     │ (ADO is external)     │ CI/CD          │
├──────────────────────────┼───────────────────────┼───────────────┤
│ AKS kubelet identity     │ Managed Identity      │ Pull ACR       │
│                          │ (system-assigned)     │ images         │
├──────────────────────────┼───────────────────────┼───────────────┤
│ CSI addon identity       │ Managed Identity      │ Fetch Key      │
│                          │ (system-assigned)     │ Vault secrets  │
├──────────────────────────┼───────────────────────┼───────────────┤
│ id-notification-         │ Managed Identity      │ Receive msgs   │
│ service-dev              │ (user-assigned)       │ from Service   │
│                          │                       │ Bus (Workload  │
│                          │                       │ Identity)      │
└──────────────────────────┴───────────────────────┴───────────────┘
```

**Why user-assigned for notification-service (not system-assigned)?**
A system-assigned identity is tied to the AKS cluster resource. If the cluster is recreated (which happens during Terraform destroy/apply), the identity changes — and the federated credential binding for Workload Identity breaks. A user-assigned identity survives cluster recreation — you just re-attach it.

### The Key Vault Access Chain (How It All Connects)

```
Terraform (local Mac)
  → uses Service Principal sp-azureshop-terraform
  → has Key Vault Secrets Officer role
  → writes secrets to Key Vault

AKS pod (user-service)
  → CSI Driver (inside AKS cluster, hosted in Azure)
  → uses CSI addon Managed Identity
  → has Key Vault Secrets User role
  → reads secrets from Key Vault → injects as env vars
```

Same Key Vault, two different identities, two different roles — one writes (Terraform SP), one reads (Managed Identity). Least privilege per identity.

### Interview Prep

1. **What is the difference between a Managed Identity and a Service Principal?** — Both are Azure AD identities used by applications. Service Principal requires you to manage credentials (Client ID + Secret). Managed Identity is created and managed by Azure — no credentials to store or rotate.
2. **When would you use a Service Principal instead of a Managed Identity?** — When the caller is not hosted in Azure. Local scripts, GitHub Actions, Terraform running on your laptop — these cannot use Managed Identity because they are not Azure resources.
3. **What is the difference between system-assigned and user-assigned Managed Identity?** — System-assigned is tied to one resource and deleted with it. User-assigned is a standalone resource that can be attached to multiple Azure resources and persists independently.
4. **Why does AzureShop use a user-assigned (not system-assigned) identity for notification-service?** — Because the federated credential for Workload Identity is bound to this identity's object ID. If the AKS cluster is destroyed and recreated, a system-assigned identity would change. The user-assigned identity survives cluster recreation.
5. **Is a Managed Identity actually a Service Principal?** — Yes. Internally, Azure creates a Service Principal for a Managed Identity. The difference is that Azure manages the credentials — you never see or store them. From the Azure RBAC perspective, assigning a role works the same way.

---

## Q18. What is the Purpose of Every Folder and File Inside the k8s/ Directory?

### The Big Picture First

Think of the `k8s/` folder as the **operations manual for the Kubernetes cluster**. The `helm/charts/` folder tells Kubernetes *how to run each service*. The `k8s/` folder tells Kubernetes *how to set up the environment those services live in*.

```
k8s/
├── namespaces/              ← Create the rooms in the building
├── secret-provider-classes/ ← Connect Key Vault to each pod
├── ingress/                 ← The front door routing rules
├── ingress-nginx-values.yaml ← Configure the front door itself
├── alert-rules/             ← Set up alarms
├── grafana-dashboards/      ← Set up monitoring screens
└── gitops/                  ← Automate deployments via Git
```

---

### namespaces/ — Creating the Rooms

#### `namespaces/dev.yaml`

Creates the `dev` namespace — the room where all 8 AzureShop services live.

The important part is the labels. The `pod-security.kubernetes.io/enforce: restricted` labels activate **Pod Security Admission** — a built-in Kubernetes security guard at the namespace door.

```
Pod tries to deploy in dev namespace
       ↓
Pod Security Admission checks: does this pod follow "restricted" rules?
Rules: runAsNonRoot? drop ALL capabilities? no privilege escalation?
       ↓
Fails any rule → Kubernetes REJECTS the pod — it never starts
```

Three modes run simultaneously:
- `enforce` → reject the pod if it violates
- `audit` → log the violation
- `warn` → show a warning to the person running kubectl

All 8 AzureShop services satisfy `restricted` because Phase 8 hardened all Helm charts.

#### `namespaces/dev-resource-quota.yaml`

Two resources in one file — **ResourceQuota** and **LimitRange**.

**ResourceQuota** is a hard ceiling on the entire `dev` namespace:

```
Total CPU requests across all pods: max 8 cores
Total CPU limits across all pods:   max 16 cores
Total memory requests:              max 8 GiB
Total memory limits:                max 16 GiB
Max 50 pods, 20 services, 50 secrets, 30 ConfigMaps
```

Analogy: it's like a building's total electricity budget. Individual tenants (pods) can use as much as they want — but the whole building can never exceed the meter limit.

**LimitRange** applies *per container*:

```
Container sets NO requests/limits → LimitRange injects defaults:
    CPU request: 100m, CPU limit: 500m
    Memory request: 128Mi, Memory limit: 512Mi

No single container can exceed:  CPU: 2 cores, Memory: 2 GiB
No container can request less than: CPU: 10m, Memory: 16Mi
```

**Why both are needed together:** ResourceQuota only counts resources that have requests/limits set. If a container sets none, it bypasses the quota entirely. LimitRange fills in defaults, so every container gets counted.

#### `namespaces/monitoring.yaml`, `staging.yaml`, `prod.yaml`

Simple namespace definitions. No security labels on `monitoring` because kube-prometheus-stack's pods (Grafana, Prometheus) need elevated permissions and would fail the `restricted` standard. `staging` and `prod` namespaces are created but not actively used (infra is destroyed).

---

### secret-provider-classes/ — The Key Vault Bridge

Five files — one for each service that needs secrets from Key Vault:

```
user-service.yaml      → needs SQL + App Insights secrets
product-service.yaml   → needs Cosmos DB + App Insights secrets
cart-service.yaml      → needs Redis + App Insights secrets
order-service.yaml     → needs Service Bus + App Insights secrets
payment-service.yaml   → needs Service Bus + App Insights secrets
```

notification-service uses Workload Identity directly — no SecretProviderClass needed. api-gateway and frontend have no secrets.

**How a SecretProviderClass works** (user-service as example):

```yaml
kind: SecretProviderClass
name: user-service-secrets
spec:
  provider: azure
  parameters:
    userAssignedIdentityID: "d755c00c-..."   # CSI addon identity
    keyvaultName: "kv-azureshop-6a6c-dev"
    objects:
      - objectName: sql-server-fqdn          # fetch from Key Vault
      - objectName: sql-admin-username
      - objectName: sql-admin-password
      - objectName: appinsights-user-service-cs
  secretObjects:
    - secretName: user-service-secrets       # create this K8s Secret
      data:
        - objectName: sql-server-fqdn
          key: SQL_SERVER                    # pod reads this env var
```

The flow:

```
Pod starts
  ↓
CSI Driver authenticates to Key Vault using the addon Managed Identity
  ↓
CSI Driver fetches sql-server-fqdn, sql-admin-password, etc.
  ↓
CSI Driver creates a Kubernetes Secret called "user-service-secrets"
  ↓
Pod reads env var SQL_SERVER from that Secret
  ↓
Pod never talked to Key Vault directly — CSI Driver did it all
```

**Why 5 separate files instead of 1 big one?** Least privilege. user-service only gets SQL secrets. cart-service only gets Redis secrets. If user-service is compromised, the attacker only gets SQL credentials — not Redis or Cosmos keys.

---

### ingress/ — The Front Door

#### `ingress/dev-ingress.yaml`

The routing rule that tells the NGINX Ingress Controller how to send external traffic to the right service.

```yaml
paths:
  - path: /api/   → backend: api-gateway:8080
  - path: /       → backend: frontend:3000
```

The full traffic flow:

```
Browser: http://134.33.223.224/products
    ↓  Azure Load Balancer
    ↓  NGINX Ingress Controller
    ↓  path /products — does NOT start with /api/
    ↓  → frontend:3000 (Next.js handles the page)

Browser: http://134.33.223.224/api/users/me
    ↓  NGINX Ingress Controller
    ↓  path starts with /api/ → api-gateway:8080
    ↓  api-gateway's nginx.conf routes to user-service:3001
```

Think of this as the building directory at the front entrance.

#### `ingress/canary-example.yaml`

A **pattern/example file** — not applied to the cluster by default. Shows how to do a canary deployment for `user-service` using two Ingress objects for the same path:

```
user-service-stable Ingress  →  user-service (old version)  ← 80% traffic
user-service-canary Ingress  →  user-service-canary (new)   ← 20% traffic
```

The annotation `nginx.ingress.kubernetes.io/canary-weight: "20"` splits traffic automatically — no code change, no DNS change, no load balancer reconfiguration needed.

To roll back instantly: delete the canary Ingress. 100% traffic immediately returns to stable.

---

### `ingress-nginx-values.yaml` — Configuring the Front Door Itself

The Helm values file used to **install the NGINX Ingress Controller** itself. Used once during cluster setup:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --values k8s/ingress-nginx-values.yaml
```

Key settings:

```yaml
replicaCount: 2           # 2 NGINX pods — no single point of failure

podAntiAffinity:          # spread the 2 pods across different nodes
  topologyKey: kubernetes.io/hostname

resources:
  requests: cpu: 100m, memory: 90Mi
  limits:   cpu: 500m, memory: 256Mi

metrics:
  enabled: true           # expose /metrics for Prometheus scraping
```

**Why `podAntiAffinity`?** If both NGINX pods landed on the same node and that node crashed, the front door goes down. Anti-affinity tells the scheduler: prefer different nodes for these two pods.

---

### alert-rules/azureshop-alerts.yaml

Defines **10 Prometheus alerts** in 3 groups using the `PrometheusRule` custom resource.

**How it gets loaded:** The Prometheus Operator watches for any `PrometheusRule` with label `release: kube-prometheus-stack`. When it finds one, it loads the rules into Prometheus automatically — no restart needed.

**Group 1 — HTTP alerts** (based on your app's own metrics):

| Alert | Condition | Severity |
|---|---|---|
| HighErrorRate | Service returns 5xx on >5% of requests for 5 min | Critical |
| HighP95Latency | P95 response time >1s for 5 min | Warning |
| ServiceReceivingNoTraffic | Zero requests for 10 min | Warning |

**Group 2 — Availability alerts** (based on kube-state-metrics):

| Alert | Condition | Severity |
|---|---|---|
| PodCrashLoopBackOff | Pod crash-looping for 5 min | Critical |
| PodNotRunning | Pod stuck in Pending/Failed for 15 min | Warning |
| DeploymentUnavailable | Zero available replicas for 2 min | Critical |
| PodUnschedulable | Can't be scheduled for 10 min | Warning |

**Group 3 — Capacity alerts**:

| Alert | Condition | Severity |
|---|---|---|
| HPAAtMaxReplicas | HPA stuck at max replicas for 10 min | Warning |
| HighMemoryUsage | Container at >85% memory limit for 5 min | Warning |
| HighCPUThrottling | Container CPU-throttled >25% of the time for 10 min | Warning |

---

### grafana-dashboards/ — The Monitoring Screens

#### `grafana-dashboards/azureshop-services.json`

The raw Grafana dashboard definition in JSON. Contains 6 panels: Request Rate, Error Rate, P95 Latency, Running Pods, CPU Usage, Memory Usage. You edit in Grafana UI, export the JSON, and save it here so the dashboard is version-controlled.

#### `grafana-dashboards/configmap.yaml`

The mechanism that loads the JSON into Grafana automatically:

```yaml
kind: ConfigMap
namespace: monitoring
labels:
  grafana_dashboard: "1"       ← this label is the trigger
data:
  azureshop-services.json: |   ← the full JSON embedded here
    { ... }
```

Grafana's sidecar container watches all ConfigMaps with label `grafana_dashboard: "1"`. When it finds one, it loads the JSON as a dashboard within ~30 seconds — no Grafana restart needed.

JSON file = the design. ConfigMap = the delivery mechanism. Label = the trigger that activates the sidecar.

---

### gitops/ — Automatic Deployments from Git (Phase 9)

#### What is GitOps?

```
Normal pipeline:  You push → pipeline runs → pipeline calls helm upgrade → cluster updates
GitOps:           You push → Flux (inside cluster) detects change in Git → Flux calls helm upgrade
```

The cluster **pulls** from Git instead of a pipeline **pushing** to the cluster.

#### `gitops/sources/git-repository.yaml`

```yaml
kind: GitRepository
spec:
  url: https://dev.azure.com/azureshop-org/AzureShop/_git/AzureShop
  ref:
    branch: dev
  interval: 1m
```

Tells Flux: "Check this Git repo every 1 minute. If anything changed on `dev`, fetch it." This is the source definition — where Flux looks for the truth.

#### `gitops/releases/*.yaml` — One HelmRelease Per Service

Each file (e.g. `user-service.yaml`) tells Flux:

```yaml
kind: HelmRelease
spec:
  interval: 5m                   # check every 5 minutes
  chart:
    spec:
      chart: ./helm/charts/user-service   # path in the Git repo
  upgrade:
    remediation:
      remediateLastFailure: true  # auto-rollback on failure
```

What happens when you push a new image tag:

```
You push to dev branch
  ↓ (within 1 minute)
Flux detects change in git-repository
  ↓
Flux reads HelmRelease for user-service
  ↓
Flux runs: helm upgrade user-service ./helm/charts/user-service
  ↓
New pods deploy with rolling update
  ↓
If it fails → Flux auto-rolls back
```

#### `gitops/releases/kustomization.yaml`

```yaml
kind: Kustomization
resources:
  - user-service.yaml
  - cart-service.yaml
  - ... (all 8)
```

The index that tells Flux "these are all the HelmRelease files I manage." Apply this one file and all 8 HelmReleases get picked up. Without this, you'd have to apply each file individually.

---

### Full Summary Map

```
k8s/
│
├── namespaces/
│   ├── dev.yaml                  → Create dev namespace + enforce Pod Security (restricted)
│   ├── dev-resource-quota.yaml   → Cap total CPU/memory + inject defaults per container
│   ├── monitoring.yaml           → Create monitoring namespace (no security labels)
│   ├── staging.yaml              → Create staging namespace (unused)
│   └── prod.yaml                 → Create prod namespace (unused)
│
├── secret-provider-classes/      → Bridge between Key Vault and each pod's env vars
│   ├── user-service.yaml         → Fetches SQL + AppInsights secrets
│   ├── cart-service.yaml         → Fetches Redis + AppInsights secrets
│   ├── order-service.yaml        → Fetches ServiceBus + AppInsights secrets
│   ├── payment-service.yaml      → Fetches ServiceBus + AppInsights secrets
│   └── product-service.yaml      → Fetches Cosmos + AppInsights secrets
│
├── ingress/
│   ├── dev-ingress.yaml          → Route /api/* → api-gateway, /* → frontend
│   └── canary-example.yaml       → Pattern: 80/20 traffic split for safe deployments
│
├── ingress-nginx-values.yaml     → Install config for NGINX Ingress Controller itself
│
├── alert-rules/
│   └── azureshop-alerts.yaml     → 10 Prometheus alerts (HTTP, availability, capacity)
│
├── grafana-dashboards/
│   ├── azureshop-services.json   → Dashboard definition (6 panels)
│   └── configmap.yaml            → Auto-loads JSON into Grafana via sidecar label trick
│
└── gitops/
    ├── sources/
    │   └── git-repository.yaml   → Tell Flux: watch this Git repo, branch dev, every 1m
    └── releases/
        ├── kustomization.yaml    → Index of all 8 HelmReleases
        └── *.yaml (×8)          → One HelmRelease per service — Flux applies Helm for you
```

### Interview Prep

1. **What is the difference between `helm/charts/` and `k8s/` in AzureShop?** — `helm/charts/` defines how each service runs (Deployment, Service, HPA, etc.). `k8s/` sets up the environment — namespaces, security policies, ingress routing, secret bridges, alerts, dashboards, and GitOps automation.
2. **What does a SecretProviderClass do?** — It bridges Azure Key Vault and a Kubernetes pod. It tells the CSI Driver which secrets to fetch from Key Vault, and creates a Kubernetes Secret from those values. The pod reads that Secret as env vars — never touching Key Vault directly.
3. **What is the difference between ResourceQuota and LimitRange?** — ResourceQuota caps the total resource consumption of an entire namespace. LimitRange sets defaults and caps per individual container. Both are needed together — LimitRange ensures containers have requests set so ResourceQuota can count them.
4. **Why does NGINX Ingress have `podAntiAffinity`?** — To prevent both NGINX replicas from landing on the same node. If that node crashes, the front door survives because the second replica is on a different node.
5. **What is GitOps and how does Flux implement it in AzureShop?** — GitOps means Git is the single source of truth for cluster state. Flux runs inside the cluster, polls the Git repo every 1 minute, and applies any changes via Helm automatically. The cluster pulls changes rather than a pipeline pushing them.
6. **How does the Grafana dashboard get loaded without restarting Grafana?** — A ConfigMap in the `monitoring` namespace is labeled `grafana_dashboard: "1"`. Grafana's sidecar container watches for ConfigMaps with this label and loads the embedded JSON as a dashboard within 30 seconds.

---

## Q19. What are Service Endpoints? (Azure VNet Service Endpoints vs Kubernetes Endpoints)

### There Are Two Types — Don't Confuse Them

```
1. Azure VNet Service Endpoints  →  Azure networking feature
2. Kubernetes Endpoints          →  Kubernetes object inside the cluster
```

---

### Azure VNet Service Endpoints

#### WHY They Exist

By default, Azure PaaS services (SQL, Redis, Cosmos DB, Storage) are public internet resources — they have public IPs and are reachable from anywhere in the world. The only protection is username/password.

```
Without Service Endpoints:
  Anyone on the internet → tries SQL → only password stops them
```

You want SQL to only accept connections from **your VNet** — nothing else.

#### What a Service Endpoint Does

A Service Endpoint creates a **direct, private route** from your VNet subnet to an Azure PaaS service — and lets you lock that service down to only accept traffic from that subnet.

```
Without Service Endpoint:
  AKS pod → public internet → Azure SQL (public IP)

With Service Endpoint:
  AKS pod → stays inside Azure backbone → Azure SQL (never touches internet)
```

The analogy: your office building (VNet) gets a **private corridor** directly to the post office (SQL). Mail can only be delivered through that corridor. The public entrance is locked.

#### How It Works in AzureShop — Terraform

In `infra/modules/networking/main.tf`, the AKS subnet has service endpoints declared:

```hcl
subnet "aks" {
  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault"
  ]
}
```

Then on the SQL Server, a firewall rule locks it to only that subnet:

```hcl
virtual_network_rule "aks" {
  subnet_id = module.networking.aks_subnet_id
}
```

Result: only traffic from the AKS subnet reaches SQL. Everything else — internet, other VNets — is rejected at the network level.

#### Azure Service Endpoints vs Private Endpoints

| | Service Endpoint | Private Endpoint |
|---|---|---|
| How it works | Private route from subnet to public service IP | Gives the PaaS service a private IP inside your VNet |
| Service still has public IP | YES | NO — fully private |
| DNS change needed | No | Yes — private DNS zone |
| Cost | Free | Paid (per hour + data) |
| Security level | Good — subnet-level lock | Better — no public IP at all |
| Used in AzureShop | Yes (SQL, Cosmos, Key Vault) | No (cost saving on dev) |

In production you'd use Private Endpoints. AzureShop uses Service Endpoints on dev because they're free and sufficient for learning.

---

### Kubernetes Endpoints (the K8s Object)

#### WHY They Exist

When you create a Kubernetes Service, it gets a stable ClusterIP. But the Service needs to know **which pod IPs to forward traffic to**. That list is stored in an **Endpoints** object.

Every Service automatically gets a matching Endpoints object with the same name, containing the current list of healthy pod IPs.

```bash
kubectl get endpoints user-service -n dev

NAME           ENDPOINTS                         AGE
user-service   10.1.1.5:3001,10.1.1.12:3001     2d
```

```
Service: user-service (ClusterIP: 10.0.12.5)
    ↓
Endpoints: user-service
    ├── 10.1.1.5:3001   ← pod 1 (healthy, passing readiness probe)
    └── 10.1.1.12:3001  ← pod 2 (healthy, passing readiness probe)
```

#### How It Updates Automatically

```
Pod fails readiness probe
  ↓
Endpoints controller removes that pod IP from the Endpoints list
  ↓
kube-proxy updates iptables rules on all nodes
  ↓
Traffic stops going to that pod immediately

Pod recovers, passes readiness probe
  ↓
Endpoints controller adds the pod IP back
  ↓
Traffic resumes to that pod
```

This is why readiness probes matter — they directly control which pod IPs are in the Endpoints list.

---

### How Both Connect in AzureShop

```
Browser
  ↓
NGINX Ingress → api-gateway Service
  ↓
Kubernetes Endpoints: [api-gateway pod 1 IP, pod 2 IP]   ← K8s Endpoints
  ↓
api-gateway pod → user-service Service
  ↓
Kubernetes Endpoints: [user-service pod 1 IP, pod 2 IP]   ← K8s Endpoints
  ↓
user-service pod → Azure SQL
  ↓
Azure VNet Service Endpoint: private route from AKS subnet → SQL   ← Azure Service Endpoint
  ↓
Azure SQL (only accepts connections from aks_subnet — everything else blocked)
```

### Interview Prep

1. **What is an Azure VNet Service Endpoint?** — A private network route from a VNet subnet directly to an Azure PaaS service (SQL, Cosmos, Key Vault), combined with a firewall rule that blocks all other traffic. Traffic stays on the Azure backbone — never touches the public internet.
2. **What is a Kubernetes Endpoints object?** — An auto-managed list of healthy pod IPs behind a Kubernetes Service. Updated in real time based on readiness probe results. kube-proxy uses it to set up iptables routing on every node.
3. **What is the difference between Azure Service Endpoints and Private Endpoints?** — Service Endpoints give a private route to a PaaS service that still has a public IP (free). Private Endpoints give the PaaS service a real private IP inside your VNet with no public IP (paid). Private Endpoints are more secure.
4. **Why does AzureShop use Service Endpoints and not Private Endpoints?** — Cost. Service Endpoints are free and sufficient for a dev environment. Production deployments would use Private Endpoints to fully remove public IP exposure.
5. **How does a readiness probe affect Kubernetes Endpoints?** — When a pod fails its readiness probe, the Endpoints controller removes that pod's IP from the Endpoints list. No new traffic is routed to it. When it recovers, the IP is added back. This is the mechanism behind zero-downtime traffic management.

---

## Q20. What is the Difference Between a Service Endpoint and a Service Principal?

### The One-Line Answer

```
Service Endpoint   =  a NETWORKING concept   (where traffic is allowed to go)
Service Principal  =  an IDENTITY concept    (who is allowed to authenticate)
```

These two have nothing to do with each other — they just both happen to have the word "Service" in their name.

### The Analogy — A Bank Vault

Think of Azure SQL as a bank vault.

**Service Endpoint** = the **private road** the bank built directly to your office. Only your office can use that road. No one from the street can reach the vault through it. This is a network-level control.

**Service Principal** = the **ID card** your employee carries. When they arrive at the vault door, the guard checks: "Who are you? Are you authorised?" This is an identity-level control.

### You Need Both — They Operate at Different Layers

```
AKS pod wants to query Azure SQL

Layer 1 — Network (Service Endpoint):
  "Is this traffic coming from the aks_subnet?" YES → allow through
  If NO → blocked at network level, request never reaches SQL

Layer 2 — Identity (Service Principal / credentials):
  "Is this the right username and password?" YES → allow query
  If NO → authentication failure
```

A Service Endpoint with no credentials → network reaches SQL but login fails.
Credentials with no Service Endpoint → network blocked before login is even attempted.

### Side-by-Side Comparison

| | Service Endpoint | Service Principal |
|---|---|---|
| **What it is** | A private network route from your VNet to an Azure PaaS service | An identity (like a user account) for an application or script |
| **What it controls** | WHERE traffic can come from — network level | WHO is allowed to authenticate — identity level |
| **Lives in** | Azure Networking / VNet subnet | Azure Active Directory |
| **How you configure it** | `service_endpoints = ["Microsoft.Sql"]` on the subnet in Terraform | `az ad sp create-for-rbac` — gives Client ID + Secret |
| **What it prevents** | Traffic from the internet or other VNets reaching your PaaS service | Unauthorised apps and scripts from authenticating to Azure |
| **Analogy** | Private road — only your building can use it | ID card — proves who you are at the door |
| **In AzureShop** | AKS subnet → SQL, Cosmos DB, Key Vault | `sp-azureshop-terraform` — Terraform uses it to create infrastructure |

### In AzureShop — Who Uses What

```
Terraform (running on your Mac)
  ├── Uses Service Principal (sp-azureshop-terraform)
  │     → proves to Azure AD: "I am Terraform, I have Contributor role"
  │     → creates VNet, AKS, SQL, etc.
  │
  └── Creates Service Endpoints on the AKS subnet
        → locks SQL so only aks_subnet traffic is allowed

AKS pod (user-service)
  ├── Reaches SQL via Service Endpoint (private route — no internet)
  └── Logs in to SQL using credentials fetched from Key Vault (CSI Driver)
```

### Interview Prep

1. **What is the difference between a Service Endpoint and a Service Principal?** — Service Endpoint is a networking concept — it creates a private route from a VNet subnet to a PaaS service and blocks all other traffic. Service Principal is an identity concept — it's an account that applications use to authenticate to Azure AD.
2. **Can you have a Service Endpoint without a Service Principal?** — Yes. Service Endpoint controls network access. Service Principal controls identity. They are independent layers. AzureShop uses both — Service Endpoints for network security, Service Principals for Terraform and pipeline authentication.
3. **Which layer would block an attacker who has stolen SQL credentials but is connecting from a home network?** — The Service Endpoint (network layer). The firewall rule only allows traffic from the AKS subnet. A home IP is not in that subnet — the connection is blocked before credentials are even checked.
4. **Which layer would block an attacker who is inside the AKS subnet but does not have SQL credentials?** — The identity/authentication layer. The attacker's traffic reaches SQL (correct network), but SQL rejects the login because the credentials are wrong.

---

## Q21. What is a Kubernetes Controller? How are Default Controllers Different from Managed Kubernetes Controllers?

### What is a Controller? — The Thermostat Analogy

Think of a Kubernetes Controller exactly like a **thermostat** in your home.

A thermostat has one simple job:
- You set the temperature to **22°C** → this is the **desired state**.
- The thermostat reads the room temperature → this is the **actual state**.
- If room is 18°C → it turns the heater ON.
- If room is 25°C → it turns the heater OFF.
- It keeps doing this check **forever, in a loop**, 24/7.

A Kubernetes Controller works **exactly the same way**:
- You tell Kubernetes "I want 2 replicas of user-service running" → **desired state**.
- The controller checks "how many are actually running right now?" → **actual state**.
- If actual ≠ desired → the controller **takes action to fix it**.
- It keeps doing this loop **forever and automatically**.

This is why Kubernetes is self-healing. If a pod crashes at 3am, a controller detects it and creates a new one — without anyone waking up.

---

### The Reconciliation Loop — The Heart of Every Controller

Every single controller in Kubernetes follows the same pattern called the **Reconciliation Loop**:

```
┌────────────────────────────────────────────────────────┐
│                  RECONCILIATION LOOP                    │
│                                                         │
│   1. OBSERVE  → Read the ACTUAL state from API Server  │
│        ↓                                               │
│   2. COMPARE  → Does actual == desired?                │
│        ↓                                               │
│   3. ACT      → If NO → take action to close the gap  │
│        ↓                                               │
│   4. REPEAT   → Go back to step 1 (runs forever)      │
└────────────────────────────────────────────────────────┘
```

**Real AzureShop example — user-service at 3am:**
```
Desired state (in Deployment): replicas: 2
Actual state (running pods):   1 pod (one crashed)

Reconciliation Loop:
  OBSERVE:  "Only 1 user-service pod is running"
  COMPARE:  "1 ≠ 2 — there is a gap"
  ACT:      "Create 1 new pod on a healthy node"
  REPEAT:   "Now 2 pods running — gap closed, nothing to do"
```

This loop repeats every few seconds, automatically, forever.

---

### Where Do Controllers Live?

All built-in Kubernetes controllers live inside one process called the **Controller Manager** (`kube-controller-manager`). This runs on the **Control Plane** (the brain of the cluster).

Think of the Controller Manager as a **factory building** with many departments inside. Each department (controller) has one specific job and works independently.

```
kube-controller-manager (the factory building)
│
├── Deployment Controller      → manages Deployments
├── ReplicaSet Controller      → manages pod replica counts (self-healing)
├── Node Controller            → watches node health
├── Job Controller             → manages one-off batch Jobs
├── CronJob Controller         → manages scheduled Jobs
├── Namespace Controller       → handles namespace lifecycle
├── ServiceAccount Controller  → creates default service accounts
├── EndpointSlice Controller   → keeps Service → pod IP mappings updated
└── ... 30+ more controllers
```

Each controller watches only its own resource type. The Deployment Controller only cares about Deployments. The Node Controller only cares about Nodes. They never interfere with each other.

---

### The Most Important Built-in Controllers Explained

#### 1. Deployment Controller
**Job:** When you create or update a Deployment, it creates or manages a ReplicaSet.

```
You:   kubectl apply -f deployment.yaml  (image: user-service:v1, replicas: 2)
  ↓
Deployment Controller sees new Deployment → creates ReplicaSet v1 (replicas: 2)

You:   kubectl set image deployment/user-service user-service=user-service:v2
  ↓
Deployment Controller creates ReplicaSet v2 (replicas: 0) and scales it UP
Simultaneously scales ReplicaSet v1 (replicas: 2) DOWN
This is the rolling update dance → zero downtime
```

---

#### 2. ReplicaSet Controller
**Job:** Makes sure exactly the right number of pods are always running. This is the **self-healing** controller.

```
Desired replicas: 2

Actual: 2 pods → nothing to do
Actual: 1 pod  → create 1 new pod immediately
Actual: 3 pods → delete 1 pod (someone created an extra manually)
Actual: 0 pods → create 2 pods immediately (maybe node crashed)
```

**Real AzureShop scenario:**
```
2:47am → Node running cart-service pod has hardware failure
2:47am → ReplicaSet Controller: "Desired=2, Actual=1. Gap detected!"
2:47am → Schedules new cart-service pod on a healthy node
2:48am → New pod is Running and Ready
2:48am → "Desired=2, Actual=2. Done."
You wake up at 9am and everything is fine. You never knew it happened.
```

---

#### 3. Node Controller
**Job:** Watches the health of all nodes (the VMs). If a node goes silent, it marks it unhealthy and evicts its pods.

```
Timeline when a node suddenly crashes:
  0 sec:  Node stops sending heartbeats to API Server
 40 sec:  Node Controller marks node status as "Unknown"
  5 min:  Node Controller marks node as "NotReady"
  5 min:  Node Controller adds NoExecute taint to the node
          → all pods on that node begin evicting
          → ReplicaSet Controller detects pod count drops
          → creates replacement pods on healthy nodes
```

Why wait 5 minutes and not act immediately? Brief network glitches happen all the time. Waiting prevents unnecessary pod churn for a 30-second hiccup.

---

#### 4. EndpointSlice Controller
**Job:** Maintains the real-time list of healthy pod IPs behind every Service.

```
user-service has 2 pods:
  Pod A: 10.1.0.5 → passing readiness probe → IN the endpoint list ✅
  Pod B: 10.1.0.6 → failing readiness probe → REMOVED from endpoint list ❌

Traffic only reaches Pod A. Pod B receives zero requests until it recovers.
When Pod B passes readiness again → added back to endpoint list automatically.
```

This is the mechanism that makes readiness probes actually affect traffic routing.

---

#### 5. Job Controller
**Job:** Runs a pod until it completes successfully. Retries on failure. Does NOT restart after success.

```
Job: "run database migration script once and stop"
  → starts pod
  → pod crashes (DB not ready yet) → Job Controller retries
  → pod runs successfully → exit code 0
  → Job marked Complete, pod not restarted again ✅
```

---

#### 6. CronJob Controller
**Job:** Creates Job objects on a cron schedule.

```
CronJob: "run backup every day at 2am"
  → At 2:00am: CronJob Controller creates a Job
  → Job Controller runs the pod
  → Pod completes successfully → Job done
  → Next day at 2:00am: repeat
```

---

### How Controllers Watch for Changes — The Watch Mechanism

Controllers do NOT poll the API Server every second (that would be wasteful and slow). Instead they use a **Watch** mechanism — like push notifications instead of constantly refreshing.

```
Step 1 — Initial sync:
  Controller → API Server: "Give me all Deployments right now" (LIST)
  Controller builds its local cache of the current state

Step 2 — Continuous watch:
  Controller → API Server: "WATCH — stream me any changes"

Step 3 — Events flow in:
  API Server → Controller: "New Deployment created!" (event)
  API Server → Controller: "A pod just died!" (event)
  API Server → Controller: "Node went NotReady!" (event)

Step 4 — Work queue:
  Events go into a queue inside the controller
  Controller processes events one by one and reconciles
```

This makes controllers react in milliseconds and use minimal resources. The cluster can have thousands of pods and the controllers handle it efficiently.

---

### Default (Self-Managed) Kubernetes vs Managed Kubernetes (AKS)

This is one of the most important distinctions in real-world Kubernetes.

#### Default Kubernetes — You Own Everything

When you install Kubernetes yourself using `kubeadm` on bare-metal or raw VMs, you are responsible for the entire Control Plane:

```
YOU must manage:
├── kube-controller-manager  → install it, keep it running, upgrade it
├── kube-apiserver           → manage TLS certificates, upgrades, HA
├── etcd                     → set up backups, multi-node HA
├── kube-scheduler           → install and manage
└── Worker node VMs          → provision VMs, join them to cluster

If kube-controller-manager crashes at 3am:
  → ALL reconciliation stops
  → Crashed pods are NOT replaced
  → Dead nodes are NOT detected
  → Deployments NOT rolled out
  → YOU get paged
```

This is fine for learning but very expensive in production — you need a dedicated platform/SRE team.

---

#### Managed Kubernetes (AKS) — Microsoft Owns the Control Plane

When you use AKS, Microsoft runs and manages the entire Control Plane for you:

```
Microsoft manages (you never touch these):
├── kube-controller-manager  → Microsoft runs it in HA, upgrades it
├── kube-apiserver           → Microsoft manages certs, HA, upgrades
├── etcd                     → auto-backed up by Azure
├── kube-scheduler           → Microsoft manages it
└── Cloud Controller Manager → Microsoft's extra controller (see below)

YOU manage:
└── Worker Node Pools → you choose VM size, count, autoscaling config

If kube-controller-manager crashes:
  → Microsoft's SRE team gets paged, not you
  → It runs in HA mode — a standby instance takes over in seconds
```

In AKS the Control Plane is **completely free** — you only pay for the worker node VMs.

---

### The Extra Controller in AKS — Cloud Controller Manager

This is the biggest difference between default Kubernetes and managed Kubernetes. AKS includes an extra controller called the **Cloud Controller Manager** that knows how to talk to the Azure API.

It has three sub-controllers:

```
Cloud Controller Manager
│
├── Node Controller (cloud version)
│     → When an Azure VM is deleted, automatically removes
│       the corresponding Node from the cluster
│
├── Route Controller
│     → Programs routes in the Azure VNet so pod IPs (Azure CNI)
│       are reachable across nodes without NAT
│
└── Service Controller ← THE MOST IMPORTANT
      → Watches for Services of type: LoadBalancer
      → Calls the Azure API to provision a real Azure Load Balancer
      → Gets a Public IP assigned
      → Configures health probes automatically
      → Writes the IP back to the Service object
```

**Real AzureShop example — how NGINX Ingress got its public IP:**
```
You ran: helm install ingress-nginx (Service type: LoadBalancer)
  ↓
Service Controller (Cloud Controller Manager) sees it
  ↓
Calls Azure API: "Provision a Load Balancer in rg-azureshop-dev"
  ↓
Azure creates Load Balancer + assigns Public IP: 134.33.223.224
  ↓
Service Controller updates the Service:
  status.loadBalancer.ingress[0].ip = "134.33.223.224"
  ↓
kubectl get svc → shows EXTERNAL-IP: 134.33.223.224 ✅
```

Without the Cloud Controller Manager, `type: LoadBalancer` would hang as `<pending>` forever. Kubernetes would have no idea how to talk to Azure and provision a Load Balancer.

---

### Side-by-Side Comparison: Default vs Managed Kubernetes

| | Default K8s (self-managed) | Managed K8s (AKS) |
|---|---|---|
| **Who runs controllers** | You | Microsoft (Control Plane SLA) |
| **Control Plane cost** | You pay for extra VMs | Free |
| **Controller crash at 3am** | You get paged | Microsoft SRE team handles it |
| **etcd backup** | You set it up manually | Automatic |
| **Control Plane HA** | You configure multi-master | Built-in, automatic |
| **Cluster upgrades** | Manual, complex | `az aks upgrade` — one command |
| **Cloud Controller Manager** | Not included | Included — talks to Azure API |
| **LoadBalancer provisioning** | You manually create the LB | Automatic via Cloud Controller |
| **Node removal when VM deleted** | Manual cleanup | Automatic via Cloud Controller |
| **Who manages TLS certs** | You (kubeadm, cert rotation) | Microsoft |

---

### Custom Controllers — The Operator Pattern

Kubernetes lets you write your own controllers for your own custom resources. This is called the **Operator Pattern**. An Operator is a custom controller that extends Kubernetes to manage complex applications automatically.

**Real AzureShop example — Prometheus Operator:**

When you installed `kube-prometheus-stack`, it installed a custom controller called the **Prometheus Operator**. It watches for a custom resource called `PrometheusRule`.

When you applied `azureshop-alerts.yaml`:
```
You: kubectl apply -f k8s/alert-rules/azureshop-alerts.yaml
     (kind: PrometheusRule — a custom resource, not built-in K8s)
  ↓
Prometheus Operator (custom controller) sees the new PrometheusRule
  ↓
Reads the alert definitions (HighErrorRate, PodCrashLoopBackOff, etc.)
  ↓
Injects them into Prometheus configuration automatically
  ↓
Prometheus starts evaluating the alerts — no restart needed ✅
```

Without the Prometheus Operator, you would have to manually edit Prometheus config files and restart Prometheus every time you added or changed an alert. The custom controller automates all of this — same reconciliation loop as built-in controllers, but for YOUR application's needs.

**Other Operator/Custom Controller examples in AzureShop:**

| Operator | What it watches | What it does automatically |
|---|---|---|
| **Prometheus Operator** | `PrometheusRule`, `ServiceMonitor` | Injects alert rules and scrape configs into Prometheus |
| **Flux (GitOps)** | `GitRepository`, `HelmRelease` | Pulls from Git every 1 min, runs `helm upgrade` on changes |
| **KEDA** | `ScaledObject` | Scales pods up/down based on queue length, event count |
| **cert-manager** | `Certificate` | Requests and auto-renews TLS certs from Let's Encrypt |
| **Secrets Store CSI Driver** | `SecretProviderClass` | Fetches secrets from Key Vault, creates K8s Secrets |

All of these follow the same reconciliation loop pattern — watch → compare → act → repeat.

---

### How It All Connects in AzureShop

```
You run: helm upgrade --install user-service ./helm/charts/user-service --set image.tag=v1.0.2
  ↓
Helm sends the new Deployment object to the API Server
  ↓
API Server saves it to etcd → streams change event to all watchers
  ↓
Deployment Controller (built-in): "Deployment updated. Create new ReplicaSet v2."
  ↓
ReplicaSet Controller: "New ReplicaSet v2 needs 0→2 pods. Creating pods."
  ↓
Scheduler: "Pod needs a node. Node aks-user-vmss000001 has capacity. Assigned."
  ↓
kubelet on aks-user-vmss000001: "New pod assigned to me. Pull image from ACR."
  ↓
containerd: pulls user-service:v1.0.2 from acrazureshopdev.azurecr.io
  ↓
Pod starts → readiness probe passes
  ↓
EndpointSlice Controller: "New healthy pod. Add 10.1.0.9:3001 to user-service endpoints."
  ↓
Deployment Controller: "v2 pods healthy. Scale down v1 ReplicaSet."
  ↓
Old pods gracefully terminate (SIGTERM → 30s grace → gone)
  ↓
Rolling update complete. Zero downtime. ✅
```

Every step in this flow is driven by a different controller — all working together, all following the same reconciliation loop.

---

### Interview Prep

1. **What is a Kubernetes controller?** — A control loop that continuously watches the cluster state (via the API Server), compares it to the desired state, and takes action to close any gap. Follows the observe → compare → act → repeat pattern. This is why Kubernetes is self-healing.
2. **What is the reconciliation loop?** — The core pattern every controller follows: read actual state, compare to desired state, act to fix any difference, repeat forever. The same loop whether it's the built-in ReplicaSet Controller or a custom Prometheus Operator.
3. **Where do built-in controllers run?** — Inside `kube-controller-manager`, which runs on the Control Plane. In AKS, Microsoft manages this — you never touch it.
4. **What is the difference between default Kubernetes and AKS regarding controllers?** — In default (self-managed) Kubernetes, YOU run and maintain all Control Plane components including kube-controller-manager. In AKS, Microsoft manages the entire Control Plane. AKS also includes the Cloud Controller Manager — an extra controller that knows how to talk to the Azure API.
5. **What does the Cloud Controller Manager do in AKS?** — It bridges Kubernetes and Azure. Its most important sub-controller is the Service Controller — when you create a `type: LoadBalancer` Service, it automatically calls the Azure API to provision an Azure Load Balancer and assign a Public IP. In AzureShop, this is how NGINX Ingress got its external IP `134.33.223.224`.
6. **What is the Operator Pattern?** — Writing a custom controller for a custom resource. The controller watches for that resource and manages a complex application automatically using the same reconciliation loop as built-in controllers. In AzureShop, the Prometheus Operator watches `PrometheusRule` objects and injects alert rules into Prometheus automatically.
7. **What happens if kube-controller-manager crashes in self-managed vs AKS?** — In self-managed Kubernetes, all reconciliation stops — crashed pods are not replaced, dead nodes not detected, rollouts stall — and you get paged. In AKS, the Control Plane runs in HA mode managed by Microsoft — a standby instance takes over in seconds and their SRE team handles it.
8. **How does a controller watch for changes efficiently without polling every second?** — Using the Kubernetes Watch mechanism. The controller does an initial LIST to sync its cache, then opens a long-lived WATCH stream to the API Server. Changes are pushed to the controller as events in real time. Changes go into a work queue and are processed asynchronously. This is fast (millisecond reaction time) and resource-efficient.

---

## Q22. What is a Kubernetes Service? Full Working, Types, and How AzureShop Uses It?

### The Problem a Service Solves — Why We Need It

Before understanding what a Service IS, understand WHY it exists.

When Kubernetes starts a pod, it assigns the pod a private IP address (e.g. `10.1.0.7`). This IP is **temporary** — the moment the pod dies and is replaced by a new one, the new pod gets a completely different IP (e.g. `10.1.0.15`).

**Real problem in AzureShop without a Service:**
```
api-gateway wants to call user-service
api-gateway's nginx.conf says: "send request to 10.1.0.7:3001"

Night 1: user-service pod crashes → replaced → new IP = 10.1.0.15
Night 2: api-gateway still sends to 10.1.0.7 → CONNECTION REFUSED
         api-gateway has no idea the IP changed
         Every request to user-service fails
```

You would have to manually update the IP every time a pod restarts. That's impossible at scale.

**A Kubernetes Service solves this by giving a permanent, stable network address** — one address that never changes, no matter how many times the pods behind it restart, scale up, or scale down.

---

### What is a Kubernetes Service?

**Think of it like a reception desk at a hospital.**

A hospital has many doctors (pods). Doctors change shifts, go on leave, move to different floors. If patients had to find each doctor's personal room number every time, it would be chaos.

Instead, there is a **reception desk** (the Service). The patient always goes to the reception desk. The reception desk knows which doctors are available and sends the patient to the right one.

```
Patient (caller)
    ↓
Reception desk (Kubernetes Service — stable IP, never changes)
    ↓  (load-balanced)
    ├── Doctor 1 (pod 10.1.0.7 — healthy)
    └── Doctor 2 (pod 10.1.0.15 — healthy)

Doctor 3 goes on leave (pod crashes)?
→ Reception desk automatically stops sending patients to Doctor 3
→ Patient never knows Doctor 3 was unavailable
```

A **Kubernetes Service** is a stable virtual network endpoint that:
- Has a permanent IP address (called **ClusterIP**) that never changes
- Has a permanent DNS name that never changes
- Automatically load-balances traffic across all healthy pods behind it
- Automatically removes unhealthy pods from rotation (via readiness probes)

---

### How a Service Works Internally — Step by Step

#### Step 1 — You Create a Service with a Selector

```yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service        # the stable DNS name
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: user-service        # match ALL pods with this label
  ports:
    - port: 3001             # the port callers use
      targetPort: 3001       # the port the container listens on
```

The `selector` is the key — it says "this Service belongs to all pods labelled `app: user-service`."

#### Step 2 — Kubernetes Assigns a Stable ClusterIP

When you apply this Service, Kubernetes assigns it a **ClusterIP** — a virtual IP from the `service_cidr` range (in AzureShop: `10.0.0.0/16`). This IP is permanent for the lifetime of the Service.

```
Service: user-service
ClusterIP: 10.0.134.22   ← this never changes
DNS name:  user-service.dev.svc.cluster.local  ← this never changes
```

#### Step 3 — EndpointSlice Controller Tracks Healthy Pods

The EndpointSlice Controller watches all pods with the matching label (`app: user-service`) and maintains a live list of their IPs. Only pods passing their readiness probe are in this list.

```
EndpointSlice for user-service:
  10.1.0.7:3001   ← pod 1 (healthy, in rotation)
  10.1.0.15:3001  ← pod 2 (healthy, in rotation)
```

#### Step 4 — kube-proxy Programs the Routing Rules

On every node in the cluster, **kube-proxy** watches the EndpointSlice and programs **iptables rules** (or IPVS rules). These rules say:

```
"Any packet going to 10.0.134.22:3001 →
  randomly send to either 10.1.0.7:3001 OR 10.1.0.15:3001"
```

This happens automatically on every node. So any pod on any node can reach user-service via its ClusterIP.

#### Step 5 — DNS Resolution (The Magic Part)

**CoreDNS** runs inside the cluster and provides DNS resolution. When api-gateway's nginx.conf says:

```nginx
server user-service:3001;
```

The DNS lookup `user-service` resolves to the ClusterIP `10.0.134.22`. The request goes to the ClusterIP. iptables routes it to one of the healthy pods. All transparently.

```
nginx (in api-gateway pod)
  → DNS lookup: "user-service"
  → CoreDNS returns: 10.0.134.22 (ClusterIP)
  → Request hits 10.0.134.22:3001
  → iptables on the node: "route to 10.1.0.7:3001"
  → user-service pod receives the request
```

Pod restarts and gets new IP `10.1.1.9`? EndpointSlice updates → iptables updates → next request automatically goes to `10.1.1.9`. The nginx.conf never changes. Zero downtime.

---

### The Four Types of Kubernetes Services

#### Type 1 — ClusterIP (Default)
The most common type. Creates a virtual IP **only reachable inside the cluster**. No external access.

```
External world → ❌ cannot reach ClusterIP
Pod inside cluster → ✅ can reach ClusterIP
```

```yaml
spec:
  type: ClusterIP        # default — internal only
  ports:
    - port: 3001
      targetPort: 3001
```

**Use for:** Any service that should only be called by other services inside the cluster. In AzureShop — ALL 8 microservices use ClusterIP because they are never directly accessed from the internet.

---

#### Type 2 — NodePort
Opens a port (30000–32767) on **every node's IP address**. External traffic can reach the service by hitting `<any-node-IP>:<nodePort>`.

```
External world → NodeIP:32001
                     ↓
               Service (NodePort)
                     ↓
               Pod 1 or Pod 2
```

```yaml
spec:
  type: NodePort
  ports:
    - port: 3001
      targetPort: 3001
      nodePort: 32001    # opens on every node
```

**Problems:** Exposes node IPs publicly. Port range is ugly (32001 not 80/443). No load balancing across nodes. Not used in production.

**Use for:** Development/testing only, or on-premises where you have no cloud load balancer.

**AzureShop:** NOT used. We use ClusterIP + Ingress instead.

---

#### Type 3 — LoadBalancer
Builds on NodePort but also **provisions a cloud load balancer automatically** (via the Cloud Controller Manager). Gives a clean public IP.

```
Internet
    ↓
Azure Load Balancer (Public IP: 134.33.223.224)  ← provisioned automatically
    ↓
NodePort on each node
    ↓
Pod 1 or Pod 2
```

```yaml
spec:
  type: LoadBalancer      # triggers Cloud Controller Manager
```

When you apply this in AKS:
- Cloud Controller Manager calls the Azure API
- Azure provisions a Load Balancer + assigns a Public IP
- The IP appears in `kubectl get svc` under EXTERNAL-IP

**AzureShop:** Used by **NGINX Ingress Controller only**. The Ingress Controller's Service is `type: LoadBalancer` — that's how it got the public IP `134.33.223.224`. All actual application services stay as ClusterIP; the Ingress is the single entry point.

---

#### Type 4 — ExternalName
Maps a Service name to an **external DNS name** (outside the cluster). No proxying, no load balancing — pure DNS alias.

```yaml
spec:
  type: ExternalName
  externalName: mydb.postgres.database.azure.com
```

Now inside the cluster, pods can call `postgres-db` and it resolves to `mydb.postgres.database.azure.com`. Useful for abstracting external services so you can swap them without changing application code.

**AzureShop:** NOT used, but a valid pattern for referencing Azure SQL or Cosmos DB by a cluster-internal name.

---

### Quick Comparison Table

| Type | Accessible From | Gets External IP | Use Case |
|---|---|---|---|
| **ClusterIP** | Inside cluster only | No | Internal service-to-service communication |
| **NodePort** | NodeIP:port from outside | No (you use node IP) | Dev/test, on-premises |
| **LoadBalancer** | Internet via cloud LB | Yes (cloud-assigned) | Single public-facing entry point |
| **ExternalName** | Inside cluster only | No | Abstract an external DNS name |

---

### Kubernetes Service vs Ingress — What is the Difference?

This confuses many beginners. Both deal with traffic. Here is the exact difference:

| | Service | Ingress |
|---|---|---|
| **What it is** | A stable network endpoint for pods | An HTTP routing rule |
| **Works at** | Layer 4 (TCP/UDP, IP+port) | Layer 7 (HTTP, URL path, hostname) |
| **Routes by** | Just IP and port | URL path, hostname, headers |
| **Needs a controller?** | No — built into Kubernetes | Yes — needs Ingress Controller (e.g. NGINX) |
| **One per service?** | Yes — every service has its own | One Ingress can route to many services |

**Think of it this way:**
- **Service** = the phone number of each department in a company
- **Ingress** = the receptionist who listens to what you need and transfers you to the right department

In AzureShop:
```
Internet → NGINX Ingress Controller (Layer 7 routing)
               ├── /api/* → api-gateway Service (ClusterIP)
               └── /*     → frontend Service (ClusterIP)
```

The Ingress handles the smart routing. The Services are the stable addresses of each destination.

---

### Where Are Services Defined in AzureShop? — Exact Locations

**Yes, AzureShop absolutely uses Services.** Every single microservice has its own Service definition. Here is the exact location of every Service file:

```
AzureShop/
└── helm/
    └── charts/
        ├── user-service/
        │   ├── templates/
        │   │   └── service.yaml        ← Service definition (template)
        │   └── values.yaml             ← port: 3001, targetPort: 3001
        │
        ├── product-service/
        │   ├── templates/
        │   │   └── service.yaml        ← Service definition (template)
        │   └── values.yaml             ← port: 3002, targetPort: 3002
        │
        ├── cart-service/
        │   ├── templates/
        │   │   └── service.yaml        ← port: 3003
        │
        ├── order-service/
        │   ├── templates/
        │   │   └── service.yaml        ← port: 3004
        │
        ├── payment-service/
        │   ├── templates/
        │   │   └── service.yaml        ← port: 3005
        │
        ├── notification-service/
        │   ├── templates/
        │   │   └── service.yaml        ← port: 3006
        │
        ├── frontend/
        │   ├── templates/
        │   │   └── service.yaml        ← port: 3000
        │
        └── api-gateway/
            ├── templates/
            │   └── service.yaml        ← port: 8080
```

**All 8 services are type: ClusterIP.** None are exposed directly to the internet.

---

### The Actual Service Template (from your project)

Every service in AzureShop uses the same Helm template. Here is the actual file from `helm/charts/user-service/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "azureshop.name" . }}      # resolves to "user-service"
  namespace: {{ .Release.Namespace }}          # resolves to "dev"
  labels:
    {{- include "azureshop.labels" . | nindent 4 }}
spec:
  type: ClusterIP                              # internal only
  ports:
    - port: {{ .Values.service.port }}         # 3001 (from values.yaml)
      targetPort: {{ .Values.service.targetPort }}  # 3001
      protocol: TCP
      name: http
  selector:
    {{- include "azureshop.selectorLabels" . | nindent 4 }}
    # resolves to: app: user-service
    # matches all pods labelled app: user-service
```

The `selector` is the bridge between the Service and the pods — it's how the Service knows which pods to route traffic to.

---

### All 8 Services at a Glance

| Service Name | DNS Name (inside cluster) | Port | Type |
|---|---|---|---|
| `user-service` | `user-service.dev.svc.cluster.local` | 3001 | ClusterIP |
| `product-service` | `product-service.dev.svc.cluster.local` | 3002 | ClusterIP |
| `cart-service` | `cart-service.dev.svc.cluster.local` | 3003 | ClusterIP |
| `order-service` | `order-service.dev.svc.cluster.local` | 3004 | ClusterIP |
| `payment-service` | `payment-service.dev.svc.cluster.local` | 3005 | ClusterIP |
| `notification-service` | `notification-service.dev.svc.cluster.local` | 3006 | ClusterIP |
| `frontend` | `frontend.dev.svc.cluster.local` | 3000 | ClusterIP |
| `api-gateway` | `api-gateway.dev.svc.cluster.local` | 8080 | ClusterIP |

Inside the same namespace (`dev`), pods can use the **short name** — just `user-service:3001`. Kubernetes CoreDNS automatically appends `.dev.svc.cluster.local`.

---

### How Services Are Used in AzureShop — Complete Traffic Flow

```
User's browser: GET http://134.33.223.224/api/users/profile
      ↓
Azure Load Balancer (134.33.223.224)    ← provisioned by Cloud Controller Manager
      ↓                                   for NGINX Ingress Service (LoadBalancer type)
NGINX Ingress Controller pod
      ↓   path starts with /api/
Ingress rule → backend: api-gateway:8080
      ↓
api-gateway Service (ClusterIP: 10.0.45.12)
      ↓   kube-proxy routes to a healthy pod
api-gateway pod (nginx.conf running)
      ↓   location /api/users/ → proxy_pass http://user_service/users/
      ↓   DNS: "user-service" → CoreDNS → 10.0.134.22 (ClusterIP)
user-service Service (ClusterIP: 10.0.134.22)
      ↓   kube-proxy routes to a healthy pod
user-service pod (Node.js app)
      ↓
Queries Azure SQL Database
      ↓
Returns JSON response all the way back up the chain
```

Every arrow that crosses a Service boundary goes through the ClusterIP → iptables → pod resolution. All transparent. All automatic. All load-balanced.

---

### Why api-gateway Uses Service Names Not IPs — The Key Insight

Look at `services/api-gateway/nginx.conf` in the project:

```nginx
upstream user_service {
  server user-service:3001;      # ← SERVICE NAME, not an IP
}
upstream product_service {
  server product-service:3002;   # ← SERVICE NAME, not an IP
}
```

This is intentional and critical. If nginx used pod IPs directly (`10.1.0.7:3001`), the moment that pod restarts and gets a new IP, nginx would be pointing to a dead address.

By using the Service name `user-service`, nginx asks CoreDNS to resolve it → gets the ClusterIP → kube-proxy routes to a live pod. This works forever, regardless of how many times pods restart, scale, or move to different nodes.

**This is the entire reason Services exist.**

---

### Interview Prep

1. **What is a Kubernetes Service and why do we need it?** — A Service is a stable network endpoint (permanent IP + DNS name) that sits in front of pods. We need it because pod IPs are temporary — they change every time a pod restarts. The Service gives callers a permanent address that never changes, regardless of what happens to the pods behind it.
2. **How does a Service know which pods to route to?** — Through a `selector` (label matching). The Service selects all pods that have the matching label (e.g. `app: user-service`). The EndpointSlice Controller maintains the live list of IPs of those pods. Only pods passing their readiness probe are in the list.
3. **What is a ClusterIP and how is it different from a pod IP?** — A ClusterIP is a virtual IP assigned to a Service — it never changes and is permanent. A pod IP is assigned to a specific pod — it changes every time the pod restarts. The ClusterIP is the stable address; pod IPs are the temporary destinations behind it.
4. **What is the difference between ClusterIP, NodePort, and LoadBalancer?** — ClusterIP is internal only — accessible only inside the cluster. NodePort opens a port on every node's physical IP — accessible from outside but ugly. LoadBalancer provisions a cloud load balancer (in AKS via Cloud Controller Manager) and gives a clean public IP — the proper way to expose a service to the internet.
5. **How are Services used in AzureShop?** — All 8 microservices have ClusterIP Services. None are directly exposed to the internet. The NGINX Ingress Controller has a LoadBalancer Service that got the public IP `134.33.223.224`. The Ingress routes HTTP traffic by URL path to the correct ClusterIP Service. api-gateway's nginx.conf references backend services by their Service DNS name (e.g. `user-service:3001`) not by pod IP.
6. **Where exactly are Services defined in AzureShop?** — In `helm/charts/{service-name}/templates/service.yaml` for each of the 8 services. Port values come from `helm/charts/{service-name}/values.yaml`. All are `type: ClusterIP`.
7. **What is the difference between a Service and an Ingress?** — A Service works at Layer 4 (IP + port) and gives a stable address to a group of pods. An Ingress works at Layer 7 (HTTP) and routes requests based on URL path or hostname to different Services. You need both: Ingress for smart HTTP routing, Services as the stable destinations.
8. **Why does api-gateway use service names like `user-service:3001` instead of pod IPs?** — Because pod IPs change every time a pod restarts. Service names are permanent — CoreDNS resolves `user-service` to the ClusterIP, and kube-proxy routes from the ClusterIP to a live pod. Using the service name means the configuration never needs to change regardless of pod restarts or scaling.

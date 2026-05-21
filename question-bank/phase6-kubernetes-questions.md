# Phase 6 — AKS Kubernetes: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Pod vs Deployment vs Service, liveness vs readiness probes, namespaces, PodDisruptionBudget, Azure CNI vs Kubenet, kubelogin, Key Vault CSI Driver, kubelet identity vs CSI addon identity, system vs user node pools, Helm vs kubectl apply, HPA, NetworkPolicy zero trust, Kubernetes Secret vs SecretProviderClass, Workload Identity, Kubernetes Nodes and Cluster architecture, Node Pools and types, Zero Downtime deployments, ConfigMap and Secret, Azure CNI deep dive, Azure AD and Azure RBAC for AKS.

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

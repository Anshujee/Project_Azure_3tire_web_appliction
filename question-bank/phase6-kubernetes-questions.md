# Phase 6 — AKS Kubernetes: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Pod vs Deployment vs Service, liveness vs readiness probes, namespaces, PodDisruptionBudget, Azure CNI vs Kubenet, kubelogin, Key Vault CSI Driver, kubelet identity vs CSI addon identity, system vs user node pools, Helm vs kubectl apply, HPA, NetworkPolicy zero trust, Kubernetes Secret vs SecretProviderClass, Workload Identity, Kubernetes Nodes and Cluster architecture, Node Pools and types, Zero Downtime deployments, ConfigMap and Secret, Azure CNI deep dive, Azure AD and Azure RBAC for AKS, Managed Identity vs Service Principal, k8s folder structure, Azure VNet Service Endpoints vs Kubernetes Endpoints, Service Endpoint vs Service Principal, Kubernetes Controllers (built-in vs managed), Reconciliation Loop, Cloud Controller Manager, Custom Controllers / Operator Pattern, Labels and Selectors (matchLabels, matchExpressions, pod-to-service wiring, Helm template labels), Kubernetes RBAC (Role, ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount, Azure RBAC vs K8s RBAC, Workload Identity integration), Service Mesh and Istio (sidecar proxy, control plane vs data plane, mTLS, traffic management, observability, VirtualService, DestinationRule, Gateway, circuit breaker, canary deployments, AzureShop comparison), Kubernetes Autoscaling (HPA, VPA, Cluster Autoscaler, KEDA, metrics-server, how Services enable transparent scaling, AzureShop HPA and node autoscaler implementation), Persistent Volumes and PVCs (PV lifecycle, StorageClass, access modes, emptyDir vs PVC, static vs dynamic provisioning, AzureShop Prometheus/Grafana PVC usage, Azure Disk vs Azure File), Kubernetes Ingress (Ingress resource vs Ingress Controller, NGINX Ingress, path-based routing, TLS termination, canary deployments, how AzureShop routes traffic through Application Gateway → NGINX → api-gateway → services).

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
23. [What is the Role of kube-proxy in Kubernetes?](#q23-what-is-the-role-of-kube-proxy-in-kubernetes)
24. [What are Labels and Selectors in Kubernetes? How are They Different and How Does AzureShop Use Them?](#q24-what-are-labels-and-selectors-in-kubernetes-how-are-they-different-and-how-does-azureshop-use-them)
25. [What is Kubernetes RBAC? How Does it Work, What are Roles, RoleBindings, ClusterRoles, and ServiceAccounts?](#q25-what-is-kubernetes-rbac-how-does-it-work-what-are-roles-rolebindings-clusterroles-and-serviceaccounts)
26. [What is a Service Mesh? What is Istio, How Does it Work, and What Problems Does it Solve in Kubernetes?](#q26-what-is-a-service-mesh-what-is-istio-how-does-it-work-and-what-problems-does-it-solve-in-kubernetes)
27. [How Does Autoscaling Work in Kubernetes? Explain HPA, VPA, Cluster Autoscaler, and KEDA with How Services Fit In](#q27-how-does-autoscaling-work-in-kubernetes-explain-hpa-vpa-cluster-autoscaler-and-keda-with-how-services-fit-in)
28. [What is a Persistent Volume and a Persistent Volume Claim in Kubernetes?](#q28-what-is-a-persistent-volume-and-a-persistent-volume-claim-in-kubernetes)
29. [What is Kubernetes Ingress? How Does it Work, and How is it Used in AzureShop?](#q29-what-is-kubernetes-ingress-how-does-it-work-and-how-is-it-used-in-azureshop)

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

---

## Q23. What is the Role of kube-proxy in Kubernetes?

### The One-Line Answer

**kube-proxy is the traffic director on every node.** It makes sure that when a request arrives at a Service's virtual IP (ClusterIP), that request actually reaches a real, live pod — by programming the networking rules on the node's operating system.

---

### The Problem kube-proxy Solves

In Q22 we learned that a Kubernetes Service has a **ClusterIP** — a virtual, permanent IP address (e.g. `10.0.134.22`). But here is the important thing:

**A ClusterIP is NOT a real IP address. No actual network interface holds it. No physical device owns it.**

It is completely virtual — it only exists as a rule in the node's kernel. If you try to ping a ClusterIP from outside the cluster, nothing responds. It is purely a routing trick.

The question then is: **how does a packet sent to `10.0.134.22:3001` actually reach the user-service pod at `10.1.0.7:3001`?**

The answer is **kube-proxy**.

---

### What is kube-proxy?

**Think of kube-proxy like a postman inside your building.**

Your building (Kubernetes node) receives a letter addressed to "Reception Desk, Room 10.0.134.22" (the ClusterIP). But Room 10.0.134.22 does not physically exist. The postman (kube-proxy) knows the real room numbers of the people who work at the reception desk (the pods). He grabs the letter and delivers it directly to one of the real rooms.

```
Letter arrives: "deliver to 10.0.134.22:3001"   (ClusterIP — virtual)
     ↓
Postman (kube-proxy) checks his routing table:
"10.0.134.22 maps to: 10.1.0.7:3001 or 10.1.0.15:3001"
     ↓
Postman re-addresses the letter: "deliver to 10.1.0.7:3001"  (real pod IP)
     ↓
Letter delivered to the actual pod
```

kube-proxy does this at the **Linux kernel level** — it programs the kernel's packet filtering rules so this translation happens automatically for every packet, at wire speed, before any user-space code even sees the packet.

---

### Where Does kube-proxy Run?

kube-proxy runs as a **DaemonSet** — meaning **one kube-proxy pod on every single node** in the cluster. It is not just on the control plane. Every worker node has its own kube-proxy.

```
Cluster: aks-azureshop-dev
│
├── Control Plane (managed by Azure)
│
├── Node: aks-system-vmss000000    → kube-proxy pod running here
├── Node: aks-system-vmss000001    → kube-proxy pod running here
├── Node: aks-user-vmss000000      → kube-proxy pod running here
└── Node: aks-user-vmss000001      → kube-proxy pod running here
```

Why on every node? Because **any pod on any node** might need to call any Service. The routing rules must exist on every node so the translation can happen locally, without sending the packet to some central proxy first. Local = fast.

---

### How kube-proxy Works — Step by Step

#### Step 1 — kube-proxy Watches the API Server

kube-proxy runs a watch loop against the API Server — the same reconciliation pattern as controllers. It watches for:
- **Service** objects — to know what ClusterIPs exist and which ports they use.
- **EndpointSlice** objects — to know the live pod IPs behind each Service.

```
kube-proxy → API Server: "Watch Services and EndpointSlices"
API Server → kube-proxy: "New Service created: user-service, ClusterIP 10.0.134.22, port 3001"
API Server → kube-proxy: "EndpointSlice updated: pods are 10.1.0.7:3001 and 10.1.0.15:3001"
```

#### Step 2 — kube-proxy Programs iptables Rules

When kube-proxy learns about a Service and its endpoints, it immediately programs **iptables rules** (Linux kernel packet filtering) on its node.

The rules look like this conceptually:

```
Rule 1: "Any packet going to 10.0.134.22:3001 →
         randomly send to EITHER 10.1.0.7:3001 OR 10.1.0.15:3001"

Rule 2: "If you chose 10.1.0.7:3001, rewrite the destination IP
         from 10.0.134.22 to 10.1.0.7 (DNAT)"
```

This rewriting of the destination IP is called **DNAT (Destination Network Address Translation)**. The kernel does this at the packet level — before the packet reaches any application.

#### Step 3 — Packet Travels to the Pod

After DNAT, the packet has the pod's real IP. The kernel routes it normally — either to a pod on the same node (no network hop) or across the node's network interface to a pod on a different node.

```
Source: api-gateway pod (10.1.0.3)
Destination written by app: 10.0.134.22:3001   ← ClusterIP (virtual)

iptables DNAT kicks in (kube-proxy programmed this):
Destination rewritten to: 10.1.0.7:3001        ← real pod IP

Packet travels to 10.1.0.7 on node aks-user-vmss000000
user-service pod receives the packet ✅
```

The api-gateway pod thinks it talked to `10.0.134.22`. It has no idea that DNAT happened. It is completely transparent.

#### Step 4 — Response Comes Back (SNAT)

The response from the pod (`10.1.0.7`) goes back. The kernel also rewrites the source IP back to the ClusterIP (`10.0.134.22`) so the caller thinks the response came from the Service. This is **SNAT (Source NAT)**. Again, fully transparent.

---

### The Three Modes of kube-proxy

kube-proxy can work in three different modes. The mode determines HOW it programs the node's networking rules.

#### Mode 1 — iptables (Default in most clusters, including AKS)

Programs Linux **iptables** rules — a chain of packet matching rules in the kernel.

```
Packet arrives at node
  ↓
Kernel checks iptables chain: PREROUTING
  ↓
Matches rule: "dest is 10.0.134.22:3001"
  ↓
Randomly picks one pod IP (50/50 for 2 pods) using iptables probability
  ↓
DNAT: rewrites destination to chosen pod IP
  ↓
Packet forwarded to pod
```

**Pros:** Stable, battle-tested, works on all Linux kernels.
**Cons:** At very large scale (10,000+ Services), the iptables chain becomes very long → each packet must check through thousands of rules → can add latency. Also, iptables uses random selection (not true round-robin) so load distribution is not perfectly even.

#### Mode 2 — IPVS (IP Virtual Server)

Uses the Linux kernel's **IPVS** module — a purpose-built load balancing subsystem. Instead of a chain of rules (iptables), IPVS uses a hash table — O(1) lookup regardless of how many Services exist.

```
Packet arrives at node
  ↓
Kernel IPVS hash table lookup: "10.0.134.22:3001"
  ↓
IPVS picks pod using a proper load balancing algorithm:
  - Round Robin
  - Least Connections
  - Source IP Hash (sticky sessions)
  ↓
DNAT → packet forwarded
```

**Pros:** Scales to 100,000+ Services without performance degradation. Better load balancing algorithms. Real round-robin.
**Cons:** Requires IPVS kernel modules (available in AKS). Slightly more complex setup.

#### Mode 3 — userspace (Legacy, not used anymore)

Old mode where kube-proxy itself acted as a proxy in user space. Every packet went through the kube-proxy process. Very slow compared to kernel-level modes. Abandoned in modern Kubernetes.

---

### kube-proxy vs CoreDNS — Who Does What?

These two are often confused because they both play a role in getting traffic to the right pod. They solve **different parts of the problem**.

| | CoreDNS | kube-proxy |
|---|---|---|
| **What it does** | Translates a **name** to a ClusterIP | Translates a **ClusterIP** to a real pod IP |
| **Layer** | DNS (name resolution) | Network (packet routing) |
| **When it runs** | When your app does a DNS lookup | When a packet hits the ClusterIP |
| **Output** | "user-service = 10.0.134.22" | "10.0.134.22 → 10.1.0.7 (DNAT in kernel)" |
| **Where it runs** | Pods in kube-system namespace | DaemonSet on every node |

**They work in sequence, not instead of each other:**

```
Step 1 (CoreDNS):
  App says: connect to "user-service:3001"
  DNS lookup: "user-service" → 10.0.134.22  (CoreDNS answers)

Step 2 (kube-proxy):
  Packet sent to 10.0.134.22:3001
  iptables rule (written by kube-proxy) fires: DNAT → 10.1.0.7:3001
  Packet reaches real pod
```

Remove CoreDNS → apps can't resolve service names → they don't know what IP to send to.
Remove kube-proxy → apps resolve the ClusterIP correctly, but packets sent to that IP go nowhere because there are no iptables rules to forward them.

**Both are required. Neither replaces the other.**

---

### kube-proxy and Load Balancing

kube-proxy provides **basic load balancing** across pods. In iptables mode, it uses probability-based rules:

```
2 pods behind user-service:

iptables rule chain:
  Rule A: "50% chance → DNAT to 10.1.0.7:3001"
  Rule B: "50% chance → DNAT to 10.1.0.15:3001"
```

For 3 pods:
```
  Rule A: "33% → pod 1"
  Rule B: "50% of remaining → pod 2"   (= 33% overall)
  Rule C: "100% of remaining → pod 3"  (= 33% overall)
```

This is **random selection**, not true round-robin. Under high traffic the distribution averages out, but individual request sequences are not perfectly equal.

**Important:** kube-proxy load balancing is NOT sophisticated. It has no concept of:
- Response time (it doesn't pick the fastest pod)
- Connection count (it doesn't pick the least-loaded pod)
- Session affinity (by default — can be configured with `sessionAffinity: ClientIP`)

For sophisticated load balancing (health-aware, latency-weighted), you use a **service mesh** (Istio, Linkerd) which adds a sidecar proxy (Envoy) to every pod.

---

### What Happens When a Pod Dies — kube-proxy Reacts

This is one of the most important behaviours to understand.

```
Scenario: user-service pod 10.1.0.7 crashes

Step 1: Pod crashes → readiness probe fails (or pod disappears)
Step 2: EndpointSlice Controller removes 10.1.0.7 from the EndpointSlice
Step 3: API Server streams EndpointSlice update event to all kube-proxy instances
Step 4: kube-proxy on EVERY node updates its iptables rules:
        BEFORE: 50% → 10.1.0.7, 50% → 10.1.0.15
        AFTER:  100% → 10.1.0.15
Step 5: All new requests go only to 10.1.0.15
        No requests go to the dead pod
        
Timeline: typically happens within 1-2 seconds of the pod dying
```

This is why Kubernetes achieves near-zero-downtime during pod failures. kube-proxy reacts within seconds of the EndpointSlice being updated.

**In reverse — when a new pod starts:**
```
New user-service pod starts → IP: 10.1.1.22
Passes readiness probe
EndpointSlice updated: adds 10.1.1.22
kube-proxy on all nodes: updates iptables
         BEFORE: 100% → 10.1.0.15
         AFTER:  50% → 10.1.0.15, 50% → 10.1.1.22
New pod immediately starts receiving traffic
```

---

### kube-proxy in AzureShop — Real Example

In AzureShop, every time the user-service Helm chart is deployed:

```
helm upgrade --install user-service ./helm/charts/user-service --set image.tag=v1.0.2
  ↓
New user-service pods created (10.1.1.30, 10.1.1.31)
  ↓
EndpointSlice Controller updates: adds new pod IPs
  ↓
kube-proxy on aks-user-vmss000000 updates iptables:
  "10.0.134.22:3001 → DNAT to 10.1.1.30 or 10.1.1.31"
kube-proxy on aks-user-vmss000001 updates iptables (same rules)
  ↓
Old pods (10.1.0.7, 10.1.0.15) finish graceful shutdown
  ↓
EndpointSlice removes old IPs
  ↓
kube-proxy removes old iptables rules
  ↓
All traffic now reaches new pods with v1.0.2 ✅
```

api-gateway's nginx.conf never changed. CoreDNS still returns the same ClusterIP `10.0.134.22`. But kube-proxy silently swapped the real destination behind that IP. Zero downtime, zero configuration change.

---

### Full Picture — How Everything Connects

```
api-gateway pod wants to call user-service

1. App code: fetch("http://user-service:3001/users/profile")
                           ↓
2. CoreDNS lookup: "user-service.dev.svc.cluster.local"
                   returns: 10.0.134.22
                           ↓
3. TCP packet created:
   src: 10.1.0.3 (api-gateway pod)
   dst: 10.0.134.22:3001 (ClusterIP)
                           ↓
4. Packet enters node's kernel networking stack
   iptables PREROUTING chain fires (written by kube-proxy):
   "dst 10.0.134.22:3001 → DNAT to 10.1.0.7:3001"
   dst rewritten: 10.1.0.7:3001
                           ↓
5. Kernel routes packet to 10.1.0.7
   (if on same node: loopback/veth)
   (if on different node: eth0 → Azure VNet → destination node)
                           ↓
6. user-service pod receives request at 10.1.0.7:3001
                           ↓
7. Response: src 10.1.0.7 → kernel rewrites to 10.0.134.22 (SNAT)
   api-gateway sees response from 10.0.134.22 — consistent ✅

Total time for steps 3-5: microseconds (kernel-level, no user-space)
```

---

### kube-proxy vs No kube-proxy (Modern Alternatives)

In very modern Kubernetes setups, kube-proxy is being **replaced by eBPF-based solutions**:

| | kube-proxy (iptables) | Cilium (eBPF) |
|---|---|---|
| **How** | Programs iptables rules in kernel | Programs eBPF programs directly in kernel |
| **Scale** | Degrades at 10k+ Services | Handles 100k+ Services efficiently |
| **Observability** | Limited | Deep — per-packet visibility |
| **Load balancing** | Random selection | True round-robin, maglev hashing |
| **AzureShop** | Uses kube-proxy (default AKS) | Not used |

AKS supports Cilium as an optional CNI. For AzureShop's scale (8 services, dev cluster), kube-proxy is perfectly sufficient.

---

### Interview Prep

1. **What is kube-proxy and what does it do?** — kube-proxy runs on every node as a DaemonSet. It watches the API Server for Service and EndpointSlice changes, and programs iptables rules on the node so that packets sent to a Service's virtual ClusterIP get DNAT'd (destination rewritten) to a real pod IP. It is the mechanism that makes ClusterIPs actually work.
2. **What is DNAT and why does kube-proxy use it?** — DNAT = Destination Network Address Translation. When a packet arrives at the node destined for a ClusterIP (which is virtual — no real device holds it), kube-proxy's iptables rules rewrite the destination to a real pod IP. The application never knows this happened — it thinks it talked directly to the ClusterIP.
3. **What is the difference between kube-proxy and CoreDNS?** — CoreDNS translates a service name (like `user-service`) into a ClusterIP (`10.0.134.22`) — it does DNS resolution. kube-proxy translates the ClusterIP into a real pod IP at the packet level using iptables. They work in sequence: CoreDNS resolves the name, kube-proxy routes the packet. Both are required.
4. **Why does kube-proxy run on every node, not just the control plane?** — Because any pod on any node may call any Service. The iptables rules must exist locally on every node so the routing happens at the kernel level without sending packets to a central proxy. Local kernel rules = microsecond latency.
5. **What are the modes of kube-proxy?** — Three modes: **iptables** (default — kernel rule chain, works well at moderate scale), **IPVS** (hash table-based, O(1) lookup, better for 10k+ Services, better load balancing algorithms), and **userspace** (legacy, deprecated — kube-proxy process acted as proxy, very slow).
6. **What happens in kube-proxy when a pod crashes?** — The pod fails its readiness probe → EndpointSlice Controller removes that pod's IP from the EndpointSlice → API Server streams the change to all kube-proxy instances → kube-proxy on every node updates its iptables rules to remove that pod IP → no new packets are routed to the dead pod. This happens within 1-2 seconds.
7. **Does kube-proxy do load balancing?** — Yes, basic load balancing. In iptables mode it uses probability rules — each pod gets an equal random chance of receiving the next packet. It does NOT do latency-aware, connection-count-aware, or true round-robin balancing. For that, a service mesh (Istio/Linkerd with Envoy sidecar) is needed.
8. **In AzureShop, when does kube-proxy update its rules?** — Every time a Helm deployment changes the running pods: old pods terminate, new pods start → EndpointSlice is updated → kube-proxy on all 4 nodes (2 system + 2 user) updates iptables rules → traffic silently shifts from old pod IPs to new pod IPs. The ClusterIP, DNS name, and nginx.conf never change.

---

## Q24. What are Labels and Selectors in Kubernetes? How are They Different and How Does AzureShop Use Them?

### The Core Problem Labels and Selectors Solve

In Kubernetes, you have many objects: dozens of pods, multiple Services, Deployments, HPAs, NetworkPolicies. Kubernetes needs a way to say: **"this Service belongs to these pods"**, **"this HPA controls this Deployment"**, **"this NetworkPolicy applies to these pods"**.

Without labels, Kubernetes would have no way to connect objects to each other. It cannot use pod names (they contain random suffixes like `-7d4f9b-xk2p9` that change every restart). It cannot use IP addresses (those change too). Labels are the answer.

Think of it like a **luggage tag** at an airport. You write your name on a tag and attach it to your bag. The baggage carousel attendant reads the tag and sends it to the right passenger. Labels are the tags; selectors are how Kubernetes reads and matches those tags.

---

### What is a Label?

A label is a **key-value pair** that you attach to any Kubernetes object (Pod, Deployment, Service, Node, Namespace, etc.). It is just metadata — it does not change how the object behaves on its own. Labels only matter when something else **reads them using a selector**.

```yaml
metadata:
  labels:
    app: user-service        # key=app, value=user-service
    env: production          # key=env, value=production
    version: v1.0.0          # key=version, value=v1.0.0
```

Labels are:
- **Arbitrary** — you invent any key-value pairs you want
- **Multiple** — one object can have many labels
- **Mutable** — you can add, remove, or change labels without restarting the object
- **Not unique** — many objects can share the same label (that is the point — a selector finds all of them)

---

### What is a Selector?

A selector is a **query or filter** that an object uses to find other objects by their labels. A selector says: "give me all objects that have label `app=user-service`."

There are two types of selectors in Kubernetes:

#### 1. Equality-Based Selector (`matchLabels`)

The simplest form. It says: label key must equal this value.

```yaml
selector:
  matchLabels:
    app: user-service       # find pods where app == user-service
```

This is what you see in almost every Deployment and Service. It finds all pods where `app` equals `user-service`.

#### 2. Set-Based Selector (`matchExpressions`)

More powerful. Supports `In`, `NotIn`, `Exists`, `DoesNotExist` operators.

```yaml
selector:
  matchExpressions:
    - key: env
      operator: In
      values: [production, staging]   # env must be either production or staging
    - key: tier
      operator: NotIn
      values: [cache]                 # tier must NOT be cache
    - key: critical
      operator: Exists               # label critical must exist (any value)
```

`matchLabels` and `matchExpressions` can be combined — both must match simultaneously (logical AND).

---

### Labels vs Selectors — The Key Difference

| Concept | What it is | Where it lives | Who uses it |
|---|---|---|---|
| **Label** | A key-value tag attached TO an object | On the object itself (Pod, Deployment, etc.) | Passive — just sits there |
| **Selector** | A query that finds objects BY their labels | On the object that wants to find others | Active — searches for matching labels |

Labels are like price tags on products. A selector is like a shopping filter ("show me all red items under $20"). The product doesn't know it's being filtered; the filter just reads the tags.

---

### How Labels Wire Objects Together

The most important use of labels and selectors in day-to-day Kubernetes is the **Deployment → Service wiring**. Here is exactly how it works:

#### Step 1: Deployment creates pods with labels

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  selector:
    matchLabels:
      app: user-service          # Deployment manages pods that have this label
  template:                      # pod template — every pod gets these labels
    metadata:
      labels:
        app: user-service        # ← label stamped on every pod
        version: v1.0.0
    spec:
      containers:
        - name: user-service
          image: acrazureshopdev.azurecr.io/user-service:v1.0.0
```

Every pod the Deployment creates gets labels `app=user-service` and `version=v1.0.0` stamped on it automatically.

#### Step 2: Service finds pods using a selector

```yaml
apiVersion: v1
kind: Service
spec:
  selector:
    app: user-service            # ← find all pods where app == user-service
  ports:
    - port: 3001
      targetPort: 3001
```

The Service does NOT reference the Deployment by name. It does NOT reference pod names. It finds pods purely by reading their labels. Any pod on any node with label `app=user-service` will be added to this Service's endpoint list.

#### Why This is Powerful

```
BEFORE update:
  pod-v1-abc (app=user-service, version=v1.0.0) ← included in Service
  pod-v1-def (app=user-service, version=v1.0.0) ← included in Service

DURING rolling update:
  pod-v1-abc (app=user-service, version=v1.0.0) ← still included
  pod-v2-xyz (app=user-service, version=v2.0.0) ← automatically included (same app label!)

AFTER update completes:
  pod-v2-xyz (app=user-service, version=v2.0.0) ← included
  pod-v2-pqr (app=user-service, version=v2.0.0) ← included
```

The Service always routes to whatever pods match its selector — whether those pods are old, new, or a mix during an update. Zero downtime rolling updates work because labels remain consistent across versions.

---

### The Deployment's Own Selector vs the Pod Template's Labels

A Deployment has TWO separate label sections, and beginners often confuse them:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels:                        # ← labels ON THE DEPLOYMENT OBJECT ITSELF
    app: user-service            #    used by nothing critical; just for kubectl filtering
spec:
  selector:
    matchLabels:
      app: user-service          # ← what pods this Deployment manages (IMMUTABLE after creation)
  template:
    metadata:
      labels:
        app: user-service        # ← labels stamped on PODS created by this Deployment
        version: v1.0.0          #    must be a superset of spec.selector.matchLabels
```

**Critical rule:** `spec.selector.matchLabels` must be a **subset** of `spec.template.metadata.labels`. If the selector asks for `app=user-service`, every pod template must have `app=user-service`. If they don't match, Kubernetes rejects the Deployment at creation time.

**Also critical:** `spec.selector` is **immutable** — you cannot change the Deployment's selector labels after it is created. You have to delete and recreate the Deployment if you need to change selectors. This is because changing the selector would cause the Deployment to "orphan" its existing pods (they no longer match) and create a new set — which is dangerous and usually a mistake.

---

### Labels in AzureShop — How the Helm Template Works

In AzureShop, all Kubernetes objects are generated from Helm templates. Let's trace exactly how labels flow through the system.

#### The Helm helper template — `_helpers.tpl`

The shared library chart defines reusable label snippets:

```
helm/charts/user-service/templates/_helpers.tpl
```

This file (generated by `helm create`) defines two key functions:

```go
{{- define "azureshop.labels" -}}
helm.sh/chart: {{ include "azureshop.chart" . }}
{{ include "azureshop.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "azureshop.selectorLabels" -}}
app.kubernetes.io/name: {{ include "azureshop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

There are **two separate label sets** used for different purposes:

| Helper | Labels it produces | Used where |
|---|---|---|
| `azureshop.labels` | 4 labels: chart name, version, service name, instance, managed-by | Deployment metadata, Service metadata — all objects for `kubectl get` filtering |
| `azureshop.selectorLabels` | 2 labels: service name + release instance | `spec.selector.matchLabels` and pod template labels — the ones that wire Service to pods |

The `selectorLabels` are kept minimal (only 2) because they are **immutable** once the Deployment is created. `version` is NOT in selectorLabels — if it were, a version bump would create a new Deployment with a different selector, orphaning all existing pods.

#### The Deployment template

```
helm/charts/user-service/templates/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "azureshop.name" . }}        # e.g. "user-service"
  labels:
    {{- include "azureshop.labels" . | nindent 4 }}   # all 4 labels on the Deployment object
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "azureshop.selectorLabels" . | nindent 6 }}  # 2 selector labels (immutable)
  template:
    metadata:
      labels:
        {{- include "azureshop.labels" . | nindent 8 }}         # all 4 labels on pods
```

For user-service, this renders to:

```yaml
# On the Deployment object:
labels:
  helm.sh/chart: user-service-0.1.0
  app.kubernetes.io/name: user-service
  app.kubernetes.io/instance: user-service
  app.kubernetes.io/version: "v1.0.0"
  app.kubernetes.io/managed-by: Helm

# Deployment's selector (immutable):
selector:
  matchLabels:
    app.kubernetes.io/name: user-service
    app.kubernetes.io/instance: user-service

# Labels on pods:
labels:
  helm.sh/chart: user-service-0.1.0
  app.kubernetes.io/name: user-service
  app.kubernetes.io/instance: user-service
  app.kubernetes.io/version: "v1.0.0"
  app.kubernetes.io/managed-by: Helm
```

#### The Service template

```
helm/charts/user-service/templates/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "azureshop.name" . }}        # "user-service"
  labels:
    {{- include "azureshop.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "azureshop.selectorLabels" . | nindent 4 }}  # matches pods by same 2 labels
  ports:
    - port: {{ .Values.service.port }}           # 3001
      targetPort: {{ .Values.service.targetPort }}
```

The Service uses `selectorLabels` — the same 2 labels as the Deployment's `spec.selector.matchLabels`. This guarantees the Service always selects exactly the pods managed by this Deployment.

#### The HPA template

```
helm/charts/user-service/templates/hpa.yaml
```

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "azureshop.name" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "azureshop.name" . }}       # ← HPA references Deployment by NAME, not labels
```

The HPA is an exception — it finds the Deployment by name, not by selector. Labels are not used for HPA → Deployment wiring.

---

### All 8 AzureShop Services — Their Labels

Each of the 8 services generates the same label structure from the shared Helm helper template. Only the values differ:

| Service | `app.kubernetes.io/name` | `app.kubernetes.io/instance` | Port |
|---|---|---|---|
| api-gateway | `api-gateway` | `api-gateway` | 8080 |
| user-service | `user-service` | `user-service` | 3001 |
| product-service | `product-service` | `product-service` | 3002 |
| cart-service | `cart-service` | `cart-service` | 3003 |
| order-service | `order-service` | `order-service` | 3004 |
| payment-service | `payment-service` | `payment-service` | 3005 |
| frontend | `frontend` | `frontend` | 3000 |
| notification-service | `notification-service` | `notification-service` | 3006 |

Each service's Service object selects pods with the matching `app.kubernetes.io/name`. There is zero cross-talk — `app.kubernetes.io/name: user-service` only matches user-service pods, never product-service pods.

---

### Labels for kubectl Filtering — Not Just Wiring

Labels also serve a pure operational purpose: filtering output of `kubectl` commands.

```bash
# Get only user-service pods
kubectl get pods -l app.kubernetes.io/name=user-service -n azureshop

# Get all pods managed by Helm
kubectl get pods -l app.kubernetes.io/managed-by=Helm -n azureshop

# Get all pods for a specific Helm release
kubectl get pods -l app.kubernetes.io/instance=user-service -n azureshop

# Delete all pods for a specific service (they will be recreated by Deployment)
kubectl delete pods -l app.kubernetes.io/name=cart-service -n azureshop
```

This is why `helm.sh/chart` and `app.kubernetes.io/managed-by` are included in `azureshop.labels` but NOT in `azureshop.selectorLabels` — they are for human filtering, not for Service → pod wiring.

---

### Labels on Nodes — A Different Use Case

Labels are not just for pods. Nodes can have labels too, and they are used to **control where pods are scheduled**.

In AzureShop the AKS cluster has two node pools:
- `system` node pool: labeled `agentpool=system`, `kubernetes.azure.com/mode=system`
- `user` node pool: labeled `agentpool=user`, `kubernetes.azure.com/mode=user`

The system node pool has a `CriticalAddonsOnly` taint, which repels application pods. Application pods are scheduled on user pool nodes. This is how AKS ensures kube-system components (CoreDNS, metrics-server) never compete for resources with your app pods.

Pod spec can use `nodeSelector` to require a specific node label:

```yaml
spec:
  nodeSelector:
    agentpool: user               # only schedule on the user node pool
```

Or the more powerful `nodeAffinity`:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.azure.com/mode
                operator: In
                values: [user]
```

AzureShop's Helm charts do not currently specify nodeSelector because the `CriticalAddonsOnly` taint on the system pool naturally prevents app pods from landing there.

---

### NetworkPolicy and Labels

Labels are also how NetworkPolicies identify which pods to allow or block. In AzureShop's zero-trust NetworkPolicy setup:

```yaml
# Allow product-service to receive traffic only from api-gateway
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-gateway-to-product-service
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: product-service   # THIS policy applies to product-service pods
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: api-gateway  # ONLY allow traffic from api-gateway pods
```

The NetworkPolicy does not reference service names or IP addresses. It works entirely through labels — which pods this policy covers (`podSelector`) and which pods are allowed as sources (`ingress.from.podSelector`).

---

### Are Labels the Same Across All Deployments?

**The label keys are the same. The values differ per service.** This is intentional:

- `app.kubernetes.io/name` — same key, different value per service (`user-service`, `product-service`, etc.)
- `app.kubernetes.io/instance` — in AzureShop this matches the service name (could differ if two instances of the same chart were deployed)
- `helm.sh/chart` — same key, includes the chart version (could differ if charts have different versions)
- `app.kubernetes.io/managed-by` — always `Helm` across all services (same key AND value)

So labels are not identical — they are structurally the same (same keys), but the values distinguish one service from another. That is what makes selectors work: each Service's selector matches ONLY its own pods because the `app.kubernetes.io/name` value is unique per service.

---

### Common Mistakes With Labels and Selectors

**Mistake 1: Typo in selector label**

```yaml
# Deployment labels pods with:
labels:
  app: user-service

# Service selector has a typo:
selector:
  app: user_service    # underscore instead of hyphen!
```

Result: The Service finds zero pods. `kubectl get endpoints user-service` shows `<none>`. Traffic hits the ClusterIP but gets no response (connection refused). This is one of the most common misconfigurations in Kubernetes.

**Mistake 2: Forgetting that Deployment selector is immutable**

```yaml
# Original deployment
spec:
  selector:
    matchLabels:
      app: user-service

# You try to change it to:
spec:
  selector:
    matchLabels:
      app: user-service
      env: production    # added a new label
```

Result: `kubectl apply` fails with: `field is immutable`. You must delete and recreate the Deployment (causing brief downtime unless you use a strategy like Blue/Green).

**Mistake 3: Selector too broad**

```yaml
# HPA configured to select pods with:
selector:
  matchLabels:
    env: production      # matches ALL production pods across ALL services!
```

Result: The HPA would scale all services together. Always use the specific `app.kubernetes.io/name` label in selectors.

**Mistake 4: Version in selector**

```yaml
selector:
  matchLabels:
    app: user-service
    version: v1.0.0     # version in selector = bad idea
```

Result: When you deploy `v2.0.0`, the new pods have `version=v2.0.0` but the Service selector still says `v1.0.0`. The Service routes zero traffic to the new pods. Zero downtime update is broken. Never put version in selector labels.

---

### Quick Reference: Label vs Selector at a Glance

```
LABEL (on the pod)               SELECTOR (on the Service/Deployment/HPA)
─────────────────────────────    ──────────────────────────────────────────
Attached TO the object           Queries objects by their labels
Passive metadata                 Active filter
Can have many labels             Selector must match label values exactly
Anyone can read them             Used by: Services, Deployments, HPAs,
                                 NetworkPolicies, nodeAffinity, kubectl -l

Direction:
  Pod has labels ──→ Service selector reads those labels ──→ Service routes to pod
  Pod has labels ──→ Deployment selector owns those pods ──→ Deployment manages pod lifecycle
  Pod has labels ──→ NetworkPolicy selector applies rules ──→ Traffic allowed/denied
  Node has labels ──→ nodeAffinity selector reads them ──→ Pod scheduled on node
```

---

### Interview Prep

1. **What is a label in Kubernetes?** — A label is a key-value pair attached to any Kubernetes object as metadata. Labels do nothing on their own — they are just tags. They become powerful when selectors query them. Labels are used to group objects (all user-service pods have `app=user-service`) so that other objects (Services, HPAs, NetworkPolicies) can find and operate on them.

2. **What is a selector in Kubernetes?** — A selector is a query that finds Kubernetes objects by their labels. A Service with `selector: app=user-service` finds every pod with that label and routes traffic to them. Selectors are how Services discover pods, how Deployments own pods, and how NetworkPolicies apply to pods.

3. **What is the difference between labels and selectors?** — Labels are attached TO objects and are passive. Selectors are used BY objects to actively find other objects. A pod has labels; a Service has a selector that reads those labels. You write labels on pods; you write selectors on Services. The selector is the query; the label is the data it queries.

4. **Why is `spec.selector` in a Deployment immutable?** — Because the selector defines which pods the Deployment "owns." If you changed the selector after creation, the Deployment would stop managing its existing pods (they no longer match the new selector) and start creating new pods. The old pods would become orphans — running forever with nothing managing them. Kubernetes prevents this by making the selector immutable. If you need a different selector, delete and recreate the Deployment.

5. **Why should version labels NOT be in a Deployment's selector?** — Because the selector is immutable. Every time you deploy a new version, the pod template gets a new `version=v2.0.0` label, but the selector still says `version=v1.0.0`. No pods match — the Deployment cannot manage its own pods. Kubernetes would reject this. Use version labels in the pod template only, not in the selector.

6. **In AzureShop, how does the Service know which pods to route to?** — The Service uses `selectorLabels` from the Helm `_helpers.tpl`, which resolves to `app.kubernetes.io/name: user-service` and `app.kubernetes.io/instance: user-service`. The Deployment stamps these exact same two labels onto every pod in its template. The Service reads those labels and adds matching pods to its EndpointSlice. No manual pod-to-service wiring is needed.

7. **What is `matchLabels` vs `matchExpressions`?** — `matchLabels` is a simple equality check: label key must equal this value. `matchExpressions` supports operators: `In` (value must be one of), `NotIn` (value must not be one of), `Exists` (label must be present regardless of value), `DoesNotExist` (label must be absent). Both can be combined — all conditions must pass (logical AND). `matchLabels` is sufficient for most use cases; `matchExpressions` is used when you need more complex filtering like "apply this NetworkPolicy to all services except the cache tier."

8. **How would you troubleshoot a Service that has no endpoints?** — Run `kubectl get endpoints <service-name> -n <namespace>`. If it shows `<none>`, the Service selector is not matching any pods. Then run `kubectl get pods -n <namespace> --show-labels` and compare the pod labels against the Service selector. Look for typos (hyphen vs underscore), missing labels, or wrong values. A mismatch here is the most common cause of "connection refused" errors in Kubernetes.

---

## Q25. What is Kubernetes RBAC? How Does it Work, What are Roles, RoleBindings, ClusterRoles, and ServiceAccounts?

### The Core Problem RBAC Solves

In a real Kubernetes cluster, many different things need to talk to the Kubernetes API server:

- **Developers** run `kubectl get pods`, `kubectl apply`, `kubectl delete`
- **CI/CD pipelines** deploy new versions of services
- **Monitoring tools** like Prometheus read pod metrics
- **The Key Vault CSI Driver** reads secrets from Azure Key Vault
- **The HPA controller** reads CPU metrics and scales Deployments
- **Your own application pods** — do they need to call the Kubernetes API at all?

Without access control, everyone and everything could do everything — a developer could accidentally delete a production database, a compromised pod could read all secrets in the cluster, a CI pipeline could modify cluster-wide settings.

**RBAC (Role-Based Access Control)** is how Kubernetes controls who is allowed to do what.

Think of it like a building with different rooms. An employee (subject) has a keycard (Role) that gives them access to specific rooms (resources). Without the right keycard they cannot enter, regardless of how hard they try. RBAC is the keycard system for Kubernetes.

---

### The Three Questions RBAC Answers

Every access request to the Kubernetes API is checked against three questions:

```
1. WHO are you?          → Subject (User, Group, or ServiceAccount)
2. WHAT do you want to do? → Verb (get, list, create, delete, patch, watch...)
3. ON WHAT?              → Resource (pods, secrets, deployments, services...)
```

If ALL three match a Rule that has been granted to you via a Role and a Binding, the request is allowed. Otherwise it is denied with `403 Forbidden`.

---

### The Four Key Objects in Kubernetes RBAC

| Object | What it defines | Scope |
|---|---|---|
| **Role** | A set of permissions | One namespace only |
| **ClusterRole** | A set of permissions | Entire cluster (all namespaces) OR non-namespaced resources |
| **RoleBinding** | Grants a Role or ClusterRole to a Subject | One namespace |
| **ClusterRoleBinding** | Grants a ClusterRole to a Subject | Entire cluster |

These four objects work in pairs:
- **Role + RoleBinding** → "You can do X in this namespace"
- **ClusterRole + ClusterRoleBinding** → "You can do X everywhere in the cluster"
- **ClusterRole + RoleBinding** → "You can do X, but only in this specific namespace" (reuse the ClusterRole, limit by RoleBinding)

---

### Term 1: Subject — WHO is making the request?

A subject is the identity making an API request. There are three types:

#### 1. User
A real human. In raw Kubernetes this is a certificate-based identity. In AKS with Azure AD integration (`azure_rbac_enabled = true`), this is an **Azure AD user** — your Microsoft email address is your Kubernetes identity.

```
Developer: amar@company.com
→ kubectl get pods  
→ Kubernetes asks Azure AD: "Is this token valid for this user?"
→ Azure AD says yes
→ Kubernetes checks RBAC: "Does this user have permission to get pods?"
```

#### 2. Group
A collection of users. Instead of granting permissions to each individual, you grant to a group and add people to the group. In AKS with Azure AD, these are **Azure AD security groups**.

```
Group: aks-developers (Azure AD group)
→ All members of this group get the same Kubernetes permissions
→ Add/remove people from the Azure AD group = add/remove cluster access
```

#### 3. ServiceAccount
An identity for a **machine** or **process** (not a human). Pods use ServiceAccounts to authenticate to the Kubernetes API. This is the most important subject type for understanding how AzureShop works.

```
Pod: user-service-7d4f9b-xk2p9
→ Uses ServiceAccount: user-service
→ ServiceAccount has a token (JWT)
→ Any API call the pod makes is identified as "user-service ServiceAccount"
```

---

### Term 2: Verb — WHAT do you want to do?

Verbs are the actions. The full list:

| Verb | What it does | HTTP method equivalent |
|---|---|---|
| `get` | Read one specific object | GET /resource/name |
| `list` | Read all objects of a type | GET /resource |
| `watch` | Stream changes to objects | GET with `?watch=true` |
| `create` | Create a new object | POST |
| `update` | Replace an entire object | PUT |
| `patch` | Modify part of an object | PATCH |
| `delete` | Delete one object | DELETE |
| `deletecollection` | Delete all objects of a type | DELETE on collection |

Common patterns:
- **Read only:** `get`, `list`, `watch`
- **Read + write:** `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`
- **Prometheus needs:** `get`, `list`, `watch` on pods, endpoints, nodes

---

### Term 3: Resource — ON WHAT?

Resources are the Kubernetes object types: `pods`, `services`, `deployments`, `secrets`, `configmaps`, `namespaces`, `nodes`, `persistentvolumes`, etc.

Resources have **subresources** too:
- `pods/log` — read pod logs
- `pods/exec` — exec into a pod
- `pods/status` — read/update pod status
- `deployments/scale` — scale a deployment

You can grant access to a resource without granting access to its subresources, or vice versa.

Resources can also be **non-namespaced** (cluster-scoped):
- `nodes` — the actual worker VMs
- `namespaces` — the namespaces themselves
- `persistentvolumes` — cluster-wide storage
- `clusterroles`, `clusterrolebindings` — RBAC objects themselves

Non-namespaced resources can only be controlled with ClusterRoles and ClusterRoleBindings, not namespace-scoped Roles.

---

### Term 4: Role — Defining Permissions

A Role is a collection of **rules**. Each rule says: "for these resources, these verbs are allowed."

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader                  # name of this Role
  namespace: dev                    # only applies in the "dev" namespace
rules:
  - apiGroups: [""]                 # "" means core API group (pods, services, secrets)
    resources: ["pods"]             # which resources
    verbs: ["get", "list", "watch"] # what they can do

  - apiGroups: ["apps"]             # "apps" group (deployments, replicasets)
    resources: ["deployments"]
    verbs: ["get", "list"]
```

Key points:
- A Role is **purely a definition** — it grants nothing on its own
- You need a **RoleBinding** to actually grant the Role to someone
- `apiGroups: [""]` is the core API group — pods, services, configmaps, secrets, etc.
- `apiGroups: ["apps"]` covers Deployments, ReplicaSets, StatefulSets, DaemonSets
- `apiGroups: ["batch"]` covers Jobs and CronJobs
- `apiGroups: ["autoscaling"]` covers HPAs

---

### Term 5: ClusterRole — Cluster-Wide Permissions

A ClusterRole is exactly like a Role but has no namespace — it applies across the entire cluster. Use ClusterRole when:
- You need access to **non-namespaced resources** (nodes, namespaces, PersistentVolumes)
- You want to define a permission set once and reuse it in multiple namespaces

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader                 # no namespace field — cluster-scoped
rules:
  - apiGroups: [""]
    resources: ["nodes"]            # nodes are cluster-scoped, can't use Role for this
    verbs: ["get", "list", "watch"]

  - apiGroups: [""]
    resources: ["pods"]             # can also include namespaced resources
    verbs: ["get", "list", "watch"]
```

Kubernetes ships with several **built-in ClusterRoles** that you can use directly:

| Built-in ClusterRole | What it grants |
|---|---|
| `cluster-admin` | Full access to everything — superuser |
| `admin` | Full access within a namespace (used in RoleBindings) |
| `edit` | Read + write most resources in a namespace |
| `view` | Read-only access to most resources in a namespace |

In AzureShop, `azure_rbac_enabled = true` means the Azure role `Azure Kubernetes Service RBAC Cluster Admin` maps to the Kubernetes `cluster-admin` ClusterRole. This is granted in Terraform:

```hcl
# infra/main.tf — line 143
resource "azurerm_role_assignment" "aks_cluster_admin" {
  principal_id         = var.aks_admin_object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = module.aks.aks_cluster_id
}
```

---

### Term 6: RoleBinding — Granting a Role to a Subject

A RoleBinding connects a Subject to a Role (or ClusterRole) within a specific namespace. It is the bridge between "what is allowed" and "who is allowed to do it."

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: dev                    # this binding is only effective in "dev" namespace
subjects:                           # WHO gets the permissions
  - kind: ServiceAccount
    name: monitoring-agent          # the ServiceAccount name
    namespace: monitoring           # the namespace where the ServiceAccount lives
roleRef:                            # WHAT permissions are granted
  kind: Role                        # can be "Role" or "ClusterRole"
  name: pod-reader                  # the Role/ClusterRole name
  apiGroup: rbac.authorization.k8s.io
```

The RoleBinding says: "The `monitoring-agent` ServiceAccount (in namespace `monitoring`) is allowed to do everything the `pod-reader` Role permits, but only within the `dev` namespace."

**You can also bind a ClusterRole with a RoleBinding** — this is a common pattern:
```yaml
roleRef:
  kind: ClusterRole    # reusing the ClusterRole definition
  name: pod-reader
```
This grants the ClusterRole's permissions, but **limited to the namespace of the RoleBinding**. The ClusterRole is just a reusable template.

---

### Term 7: ClusterRoleBinding — Granting Cluster-Wide Access

A ClusterRoleBinding grants a ClusterRole to a Subject across the entire cluster — no namespace restriction.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-cluster-reader   # no namespace — cluster-scoped
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: cluster-reader
  apiGroup: rbac.authorization.k8s.io
```

This says: "The `prometheus` ServiceAccount (in the `monitoring` namespace) can read all pods, services, and nodes across every namespace in the cluster."

Prometheus needs this because it scrapes metrics from pods in ALL namespaces — it cannot be limited to a single namespace.

---

### Term 8: ServiceAccount — Machine Identity in Kubernetes

A ServiceAccount is the Kubernetes identity for a **pod** (or any automated process running in the cluster). Humans use User identities; pods use ServiceAccounts.

When a pod is created, Kubernetes:
1. Assigns it a ServiceAccount (default is `default` if not specified)
2. Mounts a JWT token for that ServiceAccount into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`
3. The pod presents this token when calling the Kubernetes API

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-service
  namespace: dev
automountServiceAccountToken: false   # disable auto-mount (AzureShop security practice)
```

**Default ServiceAccount:** Every namespace has a `default` ServiceAccount. If you don't specify a ServiceAccount in your pod spec, the pod gets the `default` one. In modern Kubernetes the default ServiceAccount has no permissions — it is safe but also useless for any API calls.

**`automountServiceAccountToken: false`:** Disables the automatic mounting of the JWT token. If your pod never needs to call the Kubernetes API, there is no reason to have the token available in the container's filesystem — removing it reduces the attack surface.

---

### How RBAC Works — The Full Flow

Let's trace what happens when Prometheus tries to list pods:

```
1. Prometheus pod makes HTTP request:
   GET https://kubernetes.default.svc/api/v1/pods
   Authorization: Bearer eyJhbGciOiJSUzI1NiIs...   ← ServiceAccount JWT token

2. API Server receives the request.
   It passes through THREE checks in order:

   ┌──────────────────────────────────────────────────────────────────┐
   │  AUTHENTICATION                                                  │
   │  "Who are you?"                                                  │
   │  API Server validates the JWT token against the cluster CA.      │
   │  Result: "This is ServiceAccount prometheus in namespace monitoring" │
   └──────────────────────────────────────────────────────────────────┘
                               ↓
   ┌──────────────────────────────────────────────────────────────────┐
   │  AUTHORIZATION (RBAC)                                            │
   │  "Are you allowed to do this?"                                   │
   │  API Server checks: does prometheus SA have a RoleBinding or     │
   │  ClusterRoleBinding that grants verb=list on resource=pods?      │
   │  Result: Yes → ClusterRoleBinding prometheus-cluster-reader      │
   │          grants ClusterRole that includes list/pods              │
   └──────────────────────────────────────────────────────────────────┘
                               ↓
   ┌──────────────────────────────────────────────────────────────────┐
   │  ADMISSION CONTROL                                               │
   │  "Should this operation be allowed through policy?"              │
   │  (Azure Policy, PodSecurity, ValidatingWebhookConfigurations)    │
   │  Result: Pass                                                    │
   └──────────────────────────────────────────────────────────────────┘
                               ↓
3. Response: 200 OK — list of all pods
```

If the RBAC check fails (no matching RoleBinding/ClusterRoleBinding), step 2 returns:
```
403 Forbidden: User "system:serviceaccount:monitoring:prometheus" cannot list resource "pods"
```

---

### Role vs ClusterRole vs RoleBinding vs ClusterRoleBinding — Decision Guide

```
Q: Do you need to access non-namespaced resources (nodes, namespaces, PVs)?
   → YES: Must use ClusterRole + ClusterRoleBinding

Q: Do you need to access resources in ALL namespaces?
   → YES: ClusterRole + ClusterRoleBinding
   → NO, just one namespace: Role + RoleBinding  (or ClusterRole + RoleBinding to reuse)

Q: Do you want to define permissions once but use in multiple namespaces?
   → ClusterRole (definition) + RoleBinding in each namespace (scoped grant)

Q: What does `cluster-admin` do?
   → Full access to EVERYTHING — only grant to trusted humans and trusted automation
```

Diagram:

```
Role ──────────────── RoleBinding ──── Subject
  (permissions)         (in ns=dev)      (user/SA/group)
  namespace-scoped    namespace-scoped

ClusterRole ─┬───────── ClusterRoleBinding ── Subject
  (permissions)│          (cluster-wide)
  cluster-wide │
               └───────── RoleBinding ──────── Subject
                           (in ns=dev)
                           ← limits scope to one namespace
```

---

### Azure RBAC vs Kubernetes RBAC — Two Separate Systems

In AzureShop, `azure_rbac_enabled = true` means there are TWO layers of RBAC:

| | Azure RBAC | Kubernetes RBAC |
|---|---|---|
| **Controls** | Who can run `kubectl` commands | What pods/serviceaccounts can do inside the cluster |
| **Subjects** | Azure AD users and groups | K8s Users, Groups, ServiceAccounts |
| **Defined in** | Azure portal / Terraform azurerm_role_assignment | K8s Role, ClusterRole, RoleBinding objects |
| **Examples** | AKS RBAC Cluster Admin, AKS RBAC Reader | pod-reader Role, cluster-admin ClusterRole |
| **Checked by** | Azure AD (before reaching K8s API server) | K8s API Server authorization layer |

The flow when a developer runs `kubectl get pods -n dev`:

```
Developer laptop
  → az login (Azure AD authentication)
  → kubectl uses az CLI token
  → API Server calls Azure AD: "Is this token valid?"
  → Azure AD confirms: "Yes, this is amar@company.com"
  → Azure AD also returns: "This user has Azure role AKS RBAC Cluster Admin"
  → API Server maps that Azure role → K8s cluster-admin ClusterRole
  → Access granted
```

When Azure RBAC is enabled, the Azure role assignments control access instead of local K8s ClusterRoleBindings for human users. ServiceAccounts inside the cluster still use standard K8s RBAC (Roles, RoleBindings) — Azure RBAC only covers external access via kubectl.

---

### ServiceAccount in AzureShop — Exactly How It's Used

Every one of the 8 AzureShop services has its own ServiceAccount. Let's trace user-service from definition to running pod.

#### Step 1: ServiceAccount is created by Helm

File: `helm/charts/user-service/templates/serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-service            # matches the service name
  namespace: dev
  labels:
    app.kubernetes.io/name: user-service
    app.kubernetes.io/managed-by: Helm
automountServiceAccountToken: false    # ← security: no API token in pod filesystem
```

`automountServiceAccountToken: false` is set because user-service pods never need to call the Kubernetes API. They call Azure SQL, Azure Application Insights, other microservices — but not the K8s API server. There is no reason to have the credential sitting in the container.

#### Step 2: Deployment references the ServiceAccount

File: `helm/charts/user-service/templates/deployment.yaml`

```yaml
spec:
  template:
    spec:
      serviceAccountName: user-service    # ← pod runs AS this ServiceAccount
```

Without `serviceAccountName`, the pod would use the `default` ServiceAccount. AzureShop explicitly sets it to `user-service` because:
1. It follows least-privilege: each service has its own identity
2. Workload Identity (Phase 6.7) requires binding to a specific named ServiceAccount
3. It makes audit logs meaningful — "user-service did X" instead of "default did X"

#### Step 3: Kubernetes creates the pod with the ServiceAccount identity

At runtime, the pod's process identity IS the ServiceAccount. Any action the pod takes against the Kubernetes API is as `system:serviceaccount:dev:user-service`.

Currently user-service has no RoleBindings — it cannot do anything in the Kubernetes API. This is correct. user-service only needs to talk to the database.

---

### Workload Identity — ServiceAccount Meets Azure RBAC

The notification-service goes further. It uses **Workload Identity** to authenticate to Azure services using its Kubernetes ServiceAccount. This is where K8s ServiceAccount + Azure RBAC combine.

File: `helm/charts/notification-service/values.yaml`

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "2e5e41cb-dd6c-46a5-8420-165c463fe974"

workloadIdentity:
  enabled: true
```

The annotation links the Kubernetes ServiceAccount to an Azure Managed Identity. Here is the full chain:

```
Step 1 — Terraform creates a Managed Identity
  resource "azurerm_user_assigned_identity" "notification_service"
  → Managed Identity: id-notification-service-dev
  → Client ID: 2e5e41cb-dd6c-46a5-8420-165c463fe974

Step 2 — Terraform creates a Federated Identity Credential
  resource "azurerm_federated_identity_credential" "notification_service"
  → Links K8s ServiceAccount "notification-service" in namespace "dev"
    to the Managed Identity above
  → AKS OIDC issuer signs SA tokens; Azure AD trusts this issuer

Step 3 — Terraform grants the Managed Identity access to Key Vault
  resource "azurerm_role_assignment" "notification_service_kv_secrets_user"
  → Role: Key Vault Secrets User
  → Scope: Key Vault kv-azureshop-6a6c-dev

Step 4 — Helm deploys the pod
  → ServiceAccount has annotation: azure.workload.identity/client-id = 2e5e41cb...
  → Workload Identity webhook injects:
       env var AZURE_CLIENT_ID = 2e5e41cb...
       volume: projected ServiceAccount token (short-lived, Azure-audience)

Step 5 — Pod calls Azure Key Vault SDK
  → SDK reads AZURE_CLIENT_ID and the projected token
  → Exchanges token for a short-lived Azure AD access token
  → Uses that to read secrets from Key Vault
  → No credentials stored anywhere
```

This is the most secure pattern — the pod's Kubernetes identity (ServiceAccount) directly maps to an Azure identity (Managed Identity), granting access to Azure resources without any passwords or keys.

---

### Does AzureShop Have Kubernetes Role/RoleBinding Objects?

Currently AzureShop does **not** define explicit `Role` or `RoleBinding` objects. Here is why, and here is what it would look like if it did:

**Why there are none today:**
- None of the 8 application services call the Kubernetes API — they talk to databases, queues, and other services, not to the K8s API server
- `automountServiceAccountToken: false` on every ServiceAccount means no K8s API credential is even available to the pods
- The CSI Driver (Key Vault) uses the **node's managed identity**, not the pod's ServiceAccount token — it runs as a daemonset with its own permissions granted via Azure RBAC (Terraform)
- Human access is controlled entirely by Azure RBAC (`azure_rbac_enabled = true`) — no local ClusterRoleBinding objects needed

**If Prometheus were deployed, it would need:**

```yaml
# ClusterRole — can read pods/services/nodes cluster-wide
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["nodes/metrics"]
    verbs: ["get"]
---
# ClusterRoleBinding — grant the ClusterRole to the prometheus ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-reader-binding
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: prometheus-reader
  apiGroup: rbac.authorization.k8s.io
```

**If a CI/CD pipeline ServiceAccount needed to deploy:**

```yaml
# Role — can manage deployments in the dev namespace only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: dev
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
---
# RoleBinding — grant it to the CI pipeline's ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-deployer-binding
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: azure-pipelines
    namespace: dev
roleRef:
  kind: Role
  name: deployer
  apiGroup: rbac.authorization.k8s.io
```

---

### RBAC Principle: Least Privilege

RBAC only works well when you apply **least privilege** — grant each subject the minimum permissions it needs, nothing more.

In AzureShop:

| Subject | What it needs | What it has |
|---|---|---|
| Developer | Run `kubectl` on dev cluster | Azure role: AKS RBAC Cluster Admin |
| user-service pod | Talk to Azure SQL | ServiceAccount (no K8s permissions), Azure RBAC via CSI node identity |
| notification-service pod | Read Key Vault secrets | ServiceAccount + Workload Identity → Managed Identity → Key Vault Secrets User role |
| CSI Driver (node addon) | Read Key Vault for all pods | Azure RBAC: Key Vault Secrets User on Key Vault |
| HPA controller | Read pod metrics, scale deployments | Built-in — managed by AKS control plane |
| Flux GitOps operator | Create/update Helm releases | ClusterAdmin (Flux needs cluster-wide write access — installed with its own RBAC) |

The core rule: **if a component doesn't need to call the K8s API, it should have `automountServiceAccountToken: false` and no RoleBinding.**

---

### Common RBAC Errors and What They Mean

**Error 1: 403 Forbidden**
```
Error from server (Forbidden): pods is forbidden: User 
"system:serviceaccount:dev:user-service" cannot list resource "pods" 
in API group "" in the namespace "dev"
```
**Means:** The ServiceAccount has no RoleBinding granting `list` on `pods`. Either you forgot to create the RoleBinding, or the RoleBinding is in the wrong namespace.

**Error 2: kubectl access denied after `az aks get-credentials`**
```
Error from server (Forbidden): pods is forbidden: User 
"amar@company.com" cannot list resource "pods"
```
**Means:** The Azure AD user has credentials but no Azure role assignment (like `AKS RBAC Reader` or `AKS RBAC Cluster Admin`) on the AKS cluster. Fix: add the Azure role assignment in the Azure portal or Terraform.

**Error 3: "system:anonymous" in error message**
```
User "system:anonymous" cannot get path "/"
```
**Means:** The request reached the API server without a valid token — unauthenticated. Check that `kubeconfig` is correctly set up and that `az login` or `kubelogin` succeeded.

**Error 4: ServiceAccount can list pods in namespace X but not namespace Y**
```
User "system:serviceaccount:monitoring:prometheus" cannot list resource "pods" 
in API group "" in the namespace "production"
```
**Means:** Prometheus has a `RoleBinding` in namespace `monitoring` but not in namespace `production`. Either add a RoleBinding in each namespace, or switch to a `ClusterRoleBinding` to give access everywhere.

---

### Quick Reference: The Full RBAC Picture

```
                        KUBERNETES RBAC
                        ══════════════

  WHO (Subject)          HOW (Binding)         WHAT (Role)
  ─────────────          ─────────────         ──────────────────────

  User                   RoleBinding           Role
  amar@company.com  ───► (namespace: dev)  ───► rules:
                                               - pods: get/list/watch
                                               - deployments: get/list

  Group                  RoleBinding           ClusterRole (reused)
  aks-developers    ───► (namespace: dev)  ───► rules:
                                               - pods: get/list/watch
                                               - services: get/list

  ServiceAccount         ClusterRoleBinding    ClusterRole
  prometheus        ───► (cluster-wide)    ───► rules:
  (monitoring ns)                              - nodes: get/list/watch
                                               - pods: get/list/watch
                                               (all namespaces)

  ServiceAccount         (none — no K8s       (none)
  user-service           API access needed)
  (dev ns)
        │
        └──────────────► Azure RBAC via       Key Vault Secrets User
                         Workload Identity     (on Azure Key Vault)
                         + Managed Identity
```

---

### Interview Prep

1. **What is Kubernetes RBAC?** — RBAC (Role-Based Access Control) is the Kubernetes authorization system. Every request to the Kubernetes API is checked: WHO is making it (Subject), WHAT do they want to do (Verb), and ON WHAT (Resource). RBAC grants or denies that request based on Role and RoleBinding objects. Without RBAC, any pod or user could read all secrets, delete all deployments, and crash the cluster.

2. **What is the difference between a Role and a ClusterRole?** — A Role defines permissions within a single namespace — a pod can read secrets in namespace `dev` only. A ClusterRole defines permissions cluster-wide — it can cover all namespaces and also non-namespaced resources like `nodes` and `namespaces` themselves, which Roles cannot access. You can also reuse a ClusterRole as a template by binding it with a namespace-scoped RoleBinding.

3. **What is the difference between a RoleBinding and a ClusterRoleBinding?** — A RoleBinding grants a Role (or ClusterRole) to a Subject within ONE namespace only. A ClusterRoleBinding grants a ClusterRole to a Subject across ALL namespaces and all cluster-scoped resources. Prometheus uses a ClusterRoleBinding because it needs to read pods from every namespace. A CI pipeline uses a RoleBinding because it should only deploy to the `dev` namespace.

4. **What is a ServiceAccount?** — A ServiceAccount is the Kubernetes identity for a pod. Every pod has one. When a pod calls the Kubernetes API, it authenticates using its ServiceAccount's JWT token. The ServiceAccount's permissions are controlled by RoleBindings. Unlike human users, ServiceAccounts live inside the cluster and are used by automated processes. If a pod does not need Kubernetes API access, set `automountServiceAccountToken: false`.

5. **Why does AzureShop set `automountServiceAccountToken: false` on all ServiceAccounts?** — Because none of the 8 application pods ever call the Kubernetes API directly. They call Azure SQL, Application Insights, Service Bus — but not `kubernetes.default.svc`. Auto-mounting the token means a JWT credential sits in every pod's filesystem. If a pod was compromised, the attacker could use that token to probe the Kubernetes API. Disabling the auto-mount removes the credential entirely, reducing the attack surface.

6. **What is the difference between Azure RBAC and Kubernetes RBAC?** — Azure RBAC controls who can run `kubectl` commands against the AKS cluster — it uses Azure AD identities and Azure role assignments (like `AKS RBAC Cluster Admin`). Kubernetes RBAC controls what processes running INSIDE the cluster can do — it uses ServiceAccounts, Roles, and RoleBindings. In AzureShop, `azure_rbac_enabled = true` means Azure RBAC handles human access, while Kubernetes RBAC handles internal service-to-service access. Both run simultaneously.

7. **How does Workload Identity relate to ServiceAccounts?** — Workload Identity is a bridge between a Kubernetes ServiceAccount and an Azure Managed Identity. The ServiceAccount is annotated with `azure.workload.identity/client-id`, linking it to a Managed Identity's client ID. The AKS OIDC issuer signs the ServiceAccount token; Azure AD trusts this and exchanges it for an Azure AD token scoped to the Managed Identity. The pod then uses that Azure AD token to call Azure services (Key Vault, Service Bus, etc.) without any stored credentials. In AzureShop, notification-service uses this to read Key Vault secrets at runtime.

8. **What is least privilege in RBAC and how does AzureShop apply it?** — Least privilege means granting each identity the minimum permissions it needs and nothing more. In AzureShop: application pods get their own ServiceAccounts with no K8s RBAC permissions (no RoleBindings) and `automountServiceAccountToken: false`. The CSI driver addon identity has only Key Vault Secrets User on the specific Key Vault. The developer has AKS Cluster Admin only on the dev cluster scope. No service can read another service's secrets because each ServiceAccount is separate with no cross-service access.

---

## Q26. What is a Service Mesh? What is Istio, How Does it Work, and What Problems Does it Solve in Kubernetes?

### The Problem — What Happens Without a Service Mesh

In a microservices architecture like AzureShop, dozens of services talk to each other constantly:

```
frontend → api-gateway → user-service
                       → product-service
                       → cart-service → order-service → payment-service
                                                      → notification-service
```

Every one of these connections is a network call. And with network calls come real problems that every production team has to solve:

**Problem 1 — Security:** How do you know that the request coming into payment-service is really from order-service and not from a hacker who got inside the cluster? With plain Kubernetes, pod-to-pod traffic is unencrypted — anyone who can see network traffic can read your data.

**Problem 2 — Reliability:** What happens when product-service is slow or down? Does cart-service wait forever? Does it keep hammering a broken service? You need retries, timeouts, and circuit breakers — but writing that logic in every service is repetitive and error-prone.

**Problem 3 — Observability:** How do you know how long each service call takes? Which service is causing the most errors? Where is the bottleneck in a chain of 6 services? Kubernetes gives you logs, but tracing a request through multiple hops is very hard without extra tooling.

**Problem 4 — Traffic control:** How do you roll out a new version of payment-service to 10% of traffic while keeping 90% on the old version? How do you route users from a specific country to a specific version? kube-proxy can only do random load balancing — it cannot do percentage splits or header-based routing.

**A service mesh solves all four of these problems without changing a single line of application code.**

---

### What is a Service Mesh?

A service mesh is a **dedicated infrastructure layer** that handles all service-to-service (east-west) communication inside a Kubernetes cluster. It is called a "mesh" because every service is wrapped in it — like a net covering all services simultaneously.

The key insight: instead of making each developer write retry logic, TLS handshake code, and metrics instrumentation in every service, the service mesh does it automatically at the network level. Your application code stays simple — it just makes HTTP calls. The mesh handles everything else invisibly.

Think of it like a **phone company's network**. When you make a call, you don't personally implement encryption, routing, call quality monitoring, or retry logic. The network infrastructure does it for you. A service mesh is the phone company network for your microservices.

---

### The Sidecar Pattern — How a Service Mesh Works

The core mechanism of a service mesh is the **sidecar proxy**. Here is what it means:

In standard Kubernetes, a pod has one container — your application:
```
Pod: order-service
  └── container: order-service (your Node.js app, port 3004)
```

With a service mesh, a second container (the sidecar proxy) is automatically injected into every pod:
```
Pod: order-service
  ├── container: order-service (your Node.js app, port 3004)
  └── container: istio-proxy  (Envoy proxy — injected automatically, port 15001)
```

The sidecar proxy sits between your application and the network. Every single packet going IN or OUT of the pod passes through the proxy first. Your application code never changes — it still thinks it is sending plain HTTP to `payment-service:3005`. But in reality:

```
order-service app
  → sends plain HTTP to localhost:15001 (Envoy intercepts via iptables rule)
  → Envoy encrypts with mTLS, adds tracing headers, applies retry policy
  → sends encrypted traffic to payment-service pod's Envoy sidecar
  → payment-service Envoy verifies certificate, decrypts
  → delivers plain HTTP to payment-service app
```

Neither order-service nor payment-service knows any of this happened. The mesh is completely transparent to the application.

---

### What is Istio?

Istio is the most widely used open-source service mesh. It is a CNCF (Cloud Native Computing Foundation) graduated project, backed by Google, IBM, and Lyft. It sits on top of Kubernetes and provides:

- **Automatic mTLS** — all pod-to-pod traffic is encrypted and mutually authenticated
- **Traffic management** — percentage splits, header routing, retries, timeouts, circuit breakers
- **Observability** — automatic metrics, distributed tracing, and access logs for every service call
- **Security policy** — which service is allowed to talk to which other service (authorization policies)

Istio uses **Envoy** as its sidecar proxy. Envoy is a high-performance C++ proxy originally built at Lyft. Istio manages all the Envoy sidecars centrally.

---

### Istio Architecture — Control Plane vs Data Plane

Istio has two layers: the **control plane** and the **data plane**.

#### Data Plane

The data plane is all the Envoy sidecar proxies running inside every pod. There can be hundreds of them — one per pod. They are the ones actually handling traffic, enforcing policies, and collecting metrics.

```
Pod: user-service     Pod: product-service    Pod: cart-service
  ├── app container     ├── app container        ├── app container
  └── envoy proxy       └── envoy proxy          └── envoy proxy
       ↑ data plane          ↑ data plane              ↑ data plane
```

#### Control Plane — istiod

istiod (pronounced "Istio-dee") is the single control plane process in Istio. It runs in the `istio-system` namespace and does three things:

**1. Pilot — Traffic management config distributor**
You define routing rules (VirtualService, DestinationRule) as Kubernetes objects. Pilot reads them and translates them into Envoy configuration, then pushes that config to every Envoy sidecar across the cluster. Every proxy knows the full routing rules without you configuring each one manually.

**2. Citadel — Certificate authority**
Citadel issues and rotates TLS certificates for every ServiceAccount in the cluster. Each Envoy sidecar gets a unique certificate proving its identity (e.g., "I am the payment-service ServiceAccount"). When two services connect, they verify each other's certificates — this is mutual TLS (mTLS).

**3. Galley — Config validation**
Validates that the Istio configuration objects you write are correct before applying them. Catches typos and invalid rules before they reach the proxies.

```
                        istiod (control plane)
                    ┌───────────────────────────┐
                    │  Pilot  │ Citadel │ Galley │
                    └───────────────────────────┘
                         │          │
                    push config   issue certs
                         │          │
        ┌────────────────┼──────────┼────────────────┐
        ↓                ↓          ↓                 ↓
   envoy proxy      envoy proxy  envoy proxy     envoy proxy
   (user-service)  (product)    (cart)          (payment)
        ↑                                             ↑
        └─────── encrypted mTLS traffic ─────────────┘
```

---

### The Five Core Capabilities of Istio

#### Capability 1: Mutual TLS (mTLS) — Automatic Encryption

In plain Kubernetes, all pod-to-pod traffic is unencrypted plaintext. Anyone who can observe the network inside the cluster (a compromised pod, a malicious node agent) can read everything — API responses, database queries, user data.

With Istio mTLS:
- Every pod gets a **SPIFFE** (Secure Production Identity Framework For Everyone) certificate issued by Citadel
- The certificate identity is tied to the pod's **ServiceAccount**: `spiffe://cluster.local/ns/dev/sa/order-service`
- When order-service talks to payment-service, both Envoy proxies exchange certificates and verify each other (that is the "mutual" part — both sides authenticate, not just the server)
- All traffic is encrypted with TLS 1.3

```
order-service (cert: sa/order-service)
  → Envoy: "Here is my cert. Who are you?"
  ← payment-service Envoy: "Here is my cert: sa/payment-service"
  → Both verified → encrypted channel established
  → plain HTTP inside the app; TLS outside
```

This works in two modes:
- **PERMISSIVE** — accepts both plaintext and mTLS (for gradual rollout)
- **STRICT** — rejects all plaintext, only mTLS allowed (production mode)

In AzureShop, without Istio, inter-service traffic goes over plain HTTP. With Istio in STRICT mode, every one of those 20+ service calls per request would be automatically encrypted with zero code changes.

#### Capability 2: Traffic Management

Istio gives you precise control over how traffic flows between services. This is where it goes far beyond kube-proxy's random load balancing.

**VirtualService** — defines routing rules for traffic TO a service:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service
  namespace: dev
spec:
  hosts:
    - product-service          # applies to traffic going to product-service
  http:
    # Canary: 10% of traffic to v2, 90% to v1
    - route:
        - destination:
            host: product-service
            subset: v1         # defined in DestinationRule below
          weight: 90
        - destination:
            host: product-service
            subset: v2
          weight: 10
```

**DestinationRule** — defines subsets (versions) of a service and load balancing policy:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service
  namespace: dev
spec:
  host: product-service
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN       # route to pod with fewest active connections
  subsets:
    - name: v1
      labels:
        version: v1.0.0        # matches pods with this label
    - name: v2
      labels:
        version: v2.0.0
```

**Retries and Timeouts:**

```yaml
http:
  - timeout: 3s                # if no response in 3s, fail fast
    retries:
      attempts: 3              # retry up to 3 times
      perTryTimeout: 1s        # each try gets 1s
      retryOn: 5xx,reset,connect-failure
    route:
      - destination:
          host: payment-service
```

Without this, if payment-service is slow, order-service hangs until TCP timeout (minutes). With Istio, it fails fast in 3s and retries.

**Header-based routing:**

```yaml
http:
  - match:
      - headers:
          x-user-type:
            exact: premium     # premium users get v2
    route:
      - destination:
          host: product-service
          subset: v2
  - route:                     # everyone else gets v1
      - destination:
          host: product-service
          subset: v1
```

This lets you A/B test by user type, route by geography, or test a new version for internal employees — all without touching application code.

#### Capability 3: Circuit Breaker

A circuit breaker prevents a failing service from taking down all its callers. The name comes from electrical circuit breakers — if current is too high, the breaker trips and cuts the circuit before it causes a fire.

Without circuit breaker:
```
order-service → payment-service (DOWN, 5s timeout)
             → waits 5s
             → request queue fills up
             → order-service runs out of threads
             → order-service goes down
             → cart-service goes down (was calling order-service)
             → whole platform down
```
This is called a **cascading failure**.

With Istio circuit breaker (configured in DestinationRule):

```yaml
spec:
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 5         # if 5 consecutive errors from one pod
      interval: 30s                   # in a 30-second window
      baseEjectionTime: 30s           # eject that pod for 30s
      maxEjectionPercent: 50          # never eject more than 50% of pods
    connectionPool:
      http:
        http1MaxPendingRequests: 100  # max 100 pending requests
        http2MaxRequests: 1000
```

Istio tracks error rates per pod. If a pod returns 5 errors in a row, Envoy stops sending traffic to it for 30 seconds. The pod "cools off" while the rest of the service keeps serving traffic. After 30 seconds, one request is tried again — if it succeeds, the pod comes back; if not, it is ejected again for longer.

This stops cascading failures cold.

#### Capability 4: Observability — Automatic Metrics, Tracing, and Logs

Without a service mesh, you have to add metrics, tracing, and logging code to every service manually. With Istio, it is completely automatic — every Envoy sidecar emits data about every request it handles.

**Automatic Metrics (scraped by Prometheus):**
Every Envoy proxy exports these metrics for every service-to-service call:
- `istio_requests_total` — total request count with labels: source service, destination service, response code
- `istio_request_duration_milliseconds` — request latency histogram
- `istio_request_bytes` / `istio_response_bytes` — payload sizes

These let you build dashboards showing: p50/p95/p99 latency per service pair, error rates, request volumes — all without writing a single line of metrics code in your application.

**Distributed Tracing (via Jaeger or Zipkin):**
Every request that enters the mesh gets a trace ID. Each Envoy sidecar in the chain adds a span to the trace. At the end you can see the full journey of one request:

```
Request: POST /api/orders  (trace-id: abc123)
  └── api-gateway (2ms)
        └── order-service (45ms)
              ├── cart-service (8ms)      ← this one is slow
              └── payment-service (12ms)
```

You can immediately see that cart-service is the bottleneck. Without tracing, you would only know "the order took 45ms" with no idea where the time went.

**Access Logs:**
Every proxy logs every request with: source, destination, method, path, response code, latency. This is the complete audit trail of all inter-service communication.

#### Capability 5: Authorization Policy — Who Can Call Whom

On top of mTLS (which proves identity), Istio's AuthorizationPolicy defines which services are allowed to talk to which. This is Istio's version of NetworkPolicy, but at Layer 7 (HTTP) instead of Layer 3/4 (IP/port).

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-service-policy
  namespace: dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: payment-service   # applies to payment-service pods
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/dev/sa/order-service"   # only order-service can call
    - to:
        - operation:
            methods: ["POST"]               # only POST allowed
            paths: ["/payments/*"]          # only to /payments/ path
```

This is extremely precise: payment-service only accepts POST requests to `/payments/*` from order-service. cart-service trying to call payment-service directly would get `403 Forbidden` — even though both are in the same namespace and the same cluster.

In AzureShop without Istio, the NetworkPolicy blocks at the IP/port level. With Istio, you can additionally block at the HTTP method + path level, verified by cryptographic identity.

---

### Istio's Key Resource Types — Full Reference

| Resource | API Group | Purpose |
|---|---|---|
| **VirtualService** | `networking.istio.io` | Routing rules: where does traffic for a service go? Weight splits, header matching, retries, timeouts |
| **DestinationRule** | `networking.istio.io` | Policies after routing: load balancing algorithm, circuit breaker, subsets (versions) |
| **Gateway** | `networking.istio.io` | Ingress/egress at the mesh boundary — replaces NGINX Ingress for north-south traffic |
| **ServiceEntry** | `networking.istio.io` | Register external services (outside the cluster) so Istio can manage traffic to them |
| **PeerAuthentication** | `security.istio.io` | Sets mTLS mode (PERMISSIVE or STRICT) for a namespace or specific workloads |
| **AuthorizationPolicy** | `security.istio.io` | Who is allowed to call whom (Layer 7 access control) |
| **RequestAuthentication** | `security.istio.io` | Validates JWT tokens on incoming requests (end-user authentication at the mesh level) |
| **EnvoyFilter** | `networking.istio.io` | Advanced: directly modify Envoy proxy config (low-level escape hatch) |
| **Sidecar** | `networking.istio.io` | Controls which services a pod's Envoy knows about (reduces memory usage at scale) |

---

### North-South vs East-West Traffic

Understanding where a service mesh fits requires knowing these two directions:

**North-South traffic:** Traffic flowing IN from the internet to the cluster, or OUT from the cluster to the internet.
- In AzureShop: Azure Application Gateway → NGINX Ingress → api-gateway
- Handled by: Ingress controllers, Application Gateway, Load Balancers
- Istio can handle this too via its **Gateway** resource (replaces NGINX Ingress)

**East-West traffic:** Traffic flowing between services INSIDE the cluster.
- In AzureShop: api-gateway → user-service, order-service → payment-service, etc.
- Currently handled by: Kubernetes ClusterIP Services + kube-proxy (plain HTTP, no encryption, no tracing)
- Service mesh is designed specifically for this type of traffic

```
Internet
    ↓ (north-south — NGINX Ingress handles this)
api-gateway
    ↓ (east-west — service mesh handles this)
user-service ←→ cart-service ←→ order-service ←→ payment-service
```

---

### How Istio Injects Sidecars Automatically

You don't manually add the Envoy container to every pod spec. Istio uses a **Mutating Webhook** to inject it automatically.

When you label a namespace with `istio-injection: enabled`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    istio-injection: enabled    # ← this one label activates automatic injection
```

Every new pod created in this namespace goes through the following process:

```
1. You run: kubectl apply -f deployment.yaml  (1 container defined)
2. K8s API Server receives the request
3. Mutating Admission Webhook fires (registered by Istio)
4. Istio webhook modifies the pod spec:
   - Adds init container: istio-init (sets iptables rules to intercept all traffic)
   - Adds sidecar container: istio-proxy (the Envoy proxy)
5. Pod is created with 3 containers instead of 1 (your app + init + proxy)
6. Envoy sidecar registers with istiod and gets its config + certificate
```

Your Deployment YAML does not change at all. The injection is completely transparent.

---

### Istio vs Pure Kubernetes — Side by Side

| Feature | Plain Kubernetes | With Istio |
|---|---|---|
| **Pod-to-pod encryption** | No — plain HTTP | Yes — automatic mTLS |
| **Service identity** | None — any pod can call any pod | SPIFFE certificate per ServiceAccount |
| **Who can call whom** | NetworkPolicy (IP/port level) | AuthorizationPolicy (HTTP method/path/identity) |
| **Load balancing** | Random (kube-proxy iptables) | Round-robin, least-conn, random, consistent-hash |
| **Retries** | None — you must code it | Automatic per VirtualService rules |
| **Timeouts** | TCP timeout (minutes) | Per-request timeout (seconds) |
| **Circuit breaker** | None — cascading failures possible | Automatic outlier detection + ejection |
| **Canary deployments** | Not possible — only by replica count | Precise percentage weight in VirtualService |
| **Header-based routing** | Not possible | Full HTTP header matching |
| **Request tracing** | Manual — you must add tracing code | Automatic — every request traced |
| **Per-request metrics** | Manual — you must add Prometheus code | Automatic — Envoy emits all metrics |
| **Access logs** | Container stdout only | Full mesh-wide access log per request |

---

### Istio in AzureShop — What Would Change

AzureShop does not currently use Istio. Here is exactly what exists today vs what Istio would add:

**Today (plain K8s):**
```
api-gateway (NGINX) → user-service:3001   (plain HTTP, no auth, no tracing)
                    → product-service:3002 (plain HTTP, no auth, no tracing)
                    → order-service:3004   (plain HTTP, no auth, no tracing)
                         → payment-service:3005 (plain HTTP, VERY sensitive!)
```

**With Istio:**
```
api-gateway → user-service       (mTLS, verified cert, auto retry, traced)
           → product-service      (mTLS, verified cert, circuit breaker, traced)
           → order-service        (mTLS, verified cert, timeout 3s, traced)
                → payment-service (mTLS, ONLY order-service allowed via AuthzPolicy,
                                   POST /payments only, traced, circuit breaker)
```

Payment service is the most sensitive — it would benefit most from Istio's AuthorizationPolicy preventing any service other than order-service from calling it, and from mTLS ensuring even internal cluster traffic cannot be eavesdropped.

**Canary deployment with Istio in AzureShop:**

Today, to test product-service v2.0.0 on 10% of traffic, you would need to:
- Deploy a separate Deployment with 1 replica (10% of 10 total = 10%)
- This is imprecise and couples traffic split to replica count

With Istio VirtualService:
```yaml
# Test v2.0.0 on exactly 10% regardless of replica count
- route:
    - destination: { host: product-service, subset: v1 }
      weight: 90
    - destination: { host: product-service, subset: v2 }
      weight: 10
```

Run 5 v2 replicas and 5 v1 replicas, but only 10% of requests go to v2. This is true canary — traffic percentage is independent of replica count.

**Why AzureShop doesn't use Istio today:**
- AzureShop is a dev/learning environment — the operational overhead of Istio (more complexity, more memory per pod ~50MB per sidecar, more objects to manage) is not justified
- At 8 services and low traffic, the benefits don't outweigh the costs
- At enterprise scale (50+ services, strict compliance requirements, multiple teams), Istio is standard practice

---

### Popular Alternatives to Istio

| Service Mesh | Key Trait | Best For |
|---|---|---|
| **Istio** | Most features, most complex, uses Envoy | Large enterprises, Google Cloud |
| **Linkerd** | Lightweight, simple, Rust-based proxy | Teams that want simpler operations |
| **Consul Connect** | HashiCorp ecosystem | Teams already using Vault/Consul |
| **AWS App Mesh** | AWS-native, uses Envoy | AWS-only workloads |
| **Cilium Service Mesh** | eBPF-based, no sidecar needed | High performance, newer clusters |
| **Azure Service Fabric Mesh** | Azure-managed | Azure-native microservices |

**Cilium** is particularly interesting for AKS: it uses eBPF (a Linux kernel technology) to do what Istio does, but without injecting sidecar containers. AKS has native Cilium integration and it is becoming increasingly popular as it eliminates the sidecar overhead entirely.

---

### The Sidecar Overhead — The Real Cost of a Service Mesh

Nothing is free. Each Envoy sidecar adds:

- **~50MB RAM** per pod (each AzureShop pod would go from ~128MB to ~178MB)
- **~1-2ms latency** added per hop (two proxy hops: source Envoy + destination Envoy)
- **More CPU** for TLS encryption/decryption
- **More complexity** — new CRDs, more YAML, new failure modes to debug
- **Startup time** — pods take slightly longer to start (sidecar must register with istiod)

At 8 pods per service × 8 services = 64 pods, this adds ~3.2GB of extra RAM just for sidecars. For a dev cluster this is significant. For a production cluster with 200+ pods across 50 services, the security and observability benefits easily outweigh the cost.

---

### Summary: What Problem Each Istio Feature Solves

```
PROBLEM                          ISTIO SOLUTION
─────────────────────────────    ──────────────────────────────────────
Pod-to-pod traffic readable      mTLS (PeerAuthentication STRICT mode)
by anyone on cluster network

Any service can call any          AuthorizationPolicy — cryptographic
other service                     identity-based access control (Layer 7)

Cascading failures when           Circuit breaker (outlierDetection in
one service is slow/down          DestinationRule) + retries + timeouts

Can't trace a request across      Automatic distributed tracing
multiple services                 (Jaeger/Zipkin via Envoy)

No metrics without coding         Automatic Prometheus metrics from
them into every service           every Envoy proxy

Can only do random load           DestinationRule: LEAST_CONN,
balancing (kube-proxy)            consistent-hash, round-robin

Canary = replica count            VirtualService: precise weight %
(coarse, imprecise)               independent of replica count

Header-based routing impossible   VirtualService match conditions:
                                  headers, URI, method, port

External service traffic          ServiceEntry: bring external services
unmanaged by mesh                 into the mesh's control
```

---

### Interview Prep

1. **What is a service mesh?** — A service mesh is an infrastructure layer that handles all service-to-service (east-west) communication inside a Kubernetes cluster. It uses sidecar proxy containers injected into every pod to intercept all network traffic. The application code never changes — the mesh handles encryption (mTLS), retries, timeouts, circuit breakers, traffic splitting, and observability automatically. It solves problems that would otherwise require each development team to implement the same networking logic repeatedly.

2. **What is Istio?** — Istio is the most widely used open-source service mesh for Kubernetes. It uses Envoy as its sidecar proxy and has a control plane called istiod. istiod has three components: Pilot (distributes routing config to all proxies), Citadel (issues TLS certificates for every ServiceAccount), and Galley (validates config). Istio provides mTLS, traffic management, circuit breaking, distributed tracing, automatic metrics, and authorization policies.

3. **What is the sidecar pattern?** — A sidecar is a second container injected into every pod alongside your application container. In Istio, this sidecar is an Envoy proxy. Every packet going in or out of the pod passes through the Envoy sidecar first. The sidecar intercepts traffic using iptables rules set by an init container at pod startup. The application sees nothing — it makes plain HTTP calls, and Envoy transparently handles encryption, routing policies, and telemetry. Istio injects sidecars automatically via a Mutating Admission Webhook when the namespace has `istio-injection: enabled`.

4. **What is mutual TLS (mTLS)?** — mTLS is TLS where BOTH sides authenticate, not just the server. Normal HTTPS (one-way TLS): the browser verifies the server's certificate, but the server does not verify the browser. mTLS: both services verify each other's certificates before communicating. In Istio, every pod's Envoy sidecar gets a SPIFFE certificate tied to its Kubernetes ServiceAccount. When two services connect, both Envoy proxies exchange and verify certificates. This proves that "I am really payment-service/sa/order-service" — a compromised pod cannot impersonate another service.

5. **What is a VirtualService in Istio?** — A VirtualService defines routing rules for traffic going TO a service. It answers: where does this request actually go? You can split traffic by percentage (90% to v1, 10% to v2 for canary), route by HTTP header (premium users to v2), set timeouts and retry rules, and inject faults for chaos testing. A VirtualService is bound to a specific host (service name) and applies to all traffic heading to that host.

6. **What is a DestinationRule in Istio?** — A DestinationRule defines policies that apply AFTER routing is decided. It answers: how do we connect to the destination? It sets load balancing algorithm (LEAST_CONN, ROUND_ROBIN, RANDOM, consistent hash), circuit breaker settings (outlier detection, connection pool limits), and defines subsets (named groups of pods by label, e.g., v1 and v2). VirtualService and DestinationRule always work as a pair: VirtualService says where, DestinationRule says how.

7. **What is a circuit breaker and why does Istio need one?** — A circuit breaker prevents cascading failures. If payment-service starts returning errors, without a circuit breaker, order-service keeps calling it and fills up its thread pool, eventually going down itself — taking down the whole platform. Istio's circuit breaker (configured via DestinationRule outlierDetection) watches error rates per pod. If a pod returns 5 consecutive errors, Istio stops routing to it for 30 seconds. Traffic goes to healthy pods only. After the cooldown, Istio sends one probe request to check if the pod recovered. This stops one failing service from cascading into a full outage.

8. **What does AzureShop gain from using Istio vs what it does today?** — Today AzureShop uses plain Kubernetes: inter-service traffic is unencrypted HTTP, any service can call any other service, there is no distributed tracing, and kube-proxy does only random load balancing. With Istio: all 8 services communicate via mTLS (encrypted, identity-verified), payment-service would be locked to only accept calls from order-service via AuthorizationPolicy, every request across all 6 hops is automatically traced in Jaeger with per-hop latency, and canary deployments become precise percentage splits. The trade-off is ~50MB RAM per pod overhead and increased operational complexity — justified at enterprise scale but overkill for a dev learning environment.

---

## Q27. How Does Autoscaling Work in Kubernetes? Explain HPA, VPA, Cluster Autoscaler, and KEDA with How Services Fit In

### Why Autoscaling Matters

Imagine AzureShop on a normal Tuesday at 2am — very few users, low traffic. You have 2 pods per service running. Now imagine Black Friday at noon — 100x more traffic. If you still have 2 pods per service, your services will be overwhelmed, requests will time out, and customers will leave.

Manual scaling means someone stays up all night watching dashboards and running `kubectl scale` commands. That is not realistic for a production system.

**Autoscaling** is Kubernetes automatically adding or removing pods (and even nodes) based on real-time demand — no human intervention needed.

In Kubernetes there are four distinct autoscaling mechanisms, each solving a different problem:

| Mechanism | What it scales | Based on | Scope |
|---|---|---|---|
| **HPA** — Horizontal Pod Autoscaler | Pod count | CPU, memory, custom metrics | Per Deployment |
| **VPA** — Vertical Pod Autoscaler | Pod resource requests/limits | Historical usage | Per Deployment |
| **Cluster Autoscaler** | Node count | Pending pods / underutilized nodes | Entire cluster |
| **KEDA** — Event-driven autoscaler | Pod count (including to zero) | Queue length, events, any metric | Per Deployment |

They work at different layers and are often used together:

```
KEDA / HPA                    → scales PODS (adds more copies of the same container)
Cluster Autoscaler            → scales NODES (adds more VMs to the cluster)
VPA                           → scales RESOURCES per pod (more CPU/RAM per container)
```

---

### Before Autoscaling: What is a Service and Why Does it Matter Here?

You asked about Services in the context of autoscaling. This is one of the most important connections to understand. (Services are covered in full detail in Q22 — this section explains specifically how Services enable transparent autoscaling.)

**The problem without Services:**

Imagine a caller (api-gateway) wants to send traffic to product-service. It would need to know each pod's IP address. But when HPA adds 2 new pods, those new pods have brand new IP addresses. The caller would have to be reconfigured to know about the new pods. That is impossible to do automatically.

**How a Service solves this for autoscaling:**

A Kubernetes Service has a **single stable ClusterIP** (e.g., `10.0.12.5`) that never changes, regardless of how many pods are running behind it. The Service uses a **label selector** to automatically find all pods matching `app.kubernetes.io/name: product-service`. As HPA adds or removes pods, the Service's EndpointSlice is **automatically updated** — new pods are added to the routing table, deleted pods are removed. The caller always talks to the same ClusterIP and never needs to know anything has changed.

```
Before scaling (2 pods):
api-gateway → 10.0.12.5 (ClusterIP: product-service)
                  ↓ kube-proxy
             ├── pod 10.240.0.7  (50% chance)
             └── pod 10.240.0.8  (50% chance)

After HPA adds 3 more pods (5 pods total):
api-gateway → 10.0.12.5 (same ClusterIP — nothing changes for caller)
                  ↓ kube-proxy
             ├── pod 10.240.0.7  (20% chance)
             ├── pod 10.240.0.8  (20% chance)
             ├── pod 10.240.1.2  (20% chance)  ← new
             ├── pod 10.240.1.3  (20% chance)  ← new
             └── pod 10.240.1.4  (20% chance)  ← new
```

The Service is what makes autoscaling transparent. Without a Service, autoscaling would be useless because callers would never find the new pods.

---

### Part 1: HPA — Horizontal Pod Autoscaler

#### What It Does

HPA adds more pod replicas when load is high, and removes them when load drops. "Horizontal" means scaling out/in — adding more copies of the same thing (as opposed to vertical, which means making each copy bigger).

Think of it like a restaurant: when it gets busy, you call in more waiters (scale out). When it quiets down, you send waiters home (scale in). Each waiter is identical — same job, same capability. You are just changing the number of them.

#### How HPA Works Internally

HPA is a built-in Kubernetes controller (part of kube-controller-manager). It runs a control loop every 15 seconds:

```
Every 15 seconds:
  1. Query metrics-server: "What is the average CPU across all product-service pods?"
  2. Metrics-server returns: average CPU = 85%
  3. HPA has target: 70% CPU
  4. HPA calculates: desired replicas = ceil(current replicas × (current / target))
                                      = ceil(2 × (85 / 70))
                                      = ceil(2 × 1.21)
                                      = ceil(2.43)
                                      = 3
  5. HPA updates Deployment: spec.replicas = 3
  6. Deployment controller creates 1 new pod
  7. New pod starts, passes readiness probe, joins Service endpoints
  8. Traffic is now spread across 3 pods
```

The formula: `desiredReplicas = ceil(currentReplicas × (currentMetricValue / desiredMetricValue))`

#### What is metrics-server?

metrics-server is a lightweight in-cluster component that scrapes CPU and memory usage from the `kubelet` on each node every 15 seconds. HPA queries metrics-server to get real-time resource usage. Without metrics-server, HPA cannot function.

In AKS, metrics-server is pre-installed on the system node pool — it is one of the critical system components that the system pool runs. You can verify it with: `kubectl top pods -n azureshop`.

#### Scale-Up vs Scale-Down Behaviour

HPA scales up aggressively (responds quickly to traffic spikes) but scales down conservatively (waits before removing pods, to avoid thrashing):

- **Scale up:** Acts immediately when the metric exceeds the target for 3 consecutive checks
- **Scale down:** Waits for a **stabilisation window** (default: 5 minutes) — it only scales down after the metric has been below target for 5 minutes continuously

This prevents the "flapping" problem: load spikes to 85%, HPA adds pods, load drops to 60%, HPA removes pods, load spikes again, repeat forever. The 5-minute cooldown breaks this cycle.

#### HPA in AzureShop — Exact Implementation

Every one of the 8 AzureShop services has an HPA created by Helm.

File: `helm/charts/user-service/templates/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service
  namespace: dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service        # HPA controls this Deployment
  minReplicas: 2              # never go below 2 (always HA)
  maxReplicas: 10             # never go above 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70   # target 70% CPU across all pods
```

Values from `helm/charts/user-service/values.yaml`:
```yaml
replicaCount: 2          # initial replica count set in Deployment

hpa:
  minReplicas: 2         # minimum 2 replicas at all times
  maxReplicas: 10        # maximum 10 replicas under load
  cpuUtilizationPercentage: 70  # scale when average CPU > 70%

resources:
  requests:
    cpu: "100m"          # HPA uses this as the baseline for % calculation
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

**Why `minReplicas: 2`?** Because if user-service had only 1 pod and that pod crashed, there would be a brief period with zero pods — meaning zero availability for that service. With 2 minimum replicas, if one crashes the other keeps serving while the replacement starts. This is the minimum for High Availability.

**Why `averageUtilization: 70` and not 90 or 100?**
CPU utilization of 100% means pods are completely saturated — requests are already failing or queueing. By targeting 70%, you trigger scale-out before pods are overwhelmed. The 30% headroom absorbs the spike while new pods are starting (pods take 10-30 seconds to become ready).

**How the % is calculated:** If `requests.cpu = 100m` and the pod is using `70m` of CPU, utilization = 70%. So when a user-service pod uses more than 70m CPU on average across all replicas, HPA triggers scale-out.

#### HPA with Multiple Metrics

AzureShop uses only CPU today, but HPA v2 supports multiple metrics simultaneously — it scales to satisfy the most demanding metric:

```yaml
metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # Custom metric — requests per second (requires Prometheus adapter)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"        # scale if any pod handles >100 req/s
```

HPA calculates the desired replica count independently for each metric and takes the **maximum**. If CPU says "need 3 replicas" and memory says "need 5 replicas", HPA scales to 5.

---

### Part 2: VPA — Vertical Pod Autoscaler

#### What It Does

VPA adjusts the CPU and memory **requests and limits** of running pods based on their actual historical usage. "Vertical" means making each pod bigger or smaller — more CPU, more RAM.

Think of the restaurant analogy again: instead of calling in more waiters (HPA), you train each waiter to work faster or give them better tools (VPA). You change the capability of each copy, not the number.

#### The Problem VPA Solves

When you deploy a service, you guess at the resource requests:
```yaml
resources:
  requests:
    cpu: "100m"     # is this right? what if the app actually needs 250m?
    memory: "128Mi" # what if it actually uses 300Mi?
```

If your requests are too low, pods get throttled or OOMKilled. If too high, you waste cluster resources and the scheduler cannot pack pods efficiently.

VPA watches actual usage over time and recommends (or automatically applies) correct values:

```
VPA observes user-service over 7 days:
  Actual CPU usage: p50=180m, p95=380m
  Actual memory:    p50=220Mi, p95=410Mi

VPA recommendation:
  requests.cpu:    "200m"    (was 100m — too low)
  requests.memory: "256Mi"   (was 128Mi — too low)
  limits.cpu:      "500m"    (unchanged)
  limits.memory:   "512Mi"   (unchanged)
```

#### VPA Modes

| Mode | What happens |
|---|---|
| `Off` | VPA only recommends — you apply manually |
| `Initial` | VPA sets resources when pod is created, never changes running pods |
| `Auto` | VPA automatically evicts pods and recreates them with new resource values |

The `Auto` mode is the most powerful but also the most disruptive — it must restart pods to apply new resource settings. This is why VPA and HPA should not both control the same metric simultaneously. If HPA is scaling on CPU and VPA is changing CPU requests, they fight each other. Common practice: use HPA for CPU-based scaling, VPA for memory recommendations only.

#### VPA is NOT installed in AzureShop

AzureShop does not currently use VPA. It is a separate component that must be installed explicitly. The resource values in `values.yaml` (`requests.cpu: 100m`, `memory: 128Mi`) were set manually based on estimates. VPA would let you measure actual usage and tune these automatically.

---

### Part 3: Cluster Autoscaler — Scaling the Nodes

#### What It Does

HPA adds more pods. But what if the cluster has no room for new pods? The node VMs are all full. This is where the **Cluster Autoscaler** comes in — it adds or removes entire **nodes** (VMs) from the cluster.

Think of it like: HPA calls more waiters (pods), but the restaurant is full (no free tables/nodes). The Cluster Autoscaler builds more tables — adds more VMs to the cluster so there is room for the new pods.

#### Scale-Up: Adding Nodes

```
1. HPA decides product-service needs 8 pods (currently 3 running)
2. Kubernetes scheduler tries to place 5 new pods
3. No node has enough free CPU/memory for 5 pods
4. Pods remain in "Pending" state
5. Cluster Autoscaler sees: there are Pending pods that cannot be scheduled
6. Cluster Autoscaler asks AKS to add a new node to the user node pool
7. AKS provisions a new VM (Standard_D2s_v3), joins it to the cluster
8. Pending pods are scheduled on the new node
9. All 8 pods are now running
```

This takes 2-5 minutes (VM provisioning is not instant). During that time, the existing pods handle traffic at higher load.

#### Scale-Down: Removing Nodes

```
1. Traffic drops. HPA scales product-service back to 3 pods.
2. One node now has very few pods on it (mostly empty)
3. Cluster Autoscaler checks: can all pods on this node fit on other nodes?
4. Yes → Cluster Autoscaler cordons the node (no new pods scheduled)
5. Drains the node: pods are evicted (gracefully) and rescheduled elsewhere
6. Cluster Autoscaler asks AKS to delete the VM
7. Node is removed, you stop paying for it
```

Scale-down has a 10-minute delay by default — the node must be underutilised for 10 consecutive minutes before removal.

#### Cluster Autoscaler in AzureShop — Exact Implementation

File: `infra/modules/aks/main.tf`

```hcl
# User Node Pool — runs application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name  = "user"
  vm_size = "Standard_D2s_v3"   # 2 vCPU, 8GB RAM per node

  auto_scaling_enabled = true    # ← Cluster Autoscaler is active
  node_count  = 1                # starting node count
  min_count   = 1                # never go below 1 node
  max_count   = 3                # never go above 3 nodes (free tier quota)

  lifecycle {
    ignore_changes = [node_count]  # ← don't fight the autoscaler in Terraform
  }
}
```

File: `infra/modules/aks/variables.tf`
```hcl
variable "user_node_min_count" { default = 1 }   # minimum 1 node
variable "user_node_max_count" { default = 3 }   # maximum 3 nodes
```

**`ignore_changes = [node_count]`** — this is critical. Without it, every time you run `terraform apply`, Terraform would see the autoscaler changed `node_count` from 1 to 2 (or 3) and try to set it back to 1. The `ignore_changes` tells Terraform "the autoscaler owns this field, don't touch it."

**System node pool (`default_node_pool`):** The system node pool has `node_count = 2` (fixed) with no autoscaling. System nodes run CoreDNS and metrics-server — they must always be available. You don't autoscale the control plane components.

#### HPA + Cluster Autoscaler Together — The Full Picture

```
Traffic spike hits AzureShop on Black Friday:

1. CPU on product-service pods rises above 70%
   → HPA says: "scale from 3 to 8 pods"
   → Scheduler: "only room for 2 new pods on existing nodes — 3 pods Pending"

2. Cluster Autoscaler sees 3 Pending pods
   → Asks AKS: "add 1 more node to user pool"
   → New node joins (2-5 minutes later)

3. 3 Pending pods scheduled on new node
   → All 8 pods now running
   → CPU drops back below 70%

4. Traffic normalises at midnight
   → HPA says: "scale back to 3 pods"
   → Empty node has few pods, can be drained
   → Cluster Autoscaler removes the node (saves cost)
```

They work in concert: HPA manages pods, Cluster Autoscaler manages the infrastructure those pods run on.

---

### Part 4: KEDA — Kubernetes Event-Driven Autoscaling

#### What It Does

HPA only scales based on CPU and memory (or custom metrics with an adapter). But many real-world scaling scenarios are event-driven:

- A queue has 10,000 messages → you need more workers to process them
- A database has 500 pending jobs → you need more processors
- A Kafka topic has 1M unread events → you need more consumers
- At night (no traffic) → you want zero pods to save cost

KEDA (Kubernetes Event-Driven Autoscaler) connects external event sources to Kubernetes scaling. It can scale deployments from **0 to N and back to 0** — something HPA cannot do (HPA minimum is 1).

#### How KEDA Works

KEDA installs as an operator (custom controller) in the cluster. You define a `ScaledObject` that connects a Deployment to an external trigger:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: notification-service-scaler
  namespace: dev
spec:
  scaleTargetRef:
    name: notification-service     # the Deployment to scale
  minReplicaCount: 0               # ← can go to ZERO (HPA cannot do this)
  maxReplicaCount: 20
  triggers:
    - type: azure-servicebus        # scale based on Azure Service Bus queue depth
      metadata:
        queueName: notification-queue
        namespace: sb-azureshop-dev
        messageCount: "10"         # 1 pod per 10 messages in the queue
```

With this: when the notification queue is empty → 0 pods (no cost). When 100 messages arrive → KEDA scales to 10 pods. When the queue drains → back to 0 pods.

#### KEDA Scalers — What Sources It Supports

KEDA has 70+ built-in scalers:

| Scaler | Scales based on |
|---|---|
| `azure-servicebus` | Azure Service Bus queue/topic depth |
| `azure-eventhub` | Azure Event Hub consumer lag |
| `azure-storage-queue` | Azure Storage Queue message count |
| `prometheus` | Any Prometheus metric (requests/sec, custom app metric) |
| `kafka` | Kafka consumer group lag |
| `rabbitmq` | RabbitMQ queue depth |
| `cron` | Time-based (scale to 0 at night, back up in the morning) |
| `postgresql` | PostgreSQL query result |
| `redis` | Redis list length |
| `http` | HTTP request rate (via HTTP Add-On) |

#### KEDA vs HPA

| | HPA | KEDA |
|---|---|---|
| **Minimum replicas** | 1 (cannot go to 0) | 0 (can scale to zero) |
| **Metrics source** | CPU, memory, custom (via adapter) | 70+ external sources natively |
| **Event-driven** | No | Yes — reacts to queue depth, events |
| **Installation** | Built into Kubernetes | Must install separately |
| **AzureShop** | Used — all 8 services | Not used today |
| **Best for** | Web servers, APIs (always need to serve) | Queue workers, batch processors |

For AzureShop's notification-service (which processes messages from a queue), KEDA would be a perfect fit — scale to 0 when no notifications are pending, scale up instantly when the queue fills.

#### Scale to Zero — Why It Matters for Cost

With KEDA scaling notification-service to zero replicas overnight:

```
Normal HPA (minimum 2 replicas always running):
  2 pods × 24 hours × 365 days = 17,520 pod-hours of compute cost

KEDA (queue empty 14 hours/day → 0 pods):
  2 pods × 10 hours × 365 days = 7,300 pod-hours
  Savings: 58% reduction in compute cost for that service
```

For batch processing services that only run when there is work, KEDA can save significant cost compared to always-on HPA.

---

### The Four Autoscalers Working Together — Full Picture

```
                        KUBERNETES AUTOSCALING STACK
                        ════════════════════════════

  LAYER 3: KEDA
  ─────────────────────────────────────────────────────────
  Trigger: "Azure Service Bus queue has 500 messages"
  Action:  Scale notification-service from 0 → 50 pods
  ─────────────────────────────────────────────────────────

  LAYER 2: HPA
  ─────────────────────────────────────────────────────────
  Trigger: "product-service average CPU > 70%"
  Action:  Scale product-service from 2 → 8 pods
  ─────────────────────────────────────────────────────────

  LAYER 1: Cluster Autoscaler
  ─────────────────────────────────────────────────────────
  Trigger: "8 pods are Pending — no room on existing nodes"
  Action:  Add 2 more VMs to user node pool
  ─────────────────────────────────────────────────────────

  LAYER 0: VPA (advisory)
  ─────────────────────────────────────────────────────────
  Trigger: "product-service pods consistently use 350m CPU but request only 100m"
  Action:  Recommend (or apply) requests.cpu = "400m"
  ─────────────────────────────────────────────────────────

  Kubernetes Service (transparent connector):
  ─────────────────────────────────────────────────────────
  As pods are added/removed by any autoscaler above:
  → EndpointSlice controller updates Service endpoints
  → kube-proxy updates iptables rules on all nodes
  → Callers see no change — same ClusterIP, traffic spreads automatically
  ─────────────────────────────────────────────────────────
```

---

### How the Service Enables Autoscaling to Be Transparent

This is the full internal sequence when HPA adds a new pod:

```
1. HPA updates Deployment: replicas 2 → 3
2. ReplicaSet controller creates a new pod
3. Scheduler places pod on a node
4. kubelet starts the container
5. Container passes startupProbe (30s × 30 attempts = up to 5 min wait)
6. Container passes readinessProbe (initialDelaySeconds: 10, then every 5s)
7. Pod status becomes Ready = True
8. EndpointSlice controller notices the new pod is Ready + has matching labels
9. EndpointSlice controller adds new pod IP to the EndpointSlice
10. kube-proxy on every node watches EndpointSlices
11. kube-proxy updates iptables DNAT rules to include the new pod IP
12. New traffic is now routed to the new pod automatically

Callers (api-gateway, nginx) did not change their config at all.
They still talk to the same ClusterIP. The new pod just starts receiving
its share of traffic as soon as it passes the readiness probe.
```

Steps 5-6 are why the **readiness probe** is critical for autoscaling. Without it, the new pod would be added to the Service endpoints before it is ready to serve traffic — callers would get errors. The readiness probe acts as a gate: "only add me to the load balancer when I am truly ready."

In AzureShop all 8 services define readiness probes in their Deployment template:
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 10    # wait 10s before first check
  periodSeconds: 5           # check every 5s
  failureThreshold: 3        # need 3 consecutive failures to mark not-ready
```

---

### Scale-In: What Happens When a Pod is Removed

When HPA removes a pod (scale in), the sequence is just as important:

```
1. HPA updates Deployment: replicas 5 → 3 (removing 2 pods)
2. Deployment controller marks 2 pods for deletion
3. Kubernetes sends SIGTERM to the container process
4. Pod moves to "Terminating" state
5. EndpointSlice controller removes the terminating pod from endpoints
6. kube-proxy updates iptables — no new traffic goes to the terminating pod
7. Container has terminationGracePeriodSeconds (default 30s) to finish in-flight requests
8. After 30s, if process hasn't exited, SIGKILL is sent
9. Pod is deleted
```

Step 5 and 6 happen before Step 7 — the pod is removed from the Service BEFORE it is killed, so no new requests land on it while it is shutting down. Existing in-flight requests complete during the grace period. This is how zero-downtime scale-in works.

---

### AzureShop Autoscaling — Complete Summary

| Component | Current Config | Effect |
|---|---|---|
| **user-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **product-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **cart-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **order-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **payment-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **api-gateway HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **frontend HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **notification-service HPA** | min 2, max 10, CPU 70% | Scales pods 2–10 based on CPU |
| **User node pool (CA)** | min 1 node, max 3 nodes | Scales VMs when pods are Pending |
| **System node pool** | Fixed 2 nodes | No autoscaling — always stable |
| **VPA** | Not used | Resource requests set manually |
| **KEDA** | Not used | notification-service would benefit |
| **Services** | ClusterIP per service | Transparent — endpoints auto-update on scale |

For the free-tier dev cluster, 8 services × up to 10 pods = 80 pods maximum. Each `Standard_D2s_v3` node (2 vCPU, 8GB) can run about 8-10 pods comfortably. Maximum 3 user nodes × 10 pods = 30 pods — in practice, the HPA on a dev cluster with low traffic keeps replica counts at minimum (2 per service = 16 pods total), well within 1-2 nodes.

---

### Common Autoscaling Mistakes

**Mistake 1: No resource requests set**

```yaml
resources: {}   # no requests defined!
```

HPA cannot calculate utilisation percentage without a baseline (`requests.cpu`). If you don't set resource requests, HPA silently does nothing. Always set `resources.requests`.

**Mistake 2: Readiness probe missing**

Without a readiness probe, new pods are added to Service endpoints the moment they start — before the app has initialised. Early requests fail with connection refused. Always define a readiness probe.

**Mistake 3: VPA and HPA both controlling CPU**

VPA changes CPU requests → HPA recalculates desired replicas based on new requests → HPA scales → VPA recalculates → endless loop. Use one or the other for CPU. Safe combination: HPA on CPU, VPA on memory (advisory mode only).

**Mistake 4: `minReplicas: 1` on critical services**

If the single pod crashes, there is a gap with zero availability while a replacement starts (10-30 seconds). For any service that must be highly available, always set `minReplicas: 2`.

**Mistake 5: Terraform fights the Cluster Autoscaler**

Without `ignore_changes = [node_count]` in the Terraform lifecycle block, every `terraform apply` resets node count to the initial value, undoing what the Cluster Autoscaler did. Always add `ignore_changes = [node_count]` to autoscaled node pools.

---

### Interview Prep

1. **What is the difference between HPA and VPA?** — HPA (Horizontal Pod Autoscaler) changes the NUMBER of pod replicas — it adds more copies of your container when load increases. VPA (Vertical Pod Autoscaler) changes the SIZE of each pod — it increases or decreases CPU and memory requests/limits per pod based on actual usage. HPA scales out; VPA scales up. They should not both control the same metric (e.g., both controlling CPU) as they will conflict. Common pattern: HPA for pod count scaling, VPA in advisory mode to right-size resource requests.

2. **What is the HPA scaling formula?** — `desiredReplicas = ceil(currentReplicas × (currentMetricValue / desiredMetricValue))`. If you have 2 pods, average CPU is 85%, and target is 70%: `ceil(2 × 85/70) = ceil(2.43) = 3`. HPA rounds up to ensure capacity is always sufficient. It checks every 15 seconds. Scale-up happens immediately when threshold is breached for 3 checks; scale-down waits 5 minutes (stabilisation window) to prevent thrashing.

3. **What is the Cluster Autoscaler and how does it work with HPA?** — The Cluster Autoscaler adds or removes nodes (VMs) from the cluster. HPA and Cluster Autoscaler work together: HPA detects high CPU and decides more pods are needed. The scheduler cannot place pods because nodes are full — pods stay Pending. The Cluster Autoscaler sees Pending pods and asks the cloud provider to add a new node. Once the node joins, pending pods are scheduled. When traffic drops, HPA removes pods, the node empties, and the Cluster Autoscaler removes the node. In AzureShop, the user node pool has `auto_scaling_enabled = true` with min 1 and max 3 nodes.

4. **What is KEDA and how is it different from HPA?** — KEDA (Kubernetes Event-Driven Autoscaler) scales pods based on external event sources — Azure Service Bus queue depth, Kafka consumer lag, Redis list length, time of day, etc. The critical difference from HPA: KEDA can scale deployments to **zero replicas** and back. HPA minimum is 1. For batch processors and queue workers, this means zero cost when idle. KEDA also has 70+ native scalers with no custom metric adapter needed. In AzureShop, notification-service would benefit from KEDA — scale to 0 when the notification queue is empty, scale up when messages arrive.

5. **Why does a Kubernetes Service matter for autoscaling?** — A Service provides a single stable ClusterIP that never changes regardless of pod count. As HPA adds or removes pods, the EndpointSlice controller automatically updates the Service's routing table — new pods are added once they pass their readiness probe, removed pods are deleted from the table before shutdown. Callers always use the same ClusterIP and see no disruption during scaling. Without a Service, every caller would need to track pod IPs manually — autoscaling would be useless because callers would never find the new pods.

6. **What is the role of the readiness probe in autoscaling?** — The readiness probe determines when a newly scaled pod is actually ready to receive traffic. When HPA adds a pod, the pod is NOT added to the Service endpoints until its readiness probe passes. This prevents the Service from routing traffic to a pod that is still initialising. In AzureShop, all 8 services have `initialDelaySeconds: 10` before the first readiness check — giving Node.js time to start before any traffic arrives. Without readiness probes, callers would get connection errors during scale-out events.

7. **What is the stabilisation window in HPA and why does it exist?** — The stabilisation window (default 5 minutes for scale-down) prevents HPA from rapidly scaling up and down — called "thrashing" or "flapping". Without it: load spikes → HPA adds pods → load drops → HPA removes pods → spike again → repeat indefinitely. This causes constant pod churn, degraded performance, and wasted resources. The 5-minute stabilisation window means the metric must be consistently below the target for 5 full minutes before HPA removes pods. Scale-up has no stabilisation delay — it acts immediately to handle spikes.

8. **How does `ignore_changes = [node_count]` in Terraform relate to the Cluster Autoscaler?** — The Cluster Autoscaler dynamically changes the `node_count` value on the AKS node pool as it adds/removes nodes. Terraform tracks the initial value of `node_count` in its state file. Without `ignore_changes`, every `terraform apply` would see the autoscaler-changed value as drift and reset it back to the initial count — destroying the autoscaler's work and causing downtime. Adding `ignore_changes = [node_count]` to the lifecycle block tells Terraform "this field is owned by the Cluster Autoscaler, do not touch it." All AzureShop autoscaled node pools include this.

---

## Q28. What is a Persistent Volume and a Persistent Volume Claim in Kubernetes?

### The Core Problem — Containers Lose Their Data

Every container in Kubernetes has an **ephemeral filesystem**. When a container starts, it gets a fresh copy of whatever was in the container image. When it stops or restarts, everything written to the filesystem disappears.

This is fine for stateless services like your Node.js API — the app code is in the image, the data it handles lives in a database. But for **stateful workloads** — databases, monitoring systems, message queues — the data must survive pod restarts. If Prometheus restarts and loses all its metrics data, your 15-day retention window disappears. If a PostgreSQL pod restarts and loses its data directory, your entire database is gone.

This is the problem Kubernetes Persistent Volumes solve.

Think of it like a laptop vs an external hard drive. Your laptop (the pod) can be wiped or replaced — but the external hard drive (the Persistent Volume) is separate hardware that holds your data. Even if the laptop dies, the data on the external drive survives.

---

### Volume Types in Kubernetes — From Ephemeral to Persistent

Before diving into PVs and PVCs, it helps to understand all the volume types in Kubernetes, from least to most persistent:

| Volume Type | Survives container restart? | Survives pod deletion? | Survives node failure? | Use case |
|---|---|---|---|---|
| **Container filesystem** | No | No | No | Default — app code only |
| **emptyDir** | Yes | No | No | Scratch space, /tmp, inter-container sharing |
| **hostPath** | Yes | Yes (if same node) | No | Node-level files (logs, Docker socket) |
| **PersistentVolume** | Yes | Yes | Yes | Databases, monitoring data, any state that must survive |

**emptyDir** is the simplest volume — it is an empty directory created fresh for every pod, lives on the node's local disk, and is deleted when the pod is deleted. AzureShop uses `emptyDir` for `/tmp` in all 8 services because Node.js needs a writable `/tmp` directory (for temporary files), but that data should NOT persist — it is purely throwaway scratch space.

**PersistentVolume** is backed by real durable storage — a cloud disk, a network file share, or any storage system — and lives completely independently of pods.

---

### What is a PersistentVolume (PV)?

A PersistentVolume is a **piece of storage in the cluster** that has been provisioned by an administrator (or automatically by Kubernetes). It is a cluster-level resource — not tied to any namespace, not tied to any pod. It is just a block of storage sitting there, waiting to be claimed.

Think of a PV like a **parking space** in a car park. The car park (cluster) has many spaces of different sizes. The parking space exists independently of any car — it is just a space that can be reserved.

A PV has four key properties:

**1. Capacity**
How much storage it provides:
```yaml
capacity:
  storage: 20Gi    # 20 gigabytes of storage
```

**2. Access Mode**
How the storage can be mounted — this is determined by the underlying storage technology:

| Access Mode | Short form | Meaning | Supported by |
|---|---|---|---|
| `ReadWriteOnce` | RWO | Mounted read-write by ONE node at a time | Azure Disk, AWS EBS, GCE PD |
| `ReadOnlyMany` | ROX | Mounted read-only by MANY nodes simultaneously | Azure File, NFS |
| `ReadWriteMany` | RWX | Mounted read-write by MANY nodes simultaneously | Azure File, NFS, CephFS |
| `ReadWriteOncePod` | RWOP | Mounted read-write by ONE specific pod | Azure Disk (newer) |

**Azure Disk** (what AzureShop uses) only supports `ReadWriteOnce` — it can only be attached to one node at a time. This is a physical limitation of block storage devices. If you need a disk accessible from multiple pods on different nodes simultaneously, you need Azure File (which uses SMB/NFS protocol, like a network share).

**3. Reclaim Policy**
What happens to the PV when the PVC that claimed it is deleted:

| Policy | What happens |
|---|---|
| `Retain` | PV stays with all data — admin must manually reclaim |
| `Delete` | PV and the underlying storage (Azure Disk) are deleted |
| `Recycle` | Deprecated — basic scrub and make available again |

**4. StorageClass**
Which type of storage backend created this PV. This is how Kubernetes knows to create an Azure Disk vs Azure File vs something else.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-data-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: managed-csi
  azureDisk:           # the actual Azure Disk that backs this PV
    diskName: prometheus-data-disk
    diskURI: /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/disks/prometheus-data-disk
```

In practice you almost never write a PV by hand like this. You use **dynamic provisioning** via StorageClass, which creates the PV automatically when needed.

---

### What is a PersistentVolumeClaim (PVC)?

A PVC is a **request for storage** made by a pod (or more accurately, by the user on behalf of a pod). It is like a pod saying "I need 20Gi of ReadWriteOnce storage."

Going back to the parking analogy: if the PV is a parking space, the PVC is the **parking permit** — a claim that says "I am reserving space number 42 for my car."

The PVC specifies what it needs:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce       # I need a disk I can read-write
  storageClassName: managed-csi  # I want an Azure Disk
  resources:
    requests:
      storage: 20Gi       # I need 20 gigabytes
```

Kubernetes then finds a PV that satisfies all three requirements (access mode, storage class, size) and **binds** the PVC to that PV. Once bound, that PV is exclusively reserved for this PVC — no other PVC can claim it.

The pod then mounts the PVC:
```yaml
spec:
  containers:
    - name: prometheus
      volumeMounts:
        - name: prometheus-storage
          mountPath: /prometheus    # all data written here survives restarts
  volumes:
    - name: prometheus-storage
      persistentVolumeClaim:
        claimName: prometheus-data  # use the PVC we defined above
```

Now everything Prometheus writes to `/prometheus` goes onto the Azure Disk — and survives any number of pod restarts, node reboots, or AKS upgrades.

---

### The Binding Process — How PV and PVC Connect

```
1. You create a PVC: "I need 20Gi, ReadWriteOnce, managed-csi"

2. Kubernetes PV controller searches for a matching PV:
   → Is there a PV with storageClassName=managed-csi?
   → Does it have ReadWriteOnce?
   → Is its capacity >= 20Gi?
   → Is it currently unbound (status=Available)?

3a. If a matching PV exists (static provisioning):
    → PV status changes from Available → Bound
    → PVC status changes from Pending → Bound
    → They are linked: PVC "prometheus-data" ↔ PV "prometheus-data-pv"

3b. If NO matching PV exists (dynamic provisioning):
    → StorageClass provisioner is called (azure-disk-csi-driver)
    → It creates a new Azure Disk in Azure
    → Creates a PV object representing that disk
    → Binds the PV to the PVC
    → PVC status goes Pending → Bound
```

Once bound, the pod can be scheduled and the volume mounted. If a PVC stays in `Pending` state, the pod also stays in `Pending` state — it cannot start without its storage.

---

### Static vs Dynamic Provisioning

**Static Provisioning:** An administrator manually creates PV objects upfront. Pods claim them via PVCs. This was the original approach — tedious and hard to scale.

```
Admin creates PV → User creates PVC → Kubernetes binds them → Pod uses PVC
```

**Dynamic Provisioning:** You define a **StorageClass** that tells Kubernetes HOW to create storage automatically. When a PVC is created, Kubernetes calls the storage provider's CSI driver to provision a real disk/share on demand. The PV is created automatically — you never touch a PV object directly.

```
User creates PVC → StorageClass provisioner creates real disk → PV auto-created → Bound → Pod runs
```

Dynamic provisioning is the standard today. In AKS, the `managed-csi` StorageClass uses the Azure Disk CSI driver — when a PVC asks for `managed-csi` storage, the driver automatically creates an Azure Managed Disk in your resource group, creates a PV object, and binds it. You see the disk appear in your Azure portal.

---

### What is a StorageClass?

A StorageClass is the **recipe** for creating storage dynamically. It defines:
- **Provisioner:** which CSI driver to use (Azure Disk CSI, Azure File CSI, etc.)
- **Parameters:** what type of disk (Premium_LRS, Standard_LRS, etc.), encryption, etc.
- **ReclaimPolicy:** what to do with the disk when the PVC is deleted
- **VolumeBindingMode:** when to create the disk (immediately vs wait until pod is scheduled)

AKS ships with several built-in StorageClasses:

| StorageClass | Provisioner | Disk type | Access modes |
|---|---|---|---|
| `managed-csi` | Azure Disk CSI | Standard SSD (LRS) | RWO only |
| `managed-csi-premium` | Azure Disk CSI | Premium SSD (LRS) | RWO only |
| `azurefile-csi` | Azure File CSI | Azure File Share | RWO, ROX, RWX |
| `azurefile-csi-premium` | Azure File CSI | Premium Azure File | RWO, ROX, RWX |

```bash
# See all available StorageClasses in AKS
kubectl get storageclass

# Output:
# NAME                     PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE
# managed-csi (default)    disk.csi.azure.com         Delete          WaitForFirstConsumer
# managed-csi-premium      disk.csi.azure.com         Delete          WaitForFirstConsumer
# azurefile-csi            file.csi.azure.com         Delete          Immediate
# azurefile-csi-premium    file.csi.azure.com         Delete          Immediate
```

`WaitForFirstConsumer` is important for Azure Disk — the disk is only created when a pod actually tries to use the PVC, and it is created in the same **availability zone** as the node where the pod will run. Azure Disks are zone-pinned — a disk in zone 1 can only be attached to a node in zone 1. `WaitForFirstConsumer` ensures the disk and the node end up in the same zone.

---

### PV Lifecycle — The Full Journey

```
                        PersistentVolume Lifecycle
                        ══════════════════════════

  PROVISIONING
  ┌─────────────┐
  │  Available  │  PV exists, not yet claimed by any PVC
  └──────┬──────┘
         │ PVC created that matches this PV
         ↓
  BINDING
  ┌─────────────┐
  │   Bound     │  PV is reserved for this PVC. Pod can now use the PVC.
  └──────┬──────┘
         │ PVC is deleted
         ↓
  RECLAIMING
  ┌─────────────┐    ReclaimPolicy=Retain
  │  Released   │ ──────────────────────────→  Data preserved, admin must manually
  └──────┬──────┘                               clean up and make PV available again
         │ ReclaimPolicy=Delete
         ↓
  ┌─────────────┐
  │   Deleted   │  Azure Disk is deleted. Data is gone permanently.
  └─────────────┘
```

**Released state:** The PVC was deleted but the PV still exists. The data is still there. However, Kubernetes will NOT rebind this PV to a new PVC automatically — it remembers which PVC owned it and protects the data from accidental reuse. An admin must manually clean the PV's `claimRef` to make it Available again (for Retain policy), or the disk is deleted (for Delete policy).

---

### Azure Disk vs Azure File — When to Use Which

In AKS you have two main storage options, and choosing the wrong one is a common mistake:

| | Azure Disk (`managed-csi`) | Azure File (`azurefile-csi`) |
|---|---|---|
| **Protocol** | Block storage (like a local disk) | SMB / NFS (like a network share) |
| **Access mode** | ReadWriteOnce only | ReadWriteMany (multiple pods) |
| **Performance** | High (low latency, high IOPS) | Lower (network overhead) |
| **Zone** | Zone-pinned (disk + node must match) | Zone-redundant available |
| **Shared access** | No — one node at a time | Yes — many pods on many nodes |
| **Use cases** | Databases, Prometheus, single-writer apps | Shared config, multiple readers, legacy apps |
| **Cost** | Lower (per GB) | Higher |
| **In AzureShop** | Prometheus (20Gi), Grafana (5Gi), Alertmanager (2Gi) | Not used |

**Choose Azure Disk when:** You have one pod writing to the volume (database, monitoring). You need maximum IOPS and low latency.

**Choose Azure File when:** Multiple pods across multiple nodes need to read or write the same files simultaneously. Example: a shared configuration directory that 10 pods all need to read.

---

### PVs and PVCs in AzureShop — Exact Implementation

AzureShop's application services (user-service, product-service, etc.) are stateless — they store all state in Azure SQL Database. They use **no PVCs**. Instead they use `emptyDir` volumes for `/tmp`.

The only components in AzureShop that use PVCs are the **monitoring stack** (Prometheus, Grafana, Alertmanager), deployed via the `kube-prometheus-stack` Helm chart.

File: `helm/values/kube-prometheus-stack.yaml`

#### Prometheus — 20Gi Azure Disk

```yaml
prometheus:
  prometheusSpec:
    retention: 15d           # keep 15 days of metrics on disk

    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: managed-csi     # Azure Disk
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 20Gi
```

What this means in practice:
- When `kube-prometheus-stack` is installed, it creates a PVC named `prometheus-kube-prometheus-stack-prometheus-db-0`
- The Azure Disk CSI driver provisions a 20Gi Azure Managed Disk in the AKS resource group
- Prometheus mounts this disk at `/prometheus` inside the pod
- All metrics data (scraped from 8 services every 15 seconds) is written here
- If the Prometheus pod is restarted (node drain, AKS upgrade, pod crash), it comes back and reads ALL its historical data from the disk — the 15-day window is preserved

#### Grafana — 5Gi Azure Disk

```yaml
grafana:
  persistence:
    enabled: true
    storageClassName: managed-csi     # Azure Disk
    size: 5Gi
```

- Grafana stores its SQLite database on this disk: saved dashboards, user accounts, alert rules configured via the UI, panel edits
- Without persistence, every Grafana restart loses all UI customisations
- The pre-loaded AzureShop dashboard (from the ConfigMap) survives without the disk, but any changes made in the UI would not

#### Alertmanager — 2Gi Azure Disk

```yaml
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: managed-csi
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
```

- Alertmanager stores its **silence state** and **notification deduplication log** on disk
- If Alertmanager restarts without persistence, it forgets all configured silences and could re-fire already-sent alerts

#### Application Services — emptyDir (NOT PVC)

```yaml
# helm/charts/user-service/templates/deployment.yaml
volumes:
  - name: tmp
    emptyDir: {}     # temporary, cleared on pod restart — NOT a PVC

volumeMounts:
  - name: tmp
    mountPath: /tmp  # Node.js can write temp files here
```

Why `emptyDir` and not a PVC for application services?
- Application state lives in **Azure SQL** — the database persists data, not the pod
- `/tmp` is used for truly temporary files (multipart uploads, temp processing) — no value in persisting these
- PVCs cost money and add scheduling constraints (zone pinning)
- Stateless services should never need persistent local storage — if they do, that is usually a design smell

---

### StatefulSets and PVCs — The Right Tool for Databases

If you ever deploy a database directly inside Kubernetes (instead of using Azure SQL), you would use a **StatefulSet** instead of a Deployment, with **volumeClaimTemplates**.

A StatefulSet is a special controller designed for stateful workloads. Unlike a Deployment (where all pods are interchangeable and get random names), a StatefulSet:
- Gives each pod a **stable, predictable name**: `postgres-0`, `postgres-1`, `postgres-2`
- Gives each pod its **own PVC**: `data-postgres-0`, `data-postgres-1`, `data-postgres-2`
- Starts and stops pods **in order** (not all at once)
- When a pod is replaced, the new pod gets the **same name and same PVC** as the old one

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 3
  serviceName: postgres          # headless service — each pod gets its own DNS
  template:
    spec:
      containers:
        - name: postgres
          image: postgres:15
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:          # each pod gets its own PVC automatically
    - metadata:
        name: data
      spec:
        storageClassName: managed-csi-premium   # Premium SSD for database IOPS
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 50Gi
```

This creates:
- `postgres-0` pod → `data-postgres-0` PVC → 50Gi Azure Premium Disk
- `postgres-1` pod → `data-postgres-1` PVC → 50Gi Azure Premium Disk
- `postgres-2` pod → `data-postgres-2` PVC → 50Gi Azure Premium Disk

If `postgres-1` crashes, Kubernetes creates a new `postgres-1` pod and mounts the existing `data-postgres-1` PVC — the new pod starts with all the data the old one had.

AzureShop uses **Azure SQL** instead of a PostgreSQL StatefulSet — the database is managed by Azure, not by Kubernetes. This is the recommended approach for production — managed cloud databases are simpler to operate than running a database inside Kubernetes.

---

### PVC Expansion — Growing a Volume

What if your Prometheus disk fills up and you need more space? Most StorageClasses support online volume expansion — you just edit the PVC and increase the size:

```bash
kubectl patch pvc prometheus-data -n monitoring \
  -p '{"spec":{"resources":{"requests":{"storage":"40Gi"}}}}'
```

The CSI driver expands the underlying Azure Disk from 20Gi to 40Gi. In most cases this happens without restarting the pod. The filesystem inside the pod automatically sees the extra space.

**You can only EXPAND, never shrink.** Kubernetes does not allow reducing a PVC's storage request — reducing a disk risks data corruption.

---

### Complete Picture — Volume Types in AzureShop

```
AzureShop Kubernetes Cluster
══════════════════════════════════════════════════════

  Application Services (user-service, product-service, etc.)
  ─────────────────────────────────────────────────────────
  Volume type: emptyDir
  Mount: /tmp
  Data: None — all state in Azure SQL (external)
  Survives pod restart: No (intentional — /tmp is scratch only)

  Monitoring Stack (namespace: monitoring)
  ─────────────────────────────────────────────────────────
  Prometheus pod
    └── PVC: 20Gi, managed-csi (Azure Disk, RWO)
        Mount: /prometheus
        Data: 15 days of scraped metrics from all 8 services
        Survives pod restart: YES

  Grafana pod
    └── PVC: 5Gi, managed-csi (Azure Disk, RWO)
        Mount: /var/lib/grafana
        Data: SQLite db, saved dashboards, user sessions
        Survives pod restart: YES

  Alertmanager pod
    └── PVC: 2Gi, managed-csi (Azure Disk, RWO)
        Mount: /alertmanager
        Data: silence config, deduplication log
        Survives pod restart: YES

  Azure (external to cluster)
  ─────────────────────────────────────────────────────────
  Azure SQL Database
    Data: all application data (users, products, orders, etc.)
    Managed by Azure — not a Kubernetes PV at all
```

---

### Common Mistakes With PVs and PVCs

**Mistake 1: Wrong access mode for multi-pod access**
```yaml
accessModes:
  - ReadWriteOnce    # only one NODE can mount this at a time
```
If you have 3 Prometheus replicas on 3 different nodes all trying to mount the same `ReadWriteOnce` PVC, 2 of them will fail. RWO means one node — if you need multiple pods to share storage, use Azure File (`ReadWriteMany`).

**Mistake 2: No storage class specified**
```yaml
spec:
  resources:
    requests:
      storage: 10Gi
  # no storageClassName!
```
Without `storageClassName`, Kubernetes uses the cluster's **default** StorageClass. In AKS this is `managed-csi`. This usually works but it is better to be explicit — specify the StorageClass so you know exactly what you get.

**Mistake 3: PVC in wrong namespace**
A PVC lives in a specific namespace. A pod in namespace `dev` cannot use a PVC from namespace `monitoring`. PVs are cluster-scoped (no namespace) but PVCs are namespace-scoped.

**Mistake 4: Deleting a PVC while the pod is running**
Kubernetes has a feature called **PVC Protection** — it prevents deletion of a PVC that is currently mounted by a running pod. The PVC enters `Terminating` state but the actual deletion is blocked until the pod is deleted. This prevents data loss from accidental PVC deletion.

**Mistake 5: Forgetting `ignore_changes` for PVCs in Terraform**
Similar to the Cluster Autoscaler's `node_count`, if Terraform manages a StatefulSet with PVCs, re-running `terraform apply` might try to recreate PVCs — which would destroy data. Always be careful about PVC lifecycle management in Terraform.

---

### Interview Prep

1. **What is a PersistentVolume in Kubernetes?** — A PersistentVolume is a piece of storage provisioned in the cluster that exists independently of any pod. It is a cluster-level resource backed by real durable storage — an Azure Disk, Azure File share, NFS mount, or other storage system. It has a capacity, access mode, and reclaim policy. A PV outlives the pod that used it — when the pod is deleted, the PV and its data survive. Pods never use a PV directly; they use a PVC to claim it.

2. **What is a PersistentVolumeClaim and how does it relate to a PV?** — A PVC is a request for storage from a pod. The pod says "I need 20Gi, ReadWriteOnce, of type managed-csi." Kubernetes finds a PV that satisfies those requirements and binds them together — the PV is exclusively reserved for that PVC. The pod mounts the PVC, not the PV directly. The relationship: PV = the actual storage that exists. PVC = the reservation/claim on that storage. Pod uses the PVC. This separation means you can change the underlying storage without changing the pod spec.

3. **What is dynamic provisioning and how does it work?** — Dynamic provisioning means Kubernetes automatically creates the storage when a PVC is created — you never manually create PV objects. You specify a `storageClassName` in the PVC. Kubernetes calls the corresponding CSI driver (e.g., Azure Disk CSI driver for `managed-csi`). The driver creates the actual Azure Disk in your Azure subscription, creates a PV object representing it, and binds the PVC to the PV. The whole process takes seconds. Without dynamic provisioning, an admin would have to manually create a disk and a PV object for every PVC — not scalable.

4. **What is a StorageClass?** — A StorageClass is the template Kubernetes uses to dynamically create storage. It defines which CSI driver to use (provisioner), what parameters to pass (disk type, replication, encryption), the reclaim policy (Delete or Retain), and the volume binding mode (Immediate or WaitForFirstConsumer). In AKS, `managed-csi` uses the Azure Disk CSI driver with Standard SSD and Delete reclaim policy. When a PVC references `managed-csi`, a Standard SSD Azure Disk is automatically created.

5. **What is the difference between ReadWriteOnce and ReadWriteMany?** — ReadWriteOnce (RWO) means the volume can be mounted read-write by only ONE node at a time. Azure Disks support only RWO — this is a physical limitation of block storage. ReadWriteMany (RWX) means the volume can be mounted read-write by MANY nodes simultaneously. Azure File shares support RWX — they are network shares accessed over SMB/NFS. Use Azure Disk (RWO) for databases and single-writer workloads where you need maximum performance. Use Azure File (RWX) when multiple pods across multiple nodes need shared access to the same files.

6. **What is the difference between emptyDir and a PersistentVolumeClaim?** — An `emptyDir` is a temporary directory created fresh for each pod on the node's local disk. It survives container restarts within the same pod but is **deleted when the pod is deleted**. It stores nothing permanently. A PVC is backed by real durable storage (an Azure Disk) that survives pod deletion, node failure, and AKS upgrades. In AzureShop, application services use `emptyDir` for `/tmp` (scratch space — no value in persisting) while Prometheus uses a PVC (metrics history must survive restarts). The rule: use emptyDir for truly throwaway data, use PVC for anything that must survive a pod restart.

7. **Why do AzureShop's application services (user-service, etc.) use emptyDir instead of PVCs?** — Because application services are stateless — all durable state (user records, orders, products) is stored in Azure SQL, which is external to Kubernetes. The `/tmp` directory used by Node.js is purely for temporary processing — files that are meaningless after the request completes. Using a PVC for `/tmp` would cost money, add zone-pinning constraints (the pod must always run on a node in the same zone as its Azure Disk), and provide zero benefit since the data is intentionally throwaway. Only stateful workloads need PVCs.

8. **What is a StatefulSet and when do you use it with PVCs?** — A StatefulSet is a Kubernetes controller for stateful applications that need stable identity and dedicated storage. Unlike Deployments (where pods are interchangeable), StatefulSet pods have predictable names (`postgres-0`, `postgres-1`) and each get their own PVC via `volumeClaimTemplates`. When a StatefulSet pod is replaced, the new pod gets the same name and mounts the same PVC — preserving all its data. Use StatefulSet when running databases or other stateful apps inside Kubernetes. AzureShop uses Azure SQL instead of a Kubernetes StatefulSet for its database — managed cloud databases are simpler and more reliable than managing a database StatefulSet yourself.

---

## Q29. What is Kubernetes Ingress? How Does it Work, and How is it Used in AzureShop?

### The Problem Ingress Solves

Before Ingress existed, there were two ways to expose a Kubernetes service to the outside world:

**Option 1 — NodePort:** Expose the service on a port of every node (e.g., port 30001). The caller hits `node-ip:30001`. Problems: you must know node IPs, nodes are ephemeral, ports clash between services, and you must manage firewall rules per port.

**Option 2 — LoadBalancer Service:** Each service gets its own Azure Load Balancer with its own public IP address.

```
user-service    → Azure Load Balancer #1 → public IP: 20.1.1.1
product-service → Azure Load Balancer #2 → public IP: 20.1.1.2
cart-service    → Azure Load Balancer #3 → public IP: 20.1.1.3
order-service   → Azure Load Balancer #4 → public IP: 20.1.1.4
payment-service → Azure Load Balancer #5 → public IP: 20.1.1.5
frontend        → Azure Load Balancer #6 → public IP: 20.1.1.6
```

For AzureShop's 8 services this means **8 public IP addresses** and **8 Azure Load Balancers** — each load balancer costs money, and managing 8 separate IPs for one application is a nightmare.

**The Ingress solution:** One load balancer, one public IP, smart HTTP routing rules that send traffic to the right backend service based on the URL path or hostname.

```
Internet
    ↓
48.202.215.133  (ONE public IP — shared by all 8 services)
    ↓
NGINX Ingress Controller
    ↓ routes by URL path
/api/*  → api-gateway:8080  (which then routes to individual microservices)
/       → frontend:3000
```

---

### Two Separate Concepts: Ingress Resource vs Ingress Controller

This is the most important distinction to understand about Ingress. Many beginners confuse the two — they are completely different things.

#### Ingress Resource

An Ingress resource is a **Kubernetes object** — just a YAML file that defines routing rules. It says "requests to path `/api/` should go to service `api-gateway` on port `8080`." By itself, an Ingress resource does absolutely nothing. It is just configuration data stored in the Kubernetes API.

Think of it like a **restaurant menu**. The menu lists all the dishes. But the menu itself does not cook anything — you still need a kitchen (the controller) to actually make the food.

#### Ingress Controller

An Ingress Controller is the **actual software** that reads the Ingress resource and implements the routing rules. It is a running pod (or set of pods) in your cluster that:
1. Watches the Kubernetes API for Ingress resource changes
2. Translates those routing rules into its own config (e.g., NGINX config)
3. Receives real network traffic and routes it to the right backend services

Kubernetes does NOT ship with a built-in Ingress Controller. You must install one yourself. There are many options:

| Ingress Controller | Made by | Notes |
|---|---|---|
| **NGINX Ingress Controller** | Kubernetes community | Most popular, feature-rich, what AzureShop uses |
| **Azure Application Gateway Ingress Controller (AGIC)** | Microsoft | Native AKS integration, uses Azure App Gateway |
| **Traefik** | Traefik Labs | Cloud-native, auto-discovers services |
| **HAProxy Ingress** | HAProxy Technologies | High performance |
| **Istio Gateway** | Istio | Service mesh gateway |
| **Kong** | Kong Inc. | API Gateway features built in |

**In AzureShop:** NGINX Ingress Controller is installed in the `ingress-nginx` namespace. It is exposed via an Azure Load Balancer Service of type `LoadBalancer` which gets the external IP `48.202.215.133`.

---

### The Ingress Resource — Anatomy

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: azureshop-ingress
  namespace: dev
  annotations:                                    # ← controller-specific config
    kubernetes.io/ingress.class: "nginx"          # use the NGINX controller
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
spec:
  ingressClassName: nginx                         # modern way to select controller
  rules:
    - http:                                       # no "host:" = matches ALL hostnames
        paths:
          - path: /api/
            pathType: Prefix                      # /api/ matches /api/users, /api/products etc.
            backend:
              service:
                name: api-gateway
                port:
                  number: 8080

          - path: /
            pathType: Prefix                      # / matches everything else
            backend:
              service:
                name: frontend
                port:
                  number: 3000
```

**Key fields explained:**

**`annotations`** — Extra configuration passed to the specific Ingress Controller. NGINX Ingress has 50+ annotations for fine-grained control (rate limiting, auth, rewrites, timeouts, CORS, etc.). These are NOT standard Kubernetes — they are NGINX-specific.

**`ingressClassName`** — Tells Kubernetes which installed Ingress Controller should process this Ingress resource. You can have multiple controllers installed (e.g., NGINX for regular traffic, AGIC for a specific domain), and `ingressClassName` routes the Ingress to the right one.

**`spec.rules[].http.paths[].pathType`** — Three options:
- `Prefix` — matches the path and everything after it. `/api/` matches `/api/users/123`, `/api/products/`, etc.
- `Exact` — must match exactly. `/api/health` only matches `/api/health`, not `/api/health/`
- `ImplementationSpecific` — controller decides the matching behaviour

**`spec.rules[].host`** — If specified, the rule only applies when the HTTP `Host` header matches. Omitting `host` (as AzureShop does) means the rule applies to ALL hostnames hitting this controller.

---

### Path Matching — How NGINX Decides Where to Route

When a request arrives, NGINX evaluates paths **longest match first**:

```
Request: GET /api/products/123

Ingress rules:
  /api/   → api-gateway:8080   (length 5)
  /       → frontend:3000      (length 1)

Result: /api/ wins (longer match) → api-gateway:8080
```

```
Request: GET /dashboard

Ingress rules:
  /api/   → api-gateway:8080
  /       → frontend:3000

Result: /api/ does NOT match. / matches → frontend:3000
```

This is why AzureShop's Ingress has only TWO rules:
1. `/api/` — catches all API traffic and sends it to NGINX api-gateway
2. `/` — catches everything else (frontend pages, static assets, favicon, etc.)

The api-gateway then handles the second level of routing internally (its own `nginx.conf` splits `/api/users/` → user-service, `/api/products/` → product-service, etc.).

---

### TLS Termination — HTTPS with Ingress

A real production Ingress also handles HTTPS. You store a TLS certificate as a Kubernetes Secret and reference it in the Ingress:

```yaml
spec:
  tls:
    - hosts:
        - azureshop.example.com
      secretName: azureshop-tls-secret   # Secret containing cert + key
  rules:
    - host: azureshop.example.com
      http:
        paths:
          - path: /api/
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 8080
```

The Kubernetes Secret `azureshop-tls-secret` contains:
```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
data:
  tls.crt: <base64 encoded certificate>
  tls.key: <base64 encoded private key>
```

When a client connects via HTTPS, NGINX terminates the TLS (decrypts it), then forwards plain HTTP internally to the backend services. This is called **SSL termination at the ingress** — your backend services never see TLS, keeping them simpler.

For AzureShop, TLS termination actually happens at the **Azure Application Gateway** (one layer before NGINX), not at the NGINX Ingress. The chain is:

```
Browser (HTTPS) → Azure Application Gateway (TLS termination) → NGINX Ingress (HTTP) → Services
```

---

### How the NGINX Ingress Controller Works Internally

When you `kubectl apply -f k8s/ingress/dev-ingress.yaml`, here is exactly what happens:

```
Step 1: kubectl sends the Ingress object to the Kubernetes API Server.
        It is stored in etcd. At this point nothing has changed in the network.

Step 2: The NGINX Ingress Controller (running as a pod in ingress-nginx namespace)
        is watching the Kubernetes API for Ingress resource changes.
        It detects the new Ingress object immediately.

Step 3: The controller reads the Ingress rules and translates them into an
        NGINX configuration file (nginx.conf) inside the NGINX process:

        server {
          listen 80;
          location /api/ {
            proxy_pass http://dev-api-gateway-8080;
          }
          location / {
            proxy_pass http://dev-frontend-3000;
          }
        }

Step 4: The controller does a hot reload of NGINX config — no downtime.
        NGINX starts routing traffic according to the new rules.

Step 5: Real traffic arrives at the NGINX pod's external IP (48.202.215.133).
        NGINX reads the path, looks up the right upstream (api-gateway or frontend),
        and proxies the request to the correct ClusterIP Service.

Step 6: If you later change the Ingress (add a new path, change a backend),
        the controller detects the change and regenerates nginx.conf automatically.
        No manual NGINX restart needed.
```

The NGINX Ingress Controller is a long-running reconciliation loop — it watches Ingress objects and keeps NGINX config in sync with what the objects say. This is the same pattern as every other Kubernetes controller.

---

### Hostname-Based Routing — Multiple Sites, One IP

In addition to path-based routing, Ingress also supports hostname-based routing — different domains go to different backends:

```yaml
spec:
  rules:
    - host: shop.example.com           # hostname-based rule
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 3000

    - host: admin.example.com          # different host, different backend
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin-frontend
                port:
                  number: 3001

    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 8080
```

All three hostnames share the same single public IP. NGINX reads the HTTP `Host` header on each request and routes accordingly. This is the same concept as virtual hosting in classic web servers — one IP, many websites.

---

### Canary Deployments with NGINX Ingress — Exact AzureShop Implementation

One of the most powerful NGINX Ingress features is native canary deployment support. AzureShop has a ready-to-use example:

File: `k8s/ingress/canary-example.yaml`

```yaml
# STABLE ingress — 80% of traffic
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
                name: user-service          # current production version
                port:
                  number: 3001
---
# CANARY ingress — 20% of traffic (new version being tested)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: user-service-canary
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"      # marks this as canary
    nginx.ingress.kubernetes.io/canary-weight: "20" # 20% of traffic goes here
spec:
  rules:
    - http:
        paths:
          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: user-service-canary   # new version being tested
                port:
                  number: 3001
```

How this works:
- NGINX sees two Ingress objects for the same path `/api/users`
- One is marked as `canary: "true"` with `canary-weight: "20"`
- NGINX randomly sends **20% of requests to user-service-canary** and **80% to user-service**
- No load balancer config needed — NGINX handles the split internally

Other canary strategies available:

```yaml
# Route by HTTP header — specific users get the canary
nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
nginx.ingress.kubernetes.io/canary-by-header-value: "always"
# Requests with header "X-Canary: always" → canary

# Route by cookie — users with a cookie get the canary
nginx.ingress.kubernetes.io/canary-by-cookie: "canary_user"
# Requests with cookie "canary_user=always" → canary
```

To promote canary to production: increase weight to 100, update the stable deployment's image tag, then remove the canary Ingress. To rollback: delete the canary Ingress — all traffic instantly falls back to stable.

---

### The Full AzureShop Traffic Flow — End to End

Here is the complete path a request takes from a browser to user-service, with every hop labelled:

```
BROWSER
  │
  │  HTTPS  GET https://azureshop.example.com/api/users/profile
  │
  ↓
AZURE APPLICATION GATEWAY (Layer 7 load balancer + WAF)
  ├── Public IP: 48.202.215.133
  ├── WAF inspection: OWASP 3.2 rules check for SQL injection, XSS, etc.
  ├── TLS termination: decrypts HTTPS → forwards as HTTP internally
  └── Backend pool: forwards to NGINX Ingress Controller IP
  │
  │  HTTP  GET /api/users/profile
  │
  ↓
NGINX INGRESS CONTROLLER (pod in ingress-nginx namespace)
  ├── Receives request on port 80 (from App Gateway)
  ├── Reads: path = /api/users/profile
  ├── Matches Ingress rule: /api/ → api-gateway:8080
  └── Proxies to ClusterIP of api-gateway Service
  │
  │  HTTP  GET /api/users/profile
  │
  ↓
API-GATEWAY (NGINX pod in dev namespace)
  ├── api-gateway is itself an NGINX container with its own nginx.conf
  ├── Reads: path = /api/users/profile
  ├── Matches: location /api/users/ → upstream user_service
  └── Strips /api/users prefix → proxies to user-service:3001 with path /users/profile
  │
  │  HTTP  GET /users/profile
  │
  ↓
USER-SERVICE (Node.js pod in dev namespace)
  ├── Handles the request
  ├── Queries Azure SQL Database
  └── Returns JSON response
  │
  │  200 OK  {"id": 123, "name": "Anshu", ...}
  │
  ↑ (response travels back through the same chain in reverse)
```

**Why two layers of NGINX?**
- **App Gateway** (Azure-managed): handles internet-facing concerns — WAF protection, TLS termination, DDoS protection, Azure integration
- **NGINX Ingress** (Kubernetes-managed): handles Kubernetes routing concerns — path-based routing to services, canary deployments, rate limiting, Kubernetes-native
- **api-gateway NGINX** (your own): handles microservice routing — strips path prefixes, adds headers, per-service rate limits, auth route handling

Each layer has a clear, separate responsibility.

---

### File Locations in AzureShop

```
AzureShop/
  k8s/
    ingress/
      dev-ingress.yaml          ← the Ingress resource (routing rules)
      canary-example.yaml       ← canary deployment pattern with comments
    ingress-nginx-values.yaml   ← NGINX Ingress Controller Helm values
                                   (2 replicas, anti-affinity, resource limits, metrics)

  infra/
    modules/
      appgateway/
        main.tf                 ← Azure Application Gateway (WAF v2, TLS, backend pool)
        variables.tf            ← AppGW config variables

  helm/
    charts/
      <service>/
        templates/
          networkpolicy.yaml    ← allows ingress traffic from ingress-nginx namespace
                                   allows inter-service traffic within same namespace

  services/
    api-gateway/
      nginx.conf                ← api-gateway's own NGINX config (second routing layer)
                                   routes /api/users/ → user-service:3001, etc.
```

The NGINX Ingress Controller itself is NOT in the repo as YAML — it was installed via Helm:
```bash
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f k8s/ingress-nginx-values.yaml
```

Only the **values file** (`k8s/ingress-nginx-values.yaml`) is in the repo — the actual controller runs inside the cluster, managed by Helm.

---

### NGINX Ingress Controller Configuration — AzureShop Values

File: `k8s/ingress-nginx-values.yaml`

```yaml
controller:
  replicaCount: 2              # two NGINX pods — High Availability

  service:
    annotations:
      # Azure Load Balancer health check path
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz

  resources:
    requests:
      cpu: 100m
      memory: 90Mi
    limits:
      cpu: 500m
      memory: 256Mi

  podAntiAffinity:             # spread the 2 NGINX pods across different nodes
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
          topologyKey: kubernetes.io/hostname   # "prefer different hostnames = different nodes"

  metrics:
    enabled: true              # expose Prometheus metrics from NGINX

defaultBackend:
  enabled: true                # returns 404 for requests that match no Ingress rule
```

**`replicaCount: 2`** — Two NGINX pods means if one crashes or its node goes down, the other still routes traffic. Both pods are behind the Azure Load Balancer, so traffic spreads between them.

**`podAntiAffinity`** — Tells the Kubernetes scheduler to prefer placing the two NGINX pods on **different nodes**. If both landed on the same node and that node went down, you would lose all ingress traffic. Anti-affinity ensures they spread across nodes.

**`defaultBackend`** — A simple pod that returns HTTP 404 (and optionally a custom error page) for any request that does not match any Ingress rule. Without it, NGINX returns a generic "No backend" error.

---

### NetworkPolicy — How Ingress Traffic is Allowed Into Services

Because AzureShop uses zero-trust NetworkPolicy (`policyTypes: Ingress`), all incoming traffic to each service pod is blocked by default. The NetworkPolicy on each service explicitly allows traffic from the NGINX Ingress Controller's namespace:

File: `helm/charts/user-service/templates/networkpolicy.yaml`

```yaml
ingress:
  # Allow inbound traffic from the NGINX ingress controller
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx   # ← ingress-nginx namespace

  # Allow inbound traffic from other pods in the same namespace
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: dev             # ← same namespace (api-gateway → user-service)
```

Without the first rule, the NGINX pod (in `ingress-nginx` namespace) would not be able to reach user-service pods (in `dev` namespace) — the NetworkPolicy would drop the packets silently. This is why the namespace label `kubernetes.io/metadata.name: ingress-nginx` must match the actual namespace name of your NGINX controller.

---

### Ingress vs Service LoadBalancer — Quick Comparison

| | Service type=LoadBalancer | Kubernetes Ingress |
|---|---|---|
| **What it is** | One Azure LB per Service | One Azure LB for all Services |
| **Public IPs** | One per service | One shared for all |
| **Routing** | No routing — all traffic to one service | Path/host-based routing to multiple services |
| **HTTP features** | None | TLS termination, rewrites, rate limiting, canary |
| **Cost** | High (8 LBs for 8 services) | Low (1 LB for everything) |
| **Use case** | Non-HTTP protocols (TCP/UDP), single service | HTTP/HTTPS routing to multiple services |
| **AzureShop** | Used only for NGINX Ingress Controller itself | Used for all 8 services |

The one service that uses `type: LoadBalancer` in AzureShop is the NGINX Ingress Controller itself — it needs a real public IP to receive traffic from the internet. All application services use `type: ClusterIP` and are reached through the Ingress.

---

### Interview Prep

1. **What is a Kubernetes Ingress?** — An Ingress is a Kubernetes API object that defines HTTP routing rules — which URL paths or hostnames should route to which Services. By itself it does nothing; it is just config stored in Kubernetes. An Ingress Controller (like NGINX) reads these rules and implements them, proxying real traffic to the right backends. The key benefit: one shared public IP and one load balancer for all services instead of one per service.

2. **What is the difference between an Ingress resource and an Ingress Controller?** — The Ingress resource is a YAML object — it declares routing rules (path /api/ goes to api-gateway). It is passive config. The Ingress Controller is the actual running software (a pod) that reads Ingress resources and implements them by configuring NGINX, HAProxy, or another proxy to handle real traffic. Kubernetes ships with no built-in Ingress Controller — you must install one. In AzureShop, the NGINX Ingress Controller is installed in the `ingress-nginx` namespace via Helm.

3. **What is the difference between Ingress and a Service of type LoadBalancer?** — A Service of type LoadBalancer creates one Azure Load Balancer per service with its own public IP — 8 services means 8 IPs and 8 load balancers (expensive, hard to manage). An Ingress uses ONE load balancer with ONE IP and routes all traffic to the right service based on URL path or hostname. Additionally, Ingress supports HTTP-level features: TLS termination, path rewrites, rate limiting, canary deployments. LoadBalancer Services are for non-HTTP protocols or when you need a service directly internet-accessible.

4. **How does AzureShop route traffic from the internet to user-service?** — Browser sends HTTPS to the Azure Application Gateway (WAF_v2), which inspects traffic with OWASP rules, terminates TLS, and forwards HTTP to the NGINX Ingress Controller's external IP. NGINX reads the path `/api/users/profile`, matches the Ingress rule `/api/ → api-gateway:8080`, and proxies to the api-gateway ClusterIP. The api-gateway is itself an NGINX container — it reads its own `nginx.conf`, matches `location /api/users/` → upstream user-service, strips the prefix, and proxies to user-service:3001. Three routing layers, each with a different responsibility.

5. **What are annotations in an Ingress resource and why are they important?** — Annotations are key-value pairs in the Ingress metadata that pass controller-specific configuration. They are not standard Kubernetes — they are instructions specific to your chosen controller. NGINX Ingress has 50+ annotations: `nginx.ingress.kubernetes.io/proxy-read-timeout` sets backend timeout, `nginx.ingress.kubernetes.io/canary: "true"` enables canary routing, `nginx.ingress.kubernetes.io/use-regex: "true"` enables regex path matching. Without annotations you only get basic routing. With annotations you get full control over proxying, auth, rate limiting, CORS, rewrites, and more.

6. **How does the canary deployment work with NGINX Ingress in AzureShop?** — Two Ingress objects define the same path `/api/users`. The stable Ingress routes to `user-service` (production version). The canary Ingress has the annotation `canary: "true"` and `canary-weight: "20"`, routing to `user-service-canary` (new version). NGINX randomly splits traffic: 80% to stable, 20% to canary. No changes to application code or the Service. To promote: increase canary-weight to 100 then update stable. To rollback: delete the canary Ingress — all traffic instantly returns to stable. Alternative strategies: route by header (`X-Canary: always`) or by cookie for targeted testing.

7. **Why does AzureShop use two layers of NGINX — the NGINX Ingress Controller and the api-gateway?** — They serve different purposes at different layers. The NGINX Ingress Controller handles Kubernetes-level routing: receives traffic from the internet, routes `/api/*` to api-gateway and `/` to frontend, handles canary deployments and TLS. The api-gateway is an application-level router: it receives all API traffic and further routes `/api/users/` to user-service, `/api/products/` to product-service, etc., while also applying per-service rate limits and auth handling. Separating them keeps each layer simple and independently configurable.

8. **How does NetworkPolicy interact with Ingress in AzureShop?** — AzureShop uses zero-trust NetworkPolicy — by default all pod-to-pod traffic is blocked. The NetworkPolicy on each service pod has an `ingress.from` rule that explicitly allows traffic from the `ingress-nginx` namespace (where the NGINX controller pods run) and from the `dev` namespace (for service-to-service calls). Without this rule, even if the Ingress correctly routes a request to user-service, the NetworkPolicy would drop the packet silently at the pod level and the request would fail. Ingress and NetworkPolicy work together: Ingress handles L7 routing, NetworkPolicy handles L3/L4 enforcement.

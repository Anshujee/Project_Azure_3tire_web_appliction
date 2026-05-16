# Phase 6 — AKS Kubernetes: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Pod vs Deployment vs Service, liveness vs readiness probes, namespaces, PodDisruptionBudget, Azure CNI vs Kubenet, kubelogin, Key Vault CSI Driver, kubelet identity vs CSI addon identity, system vs user node pools, Helm vs kubectl apply, HPA, NetworkPolicy zero trust, Kubernetes Secret vs SecretProviderClass, Workload Identity.

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

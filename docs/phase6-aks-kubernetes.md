# Phase 6 — AKS Kubernetes Deployment
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In this phase we took the 8 Docker images we built in Phase 4 and deployed them onto a real Kubernetes cluster running in Azure (AKS). We set up secure secret injection from Azure Key Vault, wrote Helm charts for every microservice, and put in place high-availability and security configurations so the cluster is production-ready.

By the end of this phase you will understand: what Kubernetes is and why we use it, how AKS works inside Azure, how secrets flow from Key Vault into running containers, and how Helm makes Kubernetes deployments repeatable and maintainable.

---

## Table of Contents

1. [What is Kubernetes and Why Do We Need It?](#1-what-is-kubernetes-and-why-do-we-need-it)
2. [AKS — Azure Kubernetes Service](#2-aks--azure-kubernetes-service)
3. [Core Kubernetes Objects](#3-core-kubernetes-objects)
4. [Networking — Azure CNI vs Kubenet](#4-networking--azure-cni-vs-kubenet)
5. [Azure AD Integration and kubelogin](#5-azure-ad-integration-and-kubelogin)
6. [AKS Node Pools — System vs User](#6-aks-node-pools--system-vs-user)
7. [Namespaces — Logical Separation](#7-namespaces--logical-separation)
8. [NGINX Ingress Controller](#8-nginx-ingress-controller)
9. [Azure Key Vault CSI Driver — Step 6.2](#9-azure-key-vault-csi-driver--step-62)
10. [SecretProviderClass — How Secrets Flow](#10-secretproviderclass--how-secrets-flow)
11. [Helm — The Package Manager for Kubernetes](#11-helm--the-package-manager-for-kubernetes)
12. [Helm Chart Structure We Built](#12-helm-chart-structure-we-built)
13. [Each Helm Template Explained](#13-each-helm-template-explained)
14. [Deployment Security Hardening](#14-deployment-security-hardening)
15. [High Availability Patterns](#15-high-availability-patterns)
16. [Network Policies — Zero Trust Networking](#16-network-policies--zero-trust-networking)
17. [The ARM64 vs AMD64 Problem](#17-the-arm64-vs-amd64-problem)
18. [Terraform Changes Made in Phase 6](#18-terraform-changes-made-in-phase-6)
19. [Environment-Based Values — Dev / Staging / Prod](#19-environment-based-values--dev--staging--prod)
20. [Commands Reference](#20-commands-reference)
21. [Full Step-by-Step Summary](#21-full-step-by-step-summary)
22. [Interview Questions and Answers](#22-interview-questions-and-answers)
23. [Workload Identity — OIDC and Federated Credentials](#23-workload-identity--oidc-and-federated-credentials)
24. [Real Implementation Issues Encountered](#24-real-implementation-issues-encountered)
25. [Additional Interview Questions — Steps 6.5 to 6.8](#25-additional-interview-questions--steps-65-to-68)

---

## 1. What is Kubernetes and Why Do We Need It?

### The Problem Without Kubernetes

Imagine you have 8 microservices. You deployed them on virtual machines. Everything is running. Now:

- Traffic spikes — one service needs 5 copies instead of 1. You manually create VMs.
- A node crashes — the service on it is dead until someone notices.
- You want to deploy a new version of user-service — you manually SSH in and restart it, causing downtime.
- You run out of memory on one VM but another VM is 80% idle — you cannot move containers between them.

This is the problem Kubernetes solves.

### What Kubernetes Does

Kubernetes (K8s) is a **container orchestrator**. Think of it as an operating system for your entire data centre. You tell Kubernetes "I want 3 copies of user-service running at all times" and Kubernetes:

- Decides which physical machines to run them on.
- Restarts them if they crash.
- Replaces them if the machine fails.
- Scales them up when traffic is high, down when it is quiet.
- Rolls out new versions with zero downtime.
- Routes network traffic to only the healthy copies.

```
You (developer)
     ↓  "Run 3 user-service pods"
Kubernetes Control Plane
     ↓  Schedules onto nodes
Node 1: user-service pod
Node 2: user-service pod
Node 3: user-service pod
     ↓  One crashes
Kubernetes notices → starts replacement on Node 1
```

### Why We Need It for AzureShop

Our app has 8 services. Each one needs:
- Multiple replicas for availability (if one pod dies, others keep serving)
- Auto-scaling when load goes up
- Zero-downtime deployments (rolling updates)
- Secrets (database passwords) injected securely — not baked into images
- Traffic routing (the frontend talks to api-gateway, not directly to all 8 services)
- Network isolation (the cart-service should not be able to call the payment-service directly)

Kubernetes handles all of this declaratively — you write YAML files describing the desired state, and Kubernetes makes it happen and keeps it that way.

---

## 2. AKS — Azure Kubernetes Service

### What AKS Is

AKS is Microsoft's **managed Kubernetes service**. Instead of installing and managing the Kubernetes control plane yourself (which is a full-time job), Azure manages it for you.

```
Without AKS (self-managed):
  You manage: etcd, API server, scheduler, controller manager, certificates, upgrades, backups
  You manage: worker nodes, network, load balancers, storage

With AKS:
  Azure manages: control plane (you never see it, it is free)
  You manage: worker nodes (you pay for the VMs)
  Azure helps with: node upgrades, node health, monitoring, scaling
```

### What We Built in AKS

```
AKS Cluster: aks-azureshop-dev
├── Control Plane (managed by Azure, free)
│   ├── API Server — receives kubectl commands
│   ├── etcd — stores all cluster state
│   ├── Scheduler — decides which node runs each pod
│   └── Controller Manager — ensures desired state = actual state
│
└── Node Pools (VMs you pay for)
    ├── System Pool: "system" — runs Kubernetes system components
    │   └── Standard_D2s_v3 nodes (2 CPU, 8 GB RAM)
    └── User Pool: "user" — runs your application workloads
        └── Standard_D2s_v3 nodes, autoscaling 1–5 nodes
```

### Why Separate System and User Pools?

The system pool runs critical Kubernetes components like CoreDNS (the cluster's DNS server) and the metrics server. If your application pods consume all memory and the node runs out, CoreDNS would crash and the entire cluster stops working.

By putting system components on a dedicated pool with `only_critical_addons_enabled = true`, your application pods cannot schedule there. Your app pods go to the user pool, and your system components are always safe.

---

## 3. Core Kubernetes Objects

These are the building blocks you need to understand before anything else makes sense.

### Pod

The smallest unit in Kubernetes. A pod runs one or more containers that share a network namespace and storage. Think of it as a wrapper around your Docker container.

```
Pod: user-service-7f8b9-xxx
  Container: user-service (your Docker image)
  IP: 10.240.0.15  ← real VNet IP with Azure CNI
  Volume: /mnt/secrets-store  ← Key Vault secrets
```

**Important:** You almost never create pods directly. You create a Deployment which manages pods for you.

### Deployment

A Deployment tells Kubernetes "I want N replicas of this pod running at all times, using this image." The Deployment controller continuously watches and reconciles.

```yaml
replicas: 3  # I want 3 pods
template:    # Each pod should look like this:
  image: acrazureshopdev.azurecr.io/user-service:v1.0.0
```

When you update the image tag, the Deployment does a rolling update — starts new pods, waits for them to be healthy, then removes old pods. Zero downtime.

### Service

A Service gives a stable network address to a set of pods. Pods come and go (they have random IPs), but the Service always has the same DNS name and IP.

```
user-service Service (ClusterIP: 10.100.50.25)
   ↓ load balances to
Pod 1: 10.240.0.15
Pod 2: 10.240.0.16
Pod 3: 10.240.0.17
```

Other services talk to `user-service:3001` — they never care which pod they hit.

### Namespace

A namespace is a virtual cluster inside the real cluster. It lets you run dev, staging, and prod on the same cluster with isolation. Resources in different namespaces cannot see each other unless you explicitly allow it.

```
Cluster
├── Namespace: dev       ← our dev environment
├── Namespace: staging   ← our staging environment
├── Namespace: prod      ← our production environment
├── Namespace: ingress-nginx  ← NGINX ingress controller
└── Namespace: kube-system    ← Kubernetes system components
```

### ConfigMap

A ConfigMap stores non-sensitive configuration as key-value pairs. We use it for things like the app's port number or environment name. It is not encrypted — never store passwords here.

### Secret

A Kubernetes Secret stores sensitive data. It is base64-encoded (not encrypted by default, but can be encrypted at rest). In our project, the Key Vault CSI Driver creates Secrets automatically — we never create them manually.

---

## 4. Networking — Azure CNI vs Kubenet

This is one of the most important architectural decisions in AKS.

### Kubenet (the simple way — we did NOT use this)

```
VNet Subnet: 10.240.0.0/16
  Node 1 IP: 10.240.0.4
    Pod A: 172.16.0.1  ← private address, different network
    Pod B: 172.16.0.2  ← private address, different network

Pods use NAT to reach the internet or Azure services.
Azure does not know pods exist at the VNet level.
```

The problem: Azure services like Azure SQL cannot directly target pod IPs. NSGs cannot filter individual pods. Network troubleshooting is harder.

### Azure CNI (what we built)

```
VNet Subnet: 10.240.0.0/16
  Node 1 IP: 10.240.0.4
    Pod A: 10.240.0.20  ← real VNet IP, same network
    Pod B: 10.240.0.21  ← real VNet IP, same network
  Node 2 IP: 10.240.0.5
    Pod C: 10.240.0.22  ← real VNet IP, same network
```

Every pod gets a real IP address from your VNet subnet. This means:

- Azure SQL can have firewall rules targeting pod IPs directly.
- NSGs can apply to individual pods.
- Network troubleshooting uses standard networking tools.
- Azure services see pod traffic as coming from VNet IPs — no NAT.

**The catch:** Each pod consumes one VNet IP. If you have 100 pods, you need 100 IPs in your subnet plus IPs for nodes. This is why our Terraform used a `/16` subnet (65,534 usable IPs) for the AKS subnet — we need enough address space.

### In Our Terraform

```hcl
network_profile {
  network_plugin = "azure"      # Azure CNI
  network_policy = "azure"      # Enables NetworkPolicy enforcement
  load_balancer_sku = "standard"
  outbound_type = "loadBalancer"
}
```

`network_policy = "azure"` is separate from the network plugin. It tells AKS to enforce Kubernetes NetworkPolicy objects — without this, NetworkPolicy YAML files have no effect.

---

## 5. Azure AD Integration and kubelogin

### The Problem

Standard Kubernetes uses its own user management (certificates or static tokens). In enterprise Azure environments, you want to control kubectl access using the same identity system as the rest of Azure — Microsoft Entra ID (formerly Azure Active Directory).

### How AKS Azure AD Integration Works

```
You run: kubectl get pods
              ↓
kubectl sends request to AKS API server
              ↓
AKS asks: "Who are you?" (challenges for a token)
              ↓
kubelogin fetches a token from Azure CLI / Entra ID
              ↓
AKS validates the token with Entra ID
              ↓
AKS checks Azure RBAC: does this user have permission?
              ↓
If yes → returns pod list
If no  → "forbidden"
```

### What is kubelogin?

`kubectl` does not know how to fetch Azure AD tokens by itself. `kubelogin` is a plugin that handles this. When you run `kubelogin convert-kubeconfig -l azurecli`, it rewrites the kubeconfig file to use kubelogin as the authentication helper. Now every kubectl command automatically fetches a fresh Azure AD token.

```bash
# Step 1: Get cluster credentials (writes kubeconfig)
az aks get-credentials --resource-group rg-azureshop-dev --name aks-azureshop-dev

# Step 2: Convert to use Azure CLI tokens (required for Azure AD RBAC)
kubelogin convert-kubeconfig -l azurecli

# Now kubectl works, using your az login identity
kubectl get nodes
```

### Azure RBAC for AKS

Once Entra integration is on, permissions are controlled through Azure RBAC roles — the same `az role assignment create` command used for storage and Key Vault.

Key roles:
- `Azure Kubernetes Service RBAC Cluster Admin` — full access to everything in the cluster
- `Azure Kubernetes Service RBAC Admin` — full access within a namespace
- `Azure Kubernetes Service RBAC Reader` — read-only view of cluster resources

We assigned `Azure Kubernetes Service RBAC Cluster Admin` to our user object ID on the AKS cluster scope so we could run kubectl commands.

```bash
az role assignment create \
  --assignee <user-object-id> \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope /subscriptions/<sub>/resourceGroups/rg-azureshop-dev/providers/Microsoft.ContainerService/managedClusters/aks-azureshop-dev
```

---

## 6. AKS Node Pools — System vs User

### System Pool

```hcl
default_node_pool {
  name = "system"
  only_critical_addons_enabled = true  # ← only system pods here
  vm_size = "Standard_D2s_v3"
  node_count = 1
}
```

This pool runs CoreDNS, the metrics server, the CSI driver, and other Kubernetes internals. Application pods are automatically tainted off this pool.

### User Pool

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name = "user"
  mode = "User"
  auto_scaling_enabled = true
  min_count = 1
  max_count = 5
  lifecycle {
    ignore_changes = [node_count]  # ← do not override autoscaler's decisions
  }
}
```

All 8 of our microservice pods run here. The autoscaler watches for pods stuck in `Pending` state (waiting for resources) and adds nodes, then removes nodes when they become idle.

The `ignore_changes = [node_count]` lifecycle block is critical: without it, every `terraform apply` would reset the node count to the value in your tfvars file, overwriting what the autoscaler has set.

---

## 7. Namespaces — Logical Separation

We created four namespaces:

```
dev       → runs all 8 services for the dev environment
staging   → runs all 8 services for staging
prod      → runs all 8 services for production
monitoring → will run Prometheus and Grafana in Phase 7
```

Each namespace has independent:
- Helm releases (same chart, different release)
- Secrets (SecretProviderClasses are namespace-scoped)
- Network policies
- RBAC permissions

This means the dev deployment of user-service and the prod deployment of user-service are completely isolated, even though they run on the same cluster.

```bash
kubectl apply -f k8s/namespaces/dev.yaml
kubectl apply -f k8s/namespaces/staging.yaml
kubectl apply -f k8s/namespaces/prod.yaml
kubectl apply -f k8s/namespaces/monitoring.yaml
```

---

## 8. NGINX Ingress Controller

### The Problem — Too Many Load Balancers

Without an ingress controller, each Service of type `LoadBalancer` gets its own Azure Load Balancer, which means its own public IP and costs money. With 8 services, you would have 8 separate IPs.

### The Solution — One Ingress, One IP

An ingress controller is a single load balancer that sits in front of all services and routes traffic based on HTTP rules (host name or URL path).

```
Internet
    ↓
48.202.215.133 (single public IP — our NGINX ingress)
    ↓ routes by path or hostname
/api/users    → user-service:3001
/api/products → product-service:3002
/api/cart     → cart-service:3003
/             → frontend:3000
```

### What We Installed

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f k8s/ingress-nginx-values.yaml
```

Our `ingress-nginx-values.yaml` configures:
- 2 replicas for high availability
- Pod anti-affinity (the 2 NGINX pods spread across 2 different nodes)
- Resource limits so NGINX does not starve other pods
- Prometheus metrics enabled (ready for Phase 7)
- Health probe path for the Azure Load Balancer health check

The result: a single Azure Load Balancer with external IP `48.202.215.133` that all 8 services share.

---

## 9. Azure Key Vault CSI Driver — Step 6.2

### The Secret Management Problem

Your user-service needs a database password. Where do you put it?

**Bad approach 1:** Hardcode it in your source code.
- It ends up in git. Anyone who can read the repo can read your password. Catastrophic.

**Bad approach 2:** Put it in a Kubernetes Secret manually.
- Kubernetes Secrets are only base64-encoded, not encrypted. Anyone with kubectl access can decode them.
- Secrets are not rotated automatically.
- You have to manually update secrets across dev/staging/prod.

**Good approach — Azure Key Vault CSI Driver:**
- Passwords live in Azure Key Vault (encrypted, audited, RBAC-controlled).
- The CSI driver runs on every AKS node as a DaemonSet.
- When a pod starts, the CSI driver authenticates to Key Vault, fetches the secrets, and mounts them into the pod as files. It can also create a Kubernetes Secret from them so they are available as environment variables.
- The pod application code reads `process.env.SQL_PASSWORD` — it never talks to Key Vault directly.

### How the Authentication Works

The CSI driver needs permission to read from Key Vault. It uses a **Managed Identity** — a special type of identity that Azure assigns to the AKS addon automatically (no username/password, no certificate to manage, no rotation needed).

```
AKS cluster
  └── Key Vault Secrets Provider addon
        └── Addon Managed Identity (Client ID: 4e3f0c0a-...)
              └── has role: "Key Vault Secrets User" on kv-azureshop-6a6c-dev
                    └── can read secrets: sql-server-fqdn, sql-admin-password, etc.
```

There are TWO identities on an AKS cluster. This confused us during setup:

1. **Kubelet Identity** — used by nodes to pull images from ACR and access other Azure services on behalf of the node.
2. **CSI Addon Managed Identity** — specifically used by the Key Vault Secrets Provider addon to read secrets.

Terraform initially only assigned the Key Vault role to the kubelet identity. The CSI driver uses the addon identity, so it was getting permission denied. We had to assign the role to the correct identity:

```bash
# Object ID of the CSI addon managed identity (NOT the kubelet identity)
az role assignment create \
  --assignee bbb780af-a62e-40a8-bd43-0c3df58a9667 \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/.../vaults/kv-azureshop-6a6c-dev
```

And we codified this in Terraform so future applies set it automatically:

```hcl
# In infra/main.tf
resource "azurerm_role_assignment" "csi_addon_kv_secrets_user" {
  principal_id         = module.aks.addon_identity_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.keyvault.key_vault_id
}

# In infra/modules/aks/outputs.tf
output "addon_identity_object_id" {
  value = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}
```

---

## 10. SecretProviderClass — How Secrets Flow

A `SecretProviderClass` is a custom Kubernetes resource (installed by the CSI driver) that defines: which Key Vault to read from, which secrets to fetch, and what Kubernetes Secret to create.

### The Full Secret Flow

```
1. kubectl apply -f k8s/secret-provider-classes/user-service.yaml
        ↓ creates SecretProviderClass in dev namespace

2. helm upgrade --install user-service ...
        ↓ creates Pod with CSI volume mount

3. Pod starts → Kubelet tells CSI driver to mount the volume
        ↓

4. CSI driver reads SecretProviderClass
   → authenticates to Key Vault using addon managed identity
   → fetches: sql-server-fqdn, sql-admin-username, sql-admin-password
        ↓

5. CSI driver:
   a. Writes secrets as files to /mnt/secrets-store/ inside the pod
   b. Creates Kubernetes Secret "user-service-secrets" in the dev namespace

6. Deployment has envFrom → secretRef → user-service-secrets
   → SQL_SERVER, SQL_USER, SQL_PASSWORD available as env vars in the container
```

### The SecretProviderClass for user-service

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
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "4e3f0c0a-9fee-4512-94fc-9d7eea9c96f3"  # CSI addon identity
    keyvaultName: "kv-azureshop-6a6c-dev"
    tenantId: "4c135936-7e4d-4ea6-9816-7d696b51923d"
    objects: |
      array:
        - |
          objectName: sql-server-fqdn
          objectType: secret
        - |
          objectName: sql-admin-username
          objectType: secret
        - |
          objectName: sql-admin-password
          objectType: secret
  secretObjects:
    - secretName: user-service-secrets  # K8s Secret created in the namespace
      type: Opaque
      data:
        - objectName: sql-server-fqdn
          key: SQL_SERVER      # ← available as env var SQL_SERVER in the pod
        - objectName: sql-admin-username
          key: SQL_USER
        - objectName: sql-admin-password
          key: SQL_PASSWORD
```

### Which Services Need Which Secrets

| Service | Secrets |
|---|---|
| user-service | SQL_SERVER, SQL_USER, SQL_PASSWORD |
| order-service | SQL_SERVER, SQL_USER, SQL_PASSWORD |
| payment-service | SQL_SERVER, SQL_USER, SQL_PASSWORD |
| product-service | COSMOS_ENDPOINT, COSMOS_KEY |
| cart-service | REDIS_HOST, REDIS_PORT, REDIS_PASSWORD |
| frontend, api-gateway, notification-service | No Key Vault secrets (use env vars only) |

---

## 11. Helm — The Package Manager for Kubernetes

### The Problem With Raw YAML

Imagine deploying user-service to dev, staging, and prod. You would have three nearly identical YAML files, differing only in replica count, resource limits, and image tag. When you need to change anything (a probe path, a label), you change it in three places and inevitably forget one.

Helm solves this exactly like a package manager solves software installation. Instead of three different files, you have:
- **Templates** — YAML with placeholders (`{{ .Values.replicaCount }}`)
- **Values files** — the actual values that fill the placeholders
- **Chart** — the package combining templates + default values

```
helm upgrade --install user-service helm/charts/user-service/ \
  -f helm/values/dev.yaml \
  --namespace dev
```

This means: deploy user-service chart, override defaults with dev.yaml values, into the dev namespace. Change `dev.yaml` to `prod.yaml` and the same chart deploys to production with different settings.

### Key Helm Concepts

**Release** — a named installation of a chart. `helm upgrade --install user-service ...` creates a release called `user-service`. Helm remembers its history, so you can roll back.

**Chart** — the package. Contains templates and a default values.yaml.

**Values** — the configuration. Stacked: chart defaults → override file (-f) → --set flags.

**Release namespace** — where Kubernetes resources are created. `{{ .Release.Namespace }}` in templates uses this automatically.

```bash
# See all releases in dev namespace
helm list --namespace dev

# Roll back user-service to previous version
helm rollback user-service 1 --namespace dev

# See what YAML Helm would render (without applying it)
helm template user-service helm/charts/user-service/ -f helm/values/dev.yaml
```

---

## 12. Helm Chart Structure We Built

```
helm/
├── charts/
│   ├── user-service/
│   │   ├── Chart.yaml            ← chart metadata (name, version, appVersion)
│   │   ├── values.yaml           ← default values for this service
│   │   └── templates/
│   │       ├── _helpers.tpl      ← shared label/name functions
│   │       ├── deployment.yaml   ← the Pod spec + security + probes
│   │       ├── service.yaml      ← ClusterIP Service
│   │       ├── hpa.yaml          ← HorizontalPodAutoscaler
│   │       ├── pdb.yaml          ← PodDisruptionBudget
│   │       ├── serviceaccount.yaml ← ServiceAccount (used for Workload Identity)
│   │       └── networkpolicy.yaml  ← ingress/egress firewall rules
│   ├── product-service/  (identical structure, different values)
│   ├── cart-service/
│   ├── order-service/
│   ├── payment-service/
│   ├── notification-service/
│   ├── frontend/
│   └── api-gateway/
│
└── values/
    ├── dev.yaml      ← dev overrides (1 replica, lower resources)
    ├── staging.yaml  ← staging overrides (2 replicas)
    └── prod.yaml     ← prod overrides (3 replicas, higher limits)
```

### Why All 8 Charts Are Identical in Structure

Our 8 services all follow the same pattern: one Deployment, one Service, one HPA, etc. By using identical templates driven by values.yaml, we get:
- A bug fix in deployment.yaml fixed everywhere at once
- A security hardening in Phase 8 applied to all 8 services by editing one template
- Consistency — every service behaves predictably

The only differences are in each service's `values.yaml`: the image repository, port number, environment variables, and whether Key Vault secrets are needed.

---

## 13. Each Helm Template Explained

### _helpers.tpl — Shared Functions

This file defines named templates that are reused across all other templates. Helm calls these "partial templates" or "named templates."

```
{{- define "azureshop.name" -}}
{{- .Chart.Name }}
{{- end }}
```

`.Chart.Name` is the chart name from Chart.yaml (e.g. `user-service`). Every resource — the Deployment, Service, HPA — uses `{{ include "azureshop.name" . }}` as its name. This means all resources for user-service are named `user-service`.

The labels template (`azureshop.labels`) puts standard Kubernetes labels on every resource. These labels let tools like kubectl, Helm, and monitoring systems understand which resources belong together.

### deployment.yaml — The Heart of Every Service

The Deployment is the most important resource. It describes what your container looks like when running.

```yaml
spec:
  replicas: {{ .Values.replicaCount }}     # how many pods to run
  selector:
    matchLabels:
      {{- include "azureshop.selectorLabels" . | nindent 6 }}
  template:                                # pod template
    spec:
      serviceAccountName: {{ include "azureshop.name" . }}
      containers:
        - image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

The `selector` connects the Deployment to its Pods. The labels in `selector.matchLabels` must match the labels on the pod template. This is how the Deployment knows which pods it manages.

### service.yaml — Stable Network Address

```yaml
spec:
  type: ClusterIP         # internal only — no external IP
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
  selector:
    {{- include "azureshop.selectorLabels" . | nindent 4 }}
```

`ClusterIP` means the service is only reachable from inside the cluster. Other pods use `user-service:3001` to reach it. External traffic comes through the Ingress, not directly to this service.

### hpa.yaml — Auto Scaling

```yaml
spec:
  scaleTargetRef:
    kind: Deployment
    name: {{ include "azureshop.name" . }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.cpuUtilizationPercentage }}
```

The HPA watches CPU utilization across all pods of the Deployment. When average CPU exceeds the threshold (e.g. 70%), it adds pods. When load drops, it removes pods (but never below `minReplicas`).

This requires resource requests to be set on the container — the HPA calculates utilization as `current CPU / requested CPU`. Without requests, the HPA cannot calculate utilization and does nothing.

### pdb.yaml — Protection During Maintenance

```yaml
spec:
  minAvailable: 1
  selector:
    matchLabels:
      {{- include "azureshop.selectorLabels" . | nindent 6 }}
```

When AKS does a node upgrade, it drains the node — evicts all pods from it. Without a PodDisruptionBudget, it might evict all replicas of user-service at once, causing complete downtime.

With `minAvailable: 1`, the Kubernetes eviction API refuses to evict a pod if doing so would leave fewer than 1 pod running. The upgrade waits until a new pod is scheduled elsewhere before proceeding. Guaranteed minimum availability during cluster maintenance.

### serviceaccount.yaml — Identity for the Pod

```yaml
metadata:
  name: {{ include "azureshop.name" . }}
  annotations:
    {{- toYaml .Values.serviceAccount.annotations | nindent 4 }}
```

A ServiceAccount is the identity a pod uses when talking to the Kubernetes API or to external Azure services. In Step 6.7 (Workload Identity), we add an annotation to bind the ServiceAccount to an Azure Managed Identity — enabling pods to authenticate to Azure services without any credentials stored in the pod.

### networkpolicy.yaml — Pod-Level Firewall

This is the Kubernetes equivalent of a firewall rule. By default, all pods can talk to all other pods. NetworkPolicy locks this down.

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx   # allow NGINX
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: dev             # allow same namespace
egress:
  - ports: [53/UDP, 53/TCP]    # DNS (required for service discovery)
  - to: [same namespace]        # service-to-service calls
  - ports: [443, 1433, 6380, 5671]  # Azure PaaS: HTTPS, SQL, Redis, Service Bus
```

---

## 14. Deployment Security Hardening

### Pod-Level Security Context

```yaml
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
```

`seccompProfile: RuntimeDefault` applies the container runtime's default system call filter. It blocks dangerous system calls like `ptrace` (used for process injection) and many others that a web service never needs. This is free security that should always be enabled.

### Container-Level Security Context

```yaml
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
```

- `allowPrivilegeEscalation: false` — prevents a process inside the container from gaining more privileges than it started with (e.g. via `setuid` binaries).
- `capabilities: drop: ALL` — Linux capabilities are fine-grained permissions (like `NET_ADMIN` for networking, `SYS_ADMIN` for many system operations). Dropping all of them means the container can only do what a normal user process can do — nothing more.

### The runAsNonRoot Issue We Hit

We initially set `runAsNonRoot: true` at the pod level. This tells Kubernetes to refuse to start any container that would run as the root user (UID 0).

Two services failed:
1. **api-gateway (NGINX):** NGINX's official image starts the master process as root (it needs to bind port 80, which requires root on Linux). The image declares no `USER` instruction.
2. **user-service:** The Dockerfile uses `USER nodejs` (a string name), not `USER 1001` (a UID). Kubernetes cannot verify that `nodejs` is non-root without looking up `/etc/passwd` inside the container, which it cannot do at scheduling time.

We removed `runAsNonRoot: true` from the pod spec. The container-level hardening (`allowPrivilegeEscalation: false`, `drop: ALL`) remains. Phase 8 will pin UIDs per image once we know the correct UID for each base image.

### Probes — Kubernetes Health Checks

Three probes are defined on every container:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 3001
  failureThreshold: 30
  periodSeconds: 10
```

The startup probe gives a slow-starting container up to 300 seconds (30 × 10) to become ready before liveness kicks in. Without this, a slow JVM or Node.js startup would trigger a liveness failure and cause a crash loop.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

The liveness probe restarts the container if it fails 3 consecutive checks. It catches containers that are running but stuck (deadlocked, out of memory, in an error state).

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3001
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

The readiness probe removes the pod from the Service's endpoint list when it fails. Traffic stops flowing to it. This prevents sending requests to a pod that is starting up or temporarily unhealthy. The pod stays running but receives no traffic until it is healthy again.

**Key difference:** Liveness failure → restart the container. Readiness failure → remove from load balancer (no restart).

---

## 15. High Availability Patterns

### Topology Spread Constraints

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: user-service
```

`maxSkew: 1` means the difference in pod count between any two nodes can be at most 1. If Node A has 2 pods and Node B has 0, the scheduler tries to put the next pod on Node B.

`whenUnsatisfiable: ScheduleAnyway` is important: if we only have 1 node (as in dev with 1 replica), we cannot spread, so Kubernetes schedules anyway rather than leaving pods pending.

This replaced the older `podAntiAffinity` approach. The difference:
- `podAntiAffinity` blocks scheduling entirely if the constraint cannot be met
- `topologySpreadConstraints` with `ScheduleAnyway` tries its best but does not block

### PodDisruptionBudget

Already explained in the template section — ensures at least 1 pod survives node drain during upgrades.

### HPA + Resource Requests

For HPA to work, every container must declare `resources.requests`. The HPA uses this to calculate utilization. Without it, the HPA cannot function.

For node autoscaling to work, the Cluster Autoscaler watches for pods in `Pending` state. A pod is `Pending` when no node has enough available resources to schedule it. The autoscaler adds a node. When pods are removed and a node becomes idle, the autoscaler removes it.

---

## 16. Network Policies — Zero Trust Networking

### The Default — Kubernetes Allows Everything

By default, any pod can talk to any other pod in any namespace. The payment-service could talk directly to the user database. A compromised container could scan the entire cluster.

Network Policies implement **zero trust** — default deny, then explicitly allow only what is needed.

Because we use `network_policy = "azure"` in Terraform, Kubernetes NetworkPolicy objects are enforced by Azure CNI's built-in policy engine.

### Our NetworkPolicy Design

Each service's NetworkPolicy follows this pattern:

**Ingress (who can talk TO this service):**
- The NGINX ingress controller namespace (so traffic from the internet can reach the pod)
- The same namespace (so other microservices can call each other, e.g. api-gateway → user-service)

**Egress (who this service can talk TO):**
- DNS (port 53) — always required for service discovery
- Same namespace (service-to-service calls)
- Azure PaaS ports: 443 (HTTPS/Key Vault/Cosmos), 1433 (SQL), 6380 (Redis TLS), 5671 (Service Bus AMQP)

```
internet → ingress-nginx → user-service ✓ (allowed)
other-namespace-pod → user-service ✗ (blocked)
user-service → product-service ✓ (same namespace)
user-service → external SQL:1433 ✓ (egress rule)
user-service → random-ip:8080 ✗ (blocked, not in egress rules)
```

---

## 17. The ARM64 vs AMD64 Problem

### What Happened

Docker images were built on a MacBook Air with Apple Silicon (M1/M2 chip). Apple Silicon is ARM64 architecture. AKS nodes are standard x86 Intel/AMD virtual machines — AMD64 architecture.

An ARM64 binary cannot run on an AMD64 processor. When Kubernetes tried to start a container, the Linux kernel rejected it:

```
exec /docker-entrypoint.sh: exec format error
```

This is a binary format mismatch at the OS level. The container started (Docker pulled the image fine) but the moment the kernel tried to execute the entry point binary, it failed.

### How to Identify It

```bash
kubectl describe pod <pod-name> -n dev
# Look for: exec format error in the State section

docker inspect acrazureshopdev.azurecr.io/user-service:v1.0.0 | grep Architecture
# Shows: arm64  ← wrong for AKS nodes
```

### The Fix

Build multi-platform images using `docker buildx`:

```bash
# One-time setup: create a builder that supports cross-platform builds
docker buildx create --name multiarch --driver docker-container --use

# Build and push AMD64 image
docker buildx build \
  --builder multiarch \
  --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/user-service:v1.0.0 \
  --push \
  services/user-service/
```

The `--platform linux/amd64` flag tells Docker to compile the image for AMD64 even though the build machine is ARM64. Docker uses QEMU emulation under the hood.

### Why This Only Appears at Runtime

During Phase 4, we ran containers locally (docker-compose) on the Mac. ARM64 runs fine on ARM64 — no error. The problem only appears when those images run on AMD64 nodes. In a production CI/CD setup (Azure Pipelines, which runs on AMD64 agents), the build agent is AMD64, so images are built natively for AMD64 and this problem never occurs.

**Lesson:** Always build production images on the target architecture or use `--platform linux/amd64` explicitly when building from an Apple Silicon Mac.

---

## 18. Terraform Changes Made in Phase 6

### ACR Conflict Resolution

Before Phase 6, a Basic SKU ACR was manually created to hold Docker images. Terraform did not know about it. Running `terraform apply` would fail because it tried to create an ACR with the same name that already existed.

Two options:
1. Delete the ACR (lose all images, have to rebuild)
2. Import the ACR into Terraform state (keep all images, Terraform takes ownership)

We chose option 2 — `terraform import`:

```bash
TF_VAR_sql_admin_password='...' \
terraform import \
  -var-file="environments/dev/terraform.tfvars" \
  module.acr.azurerm_container_registry.main \
  /subscriptions/.../resourceGroups/rg-azureshop-dev/providers/Microsoft.ContainerRegistry/registries/acrazureshopdev
```

After import, Terraform upgraded the ACR from Basic to Premium SKU (as defined in the Terraform module) without deleting any images.

### CSI Addon Identity Role Assignment

Added to `infra/main.tf`:

```hcl
resource "azurerm_role_assignment" "csi_addon_kv_secrets_user" {
  principal_id         = module.aks.addon_identity_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = module.keyvault.key_vault_id
}
```

Added output to `infra/modules/aks/outputs.tf`:

```hcl
output "addon_identity_object_id" {
  description = "Object ID of the Key Vault Secrets Provider addon managed identity"
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}
```

### Key Vault in Terraform vs Key Vault Name

There are two Key Vaults in the project history:
- `kv-azureshop-6a6c` — manually created in Phase 1 for learning (no longer used)
- `kv-azureshop-6a6c-dev` — created by Terraform in Phase 6

The Terraform Key Vault name uses the first 4 characters of the subscription ID (`6a6c`) to make it globally unique. All SecretProviderClass files reference `kv-azureshop-6a6c-dev`.

---

## 19. Environment-Based Values — Dev / Staging / Prod

One of Helm's most powerful features is stacking values files. The same chart can behave differently in each environment.

### helm/values/dev.yaml

```yaml
replicaCount: 1           # single pod saves resources
resources:
  requests: {cpu: "50m", memory: "64Mi"}
  limits:   {cpu: "300m", memory: "256Mi"}
hpa:
  minReplicas: 1
  maxReplicas: 3
  cpuUtilizationPercentage: 80
```

### helm/values/staging.yaml

```yaml
replicaCount: 2           # two pods for HA testing
resources:
  requests: {cpu: "100m", memory: "128Mi"}
  limits:   {cpu: "500m", memory: "512Mi"}
hpa:
  minReplicas: 2
  maxReplicas: 6
  cpuUtilizationPercentage: 70
```

### helm/values/prod.yaml

```yaml
replicaCount: 3           # three pods, spread across three nodes
resources:
  requests: {cpu: "100m", memory: "128Mi"}
  limits:   {cpu: "500m", memory: "512Mi"}
hpa:
  minReplicas: 3
  maxReplicas: 10
  cpuUtilizationPercentage: 70
```

### How Helm Stacks Values

When you run:

```bash
helm upgrade --install user-service helm/charts/user-service/ -f helm/values/dev.yaml
```

Helm merges values in this order (later overrides earlier):
1. `helm/charts/user-service/values.yaml` (chart defaults — port, image, probe path)
2. `helm/values/dev.yaml` (environment overrides — replicas, resources, HPA)

The final effective values are a merge of both. This means you never duplicate the port number or image URL across three environment files — only the things that differ per environment go in the override file.

---

## 20. Commands Reference

### AKS Setup

```bash
# Apply all Azure infra (AKS, SQL, Redis, Key Vault, etc.)
cd infra/
TF_VAR_sql_admin_password='...' terraform apply -var-file="environments/dev/terraform.tfvars"

# Connect kubectl to AKS
az aks get-credentials --resource-group rg-azureshop-dev --name aks-azureshop-dev

# Convert kubeconfig to use Azure CLI tokens (required for Azure AD RBAC)
kubelogin convert-kubeconfig -l azurecli

# Verify access
kubectl get nodes
kubectl get pods --all-namespaces
```

### Namespace and Ingress Setup

```bash
# Create namespaces
kubectl apply -f k8s/namespaces/

# Install NGINX ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f k8s/ingress-nginx-values.yaml

# Get the external IP assigned to NGINX
kubectl get service -n ingress-nginx
```

### Key Vault CSI Driver

```bash
# Verify CSI driver is running on all nodes
kubectl get pods -n kube-system | grep secrets-store

# Apply all SecretProviderClasses
kubectl apply -f k8s/secret-provider-classes/

# Verify a SecretProviderClass was created
kubectl get secretproviderclass -n dev
```

### Helm Deployments

```bash
# Deploy a single service to dev
helm upgrade --install user-service helm/charts/user-service/ \
  -f helm/values/dev.yaml --namespace dev

# Deploy all 8 services
for svc in user-service product-service cart-service order-service \
           payment-service notification-service frontend api-gateway; do
  helm upgrade --install $svc helm/charts/$svc/ \
    -f helm/values/dev.yaml --namespace dev
done

# List all releases in dev
helm list --namespace dev

# Check pod status
kubectl get pods -n dev

# See pod logs
kubectl logs -n dev deployment/user-service --tail=50

# Describe a pod (see events, errors)
kubectl describe pod <pod-name> -n dev

# Roll back a release
helm rollback user-service 1 --namespace dev

# Uninstall a release
helm uninstall user-service --namespace dev
```

### Debugging

```bash
# See why a pod is not starting
kubectl describe pod <pod-name> -n dev

# Check recent events in namespace
kubectl get events -n dev --sort-by='.lastTimestamp'

# Check if the K8s Secret was created by CSI driver
kubectl get secrets -n dev

# Exec into a running pod
kubectl exec -it deployment/user-service -n dev -- sh

# Check image architecture (ARM64 vs AMD64 problem)
docker inspect <image>:<tag> | grep Architecture
```

### Building AMD64 Images (ARM64 Mac Fix)

```bash
# One-time: create multi-platform builder
docker buildx create --name multiarch --driver docker-container --use

# Build and push AMD64 image for each service
for svc in user-service product-service cart-service order-service \
           payment-service notification-service frontend api-gateway; do
  docker buildx build \
    --builder multiarch \
    --platform linux/amd64 \
    -t acrazureshopdev.azurecr.io/$svc:v1.0.0 \
    --push \
    services/$svc/
done

# Check image architecture after push
docker inspect acrazureshopdev.azurecr.io/user-service:v1.0.0 | grep Architecture
# Should show: amd64

# Force Kubernetes to pull the new image (when tag is unchanged)
kubectl rollout restart deployment/api-gateway -n dev
```

### Step 6.5 — Ingress Routing

```bash
# Apply ingress routing rules for dev namespace
kubectl apply -f k8s/ingress/dev-ingress.yaml

# Verify ingress object was created and received an external address
kubectl get ingress -n dev
# Expected output:
# NAME                CLASS   HOSTS   ADDRESS          PORTS   AGE
# azureshop-ingress   nginx   *       134.33.223.224   80      5m

# Test frontend route via port-forward (bypasses NSG for local testing)
kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller 8088:80 &
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8088/
curl -s http://localhost:8088/api/health
# Kill the port-forward when done
kill %1

# Test routing from inside the cluster
kubectl run curl-test --image=curlimages/curl:latest --restart=Never --rm -n dev \
  --command -- sh -c \
  "curl -s -o /dev/null -w 'Frontend: HTTP %{http_code}\n' http://frontend:3000/ && \
   curl -s http://frontend:3000/api/health && echo '' && \
   curl -s -o /dev/null -w 'API-GW: HTTP %{http_code}\n' http://api-gateway:8080/"
```

### Step 6.6 — Network Policies

```bash
# List all network policies in dev namespace
kubectl get networkpolicy -n dev

# Describe a specific network policy to see its rules
kubectl describe networkpolicy user-service -n dev

# Test ALLOWED traffic: pod in dev → user-service (should work)
kubectl run curl-allowed --image=curlimages/curl:latest --restart=Never --rm -n dev \
  --command -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://user-service:3001/health

# Test BLOCKED traffic: pod in staging → user-service in dev (should time out)
kubectl run curl-blocked --image=curlimages/curl:latest --restart=Never --rm -n staging \
  --command -- curl --max-time 5 -s -o /dev/null -w "HTTP %{http_code}\n" \
  http://user-service.dev.svc.cluster.local:3001/health
# Expected: HTTP 000 (connection refused/timed out)
```

### Step 6.7 — Workload Identity

```bash
# Check if OIDC issuer is enabled on the AKS cluster
az aks show --name aks-azureshop-dev --resource-group rg-azureshop-dev \
  --query "oidcIssuerProfile" -o json

# Check if Workload Identity is enabled
az aks show --name aks-azureshop-dev --resource-group rg-azureshop-dev \
  --query "securityProfile.workloadIdentity" -o json

# Get the managed identity client ID (needed for Helm values)
az identity show \
  --name "id-notification-service-dev" \
  --resource-group "rg-azureshop-dev" \
  --query "clientId" -o tsv

# Force-unlock a stale Terraform state lock
terraform force-unlock -force <lock-id>

# Import an existing resource into Terraform state (avoids recreate)
terraform import \
  -var-file="environments/dev/terraform.tfvars" \
  azurerm_federated_identity_credential.notification_service \
  "/subscriptions/<sub>/resourceGroups/rg-azureshop-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-notification-service-dev/federatedIdentityCredentials/fic-notification-service-dev"

# Apply Workload Identity Terraform changes
export TF_VAR_sql_admin_password="..."
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve

# Upgrade notification-service Helm chart with Workload Identity settings
helm upgrade notification-service helm/charts/notification-service/ \
  --namespace dev \
  --values helm/charts/notification-service/values.yaml

# Verify rollout completes successfully
kubectl rollout status deployment/notification-service -n dev

# Verify Workload Identity env vars were injected by the webhook
kubectl exec -n dev deployment/notification-service -- env | grep AZURE
# Expected:
# AZURE_CLIENT_ID=2e5e41cb-dd6c-46a5-8420-165c463fe974
# AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token
# AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/

# Verify the ServiceAccount has the annotation
kubectl get serviceaccount notification-service -n dev -o jsonpath='{.metadata.annotations}'

# Verify the pod has the Workload Identity label
kubectl get pod <notification-service-pod> -n dev -o jsonpath='{.metadata.labels}'
```

### Step 6.8 — End-to-End Verification

```bash
# Full pod status check
kubectl get pods -n dev -o wide

# Check services
kubectl get svc -n dev

# Check HPA (all should show actual CPU metrics, not <unknown>)
kubectl get hpa -n dev

# Check all network policies
kubectl get networkpolicy -n dev

# Check ingress
kubectl get ingress -n dev

# Verify CSI secrets are mounted inside a pod
kubectl exec -n dev deployment/user-service -- ls /mnt/secrets-store

# Verify env vars injected from Key Vault
kubectl exec -n dev deployment/user-service -- env | grep -E "SQL|COSMOS|REDIS"

# Test SQL server TCP reachability from inside a pod
kubectl exec -n dev deployment/user-service -- \
  sh -c "nc -zv sql-azureshop-dev.database.windows.net 1433"
# Expected: Connection open

# Run health checks on all services from inside the cluster
kubectl run curl-test --image=curlimages/curl:latest --restart=Never --rm -n dev \
  --command -- sh -c "
    echo '=== Frontend ===' && curl -s http://frontend:3000/api/health && echo '' &&
    echo '=== API Gateway ===' && curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://api-gateway:8080/ &&
    echo '=== User Service ===' && curl -s http://user-service:3001/health && echo '' &&
    echo '=== Product Service ===' && curl -s http://product-service:3002/health && echo '' &&
    echo '=== Cart Service ===' && curl -s http://cart-service:3003/health && echo '' &&
    echo '=== Order Service ===' && curl -s http://order-service:3004/health && echo '' &&
    echo '=== Notification Service ===' && curl -s http://notification-service:3006/health
  "

# Check recent events in dev namespace (useful for diagnosing issues)
kubectl get events -n dev --sort-by='.lastTimestamp' | tail -20
```

---

## 21. Full Step-by-Step Summary

### Step 6.1 — AKS Initial Setup

1. Ran `terraform apply` to provision 56 Azure resources: AKS cluster, VNet, Azure SQL, Redis, Cosmos DB, Key Vault, Log Analytics, App Insights, monitoring resources.
2. ACR conflict resolved via `terraform import` (kept existing images).
3. Installed `kubelogin` via Homebrew.
4. Connected kubectl: `az aks get-credentials` → `kubelogin convert-kubeconfig`.
5. Role-assigned `Azure Kubernetes Service RBAC Cluster Admin` to user object ID.
6. Applied namespace YAML files (dev, staging, prod, monitoring).
7. Installed NGINX ingress controller via Helm → got external IP `48.202.215.133`.

### Step 6.2 — Key Vault CSI Driver Setup

1. Verified CSI driver DaemonSet was running on all nodes (installed automatically by the AKS addon).
2. Found that the CSI addon managed identity (object ID: `bbb780af-...`) did not have `Key Vault Secrets User` role.
3. Assigned the role manually, then codified in Terraform (`azurerm_role_assignment.csi_addon_kv_secrets_user`).
4. Created 5 SecretProviderClass files for user-service, product-service, cart-service, order-service, payment-service.

### Step 6.3 — Helm Charts

1. Created one chart for user-service with all 7 template files.
2. Copied the template files to all 7 other service charts (templates are identical).
3. Customized each service's `values.yaml`: port, image, env vars, secretProviderClass settings.
4. Created `helm/values/dev.yaml`, `staging.yaml`, `prod.yaml`.
5. Ran `helm lint` on all 8 charts — all passed.

### Step 6.4 — Deploy Services

1. Deployed all 8 services with `helm upgrade --install ... -f helm/values/dev.yaml`.
2. All Helm releases: `STATUS: deployed`.
3. Pods started in `CreateContainerConfigError` — `runAsNonRoot: true` rejected NGINX (runs as root) and string-UID images (`USER nodejs`). Fixed by removing `runAsNonRoot: true` from all 8 charts.
4. Pods moved to `CrashLoopBackOff` — `exec format error`. Root cause: Docker images were built on Apple Silicon (ARM64) but AKS nodes are AMD64.
5. Created `docker buildx` multi-platform builder. Rebuilt all 8 images with `--platform linux/amd64`. Pushed to ACR.
6. api-gateway pods failed with `chown /var/cache/nginx: Operation not permitted` — the standard `nginx:alpine` image requires root to set up cache directories. Switched to `nginxinc/nginx-unprivileged:1.27-alpine`. Bumped image tag to `v1.0.1`.
7. api-gateway still failing with `open /run/nginx.pid: Permission denied` — unprivileged NGINX cannot write the PID file to `/run/`. Added `pid /tmp/nginx.pid` and all temp path overrides to `nginx.conf`. Bumped image tag to `v1.0.2`.
8. frontend readiness probe returning 404 — Next.js has no built-in `/health` route. Created `pages/api/health.js` health endpoint, changed probe path from `/health` to `/api/health`. Bumped frontend image to `v1.0.1`.
9. CSI addon identity stale after AKS cluster was recreated — new cluster generated new addon identity. Updated all 5 SecretProviderClass files with new Client ID `d755c00c-d37e-47f8-997c-86202a2a77f4`.
10. All 9 pods reached `1/1 Running` in dev namespace. Step 6.4 complete.

### Step 6.5 — NGINX Ingress Routing

1. Created `k8s/ingress/dev-ingress.yaml` with two path-based routing rules:
   - `/api/` → `api-gateway:8080` (all API traffic)
   - `/` → `frontend:3000` (all other traffic — the Next.js app)
2. Applied: `kubectl apply -f k8s/ingress/dev-ingress.yaml`.
3. Ingress object received the NGINX controller's external IP `134.33.223.224` as its ADDRESS.
4. Tested routing via port-forward (bypasses NSG for local verification):
   - `GET /` → HTTP 200 (Next.js homepage loads)
   - `GET /api/health` → `{"status":"ok","service":"frontend"}` (Next.js health endpoint)
   - `GET /api/` → HTTP 308 (api-gateway redirect — routing reached the correct backend)
5. Noted: external HTTP (port 80) is blocked by the AKS subnet NSG by design (only HTTPS/443 open). Port-forward is the correct verification method for dev.
6. Committed via GitFlow → PR #29 merged to dev.

### Step 6.6 — Network Policies

1. All 8 NetworkPolicy objects were already deployed as part of the Helm charts in Step 6.4 — each chart includes a `networkpolicy.yaml` template.
2. Confirmed all 8 policies active: `kubectl get networkpolicy -n dev` showed all 8 services.
3. Tested **allowed** traffic: curl pod in `dev` namespace → `user-service:3001` → HTTP 200. Traffic within the same namespace is permitted by the egress/ingress rules.
4. Tested **blocked** traffic: curl pod in `staging` namespace → `user-service.dev.svc.cluster.local:3001` → HTTP 000 (connection timed out). Cross-namespace traffic without explicit allow is blocked.
5. Network policies confirmed working as a zero-trust pod-level firewall.
6. No separate PR needed — policies were already in the Helm charts committed in earlier PRs.

### Step 6.7 — Workload Identity

1. Added to `infra/modules/aks/main.tf`:
   - `oidc_issuer_enabled = true` — exposes an OIDC endpoint so Azure AD can verify K8s ServiceAccount tokens.
   - `workload_identity_enabled = true` — installs the Workload Identity webhook on the cluster.
2. Added `oidc_issuer_url` output to `infra/modules/aks/outputs.tf` — needed by the federated credential resource.
3. Added three new resources to `infra/main.tf`:
   - `azurerm_user_assigned_identity.notification_service` — the Azure Managed Identity for the service.
   - `azurerm_federated_identity_credential.notification_service` — links `system:serviceaccount:dev:notification-service` to the Managed Identity via OIDC trust.
   - `azurerm_role_assignment.notification_service_kv_secrets_user` — grants the Managed Identity `Key Vault Secrets User` on Key Vault scope.
4. Stale state lock from previous session force-unlocked: `terraform force-unlock -force <lock-id>`.
5. Ran `terraform apply` — AKS cluster updated in-place (27 seconds, no pod disruption). OIDC and Workload Identity enabled on the control plane only.
6. Federated Identity Credential already existed in Azure from a prior session — imported into Terraform state with `terraform import` to avoid conflict.
7. Retrieved Managed Identity Client ID: `2e5e41cb-dd6c-46a5-8420-165c463fe974`.
8. Updated `helm/charts/notification-service/values.yaml`:
   - Added `serviceAccount.annotations: {azure.workload.identity/client-id: "2e5e41cb-..."}`.
   - Added `workloadIdentity.enabled: true`.
9. Updated `helm/charts/notification-service/templates/deployment.yaml` to add pod label `azure.workload.identity/use: "true"` when `workloadIdentity.enabled` is true.
10. Ran `helm upgrade notification-service` — new pods rolled out with the label.
11. Verified Workload Identity webhook injected env vars:
    - `AZURE_CLIENT_ID=2e5e41cb-dd6c-46a5-8420-165c463fe974`
    - `AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token`
    - `AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/`
12. Committed via GitFlow → PR #30 merged to dev. Local branch deleted.

### Step 6.8 — End-to-End Verification

Full verification run confirming all Phase 6 components working correctly:

| Check | Result | Notes |
|---|---|---|
| All 9 pods `1/1 Running` | Pass | 2× notification-service, 1× each other service |
| All 8 ClusterIP Services | Pass | Correct ports for each service |
| All 8 HPA objects with live CPU metrics | Pass | CPU 1–10% across services |
| All 8 NetworkPolicy objects | Pass | Zero-trust ingress/egress enforced |
| NGINX Ingress Controller (LoadBalancer) | Pass | External IP: 134.33.223.224 |
| Ingress `GET /` → frontend HTTP 200 | Pass | Next.js homepage |
| Ingress `GET /api/health` → `{"status":"ok"}` | Pass | Next.js health endpoint |
| Ingress `GET /api/` → api-gateway HTTP 308 | Pass | Routing reached correct backend |
| CSI secrets mounted in user-service pod | Pass | `sql-server-fqdn`, `sql-admin-username`, `sql-admin-password` |
| SQL_SERVER, SQL_USER, SQL_PASSWORD env vars | Pass | Injected from Key Vault via CSI driver |
| SQL server TCP port 1433 reachable from pod | Pass | `nc -zv` returned open |
| Workload Identity `AZURE_CLIENT_ID` injected | Pass | webhook operating correctly |
| Workload Identity `AZURE_FEDERATED_TOKEN_FILE` injected | Pass | Token file projected into pod |
| External HTTP via public IP (port 80) | Expected block | NSG allows HTTPS only — correct for production design |
| `db: disconnected` in health checks | Expected — Phase 7 | TCP 1433 is open; app-level DB schema initialization is Phase 7 scope |

Phase 6 complete. All 8 microservices deployed, secured, and observable on AKS.

---

## 22. Interview Questions and Answers

### Kubernetes Fundamentals

**Q: What is the difference between a Pod, a Deployment, and a Service?**

A: A **Pod** is the smallest deployable unit — it runs one or more containers. A **Deployment** manages pods: it ensures a desired number of replicas are running, handles rolling updates, and restarts crashed pods. A **Service** provides a stable network address (ClusterIP) to a set of pods — it load-balances traffic across all healthy pods matching its selector. In practice: you never create pods directly; you create a Deployment, and the Deployment creates the pods. Other services talk to the Service's ClusterIP, not directly to pod IPs.

---

**Q: What is the difference between liveness and readiness probes?**

A: A **liveness** probe determines if the container is alive. A failure causes Kubernetes to restart the container. Use it to catch deadlocks and stuck processes. A **readiness** probe determines if the container is ready to receive traffic. A failure removes the pod from the Service's endpoint list — traffic stops, but the container is not restarted. Use it during startup and temporary unhealthy periods. There is also a **startup** probe, which disables liveness/readiness until the container first becomes healthy — important for slow-starting apps.

---

**Q: What is a Namespace and why do we use multiple namespaces?**

A: A Namespace is a virtual partition inside a Kubernetes cluster. Resources in different namespaces are isolated from each other by default. We use multiple namespaces to run dev, staging, and prod environments on the same cluster without interference. Each namespace has its own Secrets, ConfigMaps, RBAC permissions, and network policies. Cost: you pay for one cluster instead of three. Risk: a misconfigured network policy could allow cross-namespace access, so you must apply network policies carefully.

---

**Q: What is a PodDisruptionBudget and when does it matter?**

A: A PDB defines the minimum number of pods that must remain available during voluntary disruptions — node drains, cluster upgrades, or manual evictions. Without a PDB, Kubernetes might evict all replicas of a Deployment at once during a node drain, causing complete downtime. With `minAvailable: 1`, the eviction API blocks until a replacement pod is healthy before evicting the next one. PDBs only protect against voluntary disruptions (planned maintenance), not involuntary ones (node crash).

---

**Q: Explain the difference between Azure CNI and Kubenet.**

A: **Kubenet** assigns private IPs (from a non-VNet range) to pods and uses NAT for external communication. Azure services cannot directly target pod IPs. Simpler setup, uses fewer VNet IPs. **Azure CNI** assigns real VNet IPs to every pod. Azure services (SQL, NSGs, firewalls) can target individual pod IPs. Better for enterprise environments requiring direct Azure integration, detailed network monitoring, and fine-grained security. Tradeoff: requires a larger VNet subnet because every pod consumes one IP address.

---

### AKS and Azure

**Q: What is kubelogin and why is it needed for AKS?**

A: When AKS is configured with Azure AD RBAC, kubectl must present an Azure AD access token to authenticate. `kubectl` does not know how to fetch Azure AD tokens natively — it only understands certificate-based and static token auth. `kubelogin` is a credential plugin that hooks into kubectl's auth mechanism. `kubelogin convert-kubeconfig -l azurecli` rewrites the kubeconfig to use kubelogin as the auth helper, which fetches fresh tokens from Azure CLI on each kubectl command.

---

**Q: What is the Key Vault CSI Driver and how does it work?**

A: The Key Vault CSI Driver is a Kubernetes add-on that mounts Azure Key Vault secrets as volumes inside pods. It runs as a DaemonSet on every node. When a pod is scheduled, the kubelet asks the CSI driver to mount the volume. The CSI driver authenticates to Key Vault using a Managed Identity (no credentials stored anywhere), fetches the specified secrets, writes them as files to a tmpfs mount inside the pod, and optionally creates a Kubernetes Secret from them. The pod reads secrets as environment variables from the Kubernetes Secret — it never calls Key Vault directly.

---

**Q: What is the difference between the kubelet identity and the CSI addon identity in AKS?**

A: An AKS cluster has two separate managed identities. The **kubelet identity** (also called the node identity) is used by the nodes to pull images from ACR, write logs to Azure Monitor, and other node-level operations. The **CSI addon identity** is a separate identity used exclusively by the Key Vault Secrets Provider addon to authenticate to Key Vault. They are different security principals with different role assignments. A common mistake is to assign `Key Vault Secrets User` to the kubelet identity — this does not help the CSI driver, which uses its own identity.

---

**Q: Why did you use a separate System and User node pool?**

A: The system pool runs critical Kubernetes components: CoreDNS, the metrics server, the CSI DaemonSet. If application pods can schedule on the system pool and consume all resources, CoreDNS crashes and the cluster becomes non-functional. Setting `only_critical_addons_enabled = true` on the system pool automatically taints it so application pods cannot schedule there. This provides strong isolation — application resource contention never impacts cluster health.

---

### Helm

**Q: What is Helm and how is it different from `kubectl apply`?**

A: `kubectl apply` applies individual YAML files with fixed values. You need one YAML per environment. Helm is a package manager: it templates the YAML (using Go templates), takes values as input, and renders the final YAML. One Helm chart works for dev, staging, and prod — only the values file changes. Helm also tracks release history (enabling rollbacks), manages upgrades atomically, and handles install-if-not-exists vs upgrade-if-exists via `helm upgrade --install`. It treats related K8s resources as a unit (a release) rather than individual files.

---

**Q: Explain how values override works in Helm.**

A: Helm merges values from multiple sources in priority order. The chart's `values.yaml` provides defaults (image, port, probe path). An `-f <file>` flag adds an override file (environment-specific replicas, resources). A `--set key=value` flag provides the highest-priority one-off overrides. Later sources override earlier ones — only keys that differ need to be specified in the override file, reducing duplication.

---

**Q: What is a HorizontalPodAutoscaler and what does it need to function?**

A: An HPA automatically adjusts the number of pod replicas based on observed CPU or memory utilization. It watches metrics from the Metrics Server and scales up when average CPU exceeds the target percentage, scales down when load drops. Two requirements: (1) resource `requests` must be defined on containers — HPA calculates utilization as `current / requested`, and (2) the Metrics Server must be running in the cluster (installed by default on AKS).

---

### Security

**Q: What does `capabilities: drop: ALL` do and why is it important?**

A: Linux capabilities are granular permissions beyond the normal user/root distinction. `CAP_NET_ADMIN` allows network configuration. `CAP_SYS_ADMIN` allows many privileged operations. `CAP_DAC_OVERRIDE` bypasses file permission checks. Dropping all capabilities means the container process can only perform operations available to a regular user with no special privileges — even if the container somehow escapes, it cannot modify the network, mount filesystems, or perform other dangerous operations. This is defence-in-depth: even if your application has a remote code execution vulnerability, the attacker cannot do much with a process that has no capabilities.

---

**Q: What is a seccompProfile and why do we use RuntimeDefault?**

A: A seccomp (Secure Computing Mode) profile defines which Linux system calls a process is allowed to make. The `RuntimeDefault` profile is maintained by the container runtime (containerd/Docker) and blocks system calls that are never needed by normal application containers — things like `ptrace` (inject code into other processes), `unshare` (modify namespaces), and `clone3` (create processes in new namespaces). Using `RuntimeDefault` reduces the attack surface with zero application changes required.

---

**Q: Explain NetworkPolicy and how it implements zero trust in Kubernetes.**

A: By default, Kubernetes allows all pod-to-pod communication — any pod can talk to any other pod on any port. NetworkPolicy objects act as firewall rules at the pod level. In zero trust networking, you start with a deny-all stance and explicitly allow only necessary communication. A typical pattern: (1) allow inbound from the ingress controller namespace so external traffic can reach the pod, (2) allow inbound from the same namespace for service-to-service calls, (3) allow outbound DNS so service discovery works, (4) allow outbound to specific Azure PaaS ports. All other traffic is implicitly denied. This means a compromised pod cannot scan or access other services it has no business calling.

---

**Q: What is the difference between a Kubernetes Secret and a SecretProviderClass?**

A: A **Kubernetes Secret** is a native K8s object that stores base64-encoded data. It is stored in etcd. On a standard cluster without encryption-at-rest, anyone who can access etcd can decode the secrets. Secrets are not automatically rotated. A **SecretProviderClass** is a custom resource from the Secrets Store CSI Driver that defines how to fetch secrets from an external secret manager (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault). The external system is the source of truth. The CSI driver syncs secrets from Key Vault into a Kubernetes Secret, and can automatically refresh them when they change in Key Vault. The advantage: secrets live in an audited, RBAC-controlled, encrypted vault — not just in Kubernetes.

---

**Q: What is the ARM64 vs AMD64 issue and how do you prevent it in CI/CD?**

A: ARM64 and AMD64 are different CPU instruction set architectures. A binary compiled for ARM64 cannot execute on an AMD64 processor and vice versa. When Docker images are built on Apple Silicon (ARM64 Macs), the resulting images contain ARM64 binaries. AKS nodes are AMD64 VMs. The kernel rejects the binary at execution time with `exec format error`. The fix is to use `docker buildx build --platform linux/amd64` to cross-compile the image for AMD64, even when building on ARM64. In CI/CD (Azure Pipelines), build agents are typically Linux AMD64, so this problem never occurs in pipelines — it is a local developer workflow problem specific to Apple Silicon machines.

---

**Q: What is Workload Identity and why is it better than mounting service principal credentials?**

A: Workload Identity (Step 6.7 in our project) binds a Kubernetes ServiceAccount to an Azure Managed Identity. A pod that uses the ServiceAccount can obtain short-lived Azure AD tokens without any credentials stored in the pod or in Kubernetes Secrets. Compared to a service principal secret: (1) no secret to rotate — tokens expire automatically, (2) no secret to accidentally log or expose, (3) token scope is limited to what the Managed Identity has been granted, (4) all access is audited in Azure AD logs. It is the Azure-native equivalent of AWS IAM Roles for Service Accounts (IRSA).

---

## 23. Workload Identity — OIDC and Federated Credentials

### The Problem With Credentials in Pods

Before Workload Identity, the common pattern for a pod to authenticate to Azure was:

```
1. Create a Service Principal in Azure AD
2. Store its client ID and secret in a Kubernetes Secret
3. Mount the Secret as env vars into the pod
4. The pod uses the client ID + secret to get an Azure AD token
```

Problems:
- The secret has to be rotated manually (or it expires unexpectedly)
- It is stored in Kubernetes etcd (not encrypted by default)
- It could be accidentally logged or printed
- If the pod is compromised, the attacker has a long-lived credential

### How Workload Identity Solves This

Workload Identity uses a trust relationship between Kubernetes and Azure AD, removing the need for any stored credential.

```
Kubernetes (AKS)                    Azure AD
     │                                  │
     │  "I have an OIDC endpoint at     │
     │   https://oidc.prod.aks.azure.   │
     │   com/..."                       │
     │                                  │
     │  ← Federated Identity Credential │
     │    "I trust tokens signed by     │
     │     this OIDC issuer for subject │
     │     system:serviceaccount:       │
     │     dev:notification-service"    │
```

### The Five Components

**1. OIDC Issuer on AKS**
```hcl
oidc_issuer_enabled = true
```
AKS exposes an OIDC endpoint that publishes its public signing keys. Azure AD can use this to verify that a token was genuinely issued by this cluster.

**2. Workload Identity Webhook**
```hcl
workload_identity_enabled = true
```
This installs a mutating webhook in the cluster. Every pod that has the `azure.workload.identity/use: "true"` label is automatically mutated — the webhook injects env vars and a projected volume with a ServiceAccount token.

**3. User Assigned Managed Identity**
```hcl
resource "azurerm_user_assigned_identity" "notification_service" {
  name = "id-notification-service-dev"
}
```
This is the Azure identity that the pod will impersonate. It has role assignments that control what Azure resources it can access.

**4. Federated Identity Credential**
```hcl
resource "azurerm_federated_identity_credential" "notification_service" {
  issuer  = module.aks.oidc_issuer_url
  subject = "system:serviceaccount:dev:notification-service"
  audience = ["api://AzureADTokenExchange"]
}
```
This is the trust bridge. It tells Azure AD: "If you receive a token signed by this OIDC issuer (`issuer`) and the token's `sub` claim is `system:serviceaccount:dev:notification-service` (`subject`), then trust it and issue a token for this Managed Identity."

**5. ServiceAccount Annotation + Pod Label**
```yaml
# ServiceAccount:
annotations:
  azure.workload.identity/client-id: "2e5e41cb-..."

# Pod:
labels:
  azure.workload.identity/use: "true"
```

The annotation tells the webhook which Managed Identity to use. The label tells the webhook to mutate this pod.

### The Full Token Exchange Flow

```
1. Pod starts with label azure.workload.identity/use: "true"
        ↓
2. Webhook intercepts pod creation
   → Injects AZURE_CLIENT_ID env var
   → Mounts a projected ServiceAccount token at
     /var/run/secrets/azure/tokens/azure-identity-token
   → Token is scoped to "api://AzureADTokenExchange" audience
        ↓
3. Application code calls Azure SDK (e.g. KeyVaultClient)
        ↓
4. SDK reads AZURE_CLIENT_ID from env
   SDK reads the projected token from the file
        ↓
5. SDK sends request to Azure AD token endpoint:
   "I have a token signed by AKS OIDC issuer, I want a token for
    Managed Identity 2e5e41cb-..."
        ↓
6. Azure AD validates:
   → Checks OIDC issuer's public keys (from the OIDC endpoint)
   → Verifies the token signature
   → Checks if a Federated Credential exists for this issuer + subject
   → Issues a short-lived (1 hour) Azure AD access token
        ↓
7. Application uses the Azure AD token to call Key Vault / Service Bus / etc.
   → All calls are audited under the Managed Identity's identity
```

### What the Webhook Injects

When a pod with `azure.workload.identity/use: "true"` starts, the webhook automatically adds:

```yaml
env:
  - name: AZURE_CLIENT_ID
    value: "2e5e41cb-dd6c-46a5-8420-165c463fe974"
  - name: AZURE_TENANT_ID
    value: "4c135936-7e4d-4ea6-9816-7d696b51923d"
  - name: AZURE_FEDERATED_TOKEN_FILE
    value: "/var/run/secrets/azure/tokens/azure-identity-token"
  - name: AZURE_AUTHORITY_HOST
    value: "https://login.microsoftonline.com/"
volumeMounts:
  - name: azure-identity-token
    mountPath: /var/run/secrets/azure/tokens
    readOnly: true
```

The Azure SDK reads these standard env vars automatically — no code changes needed in the application.

---

## 24. Real Implementation Issues Encountered

These are all the real bugs hit during Phase 6 implementation, in the order they occurred. Each one is a genuine production scenario worth understanding.

---

### Issue #1 — ARM64 vs AMD64: `exec format error`

**Error:**
```
exec /docker-entrypoint.sh: exec format error
```

**Root Cause:** Docker images built on Apple Silicon (ARM64 Mac) cannot run on AKS nodes (AMD64 x86 VMs). The CPU architectures are incompatible.

**Fix:**
```bash
docker buildx create --name multiarch --driver docker-container --use
docker buildx build --builder multiarch --platform linux/amd64 \
  -t acrazureshopdev.azurecr.io/user-service:v1.0.0 --push services/user-service/
```
Rebuilt all 8 images with the `--platform linux/amd64` flag.

**Lesson:** Always build production images for `linux/amd64` when developing on Apple Silicon.

---

### Issue #2 — Key Vault Purge Protection: `MethodNotAllowed`

**Error:**
```
MethodNotAllowed: The operation is not allowed on a key vault with purge protection enabled
```

**Root Cause:** We had set `purge_protection_enabled = true` on the Key Vault in Terraform. When the Key Vault was destroyed (by `terraform destroy`), Azure put it in a "soft-deleted" state for 90 days — it cannot be hard-deleted or recreated with the same name during this period.

**Fix:**
```bash
az keyvault recover --name kv-azureshop-6a6c-dev
terraform import -var-file="environments/dev/terraform.tfvars" \
  module.keyvault.azurerm_key_vault.main \
  /subscriptions/.../vaults/kv-azureshop-6a6c-dev
```
Recovered the soft-deleted vault, then imported it into Terraform state.

**Lesson:** Never enable `purge_protection_enabled = true` unless you are certain the Key Vault name will never need to be reused after destroy. In dev environments, leave it disabled.

---

### Issue #3 — Stale Terraform State Lock

**Error:**
```
Error: state blob is already locked
Lock Info:
  ID: 64747e86-fdd8-9ebf-77ef-788b03d5349a
  Operation: OperationTypeApply
```

**Root Cause:** The previous session's `terraform apply` was interrupted (context expired). The Azure Blob storage lock was never released.

**Fix:**
```bash
terraform force-unlock -force 64747e86-fdd8-9ebf-77ef-788b03d5349a
```

**Lesson:** Terraform state locks are stored in Azure Blob. If an apply is interrupted (process killed, network dropout), the lock stays. `force-unlock` is safe as long as no other apply is actually running.

---

### Issue #4 — Stale Terraform State Drift

**Situation:** After the infrastructure was destroyed and rebuilt, Terraform state listed resources (AKS cluster, VNet, Log Analytics) that no longer existed in Azure.

**Root Cause:** `terraform destroy` was not run before the infrastructure was manually deleted. Terraform's state file still pointed to the old resource IDs.

**Fix:** Running `terraform apply` automatically detected the drift — Terraform planned to create the missing resources and applied the plan. No manual intervention needed.

**Lesson:** Terraform reconciles drift on every `plan`/`apply`. If resources vanish outside of Terraform, the next apply recreates them. Always use `terraform destroy` instead of deleting via the portal to keep state in sync.

---

### Issue #5 — AKS RBAC Access Lost After Cluster Recreation

**Error:**
```
Error from server (Forbidden): pods is forbidden: User "..." cannot list resource "pods" in API group "" in the namespace "default"
```

**Root Cause:** The `Azure Kubernetes Service RBAC Cluster Admin` role assignment was scoped to the old AKS cluster resource ID. When the cluster was destroyed and recreated, it got a new resource ID — the old role assignment was gone.

**Fix:**
```bash
az role assignment create \
  --assignee df0cac37-4e4b-4338-875d-a01366185bd3 \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope /subscriptions/.../managedClusters/aks-azureshop-dev

az aks get-credentials --resource-group rg-azureshop-dev --name aks-azureshop-dev
kubelogin convert-kubeconfig -l azurecli
```

**Lesson:** AKS RBAC role assignments are tied to the cluster resource ID. Any operation that destroys and recreates the cluster (including `terraform destroy` + `terraform apply`) requires re-assigning cluster RBAC roles.

---

### Issue #6 — CSI Addon Identity Stale After Cluster Recreation

**Error:**
```
failed to get key vault token: Identity not found
```

**Root Cause:** Each AKS cluster creation generates a new Key Vault Secrets Provider addon with a new managed identity (new Client ID). The SecretProviderClass files still had the old Client ID from the previous cluster.

**Fix:** Updated all 5 SecretProviderClass files with the new CSI addon Client ID:
```bash
az aks show --name aks-azureshop-dev --resource-group rg-azureshop-dev \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -o tsv
# New ID: d755c00c-d37e-47f8-997c-86202a2a77f4
```
Updated `userAssignedIdentityID` in all 5 SecretProviderClass YAML files and reapplied.

**Lesson:** When an AKS cluster is recreated, always retrieve the new CSI addon identity Client ID and update all SecretProviderClass resources.

---

### Issue #7 — api-gateway CHOWN Permission Denied

**Error:**
```
chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
```

**Root Cause:** The standard `nginx:1.27-alpine` image starts as root to set up cache directories, then drops to UID 101. With `capabilities: drop: ALL` in our security context, the container cannot perform `chown` even as root.

**Fix:** Switched to `nginxinc/nginx-unprivileged:1.27-alpine` — a variant of NGINX that runs entirely as a non-root user (UID 101) from start, never needs `chown`, and is designed for security-hardened environments.

```dockerfile
# Before:
FROM nginx:1.27-alpine

# After:
FROM nginxinc/nginx-unprivileged:1.27-alpine
```

**Lesson:** Never use the standard `nginx:alpine` image in a security-hardened Kubernetes environment. Always use `nginx-unprivileged` which is purpose-built for containers with dropped capabilities.

---

### Issue #8 — nginx PID File Permission Denied

**Error:**
```
open() "/run/nginx.pid" failed (13: Permission denied)
```

**Root Cause:** The `nginx-unprivileged` image runs as a non-root user. It cannot write to `/run/nginx.pid` which is owned by root. Our `nginx.conf` did not override the default PID path.

**Fix:** Added PID path and temp directory overrides to `nginx.conf`:

```nginx
pid /tmp/nginx.pid;

http {
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path       /tmp/proxy_temp;
  fastcgi_temp_path     /tmp/fastcgi_temp;
  uwsgi_temp_path       /tmp/uwsgi_temp;
  scgi_temp_path        /tmp/scgi_temp;
  ...
}
```

`/tmp` is writable by all users — the non-root NGINX process can write there.

**Lesson:** Any time you switch to a non-root web server image, audit every path the server writes to. PID files, temp directories, and log files all default to root-owned paths.

---

### Issue #9 — Frontend Readiness Probe 404

**Error:**
```
Readiness probe failed: HTTP probe failed with statuscode: 404
```

**Root Cause:** The frontend Helm values had `probes.path: /health`. Next.js does not have a built-in `/health` route — it returns 404 for unknown paths.

**Fix:** Created a Next.js API route at `pages/api/health.js`:
```javascript
export default function handler(req, res) {
  res.status(200).json({ status: "ok", service: "frontend" });
}
```
Updated probe path from `/health` to `/api/health` in the frontend Helm values. Next.js API routes live under `/api/` and respond at that path.

**Lesson:** Each framework has different conventions for health endpoints. Node.js Express apps typically have `/health` built in. Next.js needs an explicit `pages/api/health.js` file. Always verify your health endpoint returns 200 before setting it as a probe path.

---

### Issue #10 — Cached Docker Image After Tag Bump

**Situation:** After fixing the probe path and bumping the image tag from `v1.0.0` to `v1.0.1`, the pod still showed `404` on the probe. The new image was in ACR but Kubernetes was running the old one.

**Root Cause:** The previous deployment used `imagePullPolicy: IfNotPresent`. Once an image with tag `v1.0.0` was pulled to the node, Kubernetes never pulled it again — even after we pushed a new `v1.0.0`. Since we had not bumped the tag in Helm values before upgrading, the node had a cached copy of the old image.

**Fix:** Bumped the image tag to `v1.0.1` in `helm/charts/frontend/values.yaml` and ran `helm upgrade`. With a new tag, `IfNotPresent` correctly detected the image was not present and pulled the new one from ACR.

**Lesson:** `imagePullPolicy: IfNotPresent` (the recommended default) caches images aggressively. Always bump the image tag when you push a new image — never overwrite an existing tag in production. The only exception is `imagePullPolicy: Always`, but this adds latency to every pod start.

---

### Issue #11 — Federated Identity Credential Already Exists on Terraform Apply

**Error:**
```
a resource with the ID "...fic-notification-service-dev" already exists - to be managed via Terraform
this resource needs to be imported into the State.
```

**Root Cause:** The Federated Identity Credential was created by a `terraform apply` in a previous session that the state file did not record (the apply completed but the session ended before state was fully written, or it was created manually).

**Fix:**
```bash
terraform import \
  -var-file="environments/dev/terraform.tfvars" \
  azurerm_federated_identity_credential.notification_service \
  "/subscriptions/.../userAssignedIdentities/id-notification-service-dev/federatedIdentityCredentials/fic-notification-service-dev"
```
After import, the next `terraform apply` saw no changes needed for that resource.

**Lesson:** When Terraform says "resource already exists, import it," never delete and recreate — use `terraform import`. Deletion would disrupt any services depending on that resource.

---

## 25. Additional Interview Questions — Steps 6.5 to 6.8

### Ingress and Routing

**Q: What is a Kubernetes Ingress resource and how is it different from a Service of type LoadBalancer?**

A: A **Service of type LoadBalancer** provisions one Azure Load Balancer per service — one public IP per service. With 8 services, you get 8 public IPs and 8 load balancers, which is expensive and hard to manage. A **Kubernetes Ingress** is a routing rule that sits in front of multiple services. The Ingress Controller (in our case NGINX) is the single LoadBalancer that receives all traffic. The Ingress resource defines routing rules — for example, path `/api/` goes to api-gateway, path `/` goes to frontend. All 8 services share one public IP and one Azure Load Balancer, saving cost and centralising traffic management.

---

**Q: What is the NGINX Ingress Controller and what does it actually do?**

A: The NGINX Ingress Controller is a Kubernetes controller that watches for Ingress resources and dynamically configures an NGINX reverse proxy to match those rules. When you create or update an Ingress object, the controller re-renders the NGINX config and reloads it without downtime. In Azure, it runs as a Deployment and creates a Service of type LoadBalancer — Azure provisions a public IP and load balancer for it. All traffic enters through this single IP, and NGINX forwards it to the correct Service based on the path or hostname rules in your Ingress objects.

---

**Q: Why was HTTP (port 80) blocked from the internet to your AKS cluster?**

A: The AKS subnet has an NSG (Network Security Group) with explicit inbound rules. Our NSG allows: HTTPS (port 443) from the internet, load balancer health probes (source `AzureLoadBalancer`), and VNet-internal traffic. HTTP (port 80) is not in the allow list — this is intentional. In a production setup, all external traffic should be HTTPS (encrypted). HTTP would typically be redirected to HTTPS at the ingress layer. For development verification we used `kubectl port-forward` to bypass the NSG and test locally. For end users, the App Gateway (Phase 7) handles TLS termination and forwards HTTPS traffic into the cluster.

---

### Network Policies

**Q: How did you test that your NetworkPolicy was actually working?**

A: We ran two tests:

1. **Allowed path:** Deployed a curl pod in the `dev` namespace and hit `user-service:3001/health`. Got HTTP 200 — same-namespace traffic is allowed by the NetworkPolicy's ingress rule.

2. **Blocked path:** Deployed a curl pod in the `staging` namespace and tried to reach `user-service.dev.svc.cluster.local:3001`. Got HTTP 000 (connection timed out) — cross-namespace traffic from staging is not in user-service's ingress allow list, so Azure CNI's policy engine dropped the packets.

The timeout (not TCP reset) is characteristic of a NetworkPolicy drop — the packets are silently discarded at the virtual switch level, not rejected by the application.

---

**Q: If NetworkPolicy is declared in YAML, what actually enforces it in AKS?**

A: The Kubernetes API stores NetworkPolicy objects, but they have no effect without a network policy engine. In our cluster, we set `network_policy = "azure"` in the AKS Terraform config. This tells AKS to use the Azure NPM (Network Policy Manager), which is a DaemonSet that runs on every node and programs `iptables` rules based on the NetworkPolicy objects. When a packet arrives at a pod, the node's kernel checks these iptables rules before delivering it. Without `network_policy = "azure"` (or `calico`), NetworkPolicy objects are stored but completely ignored.

---

### Terraform State Management

**Q: What is a Terraform state lock and how do you handle a stale one?**

A: When `terraform apply` starts, it writes a lock to the state backend (in our case an Azure Blob Storage blob) to prevent two simultaneous applies from corrupting the state. The lock contains a lock ID, who created it, and when. If the apply process is killed (terminal closed, network dropout, context expired), the lock is never released. The next apply fails with "state blob is already locked."

To resolve it, first verify no apply is actually running, then force-unlock:
```bash
terraform force-unlock -force <lock-id>
```
The lock ID is shown in the error message. This is safe because we verified the apply is not running — we are not overwriting a live apply.

---

**Q: What does `terraform import` do and when do you need it?**

A: `terraform import` adds an existing Azure resource into Terraform's state file without creating or modifying the resource. You need it when a resource exists in Azure but Terraform does not know about it — either because it was created manually, created by a previous apply whose state was not saved, or created by another tool. Without import, `terraform apply` fails with "resource already exists." With import, Terraform takes ownership of the resource and manages it going forward. The resource's configuration in `.tf` files must match what is in Azure, or the next apply will try to update it to match.

---

### Workload Identity

**Q: Walk me through exactly what happens when a notification-service pod starts and needs to call Key Vault.**

A: When the pod is scheduled:

1. The Workload Identity webhook sees the pod has label `azure.workload.identity/use: "true"`. It mutates the pod spec — injects `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_FEDERATED_TOKEN_FILE`, and mounts a projected ServiceAccount token signed by the AKS OIDC issuer into the pod.

2. When the application code calls the Azure Key Vault SDK, the SDK reads `AZURE_CLIENT_ID` and `AZURE_FEDERATED_TOKEN_FILE` automatically (using `DefaultAzureCredential`).

3. The SDK reads the projected token (a JWT signed by AKS) and sends it to Azure AD with a token exchange request: "I have this K8s token, issue me an Azure AD token for Managed Identity `2e5e41cb-...`."

4. Azure AD validates the K8s token by fetching the AKS OIDC public keys from the issuer URL. It checks the Federated Identity Credential — is there one for this issuer and subject (`system:serviceaccount:dev:notification-service`)? Yes. It issues a short-lived Azure AD access token for the Managed Identity.

5. The SDK uses the Azure AD token to call Key Vault. Key Vault checks RBAC — the Managed Identity has `Key Vault Secrets User`. Access granted.

6. The whole flow took milliseconds, involved no stored credentials, and produces a token that expires in 1 hour.

---

**Q: What is a Federated Identity Credential and what does it actually contain?**

A: A Federated Identity Credential (FIC) is a rule attached to a Managed Identity that defines which external identity providers can impersonate it. It has three fields:

- **issuer** — the OIDC endpoint URL of the trusted token issuer (our AKS cluster's OIDC URL).
- **subject** — the `sub` claim in the incoming token that must match (`system:serviceaccount:dev:notification-service`).
- **audience** — the `aud` claim that must be present in the token (`api://AzureADTokenExchange`).

All three must match for Azure AD to accept the token exchange. The `subject` field is what makes it scoped to a specific Kubernetes ServiceAccount in a specific namespace — not any pod in the cluster, only the `notification-service` ServiceAccount in the `dev` namespace.

---

**Q: Why use a User Assigned Managed Identity instead of a System Assigned one for Workload Identity?**

A: A System Assigned Managed Identity is tied to the lifecycle of the resource it is attached to — if the AKS cluster is deleted, the identity is deleted. A User Assigned Managed Identity is an independent Azure resource with its own lifecycle. For Workload Identity, we use User Assigned because:

1. We can create it in Terraform before the AKS cluster exists and reference it.
2. If the AKS cluster is destroyed and recreated, the identity survives — role assignments and Federated Credentials are preserved.
3. The same identity can be used by pods across multiple clusters.
4. The Client ID is stable across cluster recreations — no need to update Helm values when the cluster is rebuilt.

---

**Q: What happens if you forget to add `azure.workload.identity/use: "true"` to the pod but the ServiceAccount annotation is present?**

A: Nothing works. The label on the pod is the trigger for the Workload Identity webhook. Without it, the webhook does not mutate the pod — no env vars are injected, no token file is projected. The application code would call `DefaultAzureCredential`, find no credentials, and fail with an authentication error. The ServiceAccount annotation alone is not enough — both the annotation (which tells the webhook which Managed Identity to use) and the pod label (which tells the webhook to act on this pod) are required.

---

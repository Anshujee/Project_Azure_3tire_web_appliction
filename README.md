# AzureShop — 3-Tier E-Commerce DevOps Project

A production-grade e-commerce platform built entirely on Azure, demonstrating end-to-end DevOps practices: Infrastructure as Code, containerised microservices, CI/CD pipelines, Kubernetes deployment, monitoring, and security.

> **Focus:** Azure DevOps engineering — not e-commerce business logic.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Full Architecture Diagram](#2-full-architecture-diagram)
3. [Technology Stack](#3-technology-stack)
4. [Project Structure](#4-project-structure)
5. [Microservices — What Each Does](#5-microservices--what-each-does)
6. [How Services Connect and Communicate](#6-how-services-connect-and-communicate)
7. [Request Lifecycle — End to End](#7-request-lifecycle--end-to-end)
8. [Infrastructure (Terraform Modules)](#8-infrastructure-terraform-modules)
9. [Azure Networking — How Traffic Flows](#9-azure-networking--how-traffic-flows)
10. [Data Storage — Which Service Uses What](#10-data-storage--which-service-uses-what)
11. [Security Architecture](#11-security-architecture)
12. [Key DevOps Concepts Used](#12-key-devops-concepts-used)
13. [Environments](#13-environments)
14. [Git Workflow](#14-git-workflow)
15. [Port Reference](#15-port-reference)
16. [Environment Variables Reference](#16-environment-variables-reference)
17. [Phase Progress](#17-phase-progress)

---

## 1. Project Overview

| Field | Value |
|---|---|
| **Project Name** | AzureShop |
| **Architecture** | 3-tier microservices e-commerce |
| **Cloud** | Microsoft Azure only |
| **CI/CD** | Azure Pipelines (YAML-based) |
| **IaC** | Terraform (remote state in Azure Blob) |
| **Container Platform** | AKS (Azure Kubernetes Service) |
| **Branching Strategy** | GitFlow (feature → dev → main) |
| **Started** | 2026-05-08 |
| **Completed** | 2026-05-16 (all 9 phases) |
| **Status** | All phases complete — infrastructure destroyed 2026-05-16 for cost saving |

**What "3-tier" means:**

```
Tier 1 — Presentation:   Frontend (Next.js) served via API Gateway
Tier 2 — Application:    6 backend microservices (Node.js + Python)
Tier 3 — Data:           Azure SQL + Cosmos DB + Redis Cache
```

---

## 2. Full Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTPS (443)
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Azure Application Gateway  (WAF v2)                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  WAF Policy: OWASP 3.2 + Microsoft BotManager (Prevention)  │   │
│  │  SSL Termination │ HTTP→HTTPS Redirect │ Autoscale 1–5      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│  Public IP: pip-appgw-azureshop-{env}  (Static, Standard SKU)       │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTP (internal)  subnet-appgw 10.3.0.0/24
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AKS Cluster  (Azure Kubernetes Service)           │
│                    aks-azureshop-{env}   subnet-aks 10.1.0.0/16     │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              NGINX API Gateway  (port 8080)                  │   │
│  │   Rate limiting │ Request logging │ Upstream routing         │   │
│  └──┬───────┬────────┬───────┬──────┬────────────┬─────────────┘   │
│     │       │        │       │      │            │                  │
│     ▼       ▼        ▼       ▼      ▼            ▼                  │
│  ┌──────┐ ┌──────┐ ┌─────┐ ┌─────┐ ┌─────────┐ ┌──────────────┐  │
│  │User  │ │Prod- │ │Cart │ │Order│ │Payment  │ │Notification  │  │
│  │Svc   │ │uct   │ │Svc  │ │Svc  │ │Svc      │ │Svc           │  │
│  │:3001 │ │Svc   │ │:3003│ │:3004│ │:3005    │ │:3006         │  │
│  │Node  │ │:3002 │ │Node │ │Node │ │Node     │ │Node          │  │
│  │.js   │ │Python│ │.js  │ │.js  │ │.js      │ │.js           │  │
│  └──┬───┘ └──┬───┘ └──┬──┘ └──┬──┘ └────┬────┘ └──────┬───────┘  │
│     │        │         │       │         │              │           │
│     │  ┌─────────────────────────────────────────────┐ │           │
│     │  │          Frontend (Next.js)  :3000          │ │           │
│     │  │   Product listing │ Cart │ Login/Register   │ │           │
│     │  └─────────────────────────────────────────────┘ │           │
│     │                                                   │           │
└─────┼───────────────────────────────────────────────────┼───────────┘
      │                                                   │
      │  Azure VNet 10.0.0.0/8      subnet-db 10.2.0.0/24│
      ▼                                                   │
┌──────────────────────────────────────────────┐         │
│              Azure SQL Server                │         │
│    sql-azureshop-{env}.database.windows.net  │         │
│  ┌─────────────┐  ┌─────────────────────┐   │         │
│  │  db-users   │  │     db-orders       │   │         │
│  │ (user-svc)  │  │  (order-service)    │   │         │
│  └─────────────┘  └─────────────────────┘   │         │
└──────────────────────────────────────────────┘         │
                                                         │
┌──────────────────────────────────────────────┐         │
│              Azure Cosmos DB                 │         │
│   cosmos-azureshop-{env}.documents.azure.com │         │
│  ┌──────────────────┐  ┌───────────────────┐ │         │
│  │   products       │  │      cart         │ │         │
│  │  /categoryId     │  │    /userId        │ │         │
│  │  (product-svc)   │  │  TTL: 7 days      │ │         │
│  └──────────────────┘  └───────────────────┘ │         │
└──────────────────────────────────────────────┘         │
                                                         │
┌──────────────────────────────────────────────┐         │
│              Azure Redis Cache               │◄────────┘
│   redis-azureshop-{env}.redis.cache.windows  │
│   TLS port 6380 │ Standard C1 │ volatile-lru │
│   Cart session caching  (cart-service)        │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│          Azure Service Bus  (Topic)           │
│         topic: "orders"                      │
│  ┌─────────────────┐  ┌──────────────────┐  │
│  │  subscription:  │  │  subscription:   │  │
│  │payment-service  │  │notification-svc  │  │
│  └─────────────────┘  └──────────────────┘  │
│    order-service PUBLISHES order.placed      │
│    payment + notification SUBSCRIBE          │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│              Azure Key Vault                 │
│          kv-azureshop-{env}                  │
│  Secrets: sql-server-fqdn                   │
│           sql-admin-password                │
│           cosmos-endpoint                   │
│           cosmos-primary-key                │
│           redis-hostname                    │
│           redis-primary-access-key          │
│  RBAC: AKS pods → Secrets User (read-only)  │
│        Pipelines → Secrets Officer (rw)      │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│      Azure Container Registry  (ACR)         │
│    acrazureshop{env}.azurecr.io              │
│    Premium SKU │ admin_enabled = false       │
│    AKS kubelet identity → AcrPull role       │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│              Azure Monitoring                │
│  Log Analytics Workspace: law-azureshop-{env}│
│  Application Insights: one per service (×8)  │
│  Grafana Dashboard: grafana-azureshop-{env}  │
│  AKS Diagnostic Settings → Log Analytics    │
└──────────────────────────────────────────────┘
```

---

## 3. Technology Stack

| Category | Service / Tool | Purpose |
|---|---|---|
| Source Control | Azure Repos | Git repositories |
| CI/CD | Azure Pipelines | Automated build and deploy |
| Project Tracking | Azure Boards | Epics, Issues, Tasks |
| IaC | Terraform | Provision all Azure resources |
| State Storage | Azure Blob Storage | Terraform remote state |
| Container Runtime | Docker | Build and package services |
| Container Registry | Azure Container Registry (ACR) | Store Docker images |
| Compute | AKS (Kubernetes) | Run microservices |
| Ingress | NGINX (in-cluster) | Internal routing + rate limiting |
| WAF / LB | Azure Application Gateway v2 | External entry point + WAF |
| Relational DB | Azure SQL Database | Users, Orders |
| NoSQL DB | Azure Cosmos DB (SQL API) | Products, Cart |
| Cache | Azure Redis Cache | Session caching |
| Messaging | Azure Service Bus | Async event-driven communication |
| Secrets | Azure Key Vault | Credentials, keys, connection strings |
| Networking | Azure VNet + NSG + Bastion | Secure network isolation |
| Identity | SystemAssigned Managed Identity | No credentials to rotate |
| Monitoring | Azure Monitor + App Insights | Metrics, traces, logs |
| Dashboards | Azure Managed Grafana | Visual dashboards |
| Security | Microsoft Defender for Cloud | Threat protection |
| Governance | Azure Policy | Compliance enforcement |
| Frontend | Next.js 14 | Customer-facing storefront |
| API Gateway | NGINX | Service routing |
| Backend | Node.js / Express | 6 of 7 backend services |
| Backend | Python / FastAPI | product-service |

---

## 4. Project Structure

```
AzureShop/
│
├── infra/                          # Terraform — all Azure infrastructure
│   ├── backend.tf                  # Remote state config (partial — key per env)
│   ├── providers.tf                # azurerm ~> 3.110.0
│   ├── variables.tf                # All input variables
│   ├── main.tf                     # Root module — wires all 7 child modules
│   ├── outputs.tf                  # Resource group, location
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── backend.hcl         # key = "dev.tfstate"
│   │   │   └── terraform.tfvars    # dev variable values
│   │   ├── staging/
│   │   │   ├── backend.hcl         # key = "staging.tfstate"
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   │       ├── backend.hcl         # key = "prod.tfstate"
│   │       └── terraform.tfvars
│   └── modules/
│       ├── networking/             # VNet, subnets, NSGs, Bastion
│       ├── acr/                    # Container Registry + AcrPull role
│       ├── aks/                    # Kubernetes cluster (2 node pools)
│       ├── databases/              # SQL + Cosmos DB + Redis
│       ├── keyvault/               # Vault + role assignments + 8 secrets
│       ├── appgateway/             # WAF v2 + public IP + routing rules
│       └── monitoring/             # Log Analytics + App Insights ×8 + Grafana
│
├── services/                       # Microservices source code
│   ├── user-service/               # Node.js — auth, JWT, Azure SQL
│   ├── product-service/            # Python/FastAPI — products, Cosmos DB
│   ├── cart-service/               # Node.js — cart, Redis
│   ├── order-service/              # Node.js — orders, SQL, Service Bus publisher
│   ├── payment-service/            # Node.js — mock payments, Service Bus subscriber
│   ├── notification-service/       # Node.js — event logger, Service Bus subscriber
│   ├── frontend/                   # Next.js 14 — storefront
│   └── api-gateway/                # NGINX — routing + rate limiting
│
├── helm/                           # Helm charts for Kubernetes (Phase 6)
│   ├── charts/                     # One chart per service
│   └── values/
│       ├── dev.yaml
│       ├── staging.yaml
│       └── prod.yaml
│
├── pipelines/                      # Azure Pipeline YAML files (Phase 5)
│   ├── templates/
│   │   ├── build-template.yaml
│   │   ├── deploy-template.yaml
│   │   └── test-template.yaml
│   ├── ci/                         # One CI pipeline per service
│   └── cd/
│       ├── deploy-dev.yaml
│       ├── deploy-staging.yaml
│       └── deploy-prod.yaml
│
├── k8s/                            # Raw Kubernetes manifests (Phase 6)
│   ├── namespaces/
│   ├── configmaps/
│   └── network-policies/
│
└── docs/                           # Documentation
    ├── azure-boards-setup.md
    └── azure-boards-work-items-import.csv
```

Each service follows the same internal structure:

```
services/<service-name>/
├── src/                    # Application source (Node.js)
│   ├── index.js            # Entry point — connects to DB, starts server
│   ├── db.js               # Database connection pool
│   ├── messaging.js        # Service Bus publisher/subscriber
│   └── routes/
│       └── *.js            # Express route handlers
├── app/                    # Application source (Python/FastAPI)
│   ├── main.py             # FastAPI app + lifespan
│   ├── db.py               # Cosmos DB client
│   └── routes/
│       └── *.py            # FastAPI routers
├── tests/                  # Unit and integration tests
├── Dockerfile              # Multi-stage build
├── .dockerignore
└── .env.example            # Template — never commit the actual .env
```

---

## 5. Microservices — What Each Does

### user-service (Node.js · port 3001)
**Database:** Azure SQL → `db-users`

Handles user identity. Registers users (bcrypt password hashing), authenticates them (JWT tokens), and serves profile data.

| Method | Endpoint | Auth | What it does |
|---|---|---|---|
| POST | `/auth/register` | None | Hash password, insert user, return `{id, email, name}` |
| POST | `/auth/login` | None | Verify password, return signed JWT (24h expiry) |
| GET | `/users/:id` | JWT | Return user profile (no password hash) |
| GET | `/health` | None | DB connectivity status |

---

### product-service (Python/FastAPI · port 3002)
**Database:** Azure Cosmos DB → `azureshop-db` → container `products` (partition: `/categoryId`)

Manages the product catalog. The only Python service — uses FastAPI for automatic Pydantic validation and OpenAPI docs at `/docs`.

| Method | Endpoint | What it does |
|---|---|---|
| GET | `/products` | List all products (cross-partition), or `?category=X` (partition-key query) |
| GET | `/products/{id}` | Point read with `?categoryId=X`, or cross-partition scan |
| POST | `/products` | Create product — UUID auto-generated as `id` |
| GET | `/health` | Cosmos DB connectivity status |

---

### cart-service (Node.js · port 3003)
**Database:** Azure Redis Cache (TLS port 6380)

Stores shopping cart as a Redis hash. Each cart is a key (`cart:{userId}`) containing hash fields, one per item. 7-day TTL resets on every add.

| Method | Endpoint | What it does |
|---|---|---|
| GET | `/cart/:userId` | `HGETALL cart:{userId}` — all items as array |
| POST | `/cart/:userId/items` | `HSET` + `EXPIRE` (reset 7-day TTL) |
| DELETE | `/cart/:userId/items/:itemId` | `HDEL` — remove one item |
| DELETE | `/cart/:userId` | `DEL` — clear entire cart |
| GET | `/health` | Redis connectivity status |

---

### order-service (Node.js · port 3004)
**Database:** Azure SQL → `db-orders`
**Messaging:** Azure Service Bus → publishes to topic `orders`

Places orders, stores them in SQL, and fires an `order.placed` event to Service Bus (fire-and-forget — messaging failure does not fail the HTTP response).

| Method | Endpoint | What it does |
|---|---|---|
| POST | `/orders` | Insert order, publish `order.placed` event |
| GET | `/orders/user/:userId` | Order history for a user |
| GET | `/orders/:orderId` | Single order with items JSON |
| PUT | `/orders/:orderId/status` | Update status (pending/confirmed/shipped/delivered/cancelled) |
| GET | `/health` | DB + messaging connectivity |

---

### payment-service (Node.js · port 3005)
**Messaging:** Azure Service Bus → subscribes to `orders` topic, subscription `payment-service`

Mock payment processor. Subscribes to `order.placed` events and auto-approves all payments. Also exposes a direct HTTP endpoint for testing.

| Method | Endpoint | What it does |
|---|---|---|
| POST | `/payments` | Direct payment request — always approves |
| GET | `/payments/:orderId` | Look up payment by order ID |
| GET | `/health` | Service Bus connectivity |

---

### notification-service (Node.js · port 3006)
**Messaging:** Azure Service Bus → subscribes to `orders` topic, subscription `notification-service`

Subscribes to `order.placed` and `payment.processed` events and logs a formatted notification (simulates email/SMS). No HTTP endpoints beyond health.

| Method | Endpoint | What it does |
|---|---|---|
| GET | `/health` | Service Bus connectivity |

---

### frontend (Next.js · port 3000)

Customer storefront. All API calls go through the API Gateway (`NEXT_PUBLIC_API_URL`). Uses `output: 'standalone'` for minimal Docker images.

| Page | Route | What it shows |
|---|---|---|
| Home | `/` | Product listing with "Add to Cart" |
| Cart | `/cart` | Cart items, remove, checkout |
| Login | `/login` | Sign in / Register toggle |

---

### api-gateway (NGINX · port 8080)

The single entry point for all browser requests inside the cluster. Adds rate limiting and routes `/api/*` paths to the correct backend service.

| Path | Upstream | Rate limit |
|---|---|---|
| `/api/users/auth/` | user-service:3001 | 10 req/min (anti brute-force) |
| `/api/users/` | user-service:3001 | 60 req/min |
| `/api/products/` | product-service:3002 | 60 req/min |
| `/api/cart/` | cart-service:3003 | 60 req/min |
| `/api/orders/` | order-service:3004 | 60 req/min |
| `/api/payments/` | payment-service:3005 | 60 req/min |
| `/` | frontend:3000 | — |

---

## 6. How Services Connect and Communicate

There are three distinct communication channels in this project:

### Channel 1: Synchronous HTTP (Browser → App Gateway → NGINX → Services)

```
Browser
  ──HTTPS──► Application Gateway (WAF, SSL terminate, public IP)
               ──HTTP──► api-gateway (NGINX, port 8080)
                           ──HTTP──► user-service:3001
                           ──HTTP──► product-service:3002
                           ──HTTP──► cart-service:3003
                           ──HTTP──► order-service:3004
                           ──HTTP──► payment-service:3005
                           ──HTTP──► frontend:3000
```

- NGINX uses Kubernetes DNS to resolve service names (`user-service` → ClusterIP)
- Every request carries `X-Real-IP` and `X-Forwarded-For` headers added by NGINX so backend services know the original client IP
- SSL terminates at Application Gateway — all traffic inside the cluster is plain HTTP

### Channel 2: Asynchronous Messaging (Service Bus Topic/Subscription)

```
order-service
  ──PUBLISH──► Service Bus topic "orders"
                    │
       ┌────────────┴──────────────┐
       ▼                           ▼
  subscription:              subscription:
  "payment-service"          "notification-service"
       │                           │
  payment-service            notification-service
  processes payment          logs notification
  (auto-approves mock)       (console output mock)
```

- **Topic vs Queue:** A queue delivers each message to exactly ONE consumer. A topic delivers a copy to EVERY subscription. Both payment and notification need the same `order.placed` event — hence a topic.
- `message.complete()` removes the message only from that subscription. The other subscription's copy is unaffected.
- order-service uses **fire-and-forget**: it doesn't await the publish. The order is saved to SQL regardless of whether the event reaches downstream services.

### Channel 3: Direct DB Access (Services → Databases)

```
user-service    ──mssql──► Azure SQL (db-users)
order-service   ──mssql──► Azure SQL (db-orders)
product-service ──azure-cosmos──► Cosmos DB (products container)
cart-service    ──ioredis──► Redis Cache (port 6380 TLS)
```

- All connections use credentials injected from Key Vault via the CSI driver (Phase 6)
- All databases are **not publicly accessible** — only the AKS subnet (10.1.0.0/16) is whitelisted
- Azure SQL firewall rule: `10.1.0.0 – 10.1.255.255`
- Cosmos DB virtual network filter: `aks_subnet_id` only
- Redis: TLS-only (port 6380), no plain-text port 6379

### How Services Know Where to Find Each Other (Kubernetes DNS)

In Kubernetes, every Service resource gets a DNS entry automatically:

```
http://user-service:3001       → resolves to ClusterIP of user-service Service
http://product-service:3002    → resolves to ClusterIP of product-service Service
```

NGINX `upstream` blocks use these names directly. No hardcoded IPs. When a pod restarts and gets a new IP, the Service ClusterIP stays the same and DNS keeps working.

---

## 7. Request Lifecycle — End to End

### Example: User adds a product to cart

```
1. Browser → GET https://azureshop.com/api/products?category=Electronics
                     │
2.          Application Gateway
            - WAF checks request against OWASP 3.2 rules
            - SSL terminates here
            - Forwards to NGINX on HTTP
                     │
3.          NGINX api-gateway
            - Checks rate limit (60r/m for /api/products/)
            - proxy_pass → product-service:3002
                     │
4.          product-service (FastAPI)
            - Receives GET /products?category=Electronics
            - Queries Cosmos DB: partition-key query on /categoryId = "Electronics"
            - Returns JSON array of products
                     │
5.          Response flows back: product-service → NGINX → App Gateway → Browser

6. User clicks "Add to Cart"
   Browser → POST https://azureshop.com/api/cart/user-123/items
                     │
7.          NGINX → cart-service:3003
            cart-service: HSET cart:user-123 item-xyz "{...}"  +  EXPIRE 604800
```

### Example: User places an order

```
1. Browser → POST /api/orders  { userId, items, totalAmount }
                     │
2.          NGINX → order-service:3004
                     │
3.          order-service:
            a. INSERT INTO orders ... → Azure SQL (db-orders)
            b. publishOrderPlaced(order)  ← fire-and-forget, no await
            c. return 201 Created to browser immediately
                     │
4.          [async] Service Bus delivers order.placed to:
            ├── payment-service subscription:
            │     Reads message → stores payment approved in-memory
            │     message.complete()
            │
            └── notification-service subscription:
                  Reads message → logs "Order confirmation for user X"
                  message.complete()
```

---

## 8. Infrastructure (Terraform Modules)

All Azure resources are defined as Terraform code in `infra/modules/`. Nothing is created manually in the portal.

### How to run Terraform

```bash
# Set sensitive variables — never put these in tfvars files
export TF_VAR_sql_admin_password="YourStr0ng@Password"

# Init with environment-specific backend
cd infra/
terraform init -backend-config="environments/dev/backend.hcl"

# Preview
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Module dependency order

```
monitoring ──────────────► creates Log Analytics Workspace (no dependencies)
                                │ workspace_id
                                ▼
aks ◄─────── needs workspace ID (Container Insights)
  │          creates cluster + kubelet identity
  │
  ├──► acr gets kubelet_identity_object_id (AcrPull role grant)
  └──► keyvault gets kubelet_identity_object_id (Secrets User role grant)

networking ──► creates subnets
  ├──► aks.subnet_id
  ├──► databases.aks_subnet_id (firewall allow rule)
  └──► appgateway.appgw_subnet_id

databases ──► creates SQL/Cosmos/Redis, outputs connection details
  └──► keyvault stores them as 8 secrets (sql-server-fqdn, cosmos-primary-key, etc.)

main.tf ──► azurerm_monitor_diagnostic_setting (uses both aks + monitoring outputs)
            Placed here to break the circular dependency
```

### Remote state separation

```
Storage account:  myprojectazshoptfstate
Container:        tfstate
│
├── dev.tfstate      ← terraform init -backend-config="environments/dev/backend.hcl"
├── staging.tfstate  ← terraform init -backend-config="environments/staging/backend.hcl"
└── prod.tfstate     ← terraform init -backend-config="environments/prod/backend.hcl"
```

Each environment has its own state file. Destroying dev doesn't affect staging or prod state.

---

## 9. Azure Networking — How Traffic Flows

```
Azure VNet: 10.0.0.0/8
│
├── subnet-appgw:   10.3.0.0/24   Application Gateway lives here
│   NSG: allow HTTP 80, HTTPS 443 from Internet
│         allow 65200–65535 from GatewayManager (Azure requirement)
│
├── subnet-aks:     10.1.0.0/16   AKS nodes + pods live here
│   NSG: allow HTTPS 443 (API server)
│         allow VNet-to-VNet (pod communication)
│         allow AzureLoadBalancer probes
│         deny everything else
│
├── subnet-db:      10.2.0.0/24   Reserved for future private endpoints
│   NSG: allow SQL 1433 from subnet-aks only
│         allow Redis 6380 from subnet-aks only
│         allow HTTPS 443 from subnet-aks only
│         deny everything else (databases unreachable from internet)
│
└── AzureBastionSubnet: 10.4.0.0/24   Azure Bastion lives here
    NSG: allow HTTPS 443 from Internet inbound
          allow SSH 22 + RDP 3389 outbound to VNet
```

**Azure CNI networking (important):**
With Azure CNI, every Kubernetes pod gets a real IP from `subnet-aks` (10.1.0.0/16). This means:
- The SQL firewall rule `10.1.0.0–10.1.255.255` allows pod traffic directly
- No NAT or overlay network translation
- NSG rules apply directly to pods

**Azure Bastion:**
Secure browser-based SSH/RDP to VMs without opening port 22/3389 to the internet. Users connect via the Azure Portal on HTTPS 443.

---

## 10. Data Storage — Which Service Uses What

| Service | Storage | Why |
|---|---|---|
| user-service | Azure SQL `db-users` | Relational, ACID, user records + password hashes |
| order-service | Azure SQL `db-orders` | Relational, transactions, order history |
| product-service | Cosmos DB `products` container | Document store, flexible schema, fast category queries |
| cart-service | Redis Cache | Sub-millisecond read/write, TTL auto-expiry, ephemeral data |
| payment-service | In-memory (Map) | Demo only — no persistence needed for mock |
| notification-service | None | Event-driven only, no storage |
| frontend | None | Stateless SSR/CSR |

### Cosmos DB partition key choices

| Container | Partition Key | Reasoning |
|---|---|---|
| `products` | `/categoryId` | Most queries filter by category — keeps related products in one partition |
| `cart` | `/userId` | Every cart operation is for one user — co-locate user's data |

### Redis hash structure for cart

```
Key:    cart:user-123          ← Redis HASH type
Fields:
  item-abc  →  {"itemId":"item-abc","productId":"p1","name":"Phone","price":499,"qty":1}
  item-def  →  {"itemId":"item-def","productId":"p2","name":"Case","price":19,"qty":2}
TTL: 7 days — resets on every HSET
```

Using a hash (not a single JSON string) means add/remove one item is O(1) and atomic, without rewriting the entire cart.

---

## 11. Security Architecture

### Secret management flow

```
Terraform apply
  → Creates secrets in Key Vault (sql-admin-password, cosmos-primary-key, etc.)
  → Sources values from databases module outputs

At runtime (Kubernetes):
  AKS pod → SecretProviderClass → Key Vault CSI Driver
  → Mounts secret as file OR env var inside pod
  → Secret rotates automatically every 2 minutes if changed in Key Vault

Secrets NEVER appear in:
  ✗ terraform.tfvars
  ✗ Kubernetes ConfigMaps
  ✗ Docker images
  ✗ Git history
  ✓ Only in Azure Key Vault
```

### RBAC model for Key Vault

| Identity | Role | Can do |
|---|---|---|
| AKS kubelet (pods) | Key Vault Secrets User | Read secrets only |
| Terraform executor | Key Vault Secrets Officer | Read + write secrets |
| Azure DevOps pipeline SP | Key Vault Secrets Officer | Read + write secrets |

### Container security

- All Dockerfiles create a non-root user and switch with `USER`
- `admin_enabled = false` on ACR — authentication uses Managed Identity, not shared passwords
- `minimum_tls_version = "1.2"` on SQL and Redis
- ACR images scanned by Microsoft Defender for Containers (Phase 8)

### WAF rules applied

- OWASP Core Rule Set 3.2 — covers SQL injection, XSS, command injection, path traversal
- Microsoft BotManager 1.0 — blocks known malicious bots by IP reputation
- Mode: Prevention — requests matching rules are **blocked** (not just logged)

---

## 12. Key DevOps Concepts Used

### Warn-and-continue (graceful degradation)

Every service starts even if its database is unreachable. The health endpoint reports the real state:

```json
{ "status": "degraded", "service": "cart-service", "cache": "disconnected" }
```

This matters because Kubernetes uses `/health` for liveness probes. If a service crashed on DB failure, Kubernetes would restart it endlessly while the DB was just slow to start.

### Multi-stage Docker builds

```
Node.js:    deps (npm ci) → runtime (copy node_modules + src only)
Python:     builder (pip --user) → runtime (copy .local + app only)
Next.js:    deps → builder (next build) → runtime (standalone output only)
```

Stage 1 has build tools. Stage 2 starts clean. Final image is 3–5× smaller and has fewer attack surface packages.

### Terraform partial backend config

```hcl
# backend.tf — common config, no key
backend "azurerm" {
  storage_account_name = "myprojectazshoptfstate"
  container_name       = "tfstate"
}
```

```bash
# key passed at runtime — one state file per environment
terraform init -backend-config="environments/dev/backend.hcl"  # key = "dev.tfstate"
```

### for_each in Terraform

```hcl
resource "azurerm_application_insights" "services" {
  for_each = toset(var.services)    # ["user-service", "product-service", ...]
  name     = "appi-${each.key}-${var.environment}"
}
```

One block creates 8 Application Insights instances. `each.key` is the current item.

### Dynamic blocks

```hcl
dynamic "oms_agent" {
  for_each = var.log_analytics_workspace_id != null ? [1] : []
  content { log_analytics_workspace_id = var.log_analytics_workspace_id }
}
```

`for_each = [1]` creates the block. `for_each = []` skips it. Conditional resource configuration without `count` hacks.

### lifecycle ignore_changes

```hcl
lifecycle {
  ignore_changes = [node_count]
}
```

AKS autoscaler changes `node_count` at runtime. Without this, every `terraform apply` would reset it to the initial value — fighting the autoscaler.

### Fire-and-forget messaging

```js
// order-service — publishes without awaiting
publishOrderPlaced(order);   // no await
res.status(201).json(order); // response already sent
```

The order record in SQL is the source of truth. Messaging is best-effort. A Service Bus blip doesn't roll back the order.

### Sensitive variables in Terraform

```hcl
variable "sql_admin_password" {
  sensitive = true   // masked in all plan/apply output
}
```

```bash
# Never in tfvars — always via environment variable
export TF_VAR_sql_admin_password="YourStr0ng@Password"
```

---

## 13. Environments

| Environment | Purpose | Log Retention | SQL Admin Password |
|---|---|---|---|
| `dev` | Development, testing | 30 days | `export TF_VAR_sql_admin_password=...` |
| `staging` | Pre-production validation | 60 days | `export TF_VAR_sql_admin_password=...` |
| `prod` | Live production | 90 days | Azure DevOps Variable Group `vg-prod` (Key Vault linked) |

**Prod rule:** Never apply Terraform locally. Use Azure Pipeline only. Requires manual approval gate.

---

## 14. Git Workflow

This project follows GitFlow:

```
main         ← production-ready, branch policies enforced, no direct push
  │
  └── dev    ← integration branch, CI must pass before merge
        │
        └── feature/phase-N-*    ← all work happens here

Hotfixes: hotfix/* → PR → main → backmerge to dev
Releases:  release/* → PR → main (when ready to ship)
```

**Branch policies on `main`:**
- Require PR + minimum 1 reviewer
- Require linked work item
- Block direct push

**Branch policies on `dev`:**
- Require PR + build validation (CI must pass)

**Commit convention:**
```
feat(scope):  new feature
fix(scope):   bug fix
docs(scope):  documentation only
infra(scope): infrastructure change
ci(scope):    pipeline change
```

---

## 15. Port Reference

| Service | Port | Protocol | Notes |
|---|---|---|---|
| frontend | 3000 | HTTP | Next.js dev server / standalone |
| user-service | 3001 | HTTP | Express |
| product-service | 3002 | HTTP | FastAPI + uvicorn |
| cart-service | 3003 | HTTP | Express |
| order-service | 3004 | HTTP | Express |
| payment-service | 3005 | HTTP | Express |
| notification-service | 3006 | HTTP | Express (health only) |
| api-gateway | 8080 | HTTP | NGINX |
| Azure SQL | 1433 | TCP | TLS required, AKS subnet only |
| Redis Cache | 6380 | TCP+TLS | Port 6379 disabled |
| Cosmos DB | 443 | HTTPS | VNet-filtered |
| App Gateway (external) | 80, 443 | HTTP/HTTPS | 80 redirects to 443 |

---

## 16. Environment Variables Reference

### user-service
| Variable | Example | Source in K8s |
|---|---|---|
| `PORT` | `3001` | ConfigMap |
| `DB_SERVER` | `sql-azureshop-dev.database.windows.net` | Key Vault |
| `DB_NAME` | `db-users` | ConfigMap |
| `DB_USER` | `sqladmin` | Key Vault |
| `DB_PASSWORD` | `***` | Key Vault |
| `JWT_SECRET` | `***` | Key Vault |

### product-service
| Variable | Example | Source in K8s |
|---|---|---|
| `PORT` | `3002` | ConfigMap |
| `COSMOS_ENDPOINT` | `https://cosmos-azureshop-dev.documents.azure.com:443/` | Key Vault |
| `COSMOS_KEY` | `***` | Key Vault |
| `COSMOS_DATABASE` | `azureshop-db` | ConfigMap |
| `COSMOS_CONTAINER` | `products` | ConfigMap |

### cart-service
| Variable | Example | Source in K8s |
|---|---|---|
| `PORT` | `3003` | ConfigMap |
| `REDIS_HOST` | `redis-azureshop-dev.redis.cache.windows.net` | Key Vault |
| `REDIS_PORT` | `6380` | ConfigMap |
| `REDIS_PASSWORD` | `***` | Key Vault |

### order-service
| Variable | Example | Source in K8s |
|---|---|---|
| `PORT` | `3004` | ConfigMap |
| `DB_SERVER` | `sql-azureshop-dev.database.windows.net` | Key Vault |
| `DB_NAME` | `db-orders` | ConfigMap |
| `DB_USER` | `sqladmin` | Key Vault |
| `DB_PASSWORD` | `***` | Key Vault |
| `SERVICE_BUS_CONNECTION_STRING` | `***` | Key Vault |
| `SERVICE_BUS_ORDERS_TOPIC` | `orders` | ConfigMap |

### payment-service / notification-service
| Variable | Example | Source in K8s |
|---|---|---|
| `PORT` | `3005` / `3006` | ConfigMap |
| `SERVICE_BUS_CONNECTION_STRING` | `***` | Key Vault |
| `SERVICE_BUS_ORDERS_TOPIC` | `orders` | ConfigMap |
| `SERVICE_BUS_*_SUBSCRIPTION` | `payment-service` | ConfigMap |

### frontend
| Variable | Example | When set |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | `http://localhost:8080` | Docker build ARG (baked in at build time) |

> All `***` values come from Azure Key Vault via the CSI driver in Kubernetes. For local development, copy `.env.example` to `.env` and fill in the values.

---

## 17. Phase Progress

| Phase | Name | Status | Completed |
|---|---|---|---|
| Phase 1 | Foundation & Azure Setup | ✅ Done | 2026-05-09 |
| Phase 2 | Infrastructure as Code (Terraform) | ✅ Done | 2026-05-09 |
| Phase 3 | Microservices Architecture | ✅ Done | 2026-05-09 |
| Phase 4 | Containerization (Docker + ACR) | ✅ Done | 2026-05-16 |
| Phase 5 | Azure Pipelines CI/CD | ✅ Done | 2026-05-16 |
| Phase 6 | AKS Kubernetes Deployment | ✅ Done | 2026-05-16 |
| Phase 7 | Monitoring & Observability | ✅ Done | 2026-05-16 |
| Phase 8 | Security & DevSecOps | ✅ Done | 2026-05-16 |
| Phase 9 | Advanced DevOps Patterns | ✅ Done | 2026-05-16 |

> **Infrastructure note:** All Azure resources were destroyed on 2026-05-16 for cost saving. The Key Vault is in 90-day soft-delete (recoverable). ACR images still exist. Terraform state file `dev.tfstate` is intact. See `project_state.md` memory for recovery steps before next `terraform apply`.

### Key Azure resources created (Phase 1)

| Resource | Value |
|---|---|
| Subscription ID | `6a6cb5d4-9c05-4211-b604-b4a53fed3284` |
| Tenant ID | `4c135936-7e4d-4ea6-9816-7d696b51923d` |
| Service Principal | `sp-azureshop-terraform` (appId: `0eaa884c-...`) |
| Key Vault (manual) | `kv-azureshop-6a6c` (eastus) |
| ADO Organization | `azureshop-org` |
| ADO Project | `AzureShop` |
| Service Connection | `sc-azureshop-azure` |
| Terraform State | `myprojectazshoptfstate` / container `tfstate` |

---

*Last updated: 2026-05-21 · All 9 phases complete*

# AzureShop — Docker Compose Local Run Guide

**Session Date:** 2026-05-23  
**Goal:** Run the full AzureShop application locally on your laptop using Docker Compose — without any Azure infrastructure.

---

## Table of Contents

1. [What is Docker Compose and Why We Use It](#1-what-is-docker-compose-and-why-we-use-it)
2. [Architecture — What Runs Locally](#2-architecture--what-runs-locally)
3. [Prerequisites](#3-prerequisites)
4. [Step-by-Step Implementation](#4-step-by-step-implementation)
5. [Bugs Encountered and Fixed](#5-bugs-encountered-and-fixed)
6. [Testing the Application](#6-testing-the-application)
7. [Local vs Azure Differences](#7-local-vs-azure-differences)
8. [Key Concepts Learned](#8-key-concepts-learned)
9. [Cleanup](#9-cleanup)

---

## 1. What is Docker Compose and Why We Use It

### The Problem Docker Compose Solves

AzureShop has **10 components** — 2 databases + 8 services. Starting each one manually would mean:
- 10 different terminal windows
- Manually wiring each service to know where the others are
- Manually setting environment variables
- Making sure databases start before services that need them

This is impractical for development.

### What Docker Compose Does

Docker Compose reads a single file (`docker-compose.yml`) and acts like a **stage director** — it starts all containers in the right order, connects them on the same network, and passes environment variables to each one.

**The analogy:** Docker Compose is like a restaurant manager. You don't tell each chef individually what to cook — the manager reads the menu (docker-compose.yml) and coordinates everything.

```
docker compose up --build
    ↓
reads docker-compose.yml
    ↓
builds Docker images for each service
    ↓
starts containers in dependency order
    ↓
all containers talk to each other by service name
```

### Why `--build` on first run?

`docker compose up --build` tells Docker to **rebuild images from Dockerfiles** before starting. This is required the first time because Docker needs to:
- Install npm packages inside the container
- Compile the Next.js app
- Install Python pip packages

On subsequent runs, use `docker compose up` (no `--build`) to use cached images — much faster.

---

## 2. Architecture — What Runs Locally

```
Browser
   |
   | port 8080
   ↓
┌─────────────────┐
│   api-gateway   │  ← NGINX — single entry point, routes all requests
│   (port 8080)   │
└────────┬────────┘
         │ routes by path prefix
    ┌────┴──────────────────────────────────┐
    │                                       │
┌───▼──────┐  ┌──────────┐  ┌──────────┐  ┌▼─────────┐
│  user-   │  │ product- │  │  cart-   │  │  order-  │
│ service  │  │ service  │  │ service  │  │ service  │
│ port 3001│  │ port 3002│  │ port 3003│  │ port 3004│
└───┬──────┘  └──────────┘  └────┬─────┘  └────┬─────┘
    │                             │              │
    │                             │              │
┌───▼──────────┐           ┌──────▼──┐    ┌──────▼──┐
│  SQL Server  │           │  Redis  │    │SQL Server│
│  db-users    │           │(cache)  │    │ db-orders│
└──────────────┘           └─────────┘    └──────────┘

┌──────────────┐  ┌──────────────────┐  ┌──────────┐
│   payment-   │  │  notification-   │  │ frontend │
│   service    │  │    service       │  │ port 3000│
│  port 3005   │  │   port 3006      │  └──────────┘
└──────────────┘  └──────────────────┘
```

### Service port map

| Service | Port | Language | Database |
|---|---|---|---|
| api-gateway | 8080 | NGINX | — |
| frontend | 3000 | Next.js | — |
| user-service | 3001 | Node.js | SQL Server (db-users) |
| product-service | 3002 | Python/FastAPI | Cosmos DB (mock locally) |
| cart-service | 3003 | Node.js | Redis |
| order-service | 3004 | Node.js | SQL Server (db-orders) |
| payment-service | 3005 | Node.js | Azure Service Bus (disconnected locally) |
| notification-service | 3006 | Node.js | Azure Service Bus (disconnected locally) |
| sqlserver | 1433 | MS SQL Server 2022 | — |
| redis | 6379 | Redis 7 | — |

---

## 3. Prerequisites

Before starting, verify these tools are installed:

```bash
docker --version        # Docker 24.x or higher
docker compose version  # Docker Compose v2.x or higher
```

Also verify Docker Desktop is running:
```bash
docker ps   # should show an empty table, not an error
```

---

## 4. Step-by-Step Implementation

### Step 1 — Navigate to project root

```bash
cd /Users/anshujee/Projects/AzureShop/AzureShop
ls   # confirm docker-compose.yml is present
```

**Why:** Docker Compose commands must be run from the directory containing `docker-compose.yml`.

---

### Step 2 — Fix package-lock.json files (first-time setup)

Before building, regenerate lock files for all 6 Node.js services:

```bash
cd services/order-service && npm install && cd ../..
cd services/user-service && npm install && cd ../..
cd services/cart-service && npm install && cd ../..
cd services/payment-service && npm install && cd ../..
cd services/notification-service && npm install && cd ../..
cd services/frontend && npm install && cd ../..
```

**Why:** `docker compose up --build` runs `npm ci` inside each Docker container. `npm ci` is strict — it requires `package.json` and `package-lock.json` to be exactly in sync. If packages were added to `package.json` without running `npm install`, the lock file is stale and the build fails.

**What you see (normal output — not an error):**
```
npm warn deprecated uuid@8.3.2: ...
added 567 packages, audited 568 packages in 3s
20 vulnerabilities (4 moderate, 16 high)
```
The `npm warn` lines are warnings, not errors. `added X packages` means success.

---

### Step 3 — Build and start all containers

```bash
docker compose up --build
```

**What happens:**
1. Docker builds images for all 8 services (takes 5–15 min first time)
2. Containers start in dependency order (databases first, then services)
3. Live logs from all containers stream to your terminal

**Leave this terminal running.** Open a second terminal for the next steps.

---

### Step 4 — Verify all 10 containers are running

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected output:**
```
NAMES                              STATUS                   PORTS
azureshop-api-gateway-1            Up X min (healthy)   0.0.0.0:8080->8080/tcp
azureshop-frontend-1               Up X min (healthy)   0.0.0.0:3000->3000/tcp
azureshop-user-service-1           Up X min (healthy)   0.0.0.0:3001->3001/tcp
azureshop-product-service-1        Up X min (healthy)   0.0.0.0:3002->3002/tcp
azureshop-cart-service-1           Up X min (healthy)   0.0.0.0:3003->3003/tcp
azureshop-order-service-1          Up X min (healthy)   0.0.0.0:3004->3004/tcp
azureshop-payment-service-1        Up X min (healthy)   0.0.0.0:3005->3005/tcp
azureshop-notification-service-1   Up X min (healthy)   0.0.0.0:3006->3006/tcp
azureshop-sqlserver-1              Up X min (healthy)   0.0.0.0:1433->1433/tcp
azureshop-redis-1                  Up X min (healthy)   0.0.0.0:6379->6379/tcp
```

All containers must show `(healthy)`.

---

### Step 5 — Create SQL tables (first-time setup)

SQL Server starts empty. The `users` and `orders` tables must be created manually:

```bash
docker exec -it azureshop-sqlserver-1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "Local@DevPassword1" -C \
  -Q "
USE [db-users];
CREATE TABLE users (
  id            INT IDENTITY(1,1) PRIMARY KEY,
  email         NVARCHAR(255) NOT NULL UNIQUE,
  name          NVARCHAR(255) NOT NULL,
  password_hash NVARCHAR(255) NOT NULL,
  created_at    DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

USE [db-orders];
CREATE TABLE orders (
  id           INT IDENTITY(1,1) PRIMARY KEY,
  user_id      NVARCHAR(255)  NOT NULL,
  total_amount DECIMAL(10,2)  NOT NULL,
  status       NVARCHAR(50)   NOT NULL,
  items        NVARCHAR(MAX)  NOT NULL,
  created_at   DATETIME2      NOT NULL DEFAULT GETUTCDATE()
);"
```

**Why:** The application code just runs SQL queries — it does not auto-create tables. On Azure, tables are created before the app is deployed (via Terraform or migration scripts). Locally, you do it manually once. After the first run, Docker volumes persist the data, so you only need to do this once.

**If you see "already exists":** The tables were created in a previous session and are still there (Docker volumes persist). Skip this step.

---

### Step 6 — Test health endpoints

```bash
curl http://localhost:3001/health   # user-service
curl http://localhost:3002/health   # product-service
curl http://localhost:3003/health   # cart-service
curl http://localhost:3004/health   # order-service
curl http://localhost:3005/health   # payment-service
curl http://localhost:3006/health   # notification-service
curl http://localhost:8080/health   # api-gateway
```

**Expected responses:**

| Service | Expected |
|---|---|
| user-service | `"status":"ok"`, `"db":"connected"` |
| product-service | `"status":"degraded"` — normal, no Cosmos DB locally |
| cart-service | `"status":"ok"`, `"cache":"connected"` |
| order-service | `"status":"ok"`, `"db":"connected"` |
| payment-service | `"status":"ok"`, `"messaging":"disconnected"` — normal |
| notification-service | `"status":"ok"`, `"messaging":"disconnected"` — normal |
| api-gateway | `"status":"ok"` |

---

### Step 7 — Open the application in browser

```
http://localhost:8080
```

**Why port 8080 and not 3000?**
This is the API Gateway concept. You never access individual services directly — everything goes through the single entry point (NGINX on port 8080). The gateway then routes to the right service internally.

---

### Step 8 — Test the full user flow

1. **Register** — Click Sign In → Register → fill in name, email, password
2. **Login** — Use registered credentials
3. **Browse products** — Homepage shows product grid
4. **Add to cart** — Click "Add to Cart" — toast notification appears
5. **View cart** — Click Cart in navbar — see items + order summary
6. **Place order** — Click "Place Order" — see success screen

---

## 5. Bugs Encountered and Fixed

During the session, 6 real bugs were found and fixed. Each went through proper GitFlow (feature branch → PR → merge → sync).

---

### Bug 1 — npm ci fails: lock files out of sync

**Error:**
```
npm error `npm ci` can only install packages when your package.json and 
package-lock.json are in sync.
npm error Missing: applicationinsights@3.15.0 from lock file
```

**Root cause:** `npm ci` is a strict installer — it refuses to proceed if `package.json` and `package-lock.json` don't match exactly. Packages were added to `package.json` but `npm install` was never run to regenerate the lock file.

**The analogy:** `npm ci` is like a strict warehouse worker who only picks items listed on the manifest. If you add items to the order form but don't update the manifest, the worker refuses to do anything.

**Fix:** Run `npm install` in all 6 Node.js service directories to regenerate lock files.

**Branch:** `fix/docker-local-run-healthcheck`

---

### Bug 2 — api-gateway container unhealthy (localhost resolves to IPv6)

**Error:**
```
wget: can't connect to remote host: Connection refused
```

**Root cause:** In Alpine Linux containers, `localhost` resolves to `::1` (IPv6 loopback), not `127.0.0.1` (IPv4). NGINX listens on `0.0.0.0:8080` (IPv4 only). The health check using `http://localhost:8080/health` tried IPv6 — nothing was listening there.

**Proof:**
```bash
# inside the container:
wget http://localhost:8080/health     → Connection refused  ❌ (tries IPv6)
wget http://127.0.0.1:8080/health    → {"status":"ok"}     ✅ (IPv4)
```

**Fix:** Change the Dockerfile HEALTHCHECK from `localhost` to `127.0.0.1`:
```dockerfile
# Before
CMD wget -q -O- http://localhost:8080/health || exit 1

# After  
CMD wget -q -O- http://127.0.0.1:8080/health || exit 1
```

**Branch:** `fix/docker-local-run-healthcheck`

---

### Bug 3 — frontend container unhealthy (Next.js binding to container IP)

**Error:**
```
wget: can't connect to remote host: Connection refused
```

**Root cause:** `docker ps` showed frontend listening on `172.20.0.6:3000` (the Docker network interface) instead of `0.0.0.0:3000` (all interfaces). The health check runs inside the container and tries `localhost:3000` or `127.0.0.1:3000` — neither of which had anything listening.

**Fix 1 — docker-compose.yml:** Add `HOSTNAME=0.0.0.0` so Next.js binds to all interfaces:
```yaml
frontend:
  environment:
    - NODE_ENV=development
    - HOSTNAME=0.0.0.0   # ← added
```

**Fix 2 — frontend Dockerfile:** Change health check from `localhost` to `127.0.0.1`:
```dockerfile
CMD wget -q -O- http://127.0.0.1:3000/ || exit 1
```

**Branches:** `fix/docker-local-run-healthcheck`, `fix/frontend-healthcheck-localhost`

---

### Bug 4 — All API routes returning 404

**Error:**
```
GET /api/products/ → 404 Not Found
```

**Root cause:** NGINX `proxy_pass` without a path forwards the **full URI** to the upstream service. So `GET /api/products/` was forwarded to `product-service:3002/api/products/`. But the product-service only has routes at `/products/` — it has no idea what `/api/products/` is.

**The flow (broken):**
```
Browser → GET /api/products/
  → NGINX → product-service:3002/api/products/   ← WRONG
  → product-service: "I don't know /api/products/"  → 404
```

**The flow (fixed):**
```
Browser → GET /api/products/
  → NGINX → product-service:3002/products/   ← CORRECT (stripped /api/)
  → product-service: "I know /products/!"  → 200
```

**Fix:** Add the target path to each `proxy_pass` directive in `nginx.conf`:
```nginx
# Before — passes full URI
location /api/products/ {
  proxy_pass http://product_service;
}

# After — strips /api/products/, replaces with /products/
location /api/products/ {
  proxy_pass http://product_service/products/;
}
```

Applied to all 5 API routes (users/auth, users, products, cart, orders, payments).

**Branch:** `fix/nginx-api-routing`

---

### Bug 5 — Products page shows "Error: HTTP 503"

**Error:** `Error: HTTP 503` on the homepage

**Root cause:** Cosmos DB is an Azure-only cloud service — there is no local emulator. The product-service checks `is_connected()` and was coded to return HTTP 503 when Cosmos DB is unavailable. The frontend received 503, couldn't parse the response, and showed "Error: HTTP 503".

**Fix:** Add mock product data to `products.py`. Return it when Cosmos DB is not connected instead of raising a 503 error:
```python
MOCK_PRODUCTS = [
    {"id": "1", "name": "Laptop Pro 15", "price": 1299.99, ...},
    {"id": "2", "name": "Wireless Mouse",  "price": 29.99,  ...},
    ...
]

@router.get("/")
async def list_products():
    if not is_connected():
        return MOCK_PRODUCTS   # ← return mock data locally
    # ... real Cosmos DB query in Azure
```

**Branch:** `fix/product-service-local-fallback`

---

### Bug 6 — Registration fails: SQL table does not exist

**Error:**
```
[auth] register error: Invalid object name 'users'.
```

**Root cause:** The `db-users` and `db-orders` databases exist in SQL Server but they are empty. The application code runs SQL queries assuming tables already exist — it has no auto-migration logic. On Azure, the schema is provisioned by Terraform/migrations before the app is deployed.

**Fix (local):** Create tables manually via `docker exec`:
```bash
docker exec -it azureshop-sqlserver-1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "Local@DevPassword1" -C \
  -Q "USE [db-users]; CREATE TABLE users (...);"
```

**Fix (Azure):** Not needed — Azure SQL schema is created before deployment. This is a local-only limitation.

---

## 6. Testing the Application

### Health checks (API level)

```bash
curl http://localhost:8080/health          # gateway
curl http://localhost:8080/api/products/   # products (returns mock data)
curl http://localhost:8080/api/users/auth/login \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"wrongpass"}'
# → {"error":"Invalid credentials"}  means routing works
```

### Full flow (browser)

| Flow | URL | Services involved |
|---|---|---|
| Homepage | `http://localhost:8080` | api-gateway → product-service |
| Register | Click Sign In → Register | api-gateway → user-service → SQL Server |
| Login | Click Sign In | api-gateway → user-service → SQL Server |
| Add to cart | Click "Add to Cart" | api-gateway → cart-service → Redis |
| View cart | Click Cart | api-gateway → cart-service → Redis |
| Place order | Click "Place Order" | api-gateway → order-service → SQL Server |

---

## 7. Local vs Azure Differences

Understanding what is different locally vs on Azure is critical:

| Component | Local (Docker Compose) | Azure (AKS) |
|---|---|---|
| Product database | Mock hardcoded data | Real Cosmos DB |
| Messaging | Disconnected (no Service Bus) | Azure Service Bus — orders trigger payments + notifications |
| SQL tables | Created manually | Created by Terraform/migrations before deploy |
| Secrets | Hardcoded in docker-compose.yml | Azure Key Vault → CSI driver → pod env vars |
| Routing | NGINX api-gateway proxy_pass | NGINX Ingress Controller + Kubernetes Services |
| Scaling | Single container per service | HPA auto-scales pods based on CPU/memory |
| Health checks | Docker HEALTHCHECK directive | Kubernetes livenessProbe + readinessProbe |
| Monitoring | None | Prometheus + Grafana + Application Insights |

---

## 8. Key Concepts Learned

### Docker Compose concepts

**`depends_on: condition: service_healthy`**
Services wait for their dependencies to pass health checks before starting. SQL Server takes ~20s to boot — user-service won't start until SQL Server is healthy.

**Docker networking**
All containers in a Compose file share a network. They reach each other by **service name** (e.g. `redis`, `sqlserver`). You don't need IP addresses.

**`npm ci` vs `npm install`**
- `npm install` — installs packages and UPDATES the lock file
- `npm ci` — installs packages from the lock file exactly, fails if out of sync

### NGINX concepts

**`proxy_pass` path stripping**
- `proxy_pass http://upstream;` → forwards full URI
- `proxy_pass http://upstream/path/;` → strips the matched location prefix, replaces with `/path/`

**Health check location**
```nginx
location /health {
  return 200 '{"status":"ok"}';
}
```
NGINX can respond directly without proxying to a backend — used for the gateway's own health check.

### Container concepts

**`localhost` in containers is NOT always `127.0.0.1`**
In Alpine Linux, `localhost` resolves to `::1` (IPv6). Always use `127.0.0.1` explicitly in health checks inside Alpine containers.

**`HOSTNAME=0.0.0.0`**
Tells a server process to listen on ALL network interfaces inside the container. Without this, some processes bind only to their assigned container IP, making them unreachable via loopback.

**Multi-stage Dockerfile**
```dockerfile
FROM node:20-alpine AS deps      # Stage 1: install packages
FROM node:20-alpine AS runtime   # Stage 2: copy only what's needed
```
Keeps the final image small — build tools and dev dependencies are left behind.

---

## 9. Cleanup

### Stop all containers (keep data)
```bash
docker compose down
```

### Stop and delete all data (fresh start next time)
```bash
docker compose down -v
```
The `-v` flag removes Docker volumes — the SQL Server data and Redis data are wiped. You'll need to re-create tables on the next run.

### Rebuild a single service (without touching others)
```bash
docker compose up --build --no-deps <service-name>
# Example:
docker compose up --build --no-deps frontend
docker compose up --build --no-deps api-gateway
```

---

*This document was created on 2026-05-23 as a learning record of the Docker Compose local run session for AzureShop.*

# Phase 4 — Containerization (Docker + ACR)
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In this phase we took all 8 microservices written in Phase 3 and:
1. Verified every Dockerfile follows production best practices
2. Wired all services together locally using Docker Compose
3. Pushed all 8 Docker images to Azure Container Registry (ACR)
4. Learned about ACR security tools (Trivy, Defender for Containers, Content Trust)

---

## Table of Contents

1. [Docker Fundamentals](#1-docker-fundamentals)
2. [Dockerfile Best Practices](#2-dockerfile-best-practices)
3. [Multi-Stage Builds](#3-multi-stage-builds)
4. [Docker Compose](#4-docker-compose)
5. [Service Discovery](#5-service-discovery)
6. [Azure Container Registry (ACR)](#6-azure-container-registry-acr)
7. [Pushing Images to ACR](#7-pushing-images-to-acr)
8. [Image Security — Trivy](#8-image-security--trivy)
9. [Image Security — Microsoft Defender for Containers](#9-image-security--microsoft-defender-for-containers)
10. [Image Security — Content Trust](#10-image-security--content-trust)
11. [Trivy vs Microsoft Defender — Key Differences](#11-trivy-vs-microsoft-defender--key-differences)
12. [Errors Faced & Fixes](#12-errors-faced--fixes)
13. [Terraform State & Manually Created Resources](#13-terraform-state--manually-created-resources)
14. [Commands Reference](#14-commands-reference)
15. [Interview Questions & Answers](#15-interview-questions--answers)

---

## 1. Docker Fundamentals

### What is Docker?

Docker is a tool that lets you package an application and everything it needs (code, runtime, libraries, config) into a single unit called a **container**. That container runs the same way on any machine — your laptop, a colleague's laptop, or a cloud server.

### Images vs Containers

This is the most important distinction in Docker:

| Term | What it is | Analogy |
|---|---|---|
| **Image** | A read-only blueprint/template | A recipe for a cake |
| **Container** | A running instance created from an image | The actual cake you baked |

```
Dockerfile  →  docker build  →  Image  →  docker run  →  Container
(instructions)                (blueprint)               (running process)
```

- One image can create **many containers** — just like one recipe can produce many cakes
- An image is **static** (it never changes once built)
- A container is **running** (it has a process, memory, network)
- When you stop a container, the image still exists — you can create a new container from it anytime

### Docker Layers

Every instruction in a Dockerfile creates a **layer**. Layers are cached. If nothing changed in a layer, Docker reuses the cached version — making builds much faster.

```dockerfile
FROM node:20-alpine        # Layer 1 — base OS + Node.js
WORKDIR /app               # Layer 2 — set working directory
COPY package*.json ./      # Layer 3 — copy package files
RUN npm ci                 # Layer 4 — install dependencies (CACHED if package.json unchanged)
COPY . .                   # Layer 5 — copy source code
RUN npm run build          # Layer 6 — build the app
```

**Key insight:** Put things that change rarely (dependencies) BEFORE things that change often (source code). This way, the slow `npm install` step is cached and only runs again when `package.json` changes.

---

## 2. Dockerfile Best Practices

These are the standards every production Dockerfile should follow. All 8 services in AzureShop use these.

### ✅ Use specific base image versions (not `latest`)

```dockerfile
# BAD — unpredictable, breaks silently when new version releases
FROM node:latest

# GOOD — pinned, reproducible, same image every time
FROM node:20-alpine
```

**Why:** `latest` changes whenever the image maintainer pushes an update. Your build that worked yesterday might break today because `latest` is now a different version.

### ✅ Use Alpine variants for smaller images

```dockerfile
FROM node:20-alpine    # ~50MB
# vs
FROM node:20           # ~350MB
```

Alpine is a minimal Linux distribution. Smaller image = faster push/pull, smaller attack surface, less storage cost.

### ✅ Use non-root user

```dockerfile
# Create a non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Switch to it before running the app
USER nodejs
```

**Why:** By default, processes inside a container run as **root**. If an attacker exploits a vulnerability in your app, they get root access inside the container — and potentially the host. Running as a non-root user limits the blast radius.

**Real world analogy:** Don't run your web server as Administrator on Windows. Run it as a limited user account. Same concept.

### ✅ Add HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -q -O- http://localhost:3000/health || exit 1
```

**Why:** Docker and Kubernetes use health checks to know if a container is actually working, not just "running". A container can be "running" but serving 500 errors. The health check catches this.

- `interval=30s` — check every 30 seconds
- `timeout=5s` — if no response in 5 seconds, count as failed
- `start-period=15s` — wait 15 seconds before first check (app needs time to start)
- `retries=3` — fail 3 times in a row before marking unhealthy

### ✅ Use .dockerignore

Just like `.gitignore`, a `.dockerignore` file tells Docker what to exclude when copying files into the image.

```
node_modules
.git
*.md
.env
*.log
coverage
.DS_Store
```

**Why:** Without this, `COPY . .` copies everything including `node_modules` (hundreds of MB), `.git` history, `.env` files with secrets, and test files. This makes images huge and potentially insecure.

### ✅ No secrets in images

Never hardcode passwords, API keys, or connection strings in a Dockerfile or source code. These get baked into the image and are readable by anyone who pulls it:

```bash
docker history your-image:v1.0.0  # shows every layer — secrets visible here
```

Instead, pass secrets as **environment variables at runtime** via Kubernetes Secrets or Azure Key Vault.

---

## 3. Multi-Stage Builds

### The Problem Without Multi-Stage

If you build a Node.js app in a single stage, the final image contains:
- The full build tools (npm, compilers)
- Dev dependencies
- Source files
- Test files

All of this is useless at runtime but sits in the image, making it large and exposing unnecessary attack surface.

### How Multi-Stage Builds Solve This

You define **multiple FROM stages** in one Dockerfile. Each stage can copy files from a previous stage. The final image only contains what the last stage puts in it.

```dockerfile
# ── Stage 1: Install dependencies ──────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci                          # install ALL deps (including dev)

# ── Stage 2: Build ──────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules   # copy from stage 1
COPY . .
RUN npm run build                   # compile/bundle the app

# ── Stage 3: Runtime ────────────────────────────────────────────
FROM node:20-alpine AS runtime      # fresh, clean image
WORKDIR /app
COPY --from=builder /app/dist ./    # copy ONLY the built output
# No node_modules, no source, no build tools
CMD ["node", "server.js"]
```

**Result:**

| Approach | Image size |
|---|---|
| Single stage | ~800MB |
| Multi-stage | ~80MB |

The intermediate stages (deps, builder) are **discarded** — they never become part of the final image. They're like scaffolding that gets removed after a building is constructed.

### Frontend (Next.js) Three-Stage Build

The `frontend` service uses Next.js with `output: 'standalone'` mode. This produces a self-contained server that includes only the files needed to run — no `node_modules` directory needed at runtime.

```dockerfile
# Stage 1: Install deps
FROM node:20-alpine AS deps
RUN npm ci

# Stage 2: Build Next.js app
FROM node:20-alpine AS builder
COPY --from=deps /app/node_modules ./node_modules
ARG NEXT_PUBLIC_API_URL=http://localhost:8080
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build && mkdir -p /app/public   # mkdir ensures /public exists even if empty

# Stage 3: Runtime — only the standalone output
FROM node:20-alpine AS runtime
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
CMD ["node", "server.js"]
```

**Important:** `NEXT_PUBLIC_*` environment variables are **baked into the JavaScript bundle at build time** (not injected at runtime). This is because Next.js inlines them into the client-side code. So they must be passed as build arguments (`ARG`), not runtime env vars.

---

## 4. Docker Compose

### What is Docker Compose?

Docker Compose is a tool for defining and running **multiple containers together** as a single application. Instead of running 8 separate `docker run` commands with all their flags, you write one `docker-compose.yml` file.

```
Without Docker Compose:
  docker run -p 3001:3001 -e DB_SERVER=sqlserver -e DB_NAME=db-users ... user-service
  docker run -p 3002:3002 -e COSMOS_ENDPOINT=... product-service
  docker run -p 3003:3003 -e REDIS_HOST=redis ... cart-service
  ... (repeat for 8 services)

With Docker Compose:
  docker compose up --build
  (one command starts everything)
```

### docker-compose.yml Structure

```yaml
services:

  # Infrastructure dependencies first
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=Local@DevPassword1
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Local@DevPassword1" -Q "SELECT 1" -C || exit 1
      interval: 10s
      start_period: 30s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  # Application services
  user-service:
    build: ./services/user-service       # build from Dockerfile in this folder
    ports:
      - "3001:3001"
    environment:
      - DB_SERVER=sqlserver              # use container name, not localhost!
      - DB_NAME=db-users
      - DB_TRUST_CERT=true              # local SQL Server uses self-signed cert
    depends_on:
      sqlserver:
        condition: service_healthy       # wait until SQL is ready, not just running

  cart-service:
    build: ./services/cart-service
    environment:
      - REDIS_HOST=redis                 # use container name
      - REDIS_PORT=6379
      - REDIS_TLS=false                  # local Redis has no TLS
    depends_on:
      redis:
        condition: service_healthy

  api-gateway:
    build: ./services/api-gateway
    ports:
      - "8080:8080"                      # only this port exposed to your browser

networks:
  default:
    name: azureshop-network
```

### Key Concepts in docker-compose.yml

**`build` vs `image`:**
- `build: ./services/user-service` — build from a Dockerfile (for your own code)
- `image: redis:7-alpine` — pull a pre-built image from Docker Hub (for third-party tools)

**`depends_on` with health conditions:**
Without `depends_on`, Docker Compose starts all containers simultaneously. `user-service` would try to connect to SQL Server before it's ready — and fail. `depends_on` with `condition: service_healthy` tells Compose: wait until the SQL Server health check passes before starting `user-service`.

**Environment variables as configuration:**
This is the **12-Factor App** principle. Your application code never hardcodes where the database is. Instead it reads from environment variables:
```javascript
server: process.env.DB_SERVER  // "sqlserver" locally, "sql-azureshop-dev.database.windows.net" in Azure
```
Same Docker image, different behaviour per environment — just change the env vars.

---

## 5. Service Discovery

### The Problem

When `user-service` needs to connect to SQL Server, what address does it use?

- On your laptop without Docker: `localhost`
- In Docker Compose: `localhost` does NOT work (each container has its own network namespace)
- In Kubernetes: `localhost` does NOT work either

### How Service Discovery Works in Docker Compose

Docker Compose creates a private network and gives each container a **DNS name equal to its service name** in the YAML file.

```yaml
services:
  sqlserver:    # ← this becomes the hostname "sqlserver" on the network
    ...
  user-service:
    environment:
      - DB_SERVER=sqlserver    # user-service finds SQL Server by name, not IP
```

```
user-service container
    → connects to "sqlserver:1433"
    → Docker DNS resolves "sqlserver" → container IP (e.g., 172.20.0.3)
    → connection established
```

**The same concept applies in Kubernetes** — services find each other by name (ClusterIP DNS), not by IP address. This is why this pattern is important to understand early.

**Real world analogy:** Like calling a colleague by name ("call John") instead of memorising their phone number. The company directory (Docker DNS / Kubernetes DNS) resolves the name to the actual number.

---

## 6. Azure Container Registry (ACR)

### What is ACR?

ACR is Microsoft Azure's **private Docker image registry**. Think of it like GitHub — but instead of storing code, it stores Docker images.

```
Public registry  → Docker Hub (anyone can pull)
Private registry → ACR (only authorised users/services can pull)
```

Your company's proprietary application images should **never** go to Docker Hub (public). They go to ACR where only your Azure services (AKS) and authorised users can access them.

### ACR SKUs

| SKU | Storage | Use case | Cost |
|---|---|---|---|
| **Basic** | 10 GB | Learning, dev | Cheapest |
| **Standard** | 100 GB | Most production workloads | Mid |
| **Premium** | 500 GB | Geo-replication, Private Link, high throughput | Most expensive |

We used **Basic** for this phase (manually created). The Terraform module provisions **Premium** for production (needed for vulnerability scanning and geo-replication features).

### ACR Naming Rules

- Globally unique across all of Azure (like a domain name)
- 5–50 characters, alphanumeric only, no hyphens
- Our registry: `acrazureshopdev` → login server: `acrazureshopdev.azurecr.io`

### Authentication — How Does Docker Know Your ACR is Trusted?

ACR is private. Before Docker can push or pull, it needs to authenticate. `az acr login` handles this:

```bash
az acr login --name acrazureshopdev
```

What this does behind the scenes:
1. Azure CLI gets a short-lived token from Azure AD (valid for 3 hours)
2. Stores it in Docker's credential store (`~/.docker/config.json`)
3. Docker uses this token automatically on every push/pull to that registry

In CI/CD pipelines, instead of `az acr login`, you use a **Service Principal** or **Managed Identity** — no human interaction needed.

---

## 7. Pushing Images to ACR

### The Three-Step Process

#### Step 1: Login
```bash
az acr login --name acrazureshopdev
# Output: Login Succeeded
```

#### Step 2: Tag the image
A Docker tag is just a **rename** that tells Docker which registry to send the image to. The registry address is embedded in the image name.

```bash
docker tag azureshop-user-service:latest acrazureshopdev.azurecr.io/user-service:v1.0.0
```

Breaking down the target name:
```
acrazureshopdev.azurecr.io  /  user-service  :  v1.0.0
│──────────────────────────│  │────────────│  │──────│
     Registry address           Repository    Version tag
```

#### Step 3: Push
```bash
docker push acrazureshopdev.azurecr.io/user-service:v1.0.0
```

Docker reads the registry address from the image name and uploads it there.

### Versioning Tags — Why v1.0.0 and Not `latest`

Using `latest` in production is bad practice:
- `latest` is overwritten every time you push — you lose the previous version
- If something breaks, you can't roll back to a specific known-good version
- Kubernetes can't tell which version is running

Using semantic versioning (`v1.0.0`, `v1.0.1`, `v2.0.0`) means:
- Every push creates a new, immutable tag
- You can always roll back to any previous version
- You know exactly what is running in production

In CI/CD pipelines (Phase 5), the tag will be the **build number** automatically:
```
acrazureshopdev.azurecr.io/user-service:build-42
acrazureshopdev.azurecr.io/user-service:build-43   ← new deployment
```

### Verifying Images in ACR

```bash
# List all repositories (services) in ACR
az acr repository list --name acrazureshopdev --output table

# List all tags for a specific service
az acr repository show-tags --name acrazureshopdev --repository user-service --output table
```

Or in Azure Portal:
**portal.azure.com → search "acrazureshopdev" → Repositories → click any service → see tags**

### Images Pushed in This Phase

| Service | Image in ACR | Size |
|---|---|---|
| api-gateway | `acrazureshopdev.azurecr.io/api-gateway:v1.0.0` | ~50MB |
| cart-service | `acrazureshopdev.azurecr.io/cart-service:v1.0.0` | ~139MB |
| frontend | `acrazureshopdev.azurecr.io/frontend:v1.0.0` | ~155MB |
| notification-service | `acrazureshopdev.azurecr.io/notification-service:v1.0.0` | ~156MB |
| order-service | `acrazureshopdev.azurecr.io/order-service:v1.0.0` | ~195MB |
| payment-service | `acrazureshopdev.azurecr.io/payment-service:v1.0.0` | ~156MB |
| product-service | `acrazureshopdev.azurecr.io/product-service:v1.0.0` | ~211MB |
| user-service | `acrazureshopdev.azurecr.io/user-service:v1.0.0` | ~185MB |

---

## 8. Image Security — Trivy

### What is Trivy?

Trivy (by Aqua Security) is a free, open-source **vulnerability scanner** for Docker images. It scans every package inside an image against a database of known vulnerabilities (CVEs — Common Vulnerabilities and Exposures).

### What is a CVE?

A CVE is a publicly disclosed security vulnerability with a unique ID (e.g., CVE-2023-44487). When a vulnerability is discovered in a software package, it gets a CVE number and a severity rating:

| Severity | Meaning |
|---|---|
| CRITICAL | Can be exploited remotely, no authentication required |
| HIGH | Serious, likely exploitable |
| MEDIUM | Requires specific conditions to exploit |
| LOW | Minor risk |

### How Trivy Works

```bash
trivy image acrazureshopdev.azurecr.io/user-service:v1.0.0
```

Trivy:
1. Pulls the image (if not local)
2. Reads every layer
3. Finds all installed packages (npm packages, OS packages, Python packages)
4. Checks each package version against the CVE database
5. Reports vulnerabilities by severity

Sample output:
```
user-service:v1.0.0 (alpine 3.18.4)
════════════════════════════════
Total: 3 (CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 0)

┌──────────────┬───────────────┬──────────┬────────────────────┐
│   Library    │ Vulnerability │ Severity │   Fixed Version    │
├──────────────┼───────────────┼──────────┼────────────────────┤
│ openssl      │ CVE-2023-XXXX │ HIGH     │ 3.1.4-r1           │
│ libcrypto3   │ CVE-2023-YYYY │ MEDIUM   │ 3.1.4-r1           │
└──────────────┴───────────────┴──────────┴────────────────────┘
```

The fix is usually: upgrade the base image (`FROM node:20-alpine` → `FROM node:20-alpine3.19`) and rebuild.

### Where Trivy Runs in This Project

Trivy runs inside **Azure Pipelines as a pipeline stage** (Phase 5), not on a developer's local machine:

```yaml
# Inside azure-pipelines.yaml
- stage: SecurityScan
  jobs:
    - job: TrivyScan
      steps:
        - script: |
            docker run --rm aquasec/trivy:latest image \
              --exit-code 1 \
              --severity HIGH,CRITICAL \
              $(ACR_LOGIN_SERVER)/$(SERVICE_NAME):$(Build.BuildId)
          displayName: 'Trivy Vulnerability Scan'
```

`--exit-code 1` means: if any HIGH or CRITICAL vulnerabilities are found, the pipeline **fails** and the image is never pushed to ACR. No human decision needed — security is enforced automatically.

### Why Trivy in the Pipeline is Better Than Local Scanning

| Local scan | Pipeline scan |
|---|---|
| Developer must remember to run it | Runs automatically every time |
| Can be skipped | Cannot be skipped |
| Different versions on different machines | Consistent version pinned in pipeline |
| Results not recorded | Results stored in pipeline history |

---

## 9. Image Security — Microsoft Defender for Containers

### What is Microsoft Defender for Containers?

Microsoft Defender for Containers is Azure's **built-in cloud security service** for container workloads. It has two main functions:

1. **Image scanning** — scans images stored in ACR for vulnerabilities (like Trivy, but cloud-native)
2. **Runtime protection** — monitors live containers running in AKS for suspicious behaviour

### How Image Scanning Works

```
You push image to ACR
        ↓
Defender automatically triggers a scan (no action needed)
        ↓
Results appear in Microsoft Defender for Cloud portal
        ↓
Recommendations: "user-service has 2 HIGH vulnerabilities — fix: upgrade openssl"
```

Unlike Trivy (which blocks the push), Defender scans images that are **already in ACR**. It cannot block a push — it only alerts after the fact.

### How Runtime Protection Works

This only applies when AKS is running (Phase 6 onwards). Defender monitors every container in your cluster and alerts on:

- Container running as root
- Privilege escalation attempts
- Unexpected outbound network connections
- Crypto-mining processes
- Container escape attempts
- Unusual file access patterns

```
AKS pod suddenly starts making requests to a cryptocurrency mining pool
        ↓
Defender detects unusual outbound connection
        ↓
Alert: "Possible crypto-mining activity detected in pod user-service-7d9b4"
        ↓
Security team investigates and kills the pod
```

### When to Enable It

Defender for Containers gives full value only when **AKS is running**. For this project, it will be fully configured in **Phase 8 (Security & DevSecOps)** when the cluster is deployed and real workloads are running.

### Cost

Approximately $0.013 per vCore per hour when monitoring AKS. For a small dev cluster, roughly $5–15/month.

---

## 10. Image Security — Content Trust

### The Problem Content Trust Solves

Imagine this attack:

```
1. Attacker gains access to your ACR (stolen credentials, misconfigured permissions)
2. They push a malicious image with the SAME tag: user-service:v1.0.0
3. Your AKS cluster pulls "user-service:v1.0.0" — it looks legitimate
4. The malicious image runs in production
5. Data is stolen or systems are compromised
```

The tag was the same. AKS had no way to know the image was tampered with or replaced.

### What Content Trust Does

Content Trust uses **digital signatures** to guarantee that an image:
- Was built by your trusted pipeline (not by an attacker)
- Has not been modified since it was signed
- Is exactly what you pushed

When an image is pushed, it is signed with a **private key** (held by your pipeline). The public key is stored in ACR. When AKS pulls the image, it verifies the signature. If it doesn't match — the image is rejected.

```
Pipeline builds image
        ↓
Pipeline signs it with private key → signature stored in ACR
        ↓
AKS pulls image
        ↓
AKS verifies signature with public key
  ✅ Signature valid → run the container
  ❌ Signature invalid or missing → REJECT, do not run
```

### Real World Analogy

Think of a government-issued passport. The passport is printed by the government (your pipeline), stamped with an official seal (digital signature). At the border (AKS), the officer checks the seal. A forged passport that looks identical will fail the verification check.

### Enabling Content Trust on ACR

```bash
# Enable Content Trust on the registry
az acr config content-trust update --name acrazureshopdev --status enabled
```

When Content Trust is enforced, unsigned images cannot be pulled from the registry — even by someone with valid credentials.

### When to Implement It

Content Trust is most effective when configured alongside CI/CD pipelines (Phase 5) so that signing is **automated** on every push. Manually signing images is error-prone. We will implement this in Phase 5.

---

## 11. Trivy vs Microsoft Defender — Key Differences

| | Trivy | Microsoft Defender for Containers |
|---|---|---|
| **Made by** | Aqua Security (open source, free) | Microsoft (paid) |
| **Cost** | Free | Paid (~$5–15/month for dev) |
| **Where it runs** | Inside CI/CD pipeline | Inside Azure cloud |
| **When it runs** | During build — BEFORE push to ACR | AFTER image is in ACR |
| **Blocks bad images?** | Yes — pipeline fails, image never pushed | No — alerts after image is already in ACR |
| **Scans running containers?** | No | Yes — monitors live AKS workloads |
| **Runtime protection?** | No | Yes |
| **Best used for** | Shift-left: catching issues early | Defence-in-depth: catching what Trivy missed + runtime |

### How They Work Together

```
Developer commits code
        ↓
Pipeline builds Docker image
        ↓
Trivy scans image ← FREE, catches 90% of issues BEFORE they reach Azure
  FAIL → developer fixes, pipeline re-runs
  PASS → image pushed to ACR
        ↓
Defender scans image in ACR ← catches remaining edge cases
        ↓
Image deployed to AKS
        ↓
Defender monitors running pods ← runtime protection (Trivy can't do this)
```

**Summary in one sentence:**
Trivy is the **gate** (stops bad images entering). Defender is the **guard** (watches everything already inside).

---

## 12. Errors Faced & Fixes

### Error 1: `npm ci` failing in Docker build

**Error message:**
```
npm error The `npm ci` command can only install with an existing package-lock.json
```

**Why it happened:**
`npm ci` is the production-safe install command. Unlike `npm install`, it requires a `package-lock.json` to guarantee exact, reproducible dependency versions. The lock files were missing from the repository.

**Fix:**
```bash
cd services/user-service
npm install --package-lock-only   # generates lock file without installing
```
Done for all 6 Node.js services. Lock files committed to the repo.

**Why npm ci instead of npm install in Docker:**
- `npm install` can silently upgrade packages (non-deterministic)
- `npm ci` installs exactly what the lock file says — same result every time, on every machine, in every pipeline

---

### Error 2: Frontend Dockerfile COPY with shell operators

**Error message:**
```
failed to solve: failed to read dockerfile: dockerfile parse error on line 26:
COPY does not support syntax: /app/public ./public 2>/dev/null || true
```

**Why it happened:**
```dockerfile
# This was the broken line:
COPY --from=builder /app/public ./public 2>/dev/null || true
```
`COPY` is a Dockerfile instruction — it does NOT run in a shell. The `2>/dev/null || true` (which means "ignore errors in shell") was interpreted as a literal file path to copy, not as a shell operator. Docker tried to find a file literally named `||` and failed.

**Fix:**
```dockerfile
# In the builder stage — ensure /public exists even if Next.js didn't create it
RUN npm run build && mkdir -p /app/public

# In the runtime stage — plain COPY with no shell tricks
COPY --from=builder /app/public ./public
```
`mkdir -p` creates the directory if it doesn't exist, so `COPY` always has something to copy.

---

### Error 3: Redis TLS failure in local Docker Compose

**Error message:**
```
[redis] Connection error: connect ECONNREFUSED
Error: Redis connection failed — TLS handshake error
```

**Why it happened:**
The `redis.js` code had TLS hardcoded ON:
```javascript
tls: { servername: host }  // always enabled — no way to turn off
```
Azure Redis Cache uses TLS on port 6380. But the local Redis container (`redis:7-alpine`) runs plain TCP on port 6379 — no TLS. The service tried to do a TLS handshake with a non-TLS server and failed.

**Fix:**
```javascript
const useTls = process.env.REDIS_TLS !== 'false';   // TLS on by default
client = new Redis({
  host, port,
  ...(useTls && { tls: { servername: host } }),     // only add TLS config if enabled
});
```
In `docker-compose.yml`: `REDIS_TLS=false` for local dev.
In Azure (AKS): `REDIS_TLS=true` (default) — no change needed.

---

### Error 4: SQL Server certificate trust failure locally

**Error message:**
```
ConnectionError: Failed to connect to sqlserver:1433 — self signed certificate
```

**Why it happened:**
The SQL Server Docker container uses a **self-signed certificate** (it generates one itself at startup). Self-signed certs are not issued by a trusted CA — they're just locally generated. The `mssql` Node.js driver rejects them by default as a security measure.

Azure SQL uses a **valid, CA-signed certificate** — no issue in production. But locally, we need to tell the driver to trust the self-signed cert.

**Fix:**
```javascript
trustServerCertificate: process.env.DB_TRUST_CERT === 'true'
```
In `docker-compose.yml`: `DB_TRUST_CERT=true`
In Azure (AKS): `DB_TRUST_CERT` not set (defaults to false) — Azure SQL uses a valid cert.

---

### Error 5: az acr login failing — wrong default resource group

**Error message:**
```
ERROR: (ResourceGroupNotFound) Resource group 'learn-azure-anshu-jee' could not be found.
```

**Why it happened:**
Azure CLI has a **defaults** system. A previous project had set the default resource group to `learn-azure-anshu-jee`. When `az acr login` ran, it tried to find the ACR in that default resource group. The group doesn't exist anymore.

**Fix:**
```bash
az configure --defaults group=rg-azureshop-dev
```
This updates the Azure CLI default resource group to the correct one. All subsequent `az` commands now use `rg-azureshop-dev` automatically.

**Lesson:** Always check `az configure --list-defaults` when getting unexpected "not found" errors.

---

## 13. Terraform State & Manually Created Resources

### The Problem

When we ran `terraform destroy` after validating Phase 2 infrastructure, all 57 resources were deleted — including ACR. For Phase 4.3 we needed ACR to exist, so we created it manually:

```bash
az acr create --name acrazureshopdev --resource-group rg-azureshop-dev --sku Basic
```

This creates a conflict: **Terraform does not know about this manually created resource.** The state file has no record of it.

```
Azure (reality)          Terraform state file
────────────────         ────────────────────
ACR exists ✅            ACR → not listed ❌
```

When `terraform apply` runs later, it will try to CREATE the ACR again → naming conflict error because the name is already taken.

### Three Ways to Resolve This

**Option 1 — Delete before terraform apply (what we chose)**
Delete the manually created ACR before running `terraform apply`. Terraform creates it fresh. No conflict.
```bash
az acr delete --name acrazureshopdev --resource-group rg-azureshop-dev --yes
terraform apply
```

**Option 2 — terraform import (the professional way)**
Tell Terraform to adopt the existing resource into its state file. After import, Terraform knows about it and `terraform apply` makes no changes to it.
```bash
terraform import module.acr.azurerm_container_registry.acr \
  /subscriptions/6a6cb5d4.../resourceGroups/rg-azureshop-dev/providers/Microsoft.ContainerRegistry/registries/acrazureshopdev
```

**Option 3 — Use a different name temporarily**
Create a throwaway registry with a different name for learning purposes, then delete it. `terraform apply` creates the production one with the correct name.

### Key Lesson

**The Terraform state file is the single source of truth for Terraform.** It tracks every resource Terraform manages. If a resource exists in Azure but not in the state file, Terraform does not know about it and will try to create it again. Always manage resources either fully through Terraform OR fully manually — never mix the two for the same resource without using `terraform import`.

---

## 14. Commands Reference

### Docker Commands

```bash
# Build an image from a Dockerfile
docker build -t image-name:tag ./path/to/service

# List all local images
docker images

# Tag an image for ACR
docker tag local-image:tag acr-name.azurecr.io/repo-name:tag

# Push image to registry
docker push acr-name.azurecr.io/repo-name:tag

# Pull image from registry
docker pull acr-name.azurecr.io/repo-name:tag

# Remove a local image
docker rmi image-name:tag

# Show image layers and history
docker history image-name:tag

# Run a container from an image
docker run -p host-port:container-port -e ENV_VAR=value image-name:tag
```

### Docker Compose Commands

```bash
# Build all images and start all containers
docker compose up --build

# Start containers (without rebuilding)
docker compose up

# Start in background (detached mode)
docker compose up -d

# Stop all containers (keep them)
docker compose stop

# Stop and remove all containers
docker compose down

# Stop, remove containers AND remove volumes (database data)
docker compose down -v

# View logs from all services
docker compose logs

# View logs from one service
docker compose logs user-service

# See running containers
docker compose ps
```

### ACR Commands

```bash
# Login to ACR
az acr login --name acrazureshopdev

# Create ACR (Basic SKU)
az acr create --name acrazureshopdev --resource-group rg-azureshop-dev --sku Basic

# List all repositories in ACR
az acr repository list --name acrazureshopdev --output table

# List tags for a specific repository
az acr repository show-tags --name acrazureshopdev --repository user-service --output table

# Delete an image from ACR
az acr repository delete --name acrazureshopdev --image user-service:v1.0.0

# Enable Content Trust
az acr config content-trust update --name acrazureshopdev --status enabled

# Delete ACR
az acr delete --name acrazureshopdev --resource-group rg-azureshop-dev --yes
```

### Azure CLI Defaults

```bash
# Check current defaults
az configure --list-defaults

# Set default resource group
az configure --defaults group=rg-azureshop-dev

# Clear a default
az configure --defaults group=''
```

---

## 15. Interview Questions & Answers

### Docker

**Q: What is the difference between a Docker image and a container?**

A: An image is a read-only template — a blueprint with all the files, libraries, and configuration needed to run an application. A container is a running instance of an image. You can create many containers from the same image. An image is like a recipe; a container is the dish you cook from it.

---

**Q: What are multi-stage builds and why do you use them?**

A: Multi-stage builds allow you to use multiple FROM instructions in a single Dockerfile. Each stage can copy files from previous stages. The final image only includes what the last stage contains. This significantly reduces image size — for example, a Node.js app might be 800MB with a single stage (includes build tools, dev dependencies) but only 80MB with multi-stage (only the compiled output). Smaller images mean faster deployments, less storage cost, and reduced attack surface.

---

**Q: Why should containers run as non-root users?**

A: By default, processes in containers run as root. If an attacker exploits a vulnerability in your application, they get root access inside the container. While container isolation limits the blast radius, running as a non-root user adds another layer of defence. If the container process is compromised, the attacker has limited privileges and cannot, for example, modify system files or escalate to the host.

---

**Q: What is a .dockerignore file?**

A: Similar to .gitignore, a .dockerignore file lists files and folders that should be excluded from the Docker build context. Without it, COPY . . would copy node_modules (hundreds of MB), .git history, .env files with secrets, and test files into the image. This makes images unnecessarily large and potentially insecure.

---

**Q: What is the difference between CMD and ENTRYPOINT in a Dockerfile?**

A: Both define what runs when a container starts. ENTRYPOINT defines the fixed command that always runs. CMD provides default arguments that can be overridden at runtime with `docker run`. For example, `ENTRYPOINT ["node"]` and `CMD ["server.js"]` means the container runs `node server.js` by default, but you could run `docker run image server-debug.js` to override CMD.

---

### Docker Compose

**Q: What is Docker Compose and when would you use it?**

A: Docker Compose is a tool for defining and running multi-container applications. You write a docker-compose.yml file describing all services, their configuration, and how they connect. With one command (`docker compose up`) you start the entire application stack. It is used for local development and testing — not for production (Kubernetes handles production).

---

**Q: How does service discovery work in Docker Compose?**

A: Docker Compose creates a private network for all services. Each service's container name becomes a DNS hostname on that network. If you define a service named `sqlserver`, other containers can reach it at `sqlserver:1433`. Docker's internal DNS resolves the service name to the container's IP automatically. This is the same concept used in Kubernetes with ClusterIP services.

---

**Q: What does depends_on do in Docker Compose?**

A: depends_on controls the startup order of services. Without it, all services start simultaneously and a service may try to connect to its database before the database is ready. With `depends_on: condition: service_healthy`, Docker Compose waits until the dependency passes its health check before starting the dependent service.

---

### Azure Container Registry

**Q: What is Azure Container Registry and why use it instead of Docker Hub?**

A: ACR is a private Docker image registry hosted in Azure. Docker Hub is public — anyone can pull public images. ACR is private — only authorised Azure services and users can pull images. For proprietary application code, you never want images on a public registry. ACR also integrates with AKS using Managed Identity (no passwords needed) and with Azure Security Center for vulnerability scanning.

---

**Q: How does AKS pull images from ACR without storing credentials?**

A: Through Managed Identity. The AKS kubelet identity (a Managed Identity assigned to AKS nodes) is granted the AcrPull role on the ACR. When a pod needs to pull an image, the node uses its Managed Identity to get a short-lived token from Azure AD and presents it to ACR. No passwords or service principal credentials are stored anywhere. This is the recommended authentication method.

---

**Q: Why do we tag Docker images with semantic versioning instead of `latest`?**

A: Using `latest` is bad practice in production because: (1) it's overwritten on every push, losing history; (2) you cannot roll back to a specific version; (3) Kubernetes cannot tell which version is running. Semantic versioning (v1.0.0, v1.0.1) creates an immutable tag for each release. In CI/CD pipelines, the build number is typically used as the tag (e.g., build-42) providing a direct link between the running image and the pipeline run that created it.

---

### Security

**Q: What is a CVE?**

A: CVE stands for Common Vulnerabilities and Exposures. It is a publicly disclosed security vulnerability with a unique identifier (e.g., CVE-2023-44487). Each CVE has a severity rating: Critical, High, Medium, or Low. Security scanners like Trivy check the packages inside a Docker image against the CVE database and report which vulnerabilities are present and what version fixes them.

---

**Q: What is Trivy and where does it fit in a CI/CD pipeline?**

A: Trivy is a free open-source vulnerability scanner by Aqua Security. It scans Docker images for known CVEs in OS packages and application dependencies (npm, pip, etc.). In a CI/CD pipeline it runs as a stage after the Docker build — before the push to ACR. If critical or high vulnerabilities are found, the pipeline fails with exit code 1 and the image is never pushed. This is "shift-left security" — catching problems early in the development cycle rather than after deployment.

---

**Q: What is the difference between Trivy and Microsoft Defender for Containers?**

A: Trivy is a free pipeline tool that scans images before they are pushed to ACR — it acts as a gate, blocking vulnerable images from entering the registry. Microsoft Defender for Containers is a paid Azure service that scans images already in ACR and monitors running AKS containers for suspicious behaviour at runtime. Together they provide defence-in-depth: Trivy prevents known vulnerabilities from reaching ACR, Defender catches anything Trivy missed and provides runtime protection.

---

**Q: What is Content Trust in ACR?**

A: Content Trust uses digital signatures to guarantee that a Docker image was built by a trusted source (your pipeline) and has not been tampered with. When Content Trust is enabled, the pipeline signs images with a private key when pushing. When AKS pulls an image, ACR verifies the signature. If the image was replaced or modified by an attacker, the signature will not match and AKS will refuse to run it. It prevents supply chain attacks where an attacker replaces a legitimate image with a malicious one.

---

**Q: What is "shift-left security"?**

A: Shift-left security means moving security checks earlier in the development process — to the left of the timeline. Traditionally, security testing happened late (before production deployment or after). Shift-left embeds security at every stage: static code analysis during the build, Trivy scanning before push, dependency vulnerability checks on every PR. Issues caught early are cheap to fix; issues caught in production are expensive and damaging.

---

*Phase 4 completed: 2026-05-10*
*Next: Phase 5 — Azure Pipelines CI/CD*

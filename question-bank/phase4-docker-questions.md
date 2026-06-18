# Phase 4 — Docker + ACR: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Docker fundamentals, images vs containers, layers, Dockerfile best practices, multi-stage builds, Docker Compose, service discovery, ACR, image tagging, Trivy, Microsoft Defender for Containers, Content Trust, shift-left security, COPY --from in multi-stage builds, RUN vs CMD, npm install vs npm ci.

---

## Table of Contents

1. [What is the Difference Between a Docker Image and a Container?](#q1-what-is-the-difference-between-a-docker-image-and-a-container)
2. [What Are Multi-Stage Builds and Why Do You Use Them?](#q2-what-are-multi-stage-builds-and-why-do-you-use-them)
3. [Why Should Containers Run as Non-Root Users?](#q3-why-should-containers-run-as-non-root-users)
4. [What is a .dockerignore File?](#q4-what-is-a-dockerignore-file)
5. [What is the Difference Between CMD and ENTRYPOINT in a Dockerfile?](#q5-what-is-the-difference-between-cmd-and-entrypoint-in-a-dockerfile)
6. [What is Docker Compose and When Would You Use It?](#q6-what-is-docker-compose-and-when-would-you-use-it)
7. [How Does Service Discovery Work in Docker Compose?](#q7-how-does-service-discovery-work-in-docker-compose)
8. [What Does depends_on Do in Docker Compose?](#q8-what-does-depends_on-do-in-docker-compose)
9. [What is Azure Container Registry and Why Use It Instead of Docker Hub?](#q9-what-is-azure-container-registry-and-why-use-it-instead-of-docker-hub)
10. [How Does AKS Pull Images from ACR Without Storing Credentials?](#q10-how-does-aks-pull-images-from-acr-without-storing-credentials)
11. [Why Do We Tag Docker Images With Semantic Versioning Instead of latest?](#q11-why-do-we-tag-docker-images-with-semantic-versioning-instead-of-latest)
12. [What is a CVE?](#q12-what-is-a-cve)
13. [What is Trivy and Where Does It Fit in a CI/CD Pipeline?](#q13-what-is-trivy-and-where-does-it-fit-in-a-cicd-pipeline)
14. [What is the Difference Between Trivy and Microsoft Defender for Containers?](#q14-what-is-the-difference-between-trivy-and-microsoft-defender-for-containers)
15. [What is Content Trust in ACR?](#q15-what-is-content-trust-in-acr)
16. [What is Shift-Left Security?](#q16-what-is-shift-left-security)
17. [How Does COPY --from Know Where Files Are in a Previous Stage?](#q17-how-does-copy---from-know-where-files-are-in-a-previous-stage)
18. [What is the Difference Between RUN and CMD in a Dockerfile?](#q18-what-is-the-difference-between-run-and-cmd-in-a-dockerfile)
19. [What is the Difference Between npm install and npm ci?](#q19-what-is-the-difference-between-npm-install-and-npm-ci)

---

## Q1. What is the Difference Between a Docker Image and a Container?

### The Core Distinction

This is the most fundamental question in Docker. Get this clear and everything else follows.

| Term | What it is | State | Analogy |
|---|---|---|---|
| **Image** | A read-only blueprint with all the files, libraries, and config needed to run an app | Static — never changes once built | A recipe for a cake |
| **Container** | A running instance created from an image | Dynamic — has a process, memory, network | The actual cake you baked |

```
Dockerfile  →  docker build  →  Image  →  docker run  →  Container
(instructions)                (blueprint)               (running process)
```

### Key Properties

**Image:**
- Built once, used many times
- Stored in a registry (Docker Hub, ACR)
- Every layer is cached — makes rebuilds fast
- Immutable: you cannot change an image that already exists. You build a new one.

**Container:**
- Created from an image — one image can create many containers
- Has its own filesystem, network, and process space
- When you stop a container, the image still exists
- When you delete a container, the image is untouched

### How Docker Layers Fit In

Every instruction in a Dockerfile creates a **layer**. Layers are cached. If nothing in a layer changed, Docker reuses the cached version — making builds much faster.

```dockerfile
FROM node:20-alpine        # Layer 1 — base OS + Node.js
WORKDIR /app               # Layer 2 — set working directory
COPY package*.json ./      # Layer 3 — copy package files
RUN npm ci                 # Layer 4 — install deps (CACHED if package.json unchanged)
COPY . .                   # Layer 5 — copy source code
RUN npm run build          # Layer 6 — build the app
```

**Key insight:** Put things that change rarely (dependencies) BEFORE things that change often (source code). The slow `npm install` step is cached and only re-runs when `package.json` changes.

### In AzureShop

We have 8 Docker images — one per microservice — all stored in ACR:

```
acrazureshopdev.azurecr.io/user-service:v1.0.0
acrazureshopdev.azurecr.io/product-service:v1.0.0
acrazureshopdev.azurecr.io/cart-service:v1.0.0
... (8 total)
```

When AKS runs these services, it creates **containers** from these images — one (or more) per service.

### Interview Answer Formula

> "An image is a read-only template — like a recipe. A container is a running instance created from that image — like the dish you cook. One image can produce many containers. The image is static and stored in a registry; the container is running and has a live process, memory, and network. When you stop a container, the image is unaffected — you can create a new container from it anytime."

---

## Q2. What Are Multi-Stage Builds and Why Do You Use Them?

### The Problem Without Multi-Stage Builds

If you build a Node.js app in a single Dockerfile stage, the final image contains everything that was needed to build it:
- Full build tools (npm, compilers, TypeScript)
- Dev dependencies (test frameworks, linting tools)
- All source files
- Intermediate build artifacts

None of this is needed at runtime. It just makes your image huge and increases the attack surface.

```
Single-stage image: ~800MB
  ├── Node.js runtime
  ├── npm + build tools
  ├── Dev dependencies (jest, eslint, typescript...)
  ├── Source code (.ts files)
  └── Compiled output (dist/)
```

### How Multi-Stage Builds Solve This

You write **multiple FROM stages** in one Dockerfile. Each stage can copy specific files from a previous stage. The final image only contains what the last stage puts in it — nothing else.

**Analogy:** Like building a house. You use scaffolding during construction (build stage), but the scaffolding is removed before anyone moves in (runtime stage). The house (final image) is clean — no scaffolding, no tools, no debris.

```dockerfile
# ── Stage 1: Install dependencies ──────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci                          # installs ALL deps (including dev)

# ── Stage 2: Build ──────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules   # copy from Stage 1
COPY . .
RUN npm run build                   # compile the app

# ── Stage 3: Runtime ─────────────────────────────────────────────
FROM node:20-alpine AS runtime      # fresh, clean image
WORKDIR /app
COPY --from=builder /app/dist ./    # copy ONLY the compiled output
# No node_modules, no source files, no build tools
CMD ["node", "server.js"]
```

The intermediate stages (`deps`, `builder`) are **discarded** — they never become part of the final image.

### Result

| Approach | Image size |
|---|---|
| Single stage | ~800MB |
| Multi-stage | ~80MB |

10× smaller. Faster to push, faster to pull, fewer packages for attackers to exploit.

### The Frontend Special Case — Next.js Standalone

The `frontend` service uses Next.js with `output: 'standalone'` mode. This produces a self-contained server with no `node_modules` needed at runtime — just the compiled standalone output.

```dockerfile
# Stage 1: Install deps
FROM node:20-alpine AS deps
RUN npm ci

# Stage 2: Build Next.js app
FROM node:20-alpine AS builder
COPY --from=deps /app/node_modules ./node_modules
ARG NEXT_PUBLIC_API_URL=http://localhost:8080
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build && mkdir -p /app/public   # mkdir -p ensures /public exists even if empty

# Stage 3: Runtime — standalone output only
FROM node:20-alpine AS runtime
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
CMD ["node", "server.js"]
```

**Important:** `NEXT_PUBLIC_*` variables are **baked into the JavaScript bundle at build time**. Next.js inlines them into client-side code. You must pass them as `ARG` at build time — runtime env vars won't work for these.

### In AzureShop

All 8 services use multi-stage builds:
- Node.js services: `deps` → `runtime` (2 stages)
- Python (product-service): `builder` (pip --user install) → `runtime` (copy .local + app)
- Next.js frontend: `deps` → `builder` → `runtime` (3 stages)

### Interview Answer Formula

> "Multi-stage builds let you use multiple FROM stages in a single Dockerfile. Build tools, dev dependencies, and source files are used in early stages but never copied into the final image. The final image only contains what you explicitly copy — typically just the compiled output. This makes images 5–10× smaller, faster to deploy, and reduces the attack surface because there are fewer packages a vulnerability could affect."

---

## Q3. Why Should Containers Run as Non-Root Users?

### The Default Behaviour — and the Problem

By default, processes inside containers run as **root** (UID 0). Root inside a container has the same permissions as root on the host — it can:
- Read and write any file in the container
- Modify system configuration
- Install packages
- In certain misconfigurations, escape the container entirely

**Real world analogy:** Imagine running your web server as the Administrator account on Windows. Yes, it works — but if someone hacks your web server, they now have Administrator access to the entire machine. That's the blast radius you're accepting.

### What Non-Root User Gives You

If an attacker exploits a vulnerability in your application code:
- **Root container:** attacker gets root access inside the container — can do almost anything
- **Non-root container:** attacker gets a limited user with no special permissions — blast radius is contained

Defence in depth: the container namespace isolates from the host already, but running as non-root adds another layer.

### How to Do It in a Dockerfile

```dockerfile
# Create a non-root group and user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Switch to that user before the final CMD
USER nodejs

CMD ["node", "server.js"]
```

Everything after `USER nodejs` runs as that user — including the application process.

### Why Use a Specific UID (1001)?

Using a specific UID (`-u 1001`) means:
- The UID is consistent across container restarts and different environments
- Kubernetes PodSecurityPolicy / SecurityContext can explicitly allow this UID
- Avoids conflicts with system UIDs (0–999 are reserved for system accounts)

### In AzureShop

All 8 AzureShop Dockerfiles follow this pattern. The non-root user is named `nodejs` (for Node.js services) and `appuser` (for the Python service). This is a **production requirement** — any security review will flag containers running as root.

### Interview Answer Formula

> "By default, Docker containers run as root. If an attacker exploits a vulnerability in your application, they get root access inside the container — and depending on the configuration, may be able to escalate further. Running as a non-root user limits the blast radius: even if the container is compromised, the attacker has the permissions of a limited user account, not root. All production Dockerfiles should create a non-root user and switch to it with the USER instruction before the CMD."

---

## Q4. What is a .dockerignore File?

### What It Is

A `.dockerignore` file tells Docker which files and directories to **exclude from the build context**. It works exactly like `.gitignore` — same syntax, same concept, different purpose.

When you run `docker build`, Docker sends your entire project directory to the Docker daemon as the "build context". The `COPY . .` instruction then copies from that context into the image. Without `.dockerignore`, you copy everything.

### Why It Matters

Without `.dockerignore`, `COPY . .` copies:

| What gets copied | Problem |
|---|---|
| `node_modules/` | Hundreds of MB — and you're about to `RUN npm ci` anyway, which reinstalls them |
| `.git/` | Your entire git history — large, irrelevant, leaks commit messages |
| `.env` | Secrets and passwords — baked into the image, readable by anyone who pulls it |
| `*.log` | Log files — irrelevant at build time |
| `coverage/` | Test coverage reports — irrelevant at runtime |
| `.DS_Store` | macOS metadata junk |

### A Standard .dockerignore

```
node_modules
.git
*.md
.env
*.log
coverage
.DS_Store
dist
.next
.nyc_output
*.test.js
```

### The Security Angle

This is the most important reason:

```bash
# Anyone who pulls your image can inspect every layer
docker history your-image:v1.0.0
docker run your-image:v1.0.0cat /app/.env
```

If `.env` gets copied into the image — even in a middle layer — it can be extracted. `.dockerignore` prevents it ever entering the build context in the first place.

### In AzureShop

Every service has a `.dockerignore`. The `node_modules` exclusion alone saves ~200–300MB of unnecessary data from entering the build context. Each Dockerfile then uses `RUN npm ci` to install the exact dependencies defined in `package-lock.json` — clean, reproducible, with no stale local modules.

### Interview Answer Formula

> "A .dockerignore file works like .gitignore — it lists files and directories Docker should exclude from the build context. Without it, COPY . . copies node_modules (hundreds of MB), .env files with secrets, .git history, and test files into the image. This makes images unnecessarily large and — more critically — potentially insecure. .dockerignore is a security control: if a file never enters the build context, it can never end up in the image."

---

## Q5. What is the Difference Between CMD and ENTRYPOINT in a Dockerfile?

### What They Both Do

Both `CMD` and `ENTRYPOINT` define what command runs when a container starts. The difference is in **how overridable they are**.

### CMD — Default Arguments, Easily Overridden

`CMD` provides the **default command** to run. It can be completely replaced at `docker run` time.

```dockerfile
CMD ["node", "server.js"]
```

```bash
docker run my-image                    # runs: node server.js (default)
docker run my-image node debug.js      # runs: node debug.js (CMD overridden)
```

### ENTRYPOINT — Fixed Command, Cannot Be Overridden Easily

`ENTRYPOINT` defines the **fixed executable**. Arguments passed at `docker run` become arguments to the entrypoint, not replacements.

```dockerfile
ENTRYPOINT ["node"]
CMD ["server.js"]
```

```bash
docker run my-image                  # runs: node server.js
docker run my-image debug.js         # runs: node debug.js (CMD replaced, ENTRYPOINT kept)
docker run --entrypoint sh my-image  # only --entrypoint flag can override it
```

### The Two Styles Side by Side

| | CMD only | ENTRYPOINT + CMD |
|---|---|---|
| Default run | `node server.js` | `node server.js` |
| User passes `debug.js` | `debug.js` (replaces everything) | `node debug.js` (appended to entrypoint) |
| Use case | Simple scripts, flexible commands | Fixed executables with optional args |

### Real World Analogy

Think of `ENTRYPOINT` as the **job title** and `CMD` as the **task for today**:
- `ENTRYPOINT ["node"]` = "You are a Node.js runner"
- `CMD ["server.js"]` = "Today, run server.js"

You can change today's task (CMD) without changing the job title (ENTRYPOINT). But you can't make a Node.js runner suddenly become a Python runner — unless you specifically override the ENTRYPOINT.

### In AzureShop

The AzureShop services use `CMD` (exec form) for simplicity:

```dockerfile
CMD ["node", "src/index.js"]        # Node.js services
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3002"]  # Python/FastAPI
```

Always use the **exec form** (JSON array `["cmd", "arg"]`) — not the shell form (`CMD node server.js`). The exec form runs the process directly, so `docker stop` sends SIGTERM directly to your process (graceful shutdown). The shell form wraps it in `/bin/sh -c`, meaning SIGTERM goes to the shell, not your app.

### Interview Answer Formula

> "Both CMD and ENTRYPOINT define what runs when a container starts. ENTRYPOINT defines the fixed executable — it's what the container always runs, and can only be overridden with the --entrypoint flag. CMD provides default arguments to the entrypoint, and is easily replaced by passing arguments to docker run. Together, ENTRYPOINT sets the role (node) and CMD sets the default task (server.js). You can override CMD at runtime; ENTRYPOINT requires explicit override."

---

## Q6. What is Docker Compose and When Would You Use It?

### What Docker Compose Is

Docker Compose is a tool for defining and running **multi-container applications** as a single unit. Instead of running 8 separate `docker run` commands with all their flags and environment variables, you write one `docker-compose.yml` file.

```
Without Docker Compose:
  docker run -p 3001:3001 -e DB_SERVER=sqlserver -e DB_NAME=db-users ... user-service
  docker run -p 3002:3002 -e COSMOS_ENDPOINT=... product-service
  docker run -p 3003:3003 -e REDIS_HOST=redis ... cart-service
  ... (8 commands, each with 5-10 flags)

With Docker Compose:
  docker compose up --build
  (one command starts everything)
```

### What Goes in docker-compose.yml

```yaml
services:

  # Infrastructure first (databases)
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
    build: ./services/user-service       # build from Dockerfile
    ports:
      - "3001:3001"
    environment:
      - DB_SERVER=sqlserver              # container name, not localhost
      - DB_NAME=db-users
      - DB_TRUST_CERT=true
    depends_on:
      sqlserver:
        condition: service_healthy       # wait until SQL passes its health check

  cart-service:
    build: ./services/cart-service
    environment:
      - REDIS_HOST=redis
      - REDIS_TLS=false                  # local Redis has no TLS
    depends_on:
      redis:
        condition: service_healthy

networks:
  default:
    name: azureshop-network
```

### build vs image

| Key | When to use | Example |
|---|---|---|
| `build:` | Your own code — build from a Dockerfile | `build: ./services/user-service` |
| `image:` | Third-party tools — pull from a registry | `image: redis:7-alpine` |

### The 12-Factor App Principle

The environment variables pattern in Compose (`DB_SERVER=sqlserver`) follows the **12-Factor App** methodology: your application code never hardcodes where the database is. It reads from env vars:

```javascript
server: process.env.DB_SERVER  // "sqlserver" locally, "sql-azureshop-dev.database.windows.net" in Azure
```

Same Docker image, different behaviour per environment — just change the env vars. This is why the same image that works in Docker Compose locally also works in Kubernetes in Azure.

### When to Use Docker Compose vs Kubernetes

| Docker Compose | Kubernetes |
|---|---|
| Local development | Production |
| Testing all services together | Multi-node, auto-scaling |
| Quick demos | High availability |
| No cloud account needed | Requires cloud infrastructure |
| Single machine only | Runs across multiple machines |

Compose is not production — it's a local development and testing tool. Kubernetes takes over when you deploy to Azure.

### In AzureShop

The root `docker-compose.yml` starts all 8 services + SQL Server + Redis locally. One command (`docker compose up --build`) gives you a running AzureShop on your laptop with all services connected.

### Interview Answer Formula

> "Docker Compose is a tool for defining and running multi-container applications. You write a docker-compose.yml describing all services, their images or Dockerfiles, environment variables, ports, and dependencies. One command — docker compose up — starts the entire stack. It is used for local development and testing. In production, Kubernetes replaces Compose because it handles scheduling across multiple nodes, auto-scaling, self-healing, and rolling deployments."

---

## Q7. How Does Service Discovery Work in Docker Compose?

### The Problem

When `user-service` needs to connect to SQL Server, what address does it use?

- On your laptop without Docker: `localhost`
- In Docker Compose: `localhost` does NOT work

Each container has its own **network namespace** — it has its own `localhost`. When `user-service` connects to `localhost:1433`, it's looking for SQL Server inside the `user-service` container itself — which doesn't exist.

### How Docker Compose Solves It

Docker Compose creates a **private virtual network** and gives every container a **DNS name equal to its service name** in the YAML file.

```yaml
services:
  sqlserver:       # ← this service name becomes the hostname "sqlserver"
    ...
  user-service:
    environment:
      - DB_SERVER=sqlserver    # user-service connects to "sqlserver", not "localhost"
```

```
user-service container
    → connects to "sqlserver:1433"
    → Docker internal DNS resolves "sqlserver" → container IP (e.g., 172.20.0.3)
    → TCP connection established
```

You never need to know the IP address — Docker handles it automatically. If a container restarts and gets a new IP, the DNS name still works.

### Real World Analogy

Like calling a colleague by name instead of memorising their phone number. The company directory (Docker DNS) resolves the name to the actual extension. If they move desks (get a new IP), you still dial the same name.

### This Is the Same Concept as Kubernetes

In Kubernetes, every Service resource gets a DNS entry automatically:

```
http://user-service:3001   → resolves to ClusterIP of the user-service Service
http://product-service:3002 → resolves to ClusterIP of the product-service Service
```

Learning service discovery in Docker Compose teaches you the mental model you'll use in Kubernetes — services find each other by name, not by IP.

### In AzureShop

| Who connects | To what service | Address used |
|---|---|---|
| user-service | SQL Server | `sqlserver:1433` |
| cart-service | Redis | `redis:6379` |
| api-gateway | user-service | `user-service:3001` |
| api-gateway | product-service | `product-service:3002` |

### Interview Answer Formula

> "Docker Compose creates a private network for all services. Each container is given a DNS hostname equal to its service name in the YAML file. If you define a service named sqlserver, other containers reach it at sqlserver:1433 — Docker's internal DNS resolves the name to the container's IP automatically. This is the same concept Kubernetes uses with ClusterIP Services and DNS — services find each other by name, never by IP."

---

## Q8. What Does depends_on Do in Docker Compose?

### The Problem Without depends_on

Docker Compose starts all services simultaneously by default. `user-service` boots up in milliseconds. SQL Server takes 20–30 seconds to initialise. `user-service` tries to connect to `sqlserver:1433` before SQL Server is ready — and fails:

```
user-service  | Error: Failed to connect to sqlserver:1433
user-service  | Connection refused — server not ready yet
user-service  | Exiting...
```

### What depends_on Does

`depends_on` controls **startup order** — Docker Compose starts dependencies before the service that needs them.

```yaml
user-service:
  depends_on:
    sqlserver:
      condition: service_healthy    # wait until health check passes
```

With `condition: service_healthy`, Docker Compose:
1. Starts SQL Server
2. Runs the SQL Server health check repeatedly
3. Only starts `user-service` after the health check passes

### Two Modes of depends_on

| Mode | What it waits for | Use when |
|---|---|---|
| `condition: service_started` | Container is running (process started) | Dependency starts fast and has no health check |
| `condition: service_healthy` | Health check passes | Dependency takes time to be truly ready |

Always use `service_healthy` for databases — they may be "running" but not yet accepting connections.

### The Health Check Required

`service_healthy` only works if the dependency has a `healthcheck` defined:

```yaml
sqlserver:
  healthcheck:
    test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Local@DevPassword1" -Q "SELECT 1" -C || exit 1
    interval: 10s        # check every 10 seconds
    start_period: 30s    # wait 30s before first check (SQL needs time to start)
    retries: 5           # fail 5 times before marking unhealthy
```

```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    retries: 3
```

### In AzureShop

The startup order in AzureShop's docker-compose.yml:

```
sqlserver (health check passes)
    ↓
user-service, order-service (depend on sqlserver)

redis (health check passes)
    ↓
cart-service (depends on redis)

api-gateway (depends on all app services being started)
```

Without this, the services would crash on startup because the databases aren't ready.

### Interview Answer Formula

> "depends_on controls startup order in Docker Compose. Without it, all containers start simultaneously — an application service may try to connect to its database before the database is ready, causing startup failures. With depends_on and condition: service_healthy, Docker Compose waits until the dependency's health check passes before starting the dependent service. This requires a healthcheck block on the dependency — otherwise Docker has no way to know when it's actually ready to accept connections."

---

## Q9. What is Azure Container Registry and Why Use It Instead of Docker Hub?

### What ACR Is

Azure Container Registry (ACR) is Microsoft Azure's **private Docker image registry**. Think of it like GitHub for code — but instead of storing code, it stores Docker images.

```
Public registry  → Docker Hub (anyone can pull — fine for open source)
Private registry → ACR (only authorised users and services can pull)
```

Your company's application images contain **proprietary code**. They must never be publicly accessible. ACR keeps them private inside your Azure environment.

### ACR vs Docker Hub

| | Docker Hub (public) | Azure Container Registry |
|---|---|---|
| **Visibility** | Public by default | Private — requires authentication |
| **Authentication** | Username/password | Azure AD (Managed Identity, Service Principal) |
| **Integration with AKS** | Manual credential setup | Native — Managed Identity, no passwords |
| **Vulnerability scanning** | Paid feature | Built-in (Microsoft Defender) |
| **Location** | Docker's global cloud | Your Azure region |
| **Compliance** | Data leaves your control | Stays in your Azure subscription |
| **Cost** | Free tier (limited) | Basic ~$5/month, Premium ~$50/month |

### ACR SKUs

| SKU | Storage | Extra features | Use case |
|---|---|---|---|
| **Basic** | 10 GB | — | Learning, dev |
| **Standard** | 100 GB | Webhooks | Most production workloads |
| **Premium** | 500 GB | Geo-replication, Private Link, Content Trust | Enterprise, high throughput |

In AzureShop: we manually created a **Basic** ACR for Phase 4 learning. The Terraform module provisions **Premium** for production (required for vulnerability scanning geo-replication).

### ACR Naming Rules

- Globally unique across all of Azure (like a domain name)
- 5–50 characters, alphanumeric only, no hyphens
- AzureShop registry: `acrazureshopdev` → login server: `acrazureshopdev.azurecr.io`

### How Authentication Works

ACR is private. Before Docker can push or pull, it must authenticate:

```bash
az acr login --name acrazureshopdev
# Output: Login Succeeded
```

Behind the scenes:
1. Azure CLI gets a short-lived token from Azure AD (valid ~3 hours)
2. Stores it in Docker's credential store (`~/.docker/config.json`)
3. Docker uses this token automatically on every push/pull to that registry

In CI/CD pipelines, a **Service Principal** or **Managed Identity** is used — no human needed.

`admin_enabled = false` in AzureShop's ACR Terraform config — this disables the shared username/password that ACR offers by default. Authentication is Managed Identity only. No shared passwords to rotate or leak.

### Interview Answer Formula

> "Azure Container Registry is Azure's private Docker image registry. Docker Hub is public — anyone can pull public images, making it unsuitable for proprietary application code. ACR is private — only authenticated users and services can pull images, and it integrates natively with AKS through Managed Identity so no passwords are needed. Images stay in your Azure subscription, meeting compliance requirements. ACR also integrates with Microsoft Defender for Container vulnerability scanning."

---

## Q10. How Does AKS Pull Images from ACR Without Storing Credentials?

### The Problem It Solves

When Kubernetes pulls a Docker image, it needs to authenticate with the registry. The naive approach is to store credentials (username/password) in a Kubernetes Secret and reference it in every pod spec. Problems:
- Passwords expire and need rotation
- Passwords can be leaked from secret objects
- Every new service needs the credentials added manually

### The Solution — Managed Identity + AcrPull Role

AKS uses a **Managed Identity** (the kubelet identity) combined with Azure RBAC to pull images — no passwords at all.

```
AKS node (kubelet) has a Managed Identity
    ↓
That identity is assigned the AcrPull role on the ACR
    ↓
When a pod schedules on the node and needs an image:
    kubelet → gets short-lived Azure AD token using its Managed Identity
    kubelet → presents token to ACR
    ACR → verifies token → allows pull
    ↓
Image pulled, container starts
```

### How It's Configured in Terraform

```hcl
# Grant AKS kubelet identity permission to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}
```

That one Terraform block means every AKS node can pull any image from ACR. No secrets. No rotation. No human involvement.

### What AcrPull Role Allows

`AcrPull` is a built-in Azure RBAC role that gives:
- Pull images from the registry ✅
- List repositories ✅
- Push images ❌ (denied — nodes shouldn't push)
- Delete images ❌ (denied)

Principle of Least Privilege: nodes only get what they need.

### In AzureShop — The 5 Managed Identities

| Identity | Role | Purpose |
|---|---|---|
| AKS system identity | Contributor on VNet/subnet | Manages Load Balancers, VNet rules |
| AKS kubelet identity | **AcrPull on ACR** | Pulls images — this question |
| CSI addon identity | Key Vault Secrets User | Reads secrets from Key Vault |
| Grafana system identity | Monitoring Reader on Subscription | Reads metrics |
| sp-azureshop-terraform | Contributor on Subscription | Terraform + pipeline deployments (Service Principal, not MI) |

### Interview Answer Formula

> "AKS uses a Managed Identity — specifically the kubelet identity assigned to AKS nodes — combined with Azure RBAC. The kubelet identity is granted the AcrPull role on the ACR. When a node needs to pull an image, it uses its Managed Identity to get a short-lived Azure AD token and presents it to ACR. ACR validates the token and allows the pull. No passwords are stored anywhere — Azure handles the token lifecycle. This is configured with a single Terraform role assignment."

---

## Q11. Why Do We Tag Docker Images With Semantic Versioning Instead of latest?

### What `latest` Actually Is

`latest` is just a tag — it has no special meaning in Docker other than "the most recently pushed image with this tag". When you push a new image with the `latest` tag, it **overwrites** the previous one. The old image still exists in the registry but is no longer reachable by the `latest` tag.

### Problems With `latest` in Production

| Problem | Impact |
|---|---|
| Overwritten on every push | Previous version is gone from `latest` — no history |
| Cannot roll back | Which image was running before the bad deploy? You don't know. |
| Kubernetes can't tell versions apart | `latest` is ambiguous — is this the same image or a new one? |
| Builds are not reproducible | `FROM node:latest` in Dockerfile = different base image every week |
| Kubernetes may cache it | With `imagePullPolicy: IfNotPresent`, Kubernetes won't pull a newer image if `latest` is already cached |

### What Semantic Versioning Gives You

Using `v1.0.0`, `v1.0.1`, `v2.0.0` — or in CI/CD pipelines the **build number** — makes every push an **immutable, unique tag**:

```
acrazureshopdev.azurecr.io/user-service:v1.0.0   ← Phase 4 manual push
acrazureshopdev.azurecr.io/user-service:build-42  ← Phase 5 pipeline push
acrazureshopdev.azurecr.io/user-service:build-43  ← next pipeline push
```

Benefits:
- Every image version is preserved — never overwritten
- Roll back is `kubectl set image` with an old tag — instant
- You know exactly which pipeline run produced which image
- Direct link: PR #42 → build-42 → deployed to AKS → observable in Grafana

### In CI/CD Pipelines (Phase 5)

Azure Pipelines automatically provides `$(Build.BuildId)` — a unique incrementing number per run. The pipeline uses it as the image tag:

```yaml
- script: |
    docker build -t $(ACR_LOGIN_SERVER)/user-service:$(Build.BuildId) .
    docker push $(ACR_LOGIN_SERVER)/user-service:$(Build.BuildId)
```

Build 42 fails in production? Roll back to build 41:
```bash
kubectl set image deployment/user-service user-service=acrazureshopdev.azurecr.io/user-service:build-41
```

### In AzureShop

Phase 4 manual pushes used `v1.0.0`. Phase 5 pipelines will use `$(Build.BuildId)`. The Kubernetes deployment manifests (Phase 6) reference specific tags — Kubernetes knows exactly which image to pull.

### Interview Answer Formula

> "Using latest in production is bad practice because it's overwritten on every push — you lose history and cannot roll back to a specific known-good version. Kubernetes also cannot differentiate between two images with the same latest tag, which breaks cache behaviour. Semantic versioning or build numbers create an immutable, unique tag per release. You can roll back to any previous version with a kubectl command and directly trace a running image back to the pipeline run that built it."

---

## Q12. What is a CVE?

### Definition

CVE stands for **Common Vulnerabilities and Exposures**. It is a publicly disclosed security vulnerability with a unique identifier — for example, `CVE-2023-44487`.

When a vulnerability is discovered in a software package:
1. A researcher reports it (sometimes publicly, sometimes through responsible disclosure)
2. The vulnerability is registered in the CVE database with a unique ID
3. The package maintainer releases a patched version
4. Security scanners (Trivy, Defender) check if your installed version is vulnerable

### CVE Severity Ratings

| Severity | CVSS Score | Meaning | Action |
|---|---|---|---|
| **CRITICAL** | 9.0–10.0 | Remotely exploitable, no authentication required | Fix immediately |
| **HIGH** | 7.0–8.9 | Serious, likely exploitable | Fix soon |
| **MEDIUM** | 4.0–6.9 | Requires specific conditions to exploit | Fix in next release |
| **LOW** | 0.1–3.9 | Minor risk, limited exploitability | Fix when convenient |

CVSS = Common Vulnerability Scoring System. Scores are calculated based on: how easy to exploit, whether authentication is needed, what damage it can cause.

### Real Example — CVE-2023-44487

This was the **HTTP/2 Rapid Reset** vulnerability (nicknamed "Rapid Reset Attack"). It allowed attackers to send a flood of requests that could take down HTTP/2 servers (nginx, Apache, etc.) with very little traffic. It was rated **HIGH** to **CRITICAL** depending on configuration.

Fix: upgrade nginx to the patched version. If your Docker image uses an old nginx, Trivy would flag this CVE and fail the pipeline.

### How CVEs Get Into Docker Images

A Docker image is a stack of packages:
- Base OS packages (Alpine Linux: musl, openssl, etc.)
- Runtime packages (Node.js, Python)
- Application dependencies (npm packages, pip packages)

Any of these can have CVEs. When you use `FROM node:20-alpine`, that image contains specific versions of Alpine Linux and Node.js. If those versions have known CVEs, your image inherits them.

**Fixing:** Usually upgrading the base image to a newer patch version clears most OS-level CVEs:

```dockerfile
# Before: Alpine 3.18 — has known CVEs
FROM node:20-alpine

# After: Alpine 3.19 — CVEs fixed in newer patch
FROM node:20-alpine3.19
```

### In AzureShop

Trivy scans all 8 AzureShop images in the CI/CD pipeline. If any image has HIGH or CRITICAL CVEs, the pipeline fails — the image is never pushed to ACR. CVE fixes are just Dockerfile updates that trigger a new build.

### Interview Answer Formula

> "CVE stands for Common Vulnerabilities and Exposures — a publicly disclosed security vulnerability with a unique ID like CVE-2023-44487. Each CVE has a severity rating from Low to Critical based on how easily it can be exploited and what damage it causes. Docker images inherit CVEs from their base OS packages and application dependencies. Security scanners like Trivy check every package in your image against the CVE database and report which vulnerabilities are present, their severity, and which package version fixes them."

---

## Q13. What is Trivy and Where Does It Fit in a CI/CD Pipeline?

### What Trivy Is

Trivy (by Aqua Security) is a **free, open-source vulnerability scanner** for Docker images. It inspects every package inside an image and checks each version against the CVE database.

What it scans:
- OS packages (Alpine, Debian, Ubuntu packages)
- Node.js packages (`node_modules`)
- Python packages (`site-packages`)
- Java packages (JAR files)
- Go binaries

### How Trivy Works

```bash
trivy image acrazureshopdev.azurecr.io/user-service:v1.0.0
```

Trivy:
1. Pulls the image (if not cached locally)
2. Reads every layer
3. Finds all installed packages and their versions
4. Checks each version against the CVE database
5. Reports vulnerabilities grouped by severity

Sample output:
```
user-service:v1.0.0 (alpine 3.18.4)
════════════════════════════════════
Total: 3 (CRITICAL: 0, HIGH: 1, MEDIUM: 2)

┌──────────────┬────────────────┬──────────┬──────────────────┐
│   Library    │ Vulnerability  │ Severity │  Fixed Version   │
├──────────────┼────────────────┼──────────┼──────────────────┤
│ openssl      │ CVE-2023-XXXX  │ HIGH     │ 3.1.4-r1         │
│ libcrypto3   │ CVE-2023-YYYY  │ MEDIUM   │ 3.1.4-r1         │
└──────────────┴────────────────┴──────────┴──────────────────┘
```

Fix: update `FROM node:20-alpine` to a newer patch version. Rebuild and scan again.

### Where Trivy Sits in the Pipeline

```
Developer pushes code
        ↓
Pipeline: Build Docker image
        ↓
Pipeline: Trivy scan  ← HERE
  CRITICAL or HIGH found?
    YES → pipeline FAILS, exit code 1 → image NEVER pushed to ACR
    NO  → pipeline continues
        ↓
Pipeline: Push image to ACR
        ↓
Pipeline: Deploy to AKS
```

The key flag is `--exit-code 1`:

```yaml
# Inside Azure Pipelines YAML
- script: |
    docker run --rm aquasec/trivy:latest image \
      --exit-code 1 \
      --severity HIGH,CRITICAL \
      $(ACR_LOGIN_SERVER)/$(SERVICE_NAME):$(Build.BuildId)
  displayName: 'Trivy Vulnerability Scan'
```

`--exit-code 1` = if HIGH or CRITICAL CVEs are found, the script exits with code 1. The pipeline interprets a non-zero exit code as failure. No human needed — security is enforced automatically, every single time.

### Local vs Pipeline Scanning

| Local scan | Pipeline scan |
|---|---|
| Developer must remember to run it | Runs automatically on every push |
| Can be skipped | Cannot be skipped |
| Different Trivy versions on different machines | Consistent pinned version in pipeline |
| Results not stored | Results stored in pipeline history |
| No enforcement | Hard enforcement — fails the build |

### In AzureShop

Phase 5 pipelines include a `SecurityScan` stage that runs Trivy on every build. If `user-service` picks up a HIGH CVE from an `openssl` upgrade in Alpine, the pipeline fails and the team is alerted. The fix is updating the base image tag in the Dockerfile — a one-line change.

### Interview Answer Formula

> "Trivy is a free open-source vulnerability scanner by Aqua Security. It scans Docker images for known CVEs in OS packages and application dependencies. In a CI/CD pipeline it runs as a stage after the Docker build — before the push to the registry. With --exit-code 1, if any HIGH or CRITICAL CVEs are found, the pipeline fails and the image is never pushed. This enforces security automatically on every commit — no manual step, no way to skip. It's a key part of shift-left security."

---

## Q14. What is the Difference Between Trivy and Microsoft Defender for Containers?

### One-Line Summary

- **Trivy** = the **gate** before images enter ACR (blocks vulnerable images from being pushed)
- **Microsoft Defender** = the **guard** inside ACR and AKS (watches everything already running)

### Detailed Comparison

| | Trivy | Microsoft Defender for Containers |
|---|---|---|
| **Made by** | Aqua Security (open source) | Microsoft (built into Azure) |
| **Cost** | Free | Paid (~$5–15/month for dev cluster) |
| **Where it runs** | Inside CI/CD pipeline | Inside Azure cloud |
| **When it runs** | During build — BEFORE push to ACR | AFTER image is pushed to ACR |
| **Can block a push?** | Yes — pipeline fails, image not pushed | No — alerts after image is already in ACR |
| **Scans running containers?** | No | Yes — monitors live AKS pods |
| **Runtime protection?** | No | Yes — detects crypto-mining, escape attempts, etc. |
| **Setup required** | Add to pipeline YAML | Enable on subscription in Azure portal |

### How Trivy Works (Left Side of Pipeline)

```
Code commit → Build image → Trivy scans → FAIL → fix CVE → rebuild
                                        ↓ PASS
                                   Push to ACR
```

Trivy is **proactive** — it stops known vulnerabilities before they ever enter your registry.

### How Defender Works (Right Side of Pipeline)

**Image scanning:**
```
Image pushed to ACR
        ↓
Defender automatically scans (no action needed from you)
        ↓
Vulnerabilities appear in Microsoft Defender for Cloud dashboard
        ↓
Alert: "user-service has 2 HIGH CVEs — fix: upgrade openssl to 3.1.4"
```
Unlike Trivy, Defender cannot block the push — it only alerts after the fact.

**Runtime protection (Phase 6+):**
Defender monitors every container running in AKS and alerts on:
- Container running as root
- Privilege escalation attempts
- Unexpected outbound connections (e.g., to a crypto-mining pool)
- Container escape attempts
- Unusual file write patterns

```
AKS pod starts making requests to a cryptocurrency mining endpoint
        ↓
Defender detects unusual outbound traffic pattern
        ↓
Alert: "Possible crypto-mining activity in pod user-service-7d9b4"
        ↓
Security team investigates, kills the pod, investigates the image
```

### How They Work Together (Defence in Depth)

```
Developer commits code
        ↓ pipeline
Trivy scans image          ← FREE, catches ~90% of issues BEFORE they reach Azure
  FAIL → fix → rebuild
  PASS → push to ACR
        ↓
Defender scans image in ACR ← catches edge cases Trivy missed, zero-day updates
        ↓
Image deployed to AKS
        ↓
Defender monitors running pods ← runtime protection (Trivy cannot do this)
```

They are not alternatives — they are **complementary layers**. Trivy is cheap and fast (shift-left). Defender is thorough and continuous (cloud-native).

### Interview Answer Formula

> "Trivy is a free pipeline tool that scans images before they are pushed — it acts as a gate, blocking vulnerable images from entering the registry by failing the build. Microsoft Defender for Containers is a paid Azure service that scans images already in ACR and monitors running AKS pods for suspicious behaviour at runtime. Trivy prevents known vulnerabilities from reaching the registry; Defender catches anything Trivy missed and provides runtime protection that Trivy cannot. Together they implement defence-in-depth."

---

## Q15. What is Content Trust in ACR?

### The Attack It Defends Against

Imagine this:

```
1. Attacker gains access to your ACR (stolen credentials, misconfigured permissions)
2. They push a malicious image with the SAME tag: user-service:v1.0.0
3. Your AKS cluster pulls "user-service:v1.0.0" — the tag looks legitimate
4. The malicious image runs in production
5. Data is stolen or the cluster is compromised
```

The tag was identical. AKS had no way to know the image had been replaced. This is a **supply chain attack** — the attacker didn't break into your app, they replaced the app itself.

### What Content Trust Does

Content Trust uses **digital signatures** to guarantee that an image:
- Was built by your trusted CI/CD pipeline — not by an attacker
- Has not been modified in any way since it was signed

```
Your pipeline builds image
        ↓
Pipeline signs it with a PRIVATE KEY → signature stored in ACR
        ↓
AKS pulls image
        ↓
AKS verifies signature with PUBLIC KEY
  ✅ Signature matches → container starts
  ❌ Signature missing or wrong → REJECTED, container never runs
```

Even if an attacker replaces `user-service:v1.0.0` with a malicious image, the signature won't match — and AKS will refuse to run it.

### Real World Analogy

A government-issued passport. The government (your pipeline) prints the passport and stamps it with an official seal (digital signature). At the border (AKS), the officer checks the seal against the known standard. A forged passport that looks identical will fail the verification — the seal can't be replicated without the government's private key.

### How to Enable It

```bash
# Enable Content Trust on the registry
az acr config content-trust update --name acrazureshopdev --status enabled
```

When enabled and enforced, unsigned images cannot be pulled from the registry — even by someone with valid pull credentials.

### When to Implement

Content Trust requires **pipeline integration** — the signing step must be automated on every push. Manually signing images is error-prone and defeats the purpose. In AzureShop, this will be fully implemented in Phase 5 (Azure Pipelines) when the pipeline is the only path for images to reach ACR.

### Content Trust vs Trivy vs Defender

| Tool | Defends against |
|---|---|
| Trivy | Known vulnerabilities in packages (CVEs) |
| Defender | Runtime threats, CVEs missed by Trivy |
| **Content Trust** | **Tampered or forged images — supply chain attacks** |

They solve different problems. A well-secured system uses all three.

### Interview Answer Formula

> "Content Trust uses digital signatures to guarantee that a Docker image was built by your trusted pipeline and has not been tampered with since. The pipeline signs images with a private key when pushing. When AKS pulls an image, it verifies the signature against the public key stored in ACR. If the signature is missing or doesn't match — for example if an attacker replaced the image — AKS refuses to run it. This protects against supply chain attacks where the image itself is compromised, not the application code."

---

## Q16. What is Shift-Left Security?

### The Traditional Approach (And Its Problem)

In traditional software development, security testing happened **late** — right before the production release, or after an incident:

```
Code → Build → Test → Stage → Security Review → Production
                                     ↑
                              Problems found HERE
                              Expensive to fix
                              Delays the release
                              Sometimes skipped entirely
```

Issues found late are:
- **Expensive:** requires rework across many layers
- **Slow:** delays release while fixes are made
- **Risky:** sometimes shipped anyway to meet deadlines

### Shift-Left Means Moving Security Earlier

"Left" refers to the left side of the development timeline. Shift-left = move security checks **as early as possible**:

```
EARLIER                                                      LATER
─────────────────────────────────────────────────────────────────────
Code  → PR Review → Build → Test → Stage → Deploy → Runtime
  ↑          ↑        ↑       ↑                       ↑
Secret    Static    Trivy   Dep      ─────────────    Defender
scanning  analysis  scan   vuln                      runtime
                          check                      protection
```

Each arrow is a security gate. Problems caught at the code stage are cheap — one developer, one fix. Problems caught in production are expensive — incident response, customer impact, potential data breach.

### Shift-Left in Practice — AzureShop Examples

| Stage | Tool / Practice | What it catches |
|---|---|---|
| Code commit | `.gitignore` + pre-commit hooks | Secrets accidentally staged |
| PR review | Code review | Logic flaws, insecure patterns |
| Build | `RUN npm ci` (not `npm install`) | Reproducible, exact dependencies |
| Build | `USER nodejs` in Dockerfile | Non-root enforcement |
| Build | Trivy scan (`--exit-code 1`) | CVEs in image packages |
| Registry | Defender for Containers | CVEs missed by Trivy |
| Runtime | Defender runtime protection | Live threat detection |

### The Cost of Finding Bugs Late

Research (IBM Systems Sciences Institute) found:
- Bug found during **coding**: cost $1
- Bug found during **testing**: cost $10
- Bug found in **production**: cost $100

Security bugs follow the same curve — but the "production" cost also includes breach costs, regulatory fines, and reputational damage.

### Shift-Left vs Defence in Depth

These are related but different concepts:

- **Shift-Left** = move security checks earlier in the timeline
- **Defence in Depth** = have multiple security layers (if one fails, another catches it)

In AzureShop, Trivy is shift-left (catches problems early). Defender is defence-in-depth (catches what Trivy missed). Both principles are applied simultaneously.

### Interview Answer Formula

> "Shift-left security means moving security checks earlier in the development process — to the left of the timeline. Traditionally, security testing happened right before production, making issues expensive and slow to fix. Shift-left embeds security at every stage: secret scanning on commit, static analysis on PR, Trivy scanning on every build, dependency checks in the pipeline. Issues caught at commit time are fixed in minutes by one developer. Issues caught in production require incident response, customer communication, and sometimes regulatory reporting. Shift-left makes security continuous and cheap rather than infrequent and expensive."

---

## Q17. How Does COPY --from Know Where Files Are in a Previous Stage?

### The Question

In a multi-stage Dockerfile you see this line:

```dockerfile
COPY --from=deps /app/node_modules ./node_modules
```

You understand that `--from=deps` means "copy from the previous stage named `deps`". But how does Docker know that `node_modules` is inside `/app` in that stage? And where does `./node_modules` come from?

### Breaking Down the Two Paths

The line has **two paths** — source and destination:

```
COPY --from=deps   /app/node_modules   ./node_modules
                   ─────────────────   ──────────────
                   SOURCE              DESTINATION
                   (from deps stage)   (in current stage)
```

**`/app/node_modules`** = source — where the files are inside the `deps` stage.

**`./node_modules`** = destination — where you want to place those files in the **current stage**. The `.` means "current working directory". Because the builder stage also has `WORKDIR /app` at the top, `./node_modules` resolves to `/app/node_modules` in the builder stage.

So the full translation is:

```
"Take /app/node_modules from the deps stage
 and copy it into /app/node_modules in this stage"
```

You are **reusing the already-installed packages** from the `deps` stage instead of running `npm ci` again — that is the whole point.

### The Answer — YOU Put Them There

It is not magic. Docker knows where the source files are because **you told it where to put them** in the `deps` stage. Trace through the `deps` stage line by line:

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app           # ← sets the working directory to /app inside the container
COPY package*.json ./  # copies package.json into /app/ (current directory)
RUN npm ci             # npm installs node_modules into the CURRENT directory = /app/node_modules
```

`WORKDIR /app` is the key instruction. It tells Docker: "from this point, every command runs inside `/app`". So when `npm ci` runs, it installs packages into the current directory — which is `/app`. That is why `node_modules` ends up at `/app/node_modules`.

Then in the next stage when you write:

```dockerfile
COPY --from=deps /app/node_modules ./node_modules
```

You already know the source path is `/app/node_modules` because **you created it** with `WORKDIR /app` + `npm ci` in the `deps` stage. And the destination `./node_modules` lands in `/app/node_modules` of the builder stage because `WORKDIR /app` is set there too.

### Step-by-Step Trace

```
deps stage:
  WORKDIR /app        → current directory is now /app
  COPY package*.json  → /app/package.json, /app/package-lock.json now exist
  RUN npm ci          → npm reads /app/package.json
                        installs packages into /app/node_modules/
                        (/app/node_modules/express, /app/node_modules/mssql, etc.)

builder stage:
  COPY --from=deps /app/node_modules ./node_modules
                      → "go into the deps stage filesystem"
                        "find /app/node_modules"
                        "copy it here as ./node_modules"
```

### Real World Analogy

> You tell your assistant (deps stage): "Go to the kitchen (`WORKDIR /app`) and buy groceries (`npm ci`)."
> The groceries land in the kitchen (`/app/node_modules`) — obviously, because that's where you sent them.
> Later you say: "Bring me the groceries from the kitchen (`COPY --from=deps /app/node_modules`)."
> You already know where they are because **you sent them there**.

### What If WORKDIR Was Different?

If you had set `WORKDIR /myapp` instead:

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /myapp         # different working directory
COPY package*.json ./
RUN npm ci             # installs into /myapp/node_modules
```

Then the COPY in the next stage would need to match:

```dockerfile
COPY --from=deps /myapp/node_modules ./node_modules   # path must match what deps stage created
```

The rule: **the path in `COPY --from` must match where the files actually are in the source stage** — and you control that with `WORKDIR` and your `RUN` commands.

### In AzureShop

All Node.js services use `WORKDIR /app` consistently. So every stage in every Dockerfile uses `/app` as the base path. This consistency means all `COPY --from` lines use `/app/...` — no confusion about which path to use.

### Interview Answer Formula

> "COPY --from copies files from a previous stage's filesystem. The path you specify must match where the files actually are in that stage — which you control with WORKDIR and RUN commands. If you set WORKDIR /app and run npm ci, node_modules lands at /app/node_modules. So COPY --from=deps /app/node_modules works because you explicitly put them there. It is not Docker guessing — it is you knowing what your own stage created."

---

## Q18. What is the Difference Between RUN and CMD in a Dockerfile?

### The Core Difference

| | RUN | CMD |
|---|---|---|
| **When it runs** | `docker build` — build time | `docker run` — every container start |
| **How many times** | Once per `RUN` line | Every time a container starts |
| **Creates a layer?** | Yes | No |
| **Purpose** | Install, build, prepare the image | Start the application |
| **Can be overridden?** | No | Yes — at `docker run` time |

### RUN — Build Time

`RUN` executes a command **while building the image**. The result is baked permanently into the image as a new layer.

```dockerfile
RUN npm ci              # runs ONCE at build time — installs packages into the image
RUN npm run build       # runs ONCE at build time — compiles the app
```

- Every `RUN` instruction creates a new layer
- Used to install packages, compile code, create files, set permissions
- Once the image is built, these commands never run again

### CMD — Runtime

`CMD` defines the command that runs **every time a container starts** from the image. It does not run during `docker build` at all.

```dockerfile
CMD ["node", "src/index.js"]   # runs every time a container starts
```

- Does NOT create a layer — it is just metadata stored in the image
- Only ONE `CMD` is allowed — if you write multiple, only the last one is used
- Can be overridden by passing a command at `docker run`

### Simple Analogy

> Building a house (`docker build`):
> - `RUN` = the construction work — lay bricks, wire electricity, paint walls. Done once, result is permanent in the house.
> - `CMD` = the instruction left for the person who moves in — "turn on the heating when you arrive". Runs every time someone moves in (container starts).

### Side by Side in a Dockerfile

```dockerfile
FROM node:20-alpine AS runtime
WORKDIR /app

# RUN — build time: these execute once when building the image
RUN npm ci              # install dependencies → baked into image
RUN npm run build       # compile TypeScript → baked into image

# CMD — runtime: this executes every time a container starts
CMD ["node", "src/index.js"]
```

### In AzureShop

All 8 AzureShop Dockerfiles follow this pattern:

```dockerfile
# Build time (RUN)
RUN npm ci                        # install exact dependencies
RUN npm run build                 # compile the application

# Runtime (CMD)
CMD ["node", "src/index.js"]      # start the server every time the container runs
```

When AKS starts a pod, it does NOT re-run `npm ci` or `npm run build` — those are already baked into the image. It only runs the `CMD` — starting the Node.js server instantly.

### Common Mistake to Avoid

```dockerfile
# WRONG — RUN starts the server at build time, not runtime
RUN node src/index.js       # this would hang the build forever

# CORRECT — CMD starts the server at container runtime
CMD ["node", "src/index.js"]
```

### Interview Answer Formula

> "RUN executes commands at build time — when docker build runs. The result is baked into the image as a layer. It is used to install packages, compile code, and prepare the image. CMD executes at runtime — every time a container starts from the image. It defines what process the container runs. RUN runs once and is permanent; CMD runs on every container start and can be overridden at docker run time."

---

## Q19. What is the Difference Between npm install and npm ci?

### The Core Difference

| | `npm install` | `npm ci` |
|---|---|---|
| **Reads from** | `package.json` | `package-lock.json` (strict) |
| **Lock file required?** | No | Yes — fails if missing |
| **Can upgrade packages?** | Yes — silently | Never — exact versions only |
| **Deletes node_modules first?** | No | Yes — always fresh install |
| **Modifies lock file?** | Yes — updates it | Never — read-only |
| **Speed** | Slower | Faster (no resolution step) |
| **Use case** | Local development | CI/CD pipelines, Docker builds |

### Why `npm install` is Risky in Docker

`npm install` reads `package.json` which specifies versions with ranges:

```json
"express": "^4.18.0"
```

The `^` means "install 4.18.0 OR any newer compatible version". So today it installs `4.18.0`, next month it silently installs `4.19.2` — without you knowing. Your build that worked yesterday might behave differently today. This is called a **non-deterministic build** — the output depends on when you run it, not just what you wrote.

### Why `npm ci` is the Right Choice for Docker

`npm ci` reads `package-lock.json` which has **exact, pinned versions with checksums**:

```json
"express": {
  "version": "4.18.0",
  "resolved": "https://registry.npmjs.org/express/-/express-4.18.0.tgz",
  "integrity": "sha512-..."   ← checksum verified on every install
}
```

- Same result **every single time** — your laptop, a colleague's laptop, the pipeline, AKS — all identical
- Verifies **integrity checksums** — detects tampered or corrupted packages
- Deletes `node_modules` before installing — no stale leftover files from a previous install
- Faster — skips the dependency resolution step since versions are already locked

### How It Works in AzureShop Dockerfiles

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./     # copies BOTH package.json AND package-lock.json
RUN npm ci                # reads package-lock.json → exact versions → checksums verified
```

`COPY package*.json ./` — the `*` wildcard matches both files:
- `package.json`
- `package-lock.json` ← this is what `npm ci` actually uses

Without `package-lock.json` in the repo, `npm ci` fails immediately:

```
npm error The `npm ci` command can only install with an existing package-lock.json
```

### This Actually Happened in AzureShop

During Phase 4, this exact error hit because lock files were missing from the repository. The fix:

```bash
cd services/user-service
npm install --package-lock-only   # generates lock file WITHOUT installing node_modules
```

This was run for all 6 Node.js services and the lock files were committed to the repo. After that, `npm ci` in the Dockerfile worked correctly.

### Simple Analogy

> - `npm install` = "Go to the supermarket and buy milk, eggs, bread — any brand is fine, get whatever looks good today"
> - `npm ci` = "Go to the supermarket and buy **exactly** Amul milk 500ml batch #A123, Hen eggs size M from Farm X, Brown bread from Brand Y lot #456 — same every time, no substitutions"

### When to Use Each

| Situation | Use |
|---|---|
| Adding a new package locally | `npm install <package>` — updates package.json and lock file |
| Local development after pulling latest code | `npm install` — fine, updates lock if needed |
| Docker build | `npm ci` — always, no exceptions |
| CI/CD pipeline | `npm ci` — always, ensures reproducible builds |
| Generating a lock file from scratch | `npm install --package-lock-only` |

### Interview Answer Formula

> "npm install reads package.json and resolves dependency versions at install time — meaning it can silently install newer versions if the version range allows it. This makes builds non-deterministic. npm ci reads package-lock.json strictly — it installs exactly the pinned versions with no resolution, verifies checksums, and always starts with a clean node_modules. In Docker builds and CI/CD pipelines, npm ci is mandatory because it guarantees the same packages are installed every single time on every machine."

---

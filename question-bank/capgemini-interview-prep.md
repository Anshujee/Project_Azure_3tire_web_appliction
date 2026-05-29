# Capgemini — Senior Azure Engineer (SRE/DevOps) Interview Prep

**Role:** Senior Azure Engineer, Mumbai/Pune  
**Prepared for:** Anshu  
**Date:** 2026-05-29  
**Project reference throughout:** AzureShop (production-grade microservices on Azure)

---

## How to Use This Document

- Read all 40 Q&A from top to bottom — one full pass.
- Mark questions you are not confident in.
- Revisit those questions the next day.
- After one full revision, move to the mock interview session.

Questions are grouped into 6 sections matching the JD:

1. Platform Engineering & IaC (Q1–Q8)
2. SRE & Reliability (Q9–Q16)
3. DevOps & CI/CD (Q17–Q24)
4. Security & Compliance (Q25–Q32)
5. Operations & Incident Management (Q33–Q37)
6. Behavioral & Collaboration (Q38–Q40)

---

## Section 1 — Platform Engineering & IaC (Q1–Q8)

---

### Q1. What is Infrastructure as Code (IaC)? Why did you choose Terraform over ARM templates or Bicep?

**Answer:**

Infrastructure as Code means you define your cloud resources (VMs, networks, databases, etc.) in code files — just like you write application code. Instead of clicking through the Azure portal, you write a `.tf` file and run `terraform apply`. The infrastructure is created, updated, or destroyed based on what that file says.

**Why this matters:**
- Repeatable: run the same code 100 times, you get the same infrastructure
- Version controlled: tracked in Git — you can see who changed what and roll back
- Reviewable: changes go through a PR just like application code
- Automated: pipelines can run it without human clicks

**Why Terraform over ARM/Bicep:**

| Factor | Terraform | ARM / Bicep |
|---|---|---|
| Multi-cloud | Works on Azure, AWS, GCP | Azure only |
| Community modules | Huge registry at registry.terraform.io | Limited |
| State management | Explicit state file (powerful) | No concept of state |
| Readability | HCL is clean and readable | ARM JSON is verbose |
| Industry adoption | Most widely used IaC tool | Azure-specific shops |

In AzureShop, you used Terraform with 7 modules: networking, aks, databases, keyvault, monitoring, acr, appgateway. Remote state was stored in Azure Blob Storage so the team shares the same state file.

**Interview tip:** If they ask "why not Bicep?" say — "Bicep is excellent for Azure-native teams. I chose Terraform because it is provider-agnostic and the most in-demand skill in the market. If this team uses Bicep, I am happy to work with it — the concepts are identical."

---

### Q2. Explain Terraform modules. Why did you structure AzureShop with modules?

**Answer:**

A Terraform module is a folder containing `.tf` files that defines a reusable piece of infrastructure. Think of it like a function in programming — you define it once and call it with different parameters.

**Without modules** you would have one giant `main.tf` with 1000 lines. Impossible to maintain.

**With modules**, your root `main.tf` looks like this:

```hcl
module "networking" {
  source              = "./modules/networking"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_address_space  = var.vnet_address_space
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = var.resource_group_name
  vnet_subnet_id      = module.networking.aks_subnet_id
}
```

Clean, readable, and the `aks` module automatically gets the subnet ID output from the `networking` module.

**In AzureShop:**
- `modules/networking` — VNet, subnets, NSGs
- `modules/aks` — AKS cluster, node pools, RBAC
- `modules/databases` — Azure SQL, Redis, Cosmos DB
- `modules/keyvault` — Key Vault, access policies, secrets
- `modules/monitoring` — Log Analytics, App Insights (×8 via for_each)
- `modules/acr` — Azure Container Registry
- `modules/appgateway` — Application Gateway, WAF

Each module has `variables.tf` (inputs), `main.tf` (resources), and `outputs.tf` (values other modules need).

**Interview tip:** They may ask about module versioning. In production you would pin modules: `source = "git::https://github.com/org/terraform-modules.git//networking?ref=v1.2.0"`. Pinning prevents a module update from breaking your production infra.

---

### Q3. What is Terraform remote state? How did you configure it in AzureShop?

**Answer:**

When you run `terraform apply`, Terraform writes a `terraform.tfstate` file that records the current state of your infrastructure — every resource, its ID, its properties. This file is Terraform's memory.

**Problem with local state:** If you work in a team, everyone has their own local state file. Two people run `terraform apply` at the same time — disaster. State files get out of sync.

**Remote state:** Store the state file in a shared, central location. Everyone reads and writes from the same place. Azure Blob Storage is the standard for Azure + Terraform.

**AzureShop configuration:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}
```

**State locking:** When one person runs `terraform apply`, Azure Blob Storage automatically locks the state file. If another person tries to run at the same time, they see: "Error acquiring the state lock." This prevents corruption.

**Important gotcha from AzureShop:** Key Vault has `purge_protection_enabled = true`. After `terraform destroy`, the Key Vault goes into a 90-day soft-delete state. Running `terraform apply` again fails because Terraform thinks it needs to create a new Key Vault but the old one still occupies the name. Fix: `az keyvault recover` first, then `terraform import` to bring it back into state.

**Interview tip:** They may ask about state file security. The state file contains secrets in plaintext (connection strings, passwords). Always enable storage account encryption, use private endpoints for the storage account, and restrict access via RBAC.

---

### Q4. Explain VNet, Subnets, and NSGs. How did you use them in AzureShop?

**Answer:**

**VNet (Virtual Network):** Your private network in Azure. Nothing from the internet can enter unless you explicitly allow it. Think of it as the walls around your office building.

**Subnet:** A division inside the VNet. You separate different parts of your system into different subnets so they can have different rules. Like different floors of the building — reception (public), offices (private), server room (restricted).

**NSG (Network Security Group):** A firewall for a subnet or a single NIC. Contains inbound and outbound rules. Each rule says: allow or deny traffic on a specific port from a specific source.

**AzureShop setup:**

```
VNet: 10.0.0.0/16
├── aks-subnet:       10.0.1.0/24   ← AKS pods and nodes
├── appgw-subnet:     10.0.2.0/24   ← Application Gateway
├── db-subnet:        10.0.3.0/24   ← Azure SQL, Redis, Cosmos
└── services-subnet:  10.0.4.0/24   ← Supporting services
```

NSG on `db-subnet`: only allow traffic from `aks-subnet`. The database is never accessible from the internet — only from the AKS pods.

NSG on `appgw-subnet`: allow inbound HTTP/HTTPS from internet (0.0.0.0/0 on ports 80, 443). The Application Gateway is the only public entry point.

**Interview tip:** The question about Private Endpoints often follows this. A Private Endpoint goes one step further than NSGs — it takes a PaaS service (like Azure SQL, Key Vault, Storage) and gives it a private IP inside your VNet. Traffic never leaves your private network. Combined with `publicNetworkAccess = Disabled`, no internet access is possible at all.

---

### Q5. What is a Private Endpoint? Why is it important? Explain with a real example.

**Answer:**

## The Problem Private Endpoint Solves

When you create an Azure SQL database, Azure gives it a public URL:

```
sql-azureshop-dev.database.windows.net
```

This URL resolves to a **public IP address** — something like `52.183.x.x`. That IP is reachable from anywhere on the internet. Azure's firewall blocks unauthorised callers, but the database is still **publicly exposed**.

Think of it like this:

> Your house (database) is on a public street. Anyone can walk up to your front door and knock. You have a lock (firewall), so they cannot get in — but they can still reach the door.

---

## What Private Endpoint Does

A Private Endpoint takes that Azure SQL database — which lives on Microsoft's public infrastructure — and **gives it a private IP address inside your VNet**.

Now your database has two addresses:
- Public: `52.183.x.x` → you **disable** this
- Private: `10.0.3.5` → only reachable inside your VNet

> Your house has been moved **inside a gated community** (your VNet). There is no public street anymore. The only way to reach the front door is to already be inside the gate.

---

## Real World Analogy — Office Building

**Without Private Endpoint:**
The file room (database) has two doors:
- A back door inside the office building (your VNet)
- A front door on the public street (internet)

The front door has a security guard (firewall). Most strangers cannot get in. But the door exists — someone can try to pick the lock or find a vulnerability.

**With Private Endpoint:**
The front door on the public street is **bricked up permanently**. There is only one way in — through the back door, inside the building. If you are not already inside the building, you cannot reach the file room at all.

---

## How It Works Technically — Step by Step

**Step 1 — Azure creates a NIC in your subnet**

Azure places a Network Interface Card (NIC) with a private IP inside your `db-subnet`. This NIC represents the Azure SQL service.

```
db-subnet (10.0.3.0/24)
├── 10.0.3.4  ← Azure reserved
├── 10.0.3.5  ← Private Endpoint NIC for Azure SQL
└── ...
```

**Step 2 — Private DNS Zone overrides the public DNS**

Before Private Endpoint:
```
DNS query: sql-azureshop-dev.database.windows.net
Answer:    52.183.x.x  (public IP)
```

After Private Endpoint, a Private DNS Zone (`privatelink.database.windows.net`) is linked to your VNet:
```
DNS query: sql-azureshop-dev.database.windows.net
Answer:    10.0.3.5  (private IP — inside your VNet)
```

Same hostname — but inside your VNet it resolves to the private IP. Outside your VNet it still resolves to the public IP (which is blocked).

**Step 3 — Disable public access entirely**

```hcl
resource "azurerm_mssql_server" "main" {
  public_network_access_enabled = false  # front door bricked up
}
```

Now the database has zero public exposure — no IP to attack, no port to scan.

---

## Real AzureShop Example — Traffic Flow

Your `product-service` pod (running in `aks-subnet`) connects to Azure SQL.

**Without Private Endpoint:**
```
product-service pod (10.0.1.x)
  → DNS lookup → 52.183.x.x (public IP)
  → Traffic leaves your VNet
  → Goes through Microsoft's public backbone
  → Hits Azure SQL's public endpoint
  → Firewall checks IP allowlist → allowed in
```

Traffic touched the public internet. Multiple attack surfaces.

**With Private Endpoint:**
```
product-service pod (10.0.1.x)
  → DNS lookup → 10.0.3.5 (private IP)
  → Traffic stays inside your VNet (aks-subnet → db-subnet)
  → Hits the Private Endpoint NIC
  → Reaches Azure SQL
```

Traffic **never left your VNet**. No public IP involved.

---

## Why It Is Important — 4 Reasons

**1. Zero public attack surface**
A hacker scanning the internet cannot find your database. There is no public IP to connect to. You cannot attack what you cannot reach.

**2. Compliance requirement**
PCI-DSS, HIPAA, SOC 2, and ISO 27001 require that sensitive data must not traverse public networks. Private Endpoint satisfies this requirement.

**3. Data exfiltration protection**
Without Private Endpoint, a compromised pod could send data to any Azure SQL server on the public internet. With Private Endpoint and `publicNetworkAccess = Disabled`, data can only go to your specific database inside your VNet.

**4. Defense in depth**
NSG rules are one layer. Private Endpoint is a second independent layer — even if NSG is misconfigured, there is no public IP to reach.

---

## Service Endpoint vs Private Endpoint (Common Interview Question)

| | Service Endpoint | Private Endpoint |
|---|---|---|
| How it works | Optimised route from VNet to service's **public IP** | Service gets a **private IP inside your VNet** |
| Public IP still exists? | Yes | No (you disable it) |
| Internet traffic possible? | Yes (if firewall allows) | No |
| Private DNS needed? | No | Yes |
| Cost | Free | Small hourly charge (~$7/month) |
| Security level | Good | Better |

**Simple way to remember:**
- Service Endpoint = faster road to the same public address
- Private Endpoint = the building moves inside your fence

---

**One-line summary for the interview:**

> A Private Endpoint gives an Azure PaaS service a private IP inside your VNet so that traffic never leaves your network and the service has no public address to attack.

---

### Q6. What is the difference between Application Gateway, Azure Load Balancer, and Azure Front Door?

**Answer:**

All three distribute traffic — but at different layers and for different use cases.

| Feature | Azure Load Balancer | Application Gateway | Azure Front Door |
|---|---|---|---|
| OSI Layer | Layer 4 (TCP/UDP) | Layer 7 (HTTP/HTTPS) | Layer 7, global |
| Traffic routing | IP/port based | URL path, host header | Global, geo-routing |
| SSL termination | No | Yes | Yes |
| WAF | No | Yes (WAF v2) | Yes |
| Scope | Single region | Single region | Multi-region, global |
| Use case | Internal load balancing, TCP apps | Web apps with routing rules | CDN, global failover |

**In AzureShop:** You used Application Gateway as the public entry point. It terminates SSL (HTTPS), has WAF for web attack protection, and routes traffic to NGINX Ingress Controller inside AKS. The flow is:

```
Internet → Application Gateway (public IP, SSL, WAF) 
         → AKS NGINX Ingress (134.33.223.224, path routing) 
         → Kubernetes Services (ClusterIP) 
         → Pods
```

**Why not Front Door?** Front Door is for multi-region global apps. AzureShop is single-region (dev). In production with multiple regions, you would put Front Door in front of Application Gateway in each region.

**Interview tip:** They may ask specifically about WAF. WAF (Web Application Firewall) protects against OWASP Top 10 attacks — SQL injection, cross-site scripting, etc. Application Gateway WAF runs in two modes: Detection (log only) and Prevention (block + log). Always start with Detection to tune rules before switching to Prevention.

---

### Q7. What is GitOps? How did you implement it in AzureShop?

**Answer:**

GitOps is a practice where Git is the **single source of truth** for both application code AND infrastructure configuration. Instead of someone running `kubectl apply` manually, a GitOps controller runs inside the cluster, watches a Git repo, and automatically applies any changes it sees.

**The GitOps loop:**
1. Developer pushes a change to the Git repo
2. GitOps controller (running in the cluster) detects the change
3. Controller pulls the new configuration and applies it to the cluster
4. Cluster state matches the Git state — always

**Benefits:**
- No one has `kubectl` access to production — the controller does it
- Every change is tracked in Git with who did it and why (PR + commit message)
- Rollback = revert the Git commit. Controller automatically reverts the cluster.
- Audit trail for compliance

**AzureShop implementation (Phase 9):**

You used **Flux** (the CNCF GitOps tool). Flux was installed as an AKS extension via Terraform:

```hcl
resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = module.aks.cluster_id
  extension_type = "microsoft.flux"
}
```

Then you created **HelmRelease** CRDs in `k8s/gitops/releases/` — one per service. A HelmRelease tells Flux: "Watch this Helm chart at this version. If I push a new version, upgrade the release automatically."

```yaml
# k8s/gitops/releases/product-service.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: product-service
spec:
  chart:
    spec:
      chart: ./helm/product-service
      version: "1.0.0"
```

**Interview tip:** They may compare Flux vs Argo CD. Both are GitOps tools. Argo CD has a better UI and is more popular for teams that want visual dashboards. Flux is more lightweight and Kubernetes-native. Capgemini may use either — say you have experience with Flux and are familiar with the Argo CD concept.

---

### Q8. What is an Azure Landing Zone?

**Answer:**

A Landing Zone is a pre-configured, opinionated Azure environment that is ready to host workloads. It is like a furnished apartment — the building (Azure subscription) is built and all the standard things (networking, security, monitoring, governance) are already set up following best practices. Application teams move their workload in without worrying about the plumbing.

**What a landing zone typically includes:**
- Management groups and subscriptions (hierarchy)
- VNet with standard subnets + Private DNS zones
- Azure Policy assignments (enforce tagging, enforce SKUs, deny public IPs)
- RBAC assignments (who can do what)
- Log Analytics workspace (centralized logging)
- Key Vault for secrets
- Budget alerts and FinOps guardrails
- Defender for Cloud enabled

**Microsoft's CAF (Cloud Adoption Framework)** defines the official landing zone architecture. It has two main zones:
- **Platform landing zone** — shared services (identity, networking, monitoring) managed by the platform team
- **Application landing zone** — where individual workloads run, with guardrails from the platform

**In AzureShop context:** Your Phase 2 Terraform built a mini landing zone — VNet, Key Vault, Log Analytics, ACR, AKS, App Gateway — all connected and secured. It is not the full enterprise CAF structure (no Management Groups, no Policy initiative), but the concepts are identical.

**Interview tip:** They may ask: "How would you scale this to 50 application teams?" Answer: Management Groups, Azure Policy (deny without tags, deny public IPs), subscription vending (automation that creates a new subscription with all guardrails pre-applied), and a platform team that maintains the shared services.

---

## Section 2 — SRE & Reliability (Q9–Q16)

---

### Q9. What are SLI, SLO, SLA, and error budgets? How do they all connect?

**Answer:**

These are the core SRE concepts for measuring and managing reliability.

**SLI — Service Level Indicator:** A specific metric you measure. It is a number. Examples:
- Request success rate: (successful requests / total requests) × 100
- Latency: P95 response time in milliseconds
- Availability: (uptime minutes / total minutes) × 100

**SLO — Service Level Objective:** The target you set for an SLI. Your promise to yourself. Examples:
- "99.9% of requests must succeed" 
- "P95 latency must be under 500ms"
- "Availability must be ≥ 99.5%"

**SLA — Service Level Agreement:** A legal contract with a customer. If you breach it, there are penalties (refunds, credits). SLA is always lower than SLO — you promise customers less than what you aim for internally.

```
SLO = 99.9%   ← internal goal
SLA = 99.5%   ← what you promise customers
Gap = 0.4%    ← buffer for unexpected incidents
```

**Error Budget:** The amount of unreliability you are allowed in a given period.

```
Error budget = 1 - SLO
For SLO = 99.9%:
Error budget = 0.1% of time per month
= 0.001 × 43,200 minutes
= 43.2 minutes of downtime per month allowed
```

If you have used 40 of those 43.2 minutes mid-month, you freeze new deployments. Why? Because the risk of a new deployment causing another outage would burn the remaining budget and breach the SLA.

**In AzureShop context:** Your Grafana dashboard tracks request rate and error rate. The PrometheusRule alert `HighErrorRate` fires when error rate > 5%. In SRE terms, that alert is your early warning that you are burning the error budget faster than expected.

**Interview tip:** They will almost certainly ask this. The key insight they are testing is: "Does this person understand that SRE is about balancing reliability vs. velocity?" The error budget is that balance. When budget is full → ship fast. When budget is low → slow down, focus on reliability.

---

### Q10. What is the difference between Application Insights, Log Analytics, and Prometheus? When do you use each?

**Answer:**

All three are observability tools but they serve different purposes.

**Application Insights:**
- Purpose: APM (Application Performance Monitoring) for your application code
- What it collects: request traces, dependencies (DB calls, API calls), exceptions, custom events, user telemetry
- How: SDK embedded in your application code (`applicationinsights` npm package, `opencensus` Python)
- Queries: KQL (Kusto Query Language) in Azure Portal
- Best for: "Why is this specific request slow?" "Which function is throwing exceptions?"

**Log Analytics Workspace:**
- Purpose: Centralized log aggregation for everything — not just your app
- What it collects: AKS node logs, pod logs, Azure resource diagnostics, security events, Windows/Linux OS logs
- How: Agents (AMA — Azure Monitor Agent) push logs from VMs and AKS
- Queries: KQL
- Best for: "Show me all logs across all services for the last hour." Infrastructure-level investigation.

**Prometheus:**
- Purpose: Time-series metrics collection for Kubernetes workloads
- What it collects: numeric metrics — CPU, memory, request rate, queue depth, custom business metrics
- How: Scrapes `/metrics` HTTP endpoints on your pods (pull model)
- Queries: PromQL
- Visualized with: Grafana
- Best for: "What is the CPU usage of the product-service pod right now?" Real-time dashboards and alerting.

**In AzureShop — all three were used together:**
- App Insights SDK on all 8 services → distributed tracing, exceptions
- Log Analytics workspace → AKS diagnostics, Terraform audit logs
- kube-prometheus-stack → pod metrics scraped every 15s, displayed in Grafana

**Interview tip:** The interviewer may say "we use Azure Monitor — is Prometheus redundant?" Answer: Azure Monitor Metrics can collect Kubernetes metrics (via Azure Monitor Agent). But Prometheus + Grafana gives much richer visualization, custom dashboards, and PromQL is far more powerful for Kubernetes-specific queries. In many production setups you have both — Prometheus for real-time cluster monitoring, Azure Monitor for long-term retention and alerting integration with Action Groups.

---

### Q11. What is distributed tracing? How did you implement it in AzureShop?

**Answer:**

In a microservices system, a single user request touches multiple services. A user clicks "place order" — it hits the API Gateway → Order Service → Payment Service → Notification Service. If something is slow or fails, how do you know which service caused it?

Distributed tracing assigns a unique **Trace ID** to every request when it enters the system. Every service that handles that request logs the same Trace ID. You can then search for that Trace ID and see the entire journey of the request across all services — with timing for each hop.

**Components:**
- **Trace:** The entire journey of one request across all services
- **Span:** One unit of work within a trace (e.g., "order-service processed the request")
- **Trace ID:** Unique ID shared across all spans of one request
- **Parent-Child:** Each span knows which span called it

**In AzureShop:**

Application Insights SDK automatically propagates the Trace ID via HTTP headers (`traceparent` header). When order-service makes an HTTP call to payment-service, the SDK injects the trace header. Payment-service picks it up and logs spans under the same trace.

```javascript
// order-service — Node.js
const appInsights = require('applicationinsights');
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
  .setAutoDependencyCorrelation(true)  // ← this enables distributed tracing
  .start();
```

In the Azure Portal, you go to Application Insights → Transaction Search → find a trace ID → see the full end-to-end map.

**Interview tip:** They may ask about OpenTelemetry. OpenTelemetry is the open standard for distributed tracing — vendor neutral. Application Insights now supports OpenTelemetry natively. If asked "would you use OpenTelemetry or Application Insights SDK?" — answer: OpenTelemetry is the modern approach (no vendor lock-in). Application Insights SDK is fine for Azure-native projects but OpenTelemetry gives you flexibility to switch backends.

---

### Q12. What is P95/P99 latency? Why is it more useful than average latency?

**Answer:**

Latency percentiles tell you about the experience of the worst-affected users — not just the average user.

**How to read percentiles:**
- P50 (median): 50% of requests are faster than this. 50% are slower.
- P95: 95% of requests are faster than this. Only 5% are slower.
- P99: 99% of requests are faster than this. Only 1% are slower.

**Why average is misleading:**

Suppose you have 100 requests:
- 99 requests take 100ms
- 1 request takes 10,000ms (10 seconds — maybe hitting a cold database)
- Average = (99 × 100 + 1 × 10,000) / 100 = 199ms

Average says 199ms. Seems fine. But one user waited 10 seconds. That is a real problem hidden by the average.

P99 = 10,000ms — this shows the truth.

**Why P95/P99 matter:**
- High-traffic systems: at 10,000 requests/minute, 1% = 100 users per minute experiencing very slow responses
- SLOs are set on percentiles: "P95 latency must be under 500ms"
- Outliers often indicate specific bugs: cold starts, unoptimized queries, timeouts

**In AzureShop:**
Your Grafana dashboard has a P95 latency panel using PromQL:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

This gives the P95 latency over the last 5 minutes, updated every 15 seconds.

**Interview tip:** They may ask "what causes high P99 latency but normal P50?" Common causes: garbage collection pauses (Java/Node.js), cold database connections, connection pool exhaustion, occasional lock contention. These are intermittent problems that average metrics hide.

---

### Q13. What are PrometheusRule alerts? How did you set them up in AzureShop?

**Answer:**

A PrometheusRule is a Kubernetes custom resource that defines alerting rules for Prometheus. When a PromQL expression evaluates to true for a defined duration, Prometheus sends an alert to Alertmanager, which routes it to your notification channel (Slack, PagerDuty, email).

**In AzureShop — 10 alerts in 3 groups:**

**Group 1: HTTP Alerts**
```yaml
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) 
        / rate(http_requests_total[5m]) > 0.05
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Error rate above 5% for 2 minutes"
```

**Group 2: Availability Alerts**
- Pod not running
- Service endpoint unreachable

**Group 3: Capacity Alerts**
- CPU usage > 80% for 5 minutes
- Memory usage > 85% for 5 minutes
- Pod restart count > 5 in 15 minutes

**The `for` field is important:** It prevents flapping. If CPU spikes for 30 seconds and recovers, no alert fires. The condition must be true for the full `for` duration before alerting.

**Alertmanager routing:** Alerts go to Alertmanager with labels (`severity: critical` vs `warning`). Alertmanager routes critical alerts to PagerDuty (immediate page) and warning alerts to Slack.

**Interview tip:** They may ask "what is the difference between Prometheus alerts and Azure Monitor alerts?" Both can alert on the same metric. Prometheus alerts are cluster-native — lower latency, richer PromQL expressions. Azure Monitor alerts integrate with Azure Action Groups (send SMS, run a Logic App, trigger an Azure Function as auto-remediation). In production you would often have both.

---

### Q14. What are Grafana dashboards? What did you build in AzureShop?

**Answer:**

Grafana is a visualization tool that connects to data sources (Prometheus, Log Analytics, SQL, etc.) and displays metrics as charts, graphs, gauges, and tables in a dashboard.

**AzureShop Grafana Dashboard — 6 Panels:**

| Panel | Metric | PromQL |
|---|---|---|
| Request Rate | Requests per second per service | `rate(http_requests_total[5m])` |
| Error Rate | % of 5xx responses | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| P95 Latency | 95th percentile response time | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` |
| Pod Count | Number of running pods per service | `kube_deployment_status_replicas_available` |
| CPU Usage | CPU per pod | `rate(container_cpu_usage_seconds_total[5m])` |
| Memory Usage | Memory per pod | `container_memory_working_set_bytes` |

**Grafana concepts:**
- **Data source:** Where Grafana fetches data (Prometheus, Azure Monitor, etc.)
- **Dashboard:** A collection of panels
- **Panel:** One visualization (one chart)
- **Variable:** Dropdown to filter — e.g., `$namespace` or `$service` so one dashboard works for all services
- **Time range selector:** Show last 1h, 6h, 24h, 7d

**Interview tip:** They may ask "how do you make dashboards consistent across teams?" Answer: Dashboard-as-code using Grafana's JSON model or **Grafonnet** (a library to generate Grafana JSON from code). Store dashboards in Git. Use the Grafana Helm chart to provision dashboards via ConfigMaps — dashboards auto-load on Grafana startup.

---

### Q15. What is chaos engineering? Give an example test you would run on AzureShop.

**Answer:**

Chaos engineering is the practice of deliberately injecting failures into your system in a controlled way to verify that it handles them gracefully. The goal is to find weaknesses before a real outage does.

**The principle:** "If we simulate this failure in a controlled test, we learn how the system responds. Then we fix it. Later when it happens for real, we are prepared."

**Famous example:** Netflix's Chaos Monkey — a tool that randomly kills production EC2 instances to ensure Netflix can survive instance failures.

**Example chaos tests for AzureShop:**

**Test 1: Kill a pod**
```bash
kubectl delete pod product-service-xxx -n dev
```
Expected: Kubernetes detects the pod is gone, schedules a replacement within 30 seconds. HPA maintains minimum replicas. Users see no downtime because other replicas handle traffic.

**Test 2: Exhaust memory**
Use a tool like Chaos Mesh or Litmus to inject a memory pressure condition on the order-service pod. Expected: OOMKilled, pod restarts. Alert fires (restart count > 5). 

**Test 3: Network partition**
Block all traffic from order-service to the Service Bus. Expected: order-service retries with exponential backoff, logs errors, eventually times out with a 503. Other services are unaffected (isolation).

**Test 4: Kill a node**
`az vmss delete-instances` on an AKS node. Expected: cluster autoscaler detects the node is gone, provisions a replacement. Pods are rescheduled on remaining nodes.

**Tools:** Azure Chaos Studio (Microsoft's managed chaos tool), Chaos Mesh (Kubernetes-native), Litmus (CNCF project).

**Interview tip:** They will not expect you to have run chaos tests in production (for a personal project). They want to know you understand the concept and can design tests. Say: "In AzureShop I validated Kubernetes self-healing manually by deleting pods. In a production SRE role I would use Azure Chaos Studio to run scheduled failure injection experiments."

---

### Q16. What is the difference between High Availability (HA) and Disaster Recovery (DR)?

**Answer:**

**High Availability (HA):**
- Goal: Keep the service running despite individual component failures
- Scope: Single region, multiple availability zones
- Mechanism: Redundancy — multiple instances, load balancers, automatic failover
- Recovery time: Seconds to minutes (automatic)
- Example: AKS with 3 nodes across 3 availability zones. One node dies → Kubernetes reschedules pods to other nodes. Users see no downtime.

**Disaster Recovery (DR):**
- Goal: Recover the service after a catastrophic event (entire region goes down)
- Scope: Multiple regions
- Mechanism: Data replication, backup and restore, failover to secondary region
- Recovery time: Minutes to hours (often manual or semi-manual)
- Key metrics:
  - **RPO (Recovery Point Objective):** Maximum data loss you can accept. "We can afford to lose up to 15 minutes of data."
  - **RTO (Recovery Time Objective):** Maximum time to restore service. "We must be back online within 2 hours."

**In AzureShop context:**
- HA: AKS with multiple nodes, PodDisruptionBudget ensuring minimum pods are always running, HPA scaling up under load
- DR would require: Azure SQL with geo-replication to a secondary region, ACR geo-replication, Terraform state backup, and a runbook for failover

**Common DR strategies:**
| Strategy | Description | Cost | RTO |
|---|---|---|---|
| Backup & Restore | Backup data, restore to new region | Low | Hours |
| Pilot Light | Secondary region with minimal resources running | Medium | 30–60 min |
| Warm Standby | Secondary region always running at reduced capacity | High | Minutes |
| Active-Active | Both regions serving traffic simultaneously | Highest | Seconds |

**Interview tip:** If asked "does AzureShop have DR?" — be honest: "The current single-region setup has HA via AKS redundancy. Full DR would require geo-replication of Azure SQL and a secondary AKS cluster. I understand the design and would implement it given the requirement."

---

## Section 3 — DevOps & CI/CD (Q17–Q24)

---

### Q17. Walk me through your full CI/CD pipeline design in AzureShop.

**Answer:**

AzureShop has **13 Azure DevOps pipelines** organized in two phases.

**Phase 1 — CI (Continuous Integration): 9 pipelines**

Pipelines 1–8 are per-service CI pipelines. Pipeline 9 is Terraform validate.

Each service CI pipeline does:
1. `docker build` — build the image using multi-stage Dockerfile
2. `trivy scan` — scan the image for vulnerabilities (blocks on unfixed critical CVEs)
3. `docker push` — push to ACR with tag = `$(Build.BuildId)`
4. `helm lint` — validate the Helm chart syntax

All CI pipelines use a **reusable template** (`build-template.yaml`) — they call the template, pass the service name, and the template does the work. No code duplication.

**Phase 2 — CD (Continuous Deployment): 4 pipelines**

- `deploy-dev` (Pipeline 10): Deploys all 8 services to the dev AKS namespace. Triggered automatically on every merge to `dev` branch. Uses `deploy-template.yaml`.
- `deploy-staging` (Pipeline 11): Deploys to staging. Triggered manually or on merge to `staging`.
- `deploy-prod` (Pipeline 12): Deploys to production. Requires **manual approval** from the production approver before running. Environment gate.
- `terraform-apply` (Pipeline 13): Applies Terraform changes. Runs against dev/staging/prod based on branch.

**Variable Groups:**
- `vg-common` (ID:1) — shared across all environments: ACR name, service names
- `vg-dev` (ID:2), `vg-staging` (ID:3), `vg-prod` (ID:4) — environment-specific values

**Interview tip:** They will ask "how do you handle secrets in pipelines?" Answer: Secrets are stored in Azure Key Vault and linked to Variable Groups in Azure DevOps. Pipelines reference `$(sql-password)` — Azure DevOps fetches the value from Key Vault at runtime. The secret is never in the pipeline YAML file.

---

### Q18. What is the difference between CI and CD? What does "continuous" mean?

**Answer:**

**CI — Continuous Integration:**
- The practice of merging code changes into a shared branch frequently (multiple times per day)
- On every merge, an automated pipeline runs: build, test, scan
- Goal: Detect integration problems early. If 5 developers each work in isolation for 2 weeks then merge, conflicts and bugs are massive. If they merge daily, problems are small and caught immediately.
- Output: A verified, tested artifact (Docker image, JAR, ZIP)

**CD — Continuous Delivery (or Continuous Deployment):**
- Continuous Delivery: Every successful CI build is deployable. But deployment requires manual approval.
- Continuous Deployment: Every successful CI build is automatically deployed to production, no manual step.
- Most companies use Continuous Delivery — automated to staging, manual gate for production.

**"Continuous" means:** Automated and frequent — not once a month but multiple times per day.

**In AzureShop:**
- CI is triggered on every PR to `dev` — automatic
- CD to dev is automatic after merge
- CD to staging is manual trigger
- CD to production requires manual approval (environment gate in Azure DevOps)

This is Continuous Delivery — not full Continuous Deployment, because production needs a human approval.

**Interview tip:** They may ask "what tests run in your CI?" In AzureShop: linting, Docker build, Trivy scan, Helm lint. A mature pipeline would also include: unit tests, integration tests, DAST (dynamic security scan), load tests on staging. Frame it as "here is what we have, here is what I would add."

---

### Q19. Explain blue/green, canary, and rolling deployments. When do you use each?

**Answer:**

**Rolling Deployment (default Kubernetes behavior):**
- Replace pods one by one. Start a new pod, wait for it to be healthy, remove an old pod. Repeat.
- Zero downtime (traffic is always served by healthy pods)
- Risk: If the new version has a bug, it is gradually replacing working pods before you notice
- Rollback: `kubectl rollout undo deployment/product-service`
- Best for: Low-risk updates, internal tools

**Blue/Green Deployment:**
- You have two identical environments: Blue (current, live) and Green (new version)
- Deploy the new version to Green. Run tests on Green.
- Switch traffic from Blue to Green instantly (update the Ingress or Load Balancer)
- Blue stays running as an instant rollback target
- Risk: Requires double the infrastructure (cost). Database migrations must be backward compatible.
- Rollback: Switch traffic back to Blue — instant
- Best for: Major releases, where you need instant rollback

**Canary Deployment:**
- Send a small percentage of traffic (e.g., 5%, 10%, 20%) to the new version
- Monitor error rates, latency, business metrics for the canary
- If metrics look good, gradually increase the percentage (20% → 50% → 100%)
- If metrics degrade, route 100% back to the old version
- Best for: High-risk changes, A/B testing features, validating with real user traffic

**In AzureShop (Phase 9 — canary example):**
```yaml
# NGINX Ingress canary annotation
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "20"
```
This routes 20% of traffic to the canary Deployment, 80% to the stable Deployment.

**Interview tip:** They may ask about database migrations with blue/green. The hard problem: if Green's code expects a new DB column that Blue doesn't have, and you roll back to Blue — Blue breaks on the new column. Solution: expand/contract migrations. Add the column, deploy (both versions work), then remove old column later.

---

### Q20. What is HPA vs VPA in Kubernetes? Which did you use?

**Answer:**

Both HPA and VPA automatically scale your application — but in different dimensions.

**HPA — Horizontal Pod Autoscaler:**
- Scales by adding or removing **pods** (horizontal = more instances)
- Triggered by: CPU usage, memory usage, or custom metrics (request rate, queue depth)
- Example: Product-service normally runs 2 pods. Traffic spikes → CPU goes to 80%. HPA adds pods until CPU drops below 70%. Traffic drops → HPA removes extra pods.

```yaml
# AzureShop HPA (in each Helm chart)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**VPA — Vertical Pod Autoscaler:**
- Scales by changing **CPU and memory limits** of existing pods (vertical = bigger instance)
- VPA watches actual resource usage, then recommends (or applies) new `requests` and `limits`
- Problem: VPA must restart pods to change their resource requests — causes brief disruption
- In Kubernetes, you generally cannot combine HPA (CPU-based) and VPA on the same pod

**What you used in AzureShop:** HPA — horizontal scaling is standard for stateless microservices. VPA is used for batch jobs, databases (stateful workloads), or to right-size resource requests.

**Cluster Autoscaler (different from both):** Scales the nodes (VMs) in AKS. If all nodes are full and a new pod cannot be scheduled, Cluster Autoscaler adds a new node. If nodes are underutilized, it removes them. HPA and Cluster Autoscaler work together: HPA adds pods → CA adds nodes if needed.

**Interview tip:** They may ask about KEDA (Kubernetes Event-Driven Autoscaling). KEDA extends HPA to scale based on external events — queue length in Service Bus, number of messages in Event Hub. Perfect for the order-processing flow in AzureShop: scale order-service based on Service Bus queue depth.

---

### Q21. What is a Helm chart? Why use it instead of raw Kubernetes YAML?

**Answer:**

A Helm chart is a package of Kubernetes YAML templates with variables. Helm is like a package manager for Kubernetes — similar to `apt`, `npm`, or `pip`.

**Problem with raw YAML:**
You have 8 services. Each needs a Deployment, Service, HPA, PDB, NetworkPolicy, ServiceAccount — about 6 YAML files per service. That is 48 YAML files. They are almost identical except for the service name, image, and port. If you want to change the resource limits, you edit 8 files. If you make a typo in one, it is hard to catch.

**Helm solution:**
Write the YAML once as a template with `{{ .Values.xxx }}` variables:

```yaml
# templates/deployment.yaml
containers:
- name: {{ .Values.service.name }}
  image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
  ports:
  - containerPort: {{ .Values.service.port }}
```

Then a `values.yaml` per service:
```yaml
# product-service/values.yaml
service:
  name: product-service
  port: 8000
image:
  repository: acrazureshopdev.azurecr.io/product-service
  tag: "1.0.0"
```

Now to deploy: `helm upgrade --install product-service ./helm/product-service -f values.yaml`

**AzureShop Helm charts (per service, in each chart):**
- `Deployment` — pod spec, image, env vars, security context
- `Service` — ClusterIP service for internal routing
- `HPA` — autoscaling rules
- `PDB` — PodDisruptionBudget (minimum 1 pod always available)
- `NetworkPolicy` — zero-trust firewall rules
- `ServiceAccount` — pod identity

**Rollback:** `helm rollback product-service 1` — instantly reverts to the previous release.

**Interview tip:** They may ask about Helm vs Kustomize. Kustomize uses base YAML + patch overlays (no templating, just JSON merge patches). Kustomize is built into `kubectl apply -k`. Helm is more powerful for complex apps. Many teams use both: Kustomize for environment-specific overrides, Helm for third-party app installs (Prometheus, NGINX).

---

### Q22. What is an Ingress Controller? How did you configure it in AzureShop?

**Answer:**

An Ingress Controller is a reverse proxy (like NGINX) running inside your Kubernetes cluster that routes external HTTP/HTTPS traffic to the correct internal service based on the request URL or hostname.

**Without Ingress:** Every service needs its own `LoadBalancer` Service, which creates a public IP. 8 services = 8 public IPs. Expensive, unmanageable, no SSL termination, no path routing.

**With Ingress:** One public IP (the NGINX Ingress Controller's external IP). All traffic enters there. NGINX reads the path and routes internally.

**AzureShop NGINX Ingress routing:**

```yaml
rules:
- host: shop.example.com
  http:
    paths:
    - path: /api/products
      backend:
        service:
          name: product-service
          port: 8000
    - path: /api/orders
      backend:
        service:
          name: order-service
          port: 3003
    - path: /
      backend:
        service:
          name: frontend
          port: 3000
```

External IP: `134.33.223.224` (NGINX Ingress Controller's LoadBalancer IP)

**Traffic flow:**
```
Internet → Application Gateway (WAF, SSL termination) 
         → NGINX Ingress (134.33.223.224, path routing) 
         → ClusterIP Service 
         → Pods
```

**SSL:** TLS termination at Application Gateway. Traffic from App Gateway to NGINX is HTTP (inside private VNet — acceptable). For strict end-to-end TLS, you would also configure TLS on the Ingress using cert-manager + Let's Encrypt.

**Interview tip:** They may ask about AGIC (Application Gateway Ingress Controller). AGIC replaces NGINX — it makes Application Gateway itself act as the Kubernetes Ingress Controller. Traffic goes directly from App Gateway to pods — no intermediate NGINX hop. Lower latency, one less component. The trade-off: AGIC is Azure-specific (NGINX is portable) and has some Helm chart limitations.

---

### Q23. What is Azure Container Registry (ACR)? Why did you use Premium SKU?

**Answer:**

ACR is Azure's private Docker container image registry. Instead of pushing images to Docker Hub (public), you push to ACR. Your AKS cluster pulls images from ACR using the cluster's managed identity — no username/password.

**Basic workflow:**
```bash
# Build and push
docker build -t acrazureshopdev.azurecr.io/product-service:1.0.0 .
docker push acrazureshopdev.azurecr.io/product-service:1.0.0

# AKS pulls automatically using managed identity
```

**ACR SKUs:**

| Feature | Basic | Standard | Premium |
|---|---|---|---|
| Storage | 10 GB | 100 GB | 500 GB |
| Geo-replication | No | No | Yes |
| Private Link | No | No | Yes |
| Image quarantine | No | No | Yes |
| Customer-managed keys | No | No | Yes |
| Price (approx) | $0.17/day | $0.67/day | $1.67/day |

**Why AzureShop uses Premium:**
1. **Private Link** — ACR is accessible only from inside the VNet via private endpoint. Public access disabled.
2. **Geo-replication** — In multi-region production, images are replicated to secondary region. AKS in that region pulls locally (faster pull, no cross-region bandwidth cost).
3. **Image quarantine** — New images are quarantined until security scan passes. Only clean images are available for pull.

**AKS pulling from ACR:** AKS is granted `AcrPull` role on ACR. No credentials in Kubernetes Secrets. The kubelet uses the AKS managed identity to authenticate.

**Interview tip:** They may ask "how do you manage image tags?" Answer: Semantic versioning for releases (`v1.2.3`), Build ID for CI builds (`$(Build.BuildId)`). Never use `latest` in production — it is non-deterministic (pull at different times gets different images). Tag immutability (ACR Premium feature) prevents overwriting a tag once pushed.

---

### Q24. What are reusable pipeline templates? How did you implement them?

**Answer:**

In Azure DevOps, a pipeline template is a YAML file that defines steps, jobs, or stages that can be called from multiple pipeline files. It prevents copy-paste duplication.

**Without templates:** 8 service CI pipelines, each with identical steps (docker build, trivy scan, docker push, helm lint). If you want to add a new step (e.g., SAST scan), you edit 8 files. Risk of inconsistency.

**With templates:** Write the steps once in `build-template.yaml`. Each service pipeline calls the template with one parameter.

**AzureShop build-template.yaml (simplified):**
```yaml
# templates/build-template.yaml
parameters:
- name: serviceName
  type: string
- name: dockerfilePath
  type: string

steps:
- task: Docker@2
  displayName: 'Build image'
  inputs:
    containerRegistry: sc-azureshop-azure
    repository: $(ACR_NAME)/$({{ parameters.serviceName }})
    command: build
    dockerfile: $({{ parameters.dockerfilePath }})
    tags: $(Build.BuildId)

- script: |
    trivy image --exit-code 1 --ignore-unfixed \
      $(ACR_LOGIN_SERVER)/{{ parameters.serviceName }}:$(Build.BuildId)
  displayName: 'Trivy security scan'

- task: Docker@2
  displayName: 'Push image'
  inputs:
    command: push
```

**Each service pipeline simply calls:**
```yaml
# pipelines/product-service-ci.yaml
stages:
- template: templates/build-template.yaml
  parameters:
    serviceName: product-service
    dockerfilePath: services/product-service/Dockerfile
```

**Benefits:**
- Change the template once → all 8 pipelines updated
- Consistent quality gates across all services
- New service onboarding: just create a 5-line YAML that calls the template

**Interview tip:** They may ask about **pipeline as code** governance. Templates should be stored in a separate repository that is access-controlled. Application teams cannot modify the build template — only the platform team can. This enforces consistent security scanning and quality gates across all teams.

---

## Section 4 — Security & Compliance (Q25–Q32)

---

### Q25. What is Azure RBAC? How is it different from Kubernetes RBAC?

**Answer:**

**Azure RBAC (Role-Based Access Control):**
Controls who can do what at the **Azure resource level** — create/delete VMs, read Key Vault secrets, push to ACR, modify AKS cluster settings.

Built-in roles: Owner, Contributor, Reader, and many specific roles (AcrPull, Key Vault Secrets User, etc.)

```
User/Group/Service Principal
  → Role Assignment
    → Role Definition (what actions are allowed)
      → Scope (subscription, resource group, or specific resource)
```

Example: AKS cluster's managed identity is assigned `AcrPull` role on ACR. This lets the kubelet pull images from ACR.

**Kubernetes RBAC:**
Controls who can do what **inside the Kubernetes cluster** — create pods, read secrets, access namespaces.

```yaml
# Kubernetes Role (what actions)
kind: Role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# Kubernetes RoleBinding (who gets the role)
kind: RoleBinding
subjects:
- kind: User
  name: developer@company.com
roleRef:
  kind: Role
  name: pod-reader
```

**Key difference:**
- Azure RBAC: "Can this person create or delete the AKS cluster itself?"
- Kubernetes RBAC: "Can this person deploy pods or read secrets inside the cluster?"

Both are needed. You can have Azure Contributor on the AKS resource (can modify the cluster) but no Kubernetes RBAC (cannot do anything inside the cluster) — or vice versa.

**In AzureShop:** Your user was assigned `Azure Kubernetes Service RBAC Cluster Admin` role (Azure RBAC) which grants full access inside the cluster. In production, developers would get only `Azure Kubernetes Service RBAC Reader` — can view but not modify.

---

### Q26. What is Key Vault CSI Driver? How did you use it in AzureShop?

**Answer:**

The Key Vault CSI Driver (officially: Secrets Store CSI Driver for Azure Key Vault) is a Kubernetes extension that mounts Key Vault secrets as files or environment variables inside pods — automatically, without storing secrets in Kubernetes Secrets or in your code.

**The problem it solves:**
Normally, you would create a Kubernetes Secret (`kubectl create secret`), then mount it in pods. But Kubernetes Secrets are base64-encoded (not encrypted) by default. They can be read by anyone with cluster access. They are also a static copy — if the Key Vault secret rotates, the Kubernetes Secret is stale.

**How CSI Driver works:**
1. Pod starts
2. CSI Driver sees the pod has a `SecretProviderClass` annotation
3. CSI Driver authenticates to Key Vault using the pod's managed identity (Workload Identity)
4. CSI Driver fetches the secrets from Key Vault
5. Secrets are mounted as files inside the pod OR synced to Kubernetes environment variables
6. Pod's app reads them via environment variables

**AzureShop SecretProviderClass:**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: product-service-secrets
spec:
  provider: azure
  parameters:
    keyvaultName: kv-azureshop-6a6c-dev
    objects: |
      - objectName: sql-connection-string
        objectType: secret
      - objectName: redis-connection-string
        objectType: secret
  secretObjects:
  - secretName: product-service-env
    type: Opaque
    data:
    - key: SQL_CONNECTION_STRING
      objectName: sql-connection-string
```

Pods reference `product-service-env` Secret → which is populated from Key Vault at pod start time.

**Interview tip:** They may ask about secret rotation. CSI Driver can be configured with `rotationPollInterval`. It polls Key Vault and updates the mounted secret. But the app must re-read the environment variable (most apps require a restart). Solution: use file mounts + inotify (watch for file changes) instead of env vars for zero-restart secret rotation.

---

### Q27. What is Workload Identity? Why is it better than using client secrets?

**Answer:**

Workload Identity (formerly AAD Pod Identity) allows a Kubernetes pod to authenticate to Azure services (Key Vault, Storage, Service Bus) using a **Managed Identity** — without any client ID, client secret, or certificate stored anywhere.

**Old approach (bad):**
```yaml
env:
- name: AZURE_CLIENT_ID
  value: "abc123"
- name: AZURE_CLIENT_SECRET
  value: "super-secret-value"  # ← stored in Kubernetes Secret, risky
```
Problems: Secret can be leaked, must be rotated manually, anyone with cluster access can read it.

**Workload Identity approach:**
1. Create an Azure Managed Identity for the service (e.g., `mi-notification-service`)
2. Grant this managed identity permissions (e.g., "Key Vault Secrets User" on Key Vault)
3. Create a Kubernetes ServiceAccount linked to this managed identity via federated credentials
4. Pod uses this ServiceAccount
5. When the pod calls Key Vault SDK, it automatically gets a token from the Azure IMDS endpoint — no credentials needed

```python
# Python code — no credentials anywhere
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()  # ← picks up Workload Identity automatically
client = SecretClient(vault_url="https://kv-azureshop-dev.vault.azure.net/", 
                      credential=credential)
secret = client.get_secret("service-bus-connection-string")
```

**In AzureShop:** Notification-service used Workload Identity to connect to Azure Service Bus.
- Managed Identity Client ID: `2e5e41cb-dd6c-46a5-8420-165c463fe974`
- No credentials anywhere in code or Kubernetes Secrets

**Interview tip:** This is a key security concept. The phrase to know: **"eliminate long-lived credentials."** Service accounts, passwords, and API keys are long-lived — they work until manually rotated. Managed Identities use short-lived tokens (valid for 1 hour) issued by Azure AD automatically. If a token is stolen, it expires quickly.

---

### Q28. What is Pod Security Admission? Explain the restricted profile.

**Answer:**

Pod Security Admission (PSA) is a built-in Kubernetes admission controller that enforces security standards on pods when they are created. If a pod violates the policy, it is either warned or rejected.

**Three profiles:**

| Profile | Description |
|---|---|
| privileged | No restrictions. Allows root, privileged containers, host networking. |
| baseline | Prevents known privilege escalations. Allows running as root. |
| restricted | Highest security. Requires non-root, read-only filesystem, no privilege escalation. |

**Three modes per profile:**

| Mode | Action |
|---|---|
| enforce | Reject the pod if it violates the policy |
| audit | Allow the pod but log the violation |
| warn | Allow the pod but show a warning to the user |

**In AzureShop:**
```yaml
# Namespace labels
labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/warn: restricted
```

**What restricted requires (and what you implemented):**
```yaml
securityContext:
  runAsNonRoot: true          # ← cannot run as root
  runAsUser: 1001             # ← specific UID
  runAsGroup: 1001
  readOnlyRootFilesystem: true  # ← cannot write to container filesystem
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]             # ← drop all Linux capabilities
```

**The readOnlyRootFilesystem challenge:** If the app needs to write temp files, you mount an `emptyDir` volume at `/tmp`. The root filesystem is read-only, but `/tmp` is writable. This is what you did for all Node.js and Python services.

**Interview tip:** They may ask "what happens if a third-party container (e.g., Redis) doesn't meet the restricted profile?" Answer: You apply namespace-level policy but use a separate namespace or less strict profile for third-party workloads. Or you set `enforce: baseline` on the namespace and `enforce: restricted` using a separate OPA/Gatekeeper policy on only your own pods.

---

### Q29. What is Trivy? How did you integrate it into CI?

**Answer:**

Trivy is an open-source container security scanner by Aqua Security. It scans Docker images (and filesystems, IaC files, Git repos) for:
- OS package vulnerabilities (CVEs)
- Application dependency vulnerabilities (npm packages, Python packages, Java JARs)
- Misconfigurations
- Exposed secrets

**Why it matters:** Your application code may be secure, but if your base image (`node:18-alpine`) has a known vulnerability (e.g., CVE-2023-xxxx in OpenSSL), your container is at risk. Trivy catches this before deployment.

**AzureShop CI integration:**

```yaml
# In build-template.yaml
- script: |
    # Install trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

    # Generate SARIF report (always — non-blocking, goes to GitHub Advanced Security)
    trivy image --format sarif --output trivy-report.sarif \
      $(ACR_LOGIN_SERVER)/$(serviceName):$(Build.BuildId)

    # Blocking gate — fail build if unfixed CRITICAL CVEs exist
    trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed \
      $(ACR_LOGIN_SERVER)/$(serviceName):$(Build.BuildId)
  displayName: 'Trivy security scan'
```

**`--ignore-unfixed`:** Only block on CVEs where a fix is available. CVEs with no fix available do not block — there is nothing you can do about them right now.

**`.trivyignore` file:** For known, accepted CVEs (e.g., a CVE in a package you must use, no fix available yet, accepted as a risk):
```
# .trivyignore
CVE-2023-12345  # accepted risk: no fix available, low exploitability
```

**SARIF output:** Security findings are uploaded to the pipeline and can integrate with security dashboards (GitHub Advanced Security, Azure Defender for DevOps).

**Interview tip:** They may ask "how do you handle base image vulnerabilities?" Answer: Use minimal base images (`distroless`, `alpine`) which have fewer packages = fewer CVEs. Rebuild images regularly (weekly automated rebuild) to pick up patched base images. Use ACR's image vulnerability scanning (built-in for Premium SKU) as a second layer.

---

### Q30. What is a NetworkPolicy in Kubernetes? What is zero-trust?

**Answer:**

By default in Kubernetes, every pod can talk to every other pod in the cluster — no restrictions. NetworkPolicy is a Kubernetes resource that defines firewall rules at the pod level.

**Zero-trust network model:** "Never trust, always verify." No pod is allowed to communicate with any other pod by default. Explicit allow rules must be created for every allowed connection. If a pod is compromised, it cannot spread laterally to other services.

**AzureShop NetworkPolicy approach:**

Every service has a NetworkPolicy that:
1. **Denies all ingress** by default
2. **Allows ingress only from specific pods** (by label selector)
3. **Allows egress only to specific pods** (and external services like Key Vault, Service Bus)

```yaml
# product-service NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: product-service-netpol
spec:
  podSelector:
    matchLabels:
      app: product-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway  # ← ONLY api-gateway can talk to product-service
    ports:
    - port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: redis  # ← product-service can talk to redis
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53  # ← DNS (always needed)
```

**Important:** NetworkPolicy requires the CNI (Container Network Interface) plugin to support it. Azure CNI and Calico support NetworkPolicy. Kubenet does not.

**Interview tip:** They may ask about Service Mesh (Istio, Linkerd). A service mesh provides network policies + mutual TLS (all pod-to-pod traffic encrypted) + traffic management (retries, circuit breaker) at the application layer. NetworkPolicy works at layer 3/4 (IP/port). Istio works at layer 7 (HTTP, gRPC). For very strict security requirements, both are used together.

---

### Q31. What is Azure Policy? Give a real-world example.

**Answer:**

Azure Policy is a governance tool that enforces rules on your Azure resources. It continuously scans resources, reports compliance, and can automatically deny, modify, or remediate non-compliant resources.

**How it works:**
- A **Policy Definition** is a rule: "All storage accounts must have HTTPS-only enabled"
- A **Policy Assignment** applies that rule to a scope (subscription, resource group)
- A **Policy Initiative** (Policy Set) is a collection of related policies — e.g., all CIS Benchmark policies grouped together

**Modes:**
| Mode | Description |
|---|---|
| Audit | Log non-compliant resources but don't block |
| Deny | Block resource creation if it violates the policy |
| Modify | Automatically fix the resource (add a tag, enable HTTPS) |
| DeployIfNotExists | Deploy a related resource if it doesn't exist (e.g., deploy Defender for every new VM) |

**Real-world examples:**

1. **"Require tags on all resources"**
   ```json
   "if": { "field": "tags['Environment']", "exists": "false" },
   "then": { "effect": "deny" }
   ```
   No resource can be created without the `Environment` tag. Enforces FinOps tagging.

2. **"No public IP addresses"**
   Deny creation of any resource with a public IP. Forces use of Private Endpoints.

3. **"Allowed VM SKUs"**
   Only allow `Standard_D2s_v3` and `Standard_D4s_v3`. Prevents engineers from spinning up expensive SKUs.

4. **"AKS must have Azure Policy add-on enabled"**
   Ensures all AKS clusters have policy enforcement inside Kubernetes (OPA/Gatekeeper).

**AzureShop gap:** Azure Policy was not explicitly implemented in AzureShop. In an enterprise landing zone, you would assign the built-in "CIS Microsoft Azure Foundations Benchmark" initiative — 100+ policies covering encryption, networking, identity, logging.

**Interview tip:** Be honest about this gap. Say: "In AzureShop I focused on pod-level security and network policies. In a production enterprise setup, Azure Policy would be the first thing I implement — it is the guardrail that prevents misconfigurations from being deployed at all."

---

### Q32. What is PIM (Privileged Identity Management)?

**Answer:**

PIM is an Azure AD (Entra ID) feature that manages, controls, and monitors access to privileged roles — just-in-time, for limited time, with approval and audit.

**The problem without PIM:**
A DBA is permanently assigned the `Contributor` role on the production database. If their account is compromised, the attacker has permanent access. Even when the DBA is on vacation, the access exists.

**With PIM — Just-in-Time (JIT) access:**
1. DBA normally has **no standing access** to production
2. When they need to do maintenance, they request activation of the `Contributor` role
3. Request goes to a manager for approval
4. If approved, the role is activated for **4 hours** (configurable)
5. After 4 hours, access automatically expires
6. The activation request, approval, and all actions during the window are fully audited in Azure AD audit logs

**PIM features:**
- **Eligible vs Active:** "Eligible" means you can activate. "Active" means you have the access right now.
- **Time-bound activation:** Set a max duration (1 hour, 8 hours, etc.)
- **Approval workflow:** Multi-level approvals
- **MFA on activation:** Even if your account is compromised, attacker cannot activate PIM role without your phone
- **Access reviews:** Quarterly review — "Does this person still need this role?" Remove if not.

**Real-world importance:** Required for SOC 2, ISO 27001, PCI-DSS compliance. Auditors want to see that privileged access is time-bound and reviewed.

**Interview tip:** Connect to least privilege principle. "PIM is the mechanism that enforces least privilege dynamically. Without PIM, the only way to restrict access is to permanently remove roles — but then engineers cannot do their jobs when needed. PIM gives them access exactly when needed, for exactly as long as needed, with full audit trail."

---

## Section 5 — Operations & Incident Management (Q33–Q37)

---

### Q33. Walk me through how you would handle a production incident.

**Answer:**

A production incident needs a structured response. The process:

**Step 1 — Detect (0–5 minutes)**
Alerting fires: Prometheus alert "HighErrorRate > 5% for 2 minutes" pages on-call via PagerDuty. On-call engineer acknowledges the alert.

**Step 2 — Communicate (first 5 minutes)**
Create a war room (Slack channel: `#incident-2026-05-29`). Post the initial status to the status page: "We are investigating elevated error rates on the checkout service."

**Step 3 — Triage (5–15 minutes)**
Find the scope: Is it one service or many? One region or all regions?
```bash
kubectl get pods -n prod          # Are pods running?
kubectl logs order-service-xxx -n prod  # What are the logs saying?
kubectl top pods -n prod          # Is CPU/memory spiking?
```
Check Grafana: Which service has the error rate spike? When did it start?

**Step 4 — Contain (15–30 minutes)**
Stop the bleeding. If a bad deployment caused it:
```bash
helm rollback order-service 2 -n prod
```
If a downstream dependency is failing, implement a feature flag or circuit breaker.

**Step 5 — Resolve**
Fix root cause, deploy fix through normal CI/CD pipeline with emergency approval.

**Step 6 — Communicate resolution**
Update status page: "Issue resolved at 14:35 UTC. All services operating normally."

**Step 7 — Post-Incident Review (within 48 hours)**
Write an RCA document. No blame. Focus on systems and processes.

**Interview tip:** The key phrase interviewers look for is **"blameless post-mortem."** The SRE culture (from Google SRE book) holds that incidents are caused by system failures, not individual mistakes. The goal is to improve the system, not to punish people. Capgemini as a large enterprise operates 24x7 on-call — showing you understand this process is critical.

---

### Q34. What is an RCA? Give me a real example from your work.

**Answer:**

An RCA (Root Cause Analysis) is a structured document written after an incident that identifies the true root cause — not just the symptom — and defines action items to prevent recurrence.

**The 5 Whys technique:**
Start with the symptom and ask "why" five times until you reach the root cause.

**Real example from AzureShop (Issue #3 — CSI Driver error):**

**Symptom:** All pods in dev namespace were crashing with `MountVolume.SetUp failed`.

Why 1: The CSI volume mount was failing.
Why 2: The CSI Driver could not authenticate to Key Vault.
Why 3: The CSI Addon Identity Client ID in the SecretProviderClass YAML was wrong.
Why 4: The correct Client ID is output by Terraform, but the YAML was hardcoded with an old value.
Why 5: **Root cause:** There was no automation linking the Terraform output to the Kubernetes manifest. The Client ID was manually copied and it was the wrong value.

**Fix applied:**
Updated the Helm chart to use the CSI Addon Identity Client ID as a Helm value, injected by the CD pipeline using `terraform output -raw csi_identity_client_id`.

**Prevention (action items):**
- All Azure resource IDs in Kubernetes manifests must come from Terraform outputs via the pipeline — no manual copy-paste
- Added a post-deployment validation step: `kubectl describe secretproviderclass` to verify secrets mounted

**Other real AzureShop examples you can use:**
- Issue #11: Docker Compose failing — missing environment variables because `docker-compose.yml` referenced Key Vault but Key Vault was not running locally. Fix: Added mock environment variable fallbacks.
- Issue #1: AKS node pool autoscaler not working — missing `cluster_autoscaler_profile` block in Terraform. Fix: Added the block with correct parameters.

**Interview tip:** Having real examples is enormously powerful. Most candidates say "we follow the 5-whys process." You can say "here is an actual incident, the root cause, and what we changed to prevent it." That is an SRE answer.

---

### Q35. What is FinOps? How did you optimize cost in AzureShop?

**Answer:**

FinOps (Financial Operations) is the practice of managing and optimizing cloud spending. It is where finance, engineering, and operations collaborate to make cost-conscious architecture decisions.

**Core FinOps principles:**
- **Visibility:** Everyone can see what they are spending and on what (cost allocation by tag, by team, by service)
- **Accountability:** Teams own their cloud costs, not just ops
- **Optimization:** Continuously right-size, eliminate waste, use commitment discounts

**Cost optimization techniques:**

**1. Reserved Instances / Savings Plans**
Commit to 1 or 3 years of usage in exchange for 30–70% discount. For baseline workloads (always-on AKS system node pool), reserved instances make sense.

**2. Spot Instances (implemented in AzureShop Phase 9)**
Use Azure Spot VMs (unused Azure capacity at up to 90% discount) for batch workloads or fault-tolerant services:
```hcl
# Spot node pool in Terraform
priority        = "Spot"
eviction_policy = "Delete"
spot_max_price  = -1  # pay up to on-demand price
```
Taint: `kubernetes.azure.com/scalesetpriority=spot:NoSchedule` — only pods that tolerate this taint are scheduled on spot nodes. Notification-service (event-driven, restartable) runs on spot.

**3. Resource Quotas (implemented in AzureShop Phase 9)**
Prevent runaway resource consumption:
```yaml
# LimitRange — default and max per pod
default:
  cpu: "250m"
  memory: "256Mi"
max:
  cpu: "2"
  memory: "2Gi"
```

**4. Destroy dev infra when not in use**
AzureShop infra was destroyed on 2026-05-16 to save cost. `terraform destroy` removes all resources. Recreate in 20 minutes with `terraform apply`. For dev environments, this alone can save 70% of cost.

**5. Tagging for cost allocation**
```hcl
tags = {
  Environment = "dev"
  Project     = "azureshop"
  Team        = "platform"
  CostCenter  = "cc-1234"
}
```
Azure Cost Management groups spending by tag. You see exactly which service, team, and environment is spending what.

**6. Auto-shutdown schedules**
Dev AKS clusters can be stopped on a schedule (nights and weekends). `az aks stop` — control plane charges stop, node VMs stop.

---

### Q36. What is a runbook? Give an example.

**Answer:**

A runbook is a documented procedure for a specific operational task. It is a step-by-step guide that anyone on the team can follow — not just the person who originally set something up. In SRE, runbooks are critical: when a 2am incident wakes you up, you need to follow a runbook, not improvise while sleep-deprived.

**Good runbook contains:**
- **Title:** What this runbook covers
- **Trigger:** When to use it (which alert, which scenario)
- **Symptoms:** What you will observe
- **Diagnosis steps:** Commands to run, what to look for
- **Remediation steps:** Exact commands to fix
- **Escalation:** Who to call if this runbook doesn't fix it

**Real AzureShop runbook — Key Vault Recovery (from your project state):**

**Title:** Key Vault Soft-Delete Recovery After Terraform Destroy

**Trigger:** Running `terraform apply` fails with "Key Vault name is already in use" after a `terraform destroy`.

**Cause:** Key Vault has `purge_protection_enabled = true`. After destroy, it enters 90-day soft-delete state occupying the name.

**Steps:**
```bash
# Step 1: Recover the soft-deleted Key Vault
az keyvault recover --name kv-azureshop-6a6c-dev

# Step 2: Import the recovered Key Vault into Terraform state
terraform import -var-file="environments/dev/terraform.tfvars" \
  module.keyvault.azurerm_key_vault.main \
  /subscriptions/6a6cb5d4-9c05-4211-b604-b4a53fed3284/resourceGroups/rg-azureshop-dev/providers/Microsoft.KeyVault/vaults/kv-azureshop-6a6c-dev

# Step 3: Resume terraform apply
export TF_VAR_sql_admin_password="..."
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

**Escalation:** If recovery fails (Key Vault purge protection expired), contact Azure Support.

**Interview tip:** Runbooks are a sign of operational maturity. Say: "Our team's rule is: if you do something manually more than once, write a runbook. If a runbook is executed more than 3 times, automate it." This shows you understand the progression from chaos → documentation → automation.

---

### Q37. What are Resource Quotas and LimitRange in Kubernetes?

**Answer:**

Both are Kubernetes mechanisms to control resource consumption in a namespace — but they operate at different levels.

**ResourceQuota — namespace-level cap:**
Sets a hard limit on the total resources (CPU, memory, pod count, etc.) that can be consumed by all pods in a namespace combined.

```yaml
# AzureShop — k8s/namespaces/dev-resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"        # total CPU requests across all pods ≤ 4 cores
    requests.memory: "8Gi"   # total memory requests ≤ 8GB
    limits.cpu: "8"
    limits.memory: "16Gi"
    count/pods: "20"         # max 20 pods in this namespace
```

If an engineer tries to deploy a 21st pod, Kubernetes rejects it: "exceeded quota."

**LimitRange — per-pod defaults and maximums:**
Sets default resource requests/limits for pods that don't specify them, and enforces maximums per pod.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  - type: Container
    default:          # applied if pod doesn't specify limits
      cpu: "250m"
      memory: "256Mi"
    defaultRequest:   # applied if pod doesn't specify requests
      cpu: "100m"
      memory: "128Mi"
    max:              # pod cannot request more than this
      cpu: "2"
      memory: "2Gi"
```

**Why this matters:**
- Without LimitRange, a pod with no limits can consume all CPU on a node, starving other pods
- Without ResourceQuota, one team's namespace can consume all cluster capacity
- Both together ensure fair sharing and prevent runaway costs

**Interview tip:** Connect this to FinOps. In a multi-team cluster (common at Capgemini — many app teams on a shared AKS cluster), ResourceQuota is the budget guardrail. Each namespace gets a quota that maps to the team's cost allocation. If they want more, they make a request and justify the need.

---

## Section 6 — Behavioral & Collaboration (Q38–Q40)

---

### Q38. Tell me about yourself and why you are applying for this role.

**Answer (your version — adapt and make it yours):**

"I have a background in tech support where I built strong troubleshooting and systems thinking skills — understanding how systems fail and how to diagnose problems under pressure. Over the past year I have been deliberately transitioning into DevOps and cloud engineering.

To make that transition real, I built AzureShop — a production-grade e-commerce microservices platform on Azure, from scratch. It covers exactly the stack in this JD: Terraform IaC with 7 modules, AKS with full Helm chart deployments, Azure DevOps CI/CD pipelines, security hardening with Pod Security Admission and Trivy scanning, observability with Prometheus, Grafana, and Application Insights, and GitOps with Flux.

The project is not theoretical — I hit 16 real bugs during deployment, diagnosed each one, wrote post-mortems, and fixed them. That process gave me practical SRE experience: incident triage, root cause analysis, and building runbooks.

I am applying because Capgemini operates at scale on Azure, and this role is exactly where I want to grow — building reliable, secure, automated platforms for engineering teams. The rotational shift model and on-call responsibility align with the operational depth I want to develop."

**Key elements in this answer:**
- Transition story (honest about background, not apologetic)
- Concrete project with specific technologies from the JD
- Real incidents = real SRE experience
- Connects your goal to the company's need

---

### Q39. Describe a time you solved a complex technical problem.

**Answer — use AzureShop Issue #3 (CSI Driver crash):**

"During the AKS deployment phase of AzureShop, all 8 services crashed simultaneously with `MountVolume.SetUp failed`. Every pod was in CrashLoopBackOff.

I started with `kubectl describe pod product-service-xxx` which showed the error was in mounting the CSI volume. I checked the CSI driver logs: `kubectl logs -n kube-system -l app=secrets-store-csi-driver`. The error was: 'failed to get keyvault token: unauthorized.'

Working backwards through the authentication chain: CSI Driver → authenticates via Managed Identity → Client ID is specified in the SecretProviderClass YAML. I compared the Client ID in my YAML with the actual CSI Addon Identity Client ID from the Azure portal — they were different. I had hardcoded the wrong value.

The root cause was manual copy-paste of a Client ID that Terraform outputs dynamically. My fix had two parts: first, update the SecretProviderClass with the correct Client ID to restore service. Second, modify the CD pipeline to inject the Client ID automatically from `terraform output -raw csi_identity_client_id` — removing the manual step entirely.

After the fix, I wrote a post-mortem and added the rule: any Azure resource ID referenced in Kubernetes must come from Terraform outputs via the pipeline, never from manual copy-paste.

Within 20 minutes all pods were running. The real win was the systemic fix — that class of error cannot happen again."

**STAR structure:**
- **Situation:** All pods crashed, CSI mount failure
- **Task:** Diagnose and fix
- **Action:** Systematic debugging through authentication chain, root cause identification
- **Result:** Service restored in 20 minutes, systemic fix prevents recurrence

---

### Q40. How would you onboard a new application team to the platform?

**Answer:**

Onboarding a new team to a shared AKS platform needs to be structured — if every team sets up their own way, you end up with inconsistency, security gaps, and cost overruns. Here is how I would structure it:

**Step 1 — Namespace and quotas**
Create a dedicated Kubernetes namespace for the team. Apply ResourceQuota (CPU, memory, pod count based on their expected workload) and LimitRange (defaults and maximums per pod).

**Step 2 — RBAC**
Create Kubernetes RBAC Role/RoleBinding giving the team `edit` access in their namespace — they can deploy pods, view logs. They cannot touch other namespaces or cluster-level resources.

Azure RBAC: grant them `Azure Kubernetes Service RBAC Writer` role scoped to their namespace (not full cluster access).

**Step 3 — CI/CD pipeline template**
Give them the reusable build template (`build-template.yaml`) and deploy template. They create a `values.yaml` and a 5-line pipeline YAML that calls the template. They do not write pipeline infrastructure from scratch — they inherit the platform standards (Trivy scanning, image naming conventions, ACR push).

**Step 4 — Networking policy baseline**
Apply a default deny-all NetworkPolicy in their namespace. Guide them to define explicit allow rules for their services. This enforces zero-trust from day one.

**Step 5 — Secrets management**
Show them how to store secrets in Key Vault and reference them via CSI Driver or Workload Identity. Document it in a runbook. They never put secrets in YAML or environment variables directly.

**Step 6 — Observability onboarding**
Add Application Insights connection string to their Key Vault. Give them the standard SDK setup for their language (Node.js/Python code snippets). Show them the shared Grafana instance where they can add their own dashboard.

**Step 7 — Documentation and review**
1-hour live walkthrough. Written runbook for common tasks (how to deploy, rollback, read logs, rotate secrets). First 2 deployments reviewed by the platform team.

**Interview tip:** They are looking for "platform engineering mindset" — you build the scaffolding once (reusable templates, NetworkPolicy baseline, RBAC model) so every team benefits consistently. This is exactly what the JD means by "create reusable modules, pipelines, and golden patterns for app teams."

---

## Quick Reference — Gap Topics

Topics not in AzureShop but in the JD. Learn these conceptually:

| Topic | One-line summary | Your honest answer |
|---|---|---|
| Azure Policy | Governance rules that enforce compliance at resource creation | "Understand the concept, implemented pod-level policies, next step is Azure Policy initiatives" |
| PIM | Just-in-time privileged access with approval and audit | "Understand the requirement, would implement for all production access" |
| APIM | API gateway for exposing and managing APIs externally | "Know the concept — NGINX in AzureShop covers internal routing; APIM for external API monetization" |
| Chaos Engineering | Deliberate failure injection to test resilience | "Validated Kubernetes self-healing manually; would use Azure Chaos Studio in production" |
| Formal SLI/SLO | Defined targets with error budget math | "Grafana tracks error rate and P95 latency; would formalize SLOs and error budget burn alerts" |
| On-call experience | Rotational shift, paging, incident response | "Tech support gave me incident triage experience under pressure; ready for on-call rotation" |

---

*Total: 40 questions across 6 JD sections. Review all 40, mark uncertain ones, revisit before the mock interview.*

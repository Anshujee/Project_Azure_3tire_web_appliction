# Phase 7 — Monitoring & Observability
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In this phase we added full observability to the AzureShop application running in AKS. Observability means you can answer three questions about your system at any point in time:

- **What is happening right now?** (metrics — numbers over time)
- **Why did something go wrong?** (logs — events with context)
- **Where did a request spend its time?** (traces — path through services)

We built the monitoring stack in four steps:

1. **Step 7.1** — Added Application Insights SDK and Prometheus `/metrics` endpoint to all 8 services
2. **Step 7.2** — Terraform: created Log Analytics Workspace, Application Insights per service, stored connection strings in Key Vault
3. **Step 7.3** — Deployed `kube-prometheus-stack` (Prometheus + Grafana + Alertmanager) into AKS; wrote Grafana dashboard
4. **Step 7.4** — Wrote PrometheusRule alert definitions (10 alerts across 3 groups)

By the end of this phase you will understand: what observability is and why it matters, how Prometheus scrapes metrics, how Grafana visualises them, how Application Insights works, what Log Analytics KQL queries look like, and how alert rules fire.

---

## Table of Contents

1. [The Three Pillars of Observability](#1-the-three-pillars-of-observability)
2. [Azure Monitor — The Umbrella Service](#2-azure-monitor--the-umbrella-service)
3. [Log Analytics Workspace](#3-log-analytics-workspace)
4. [Application Insights](#4-application-insights)
5. [Prometheus — How Metrics Scraping Works](#5-prometheus--how-metrics-scraping-works)
6. [What We Instrumented in Each Service](#6-what-we-instrumented-in-each-service)
7. [The Metrics We Expose](#7-the-metrics-we-expose)
8. [Grafana — Visualising Prometheus Metrics](#8-grafana--visualising-prometheus-metrics)
9. [kube-prometheus-stack — What It Deploys](#9-kube-prometheus-stack--what-it-deploys)
10. [Annotation-Based Pod Scraping](#10-annotation-based-pod-scraping)
11. [The Grafana Dashboard We Built](#11-the-grafana-dashboard-we-built)
12. [PromQL — Query Language Reference](#12-promql--query-language-reference)
13. [KQL — Log Analytics Query Reference](#13-kql--log-analytics-query-reference)
14. [Alert Rules — How Prometheus Alerting Works](#14-alert-rules--how-prometheus-alerting-works)
15. [The 10 Alerts We Defined](#15-the-10-alerts-we-defined)
16. [Terraform Changes Made in Phase 7](#16-terraform-changes-made-in-phase-7)
17. [Secret Flow — App Insights Connection String](#17-secret-flow--app-insights-connection-string)
18. [Azure Managed Grafana vs Embedded Grafana](#18-azure-managed-grafana-vs-embedded-grafana)
19. [Commands Reference](#19-commands-reference)
20. [Full Step-by-Step Summary](#20-full-step-by-step-summary)
21. [Interview Questions and Answers](#21-interview-questions-and-answers)

---

## 1. The Three Pillars of Observability

Observability is the ability to understand what your system is doing from the outside — by looking at the data it emits. The three pillars are:

### Metrics
Numbers collected over time. They are cheap to store and fast to query.

```
Examples:
  http_requests_total{service="user-service", status_code="200"} = 4521
  http_request_duration_seconds_p95{service="order-service"} = 0.087
  container_memory_working_set_bytes{pod="cart-service-abc"} = 134217728
```

**Use metrics to answer:** Is everything working right now? Is response time degrading?

### Logs
Text events emitted by the application as things happen. Rich in detail but expensive to store and slow to query at scale.

```
Examples:
  [ERROR] 2024-01-15 14:23:01 user-service: Failed to connect to SQL Server: timeout
  [INFO]  2024-01-15 14:23:05 order-service: Order #4521 created for user abc123
  [WARN]  2024-01-15 14:23:09 payment-service: Stripe API latency 450ms (threshold 200ms)
```

**Use logs to answer:** Why did this specific request fail? What happened right before the crash?

### Traces
A record of how a single request moved through multiple services. Each service adds a "span" to the trace showing what it did and how long it took.

```
Request: POST /api/orders
  ├─ api-gateway: 2ms (routing)
  ├─ order-service: 145ms total
  │    ├─ auth check (user-service): 12ms
  │    ├─ SQL INSERT: 98ms  ← slow!
  │    └─ notification publish: 35ms
  └─ Total: 147ms
```

**Use traces to answer:** Which service is slow? Where is time being spent in a distributed request?

### What We Built in Phase 7

| Pillar | Tool | Where |
|--------|------|--------|
| Metrics | Prometheus + prom-client / prometheus-client | AKS — kube-prometheus-stack |
| Metrics (Azure) | Application Insights | Azure Monitor |
| Logs | Application Insights SDK (auto-collected) | Azure Monitor |
| Traces | Application Insights SDK (auto-collected) | Azure Monitor |
| Visualisation | Grafana (embedded + Azure Managed) | AKS + Azure |
| Alerting | Prometheus Alertmanager + PrometheusRule | AKS |
| Log queries | KQL in Log Analytics Workspace | Azure Monitor |

---

## 2. Azure Monitor — The Umbrella Service

Azure Monitor is Microsoft's central observability platform. It is not one product — it is a collection of services that work together:

```
Azure Monitor
├── Log Analytics Workspace  — stores all logs and metrics (SQL-like query engine)
├── Application Insights     — SDK-based tracing and metrics for your code
├── Container Insights       — AKS pod/node metrics pushed automatically
├── Azure Managed Grafana    — managed Grafana connected to Azure Monitor
└── Alerts                   — rules that fire notifications based on data in the workspace
```

### Why We Use Both Azure Monitor and Prometheus

They answer different questions:

| | Prometheus | Azure Monitor |
|--|--|--|
| **Data source** | Your app's `/metrics` endpoint | SDK inside your app + Azure platform |
| **Best for** | Custom app metrics, Kubernetes state | Distributed traces, Azure resource metrics |
| **Query language** | PromQL | KQL |
| **Retention** | 15 days (our config) | 30 days (our config), up to 2 years |
| **Alerting** | PrometheusRule CRDs | Azure Monitor Alert Rules |

Using both gives you the full picture: Prometheus shows you what your app and cluster are doing right now; Azure Monitor stores the history and the deep traces.

---

## 3. Log Analytics Workspace

A Log Analytics Workspace (LAW) is the central database for Azure Monitor. Everything flows into it:

```
AKS Container Insights → LAW
Application Insights   → LAW
Azure Activity Logs    → LAW
Diagnostic Settings    → LAW (AKS control plane logs, SQL logs, etc.)
```

### What We Created

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-azureshop-dev"
  sku                 = "PerGB2018"    # pay per GB ingested
  retention_in_days   = 30
}
```

- **SKU `PerGB2018`**: You pay per gigabyte of data ingested. No fixed cost. The most common production choice.
- **Retention 30 days**: Logs older than 30 days are automatically deleted. Use 90+ days for staging/prod.

### Why One Workspace for Everything

You could have one LAW per service, but that makes cross-service queries impossible. With one workspace you can write a query like:

```kql
-- Find all 5xx errors across all services in the last hour
requests
| where resultCode >= 500
| summarize count() by cloud_RoleName, resultCode
| order by count_ desc
```

---

## 4. Application Insights

Application Insights (App Insights) is an Azure service that collects telemetry from your application code via an SDK.

### How It Works

```
Your Service (Node.js)
    ↓ SDK initialises on startup
    ↓ Intercepts all HTTP requests/responses automatically
    ↓ Intercepts all outgoing HTTP calls (to databases, other services)
    ↓ Captures all unhandled exceptions automatically
    ↓ Batches telemetry every 15 seconds
    ↓ Sends to App Insights endpoint (HTTPS)
    ↓
Application Insights (Azure)
    ↓ Stores in Log Analytics Workspace
    ↓
KQL queries / Grafana dashboards / Azure Monitor Alerts
```

### What the SDK Captures Automatically

| Telemetry Type | Examples |
|---|---|
| **Requests** | Every incoming HTTP request with URL, method, status, duration |
| **Dependencies** | Every SQL query, HTTP call to another service, Redis command |
| **Exceptions** | All unhandled errors with full stack trace |
| **Traces** | `console.log()` output (when `setAutoCollectConsole(true)`) |
| **Performance** | CPU, memory, event loop lag (Node.js) |

### One Instance Per Service

We create one Application Insights resource per microservice:

```
appi-user-service-dev
appi-product-service-dev
appi-cart-service-dev
appi-order-service-dev
appi-payment-service-dev
appi-notification-service-dev
appi-frontend-dev
appi-api-gateway-dev
```

This lets you filter the App Insights UI to a single service, or query across all of them in the shared Log Analytics Workspace.

### The Connection String

Each App Insights instance has a connection string like:

```
InstrumentationKey=abc123;IngestionEndpoint=https://eastus-0.in.applicationinsights.azure.com/
```

This is what the SDK uses to know where to send telemetry. We store it in Key Vault and inject it into pods as `APPLICATIONINSIGHTS_CONNECTION_STRING`.

### Node.js SDK Setup (Step 7.1)

We created `services/user-service/src/telemetry.js`:

```javascript
// Only initialise if the connection string exists — safe to run locally without it
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  const appInsights = require('applicationinsights');
  appInsights
    .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)   // links requests to their dependencies
    .setAutoCollectRequests(true)          // tracks all incoming HTTP requests
    .setAutoCollectPerformance(true)       // CPU, memory, GC
    .setAutoCollectExceptions(true)        // unhandled errors
    .setAutoCollectDependencies(true)      // SQL, Redis, HTTP calls
    .setAutoCollectConsole(true, true)     // console.log as traces
    .setSendLiveMetrics(false)             // Live Metrics costs extra — skip for dev
    .start();
}
```

### Python SDK Setup (Step 7.1)

For product-service (FastAPI), we used OpenTelemetry-based SDK:

```python
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

def setup_telemetry(app):
    conn_str = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if conn_str:
        configure_azure_monitor(connection_string=conn_str)
        FastAPIInstrumentor.instrument_app(app)  # auto-traces all FastAPI requests
```

### Next.js SDK Setup (Step 7.1)

Next.js has a special `instrumentation.js` hook that runs once on server startup:

```javascript
// services/frontend/src/instrumentation.js
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs'
      && process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    const appInsights = await import('applicationinsights');
    appInsights.default
      .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
      .start();
  }
}
```

The `instrumentationHook: true` flag in `next.config.js` enables this file.

---

## 5. Prometheus — How Metrics Scraping Works

Prometheus uses a **pull model** — it actively fetches metrics from your services on a schedule, rather than your services pushing data to it.

### The Pull Model

```
Every 30 seconds:
  Prometheus → GET http://user-service-pod:3001/metrics
  Prometheus → GET http://product-service-pod:3002/metrics
  Prometheus → GET http://cart-service-pod:3003/metrics
  ... (all 8 services)

Response (Prometheus text format):
  # HELP http_requests_total Total number of HTTP requests
  # TYPE http_requests_total counter
  http_requests_total{method="GET",route="/api/users",status_code="200"} 4521
  http_requests_total{method="POST",route="/api/users/auth",status_code="401"} 12

Prometheus stores these as time-series:
  (metric_name, labels) → [(timestamp, value), (timestamp, value), ...]
```

### Why Pull Model?

| Pull (Prometheus) | Push (StatsD, InfluxDB) |
|---|---|
| Prometheus controls the scrape schedule | Services control when to send |
| Easy to see if a service is down (scrape fails) | Hard to detect — service just stops sending |
| No data loss if Prometheus is briefly down | Data lost if collector is down |
| Services don't need to know where Prometheus is | Services need Prometheus address |

### How Prometheus Discovers Our Services

We use **annotation-based discovery** — pods advertise themselves to Prometheus via Kubernetes annotations. We added these to all 8 Helm deployment templates:

```yaml
template:
  metadata:
    annotations:
      prometheus.io/scrape: "true"       # opt in to scraping
      prometheus.io/port: "3001"         # which port to scrape
      prometheus.io/path: "/metrics"     # which path (default is /metrics)
```

The `additionalScrapeConfigs` in our `kube-prometheus-stack.yaml` values file watches for these annotations and automatically adds the pod to the scrape list. No manual configuration per service.

---

## 6. What We Instrumented in Each Service

### Node.js Services (user, cart, order, payment, notification)

Each got a `telemetry.js` module with two responsibilities:

1. **Application Insights** — initialised if `APPLICATIONINSIGHTS_CONNECTION_STRING` exists
2. **Prometheus** — always-on; `prom-client` exposes `/metrics` endpoint

```javascript
// prom-client setup
const client = require('prom-client');
const register = new client.Registry();
register.setDefaultLabels({ service: 'user-service' });
client.collectDefaultMetrics({ register });  // Node.js runtime metrics (event loop, GC, heap)

// Custom counter — incremented on every response
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// Custom histogram — measures how long requests take
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});
```

### Express Middleware (all 5 Node.js services)

A middleware function intercepts every request and records timing:

```javascript
function metricsMiddleware(req, res, next) {
  if (req.path === '/metrics') return next();  // don't track the scrape itself
  const start = process.hrtime();
  res.on('finish', () => {
    const [s, ns] = process.hrtime(start);
    const route = req.route ? req.baseUrl + req.route.path : req.path;
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestsTotal.inc(labels);
    httpRequestDuration.observe(labels, s + ns / 1e9);
  });
  next();
}
```

### Python FastAPI Service (product-service)

```python
from prometheus_client import Counter, Histogram, CollectorRegistry

registry = CollectorRegistry()
http_requests_total = Counter(
    "http_requests_total", "Total HTTP requests",
    ["method", "route", "status_code"], registry=registry
)
```

### API Gateway (NGINX)

NGINX cannot run the prom-client SDK. Instead we enable `stub_status`:

```nginx
location /nginx_status {
  stub_status on;
  access_log off;
  allow 127.0.0.1;   # only the sidecar scrapes this
  deny all;
}
```

`stub_status` exposes: active connections, accepted connections, handled connections, total requests, reading/writing/waiting counts. A Prometheus nginx-exporter sidecar translates these into standard Prometheus metrics.

---

## 7. The Metrics We Expose

### Custom Metrics (from our code)

| Metric | Type | Labels | What It Measures |
|--------|------|--------|-----------------|
| `http_requests_total` | Counter | method, route, status_code | Total requests served |
| `http_request_duration_seconds` | Histogram | method, route, status_code | How long requests take |

### Default Node.js Metrics (from prom-client `collectDefaultMetrics`)

| Metric | What It Measures |
|--------|-----------------|
| `nodejs_eventloop_lag_seconds` | How backed up the event loop is |
| `nodejs_heap_size_used_bytes` | JavaScript heap memory in use |
| `nodejs_gc_duration_seconds` | Garbage collection pause time |
| `process_cpu_seconds_total` | CPU time consumed by the process |

### Kubernetes Metrics (from kube-state-metrics)

| Metric | What It Measures |
|--------|-----------------|
| `kube_pod_status_phase` | Whether each pod is Running/Pending/Failed |
| `kube_deployment_status_replicas_available` | How many replicas are healthy |
| `kube_horizontalpodautoscaler_status_current_replicas` | Current HPA replica count |
| `kube_horizontalpodautoscaler_spec_max_replicas` | HPA maximum limit |

### Node Metrics (from node-exporter)

| Metric | What It Measures |
|--------|-----------------|
| `container_cpu_usage_seconds_total` | CPU used by each container |
| `container_memory_working_set_bytes` | Memory in use (excluding cache) |
| `container_cpu_cfs_throttled_seconds_total` | Time the container was CPU-throttled |

---

## 8. Grafana — Visualising Prometheus Metrics

Grafana is a dashboard tool. You write PromQL queries and Grafana draws them as graphs, gauges, and tables.

### How Grafana Connects to Prometheus

```
Grafana → HTTP GET → Prometheus API (/api/v1/query_range)
                          ↓
                    Returns time-series data
                          ↓
                    Grafana renders as graph
```

Grafana needs to know the Prometheus address. In our setup:
- Prometheus is a ClusterIP service: `kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`
- Grafana (also in the cluster) can reach this address directly
- kube-prometheus-stack pre-configures this data source automatically

### Accessing Grafana

```bash
# Port-forward to your laptop — no public exposure needed
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Open in browser
http://localhost:3000
# Username: admin
# Password: AzureShop@Grafana2024
```

---

## 9. kube-prometheus-stack — What It Deploys

`kube-prometheus-stack` is a Helm chart that installs the entire monitoring stack in one command. It uses the Prometheus Operator pattern.

### What Gets Deployed

```
monitoring namespace
├── Prometheus Operator (Deployment)
│     Watches for PrometheusRule, ServiceMonitor, PodMonitor CRDs
│     Translates them into Prometheus config automatically
│
├── Prometheus (StatefulSet)
│     Scrapes metrics every 30s
│     Stores data in a PVC (20Gi, managed-csi)
│     Retains 15 days of data
│
├── Alertmanager (StatefulSet)
│     Receives firing alerts from Prometheus
│     Routes them (email, Slack, PagerDuty — not yet configured)
│     Deduplicates and groups alerts
│
├── Grafana (Deployment)
│     Reads from Prometheus via PromQL
│     Serves dashboard UI on port 3000
│     Stores dashboards in a PVC (5Gi)
│
├── node-exporter (DaemonSet — one pod per node)
│     Exposes node-level metrics: CPU, memory, disk, network
│
└── kube-state-metrics (Deployment)
      Watches Kubernetes API
      Exposes pod/deployment/HPA state as Prometheus metrics
```

### Install Command

```bash
# Add the Helm repo (one-time)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install / upgrade
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm/values/kube-prometheus-stack.yaml \
  --version 61.3.0 \
  --wait
```

### The Prometheus Operator Pattern

Before the Operator, you had to edit Prometheus config files and restart Prometheus to add new scrape targets. The Operator introduced CRDs:

```
You create: PrometheusRule   → Operator loads alert rules into Prometheus
You create: ServiceMonitor   → Operator adds service to scrape list
You create: PodMonitor       → Operator adds pods to scrape list
You create: AlertmanagerConfig → Operator configures routing in Alertmanager
```

Prometheus watches for these objects and reconfigures itself without a restart.

---

## 10. Annotation-Based Pod Scraping

The `additionalScrapeConfigs` block in our values file makes Prometheus scrape any pod that has the right annotations. Here is how the relabel rules work:

```yaml
additionalScrapeConfigs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod          # watch the Kubernetes API for pods

    relabel_configs:
      # Rule 1: Only keep pods that have opted in
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"

      # Rule 2: Use the annotated path instead of default /metrics
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

      # Rule 3: Replace the port with the annotated port
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

      # Rule 4: Copy all pod labels as Prometheus labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
```

**How `regex: ([^:]+)(?::\d+)?;(\d+)` works:**
- `[^:]+` — captures the IP address (everything before the colon)
- `(?::\d+)?` — optionally matches and discards the existing port
- `;(\d+)` — captures the annotated port number
- `replacement: $1:$2` — rebuilds as `<ip>:<annotated-port>`

Result: a pod at `10.244.0.5:3001` with annotation `prometheus.io/port: "3001"` is scraped at `10.244.0.5:3001/metrics`.

---

## 11. The Grafana Dashboard We Built

File: `k8s/grafana-dashboards/azureshop-services.json`

The dashboard has 6 panels in a 3-row, 2-column grid:

| Row | Left | Right |
|-----|------|-------|
| 1 | Request Rate (req/s) | Error Rate (%) |
| 2 | P95 Latency (seconds) | Running Pods |
| 3 | CPU Usage (cores) | Memory Usage (MB) |

### Service Variable

The dashboard has a `$service` variable at the top that lets you filter to one or multiple services. It is populated automatically from the `service` label on the `http_requests_total` metric.

### Dashboard Auto-Provisioning

Grafana in kube-prometheus-stack includes a **sidecar container** that watches for ConfigMaps with the label `grafana_dashboard: "1"` and loads them as dashboards automatically — no restart, no manual import.

```bash
# Apply the ConfigMap — Grafana picks it up within 30 seconds
kubectl apply -f k8s/grafana-dashboards/configmap.yaml
```

---

## 12. PromQL — Query Language Reference

PromQL (Prometheus Query Language) is how you query Prometheus data. It operates on time-series: each series is a metric name + a set of labels.

### Core Concepts

**Counter** — only goes up (e.g. total request count). Never query the raw value. Always use `rate()`.

**Gauge** — goes up and down (e.g. memory in use). Query the raw value directly.

**Histogram** — stores the distribution of values in buckets (e.g. request durations). Use `histogram_quantile()` to calculate percentiles.

### Key Functions

```promql
# rate() — per-second rate of increase of a counter over a time window
# Use for request counts, error counts, CPU usage
rate(http_requests_total[5m])

# sum() by — aggregate across multiple series, keeping the specified label
sum(rate(http_requests_total[5m])) by (service)

# histogram_quantile() — calculate a percentile from histogram buckets
# 0.95 = P95 (95th percentile)
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (service, le)
)
# NOTE: the "le" (less than or equal) label is required — it defines the bucket boundaries

# absent() — returns 1 if a metric series does not exist
# Useful for "service is down" alerts
absent(rate(http_requests_total{namespace="dev"}[5m]))

# / (division) — ratio between two metrics
# Error rate example:
sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (service)
/
sum(rate(http_requests_total[5m])) by (service)
```

### Label Matching

```promql
# Exact match
http_requests_total{service="user-service"}

# Regex match (=~)
http_requests_total{status_code=~"5.."}    # any 5xx status
http_requests_total{service=~"$service"}   # Grafana variable

# Negative regex (!~)
container_memory_working_set_bytes{container!~"POD|"}
```

### Our Dashboard Queries Explained

```promql
-- Request rate per service
sum(rate(http_requests_total{namespace="dev", service=~"$service"}[5m])) by (service)

-- Error rate (fraction of requests that are 5xx)
sum(rate(http_requests_total{namespace="dev", status_code=~"5.."}[5m])) by (service)
/
sum(rate(http_requests_total{namespace="dev"}[5m])) by (service)

-- P95 latency
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{namespace="dev"}[5m])) by (service, le)
)

-- Memory usage in MB (working set / 1024 / 1024)
sum(container_memory_working_set_bytes{namespace="dev", container!="", container!="POD"}) by (container)
/ 1024 / 1024

-- CPU throttling ratio (time throttled / total periods)
sum(rate(container_cpu_cfs_throttled_seconds_total{namespace="dev"}[5m])) by (container)
/
sum(rate(container_cpu_cfs_periods_total{namespace="dev"}[5m])) by (container)
```

---

## 13. KQL — Log Analytics Query Reference

KQL (Kusto Query Language) is how you query data in Azure Log Analytics. It looks like a pipeline — each `|` passes the result to the next operation.

### Basic Structure

```kql
TableName
| where <filter condition>
| summarize <aggregation> by <group>
| order by <column> desc
| take 100
```

### Key Tables in Azure Monitor

| Table | Contains |
|-------|---------|
| `requests` | All HTTP requests tracked by App Insights SDK |
| `exceptions` | All unhandled exceptions |
| `dependencies` | All outgoing calls (SQL, Redis, HTTP) |
| `traces` | `console.log()` output from Node.js SDK |
| `performanceCounters` | CPU, memory, etc. |
| `ContainerLog` | Stdout/stderr from AKS pods |
| `KubePodInventory` | Pod state from Container Insights |

### Useful Queries

```kql
// ── Error Rate by Service (last 1 hour) ──────────────────────────────────
requests
| where timestamp > ago(1h)
| summarize
    total = count(),
    errors = countif(resultCode >= 500)
  by cloud_RoleName
| extend error_rate = round(todouble(errors) / total * 100, 2)
| order by error_rate desc

// ── Slow Requests (P95 latency) ──────────────────────────────────────────
requests
| where timestamp > ago(1h)
| summarize
    p95_ms = percentile(duration, 95),
    p99_ms = percentile(duration, 99),
    count  = count()
  by cloud_RoleName, name
| where p95_ms > 1000
| order by p95_ms desc

// ── Recent Exceptions ────────────────────────────────────────────────────
exceptions
| where timestamp > ago(2h)
| project timestamp, cloud_RoleName, type, outerMessage, innermostMessage
| order by timestamp desc
| take 50

// ── Slow SQL Queries ─────────────────────────────────────────────────────
dependencies
| where timestamp > ago(1h)
    and type == "SQL"
    and duration > 500   -- milliseconds
| project timestamp, cloud_RoleName, name, duration, success
| order by duration desc
| take 20

// ── Failed Dependency Calls ──────────────────────────────────────────────
dependencies
| where timestamp > ago(1h) and success == false
| summarize failures = count() by cloud_RoleName, type, target
| order by failures desc

// ── AKS Pod Restarts (Container Insights) ────────────────────────────────
KubePodInventory
| where TimeGenerated > ago(1h)
| where Namespace == "dev"
| summarize restarts = max(RestartCount) by PodName, ContainerName
| where restarts > 0
| order by restarts desc

// ── Container CPU Usage ───────────────────────────────────────────────────
Perf
| where TimeGenerated > ago(30m)
    and ObjectName == "K8SContainer"
    and CounterName == "cpuUsageNanoCores"
| summarize avg_cpu_cores = avg(CounterValue) / 1e9 by InstanceName
| order by avg_cpu_cores desc

// ── Request Volume Over Time ──────────────────────────────────────────────
requests
| where timestamp > ago(6h)
| summarize request_count = count() by bin(timestamp, 5m), cloud_RoleName
| render timechart
```

### KQL vs PromQL

| | PromQL | KQL |
|--|--|--|
| **Best for** | Real-time metric queries | Historical log analysis |
| **Retention** | 15 days (our config) | 30 days (our config) |
| **Aggregation** | `sum()`, `rate()`, `histogram_quantile()` | `summarize`, `percentile()`, `bin()` |
| **Pipeline syntax** | No — function calls | Yes — `\|` operator |
| **Regex** | `=~` | `matches regex` |

---

## 14. Alert Rules — How Prometheus Alerting Works

### The Alert Lifecycle

```
PrometheusRule (YAML) → Prometheus Operator loads it
         ↓
Prometheus evaluates the rule every 1 minute
         ↓
If expr returns any data AND has been true for `for` duration:
  Alert status changes from "inactive" → "pending" → "firing"
         ↓
Firing alert sent to Alertmanager
         ↓
Alertmanager routes → notification (email, Slack, PagerDuty)
                       (not yet configured in Phase 7 — Phase 8)
```

### The `for` Duration

The `for` field prevents flapping — brief spikes do not fire an alert.

```yaml
- alert: HighErrorRate
  expr: error_rate > 0.05
  for: 5m          # must be true for 5 consecutive minutes to fire
```

Without `for: 5m`, a single bad second would fire the alert. With it, Prometheus waits 5 full minutes of sustained high error rate before firing.

### Alert States

| State | Meaning |
|-------|---------|
| `inactive` | Expression evaluates to no data or false |
| `pending` | Expression is true but `for` duration not yet elapsed |
| `firing` | Expression has been true for at least `for` duration |

### Severity Labels

We use two severity levels:

- **`critical`**: Service is down or severely degraded — act immediately
- **`warning`**: Something needs attention soon but service is still running

---

## 15. The 10 Alerts We Defined

File: `k8s/alert-rules/azureshop-alerts.yaml`

### Group: azureshop.http

| Alert | Expression | For | Severity | Why This Threshold |
|-------|-----------|-----|----------|-------------------|
| `HighErrorRate` | `5xx rate > 5%` | 5m | critical | Normal transient errors stay <1%; 5% means structural failure |
| `HighP95Latency` | `P95 > 1 second` | 5m | warning | Our SLO target; users notice slowness above 1s |
| `ServiceReceivingNoTraffic` | `absent(rate(...))` | 10m | warning | If metrics vanish, either service is down or Prometheus can't scrape it |

### Group: azureshop.availability

| Alert | Expression | For | Severity | Why This Threshold |
|-------|-----------|-----|----------|-------------------|
| `PodCrashLoopBackOff` | `waiting_reason == CrashLoopBackOff` | 5m | critical | CrashLoop means every restart fails — needs investigation |
| `PodNotRunning` | `phase != Running or Succeeded` | 15m | warning | 15 min gives time for slow starts; faster would create noise |
| `DeploymentUnavailable` | `available_replicas == 0` | 2m | critical | Zero replicas = service completely down |
| `PodUnschedulable` | `unschedulable == 1` | 10m | warning | Means cluster is too full or misconfigured |

### Group: azureshop.capacity

| Alert | Expression | For | Severity | Why This Threshold |
|-------|-----------|-----|----------|-------------------|
| `HPAAtMaxReplicas` | `current == max` | 10m | warning | Can't scale further — either raise limit or investigate load |
| `HighMemoryUsage` | `working_set > 85% of limit` | 5m | warning | 85% gives time to act before OOM kill at 100% |
| `HighCPUThrottling` | `throttled > 25% of periods` | 10m | warning | CPU throttling causes latency even without OOM |

### Remediation Commands in Annotations

Every alert includes the exact `kubectl` command to start investigating:

```yaml
annotations:
  description: >
    Check logs: kubectl logs -l app={{ $labels.service }} -n dev --tail=50
```

This means on-call doesn't waste time remembering syntax at 3am.

---

## 16. Terraform Changes Made in Phase 7

### New Resources (monitoring module — already existed from Phase 2)

```hcl
# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name              = "law-azureshop-dev"
  sku               = "PerGB2018"
  retention_in_days = 30
}

# One Application Insights per service — for_each creates 8 resources
resource "azurerm_application_insights" "services" {
  for_each         = toset(var.services)
  name             = "appi-${each.key}-dev"
  workspace_id     = azurerm_log_analytics_workspace.main.id
  application_type = each.key == "product-service" ? "other" : "web"
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "main" {
  name    = "grafana-azureshop-dev"
  sku     = "Standard"
  grafana_major_version = 11
}
```

### New: Key Vault Secrets for App Insights (Phase 7 Step 7.2)

```hcl
# keyvault/main.tf — for_each creates one secret per service
resource "azurerm_key_vault_secret" "appinsights_connection_strings" {
  for_each = var.application_insights_connection_strings

  name         = "appinsights-${each.key}-cs"   # e.g. appinsights-user-service-cs
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id
}
```

### Wiring in main.tf

```hcl
module "keyvault" {
  ...
  # Pass monitoring outputs → keyvault creates KV secrets from them
  application_insights_connection_strings = module.monitoring.application_insights_connection_strings
}
```

### Secret Flow After terraform apply

```
Terraform creates App Insights → gets connection string
  → stores as Key Vault secret: appinsights-user-service-cs
  → CSI driver reads from KV when pod starts
  → creates Kubernetes Secret: user-service-secrets
  → pod reads env var: APPLICATIONINSIGHTS_CONNECTION_STRING
  → SDK initialises and starts sending telemetry
```

---

## 17. Secret Flow — App Insights Connection String

We updated all 5 SecretProviderClass files to add the App Insights secret alongside the existing database secrets:

```yaml
# k8s/secret-provider-classes/user-service.yaml
spec:
  parameters:
    objects: |
      array:
        - |
          objectName: sql-server-fqdn         # existing
          objectType: secret
        - |
          objectName: appinsights-user-service-cs   # NEW in Phase 7
          objectType: secret
  secretObjects:
    - secretName: user-service-secrets
      type: Opaque
      data:
        - objectName: sql-server-fqdn
          key: SQL_SERVER
        - objectName: appinsights-user-service-cs   # NEW
          key: APPINSIGHTS_CONNECTION_STRING
```

And in `values.yaml` for each service:

```yaml
env:
  - name: APPLICATIONINSIGHTS_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: user-service-secrets
        key: APPINSIGHTS_CONNECTION_STRING
        optional: true    # pod starts even if secret doesn't exist yet
```

The `optional: true` is important — it means the pod starts cleanly when running locally or before Key Vault is provisioned. The SDK skips initialisation if the env var is absent.

---

## 18. Azure Managed Grafana vs Embedded Grafana

We have two Grafana instances:

### Embedded Grafana (kube-prometheus-stack)

- Lives inside AKS in the `monitoring` namespace
- Data source: **Prometheus** (within the cluster)
- Best for: Kubernetes metrics, custom app metrics (request rate, latency)
- Access: `kubectl port-forward` only — not publicly exposed
- Dashboards: our `azureshop-services.json` dashboard

### Azure Managed Grafana

- Managed Azure service created by Terraform
- Data source: **Azure Monitor** (App Insights, Container Insights, Log Analytics)
- Best for: Azure-native metrics, distributed traces, App Insights data
- Access: Public URL from Azure (`grafana-azureshop-dev.eus.grafana.azure.com`)
- Dashboards: configure via Azure portal or Grafana API

### Why Two?

They are complementary, not redundant:

```
Question: "What is the P95 latency of user-service right now?"
  → Embedded Grafana (Prometheus data, 30s resolution)

Question: "Why did the payment-service fail at 14:23 yesterday?"
  → Azure Managed Grafana → App Insights (full distributed trace)

Question: "How much memory is the AKS cluster using overall?"
  → Either works — Container Insights data is in both
```

---

## 19. Commands Reference

### Phase 7 Step 7.1 — SDK setup (no Azure resources needed)

```bash
# Verify telemetry.js exists in each service
ls services/*/src/telemetry.js
ls services/product-service/app/telemetry.py
ls services/frontend/src/instrumentation.js

# Verify /metrics endpoint works locally
cd services/user-service
npm install
node src/index.js &
curl http://localhost:3001/metrics
# Should return Prometheus text format with http_requests_total etc.
```

### Phase 7 Step 7.2 — Terraform apply (requires Azure infra)

```bash
cd infra/

# Preview what will be created
terraform plan -var-file="environments/dev/terraform.tfvars" \
  -var="sql_admin_password=$TF_VAR_sql_admin_password"

# Apply
terraform apply -var-file="environments/dev/terraform.tfvars" \
  -var="sql_admin_password=$TF_VAR_sql_admin_password"

# Verify App Insights resources were created
az monitor app-insights component list \
  --resource-group rg-azureshop-dev \
  --query "[].{name:name, connectionString:connectionString}" \
  --output table

# Verify KV secrets were created
az keyvault secret list \
  --vault-name kv-azureshop-6a6c-dev \
  --query "[?contains(name, 'appinsights')].name" \
  --output table
```

### Phase 7 Step 7.3 — Deploy kube-prometheus-stack

```bash
# Add Helm repo (one-time)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy (monitoring namespace must exist first)
kubectl apply -f k8s/namespaces/monitoring.yaml

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm/values/kube-prometheus-stack.yaml \
  --version 61.3.0 \
  --wait

# Verify all pods are running
kubectl get pods -n monitoring

# Apply Grafana dashboard ConfigMap
kubectl apply -f k8s/grafana-dashboards/configmap.yaml

# Access Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# http://localhost:3000  admin / AzureShop@Grafana2024

# Verify Prometheus scraping our services
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# http://localhost:9090/targets  — should show all 8 dev namespace pods
```

### Phase 7 Step 7.4 — Alert rules

```bash
# Apply PrometheusRule
kubectl apply -f k8s/alert-rules/azureshop-alerts.yaml

# Verify the operator loaded it
kubectl get prometheusrule -n monitoring

# Check alerts in Prometheus UI
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# http://localhost:9090/alerts
# All 10 alerts should appear (state: inactive if system is healthy)
```

### Useful Debugging Commands

```bash
# See Prometheus scrape targets and their status
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# http://localhost:9090/targets

# Test a PromQL query
# http://localhost:9090/graph?g0.expr=rate(http_requests_total[5m])

# Check if App Insights env var is injected into pods
kubectl exec -n dev deployment/user-service -- env | grep APPINSIGHTS

# Tail logs from all user-service pods
kubectl logs -n dev -l app=user-service --tail=50 -f

# Check Alertmanager
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
# http://localhost:9093

# Verify SecretProviderClass synced correctly
kubectl get secret user-service-secrets -n dev -o jsonpath='{.data}' | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
for k, v in data.items():
    print(f'{k}: {base64.b64decode(v).decode()[:20]}...')
"
```

---

## 20. Full Step-by-Step Summary

### Step 7.1 — Application Insights SDK + Prometheus /metrics

**What we did:**
- Added `telemetry.js` to 5 Node.js services (user, cart, order, payment, notification)
- Added `telemetry.py` to product-service (FastAPI)
- Added `instrumentation.js` to frontend (Next.js)
- Added `/nginx_status` to api-gateway nginx.conf
- Added `/metrics` endpoint to all 8 services
- Updated all 8 Helm deployment templates with Prometheus scrape annotations
- Updated all 8 `values.yaml` with `APPLICATIONINSIGHTS_CONNECTION_STRING` env var (`optional: true`)
- Updated all 5 SecretProviderClass YAMLs to fetch `appinsights-<service>-cs` from Key Vault

**Files changed:** 43 files across services/, helm/, k8s/

**Key decision:** `optional: true` on the `secretKeyRef` means pods start without the connection string — safe for local dev and before Azure infra exists.

### Step 7.2 — Terraform Monitoring Module

**What we did:**
- Confirmed monitoring module (Log Analytics + App Insights + Grafana) was already in place from Phase 2
- Added `application_insights_connection_strings` variable to keyvault module
- Added `for_each` resource to create one KV secret per App Insights connection string
- Wired `module.monitoring.application_insights_connection_strings` → `module.keyvault`

**Files changed:** 3 Terraform files

**Key insight:** `for_each = var.application_insights_connection_strings` creates 8 KV secrets from one resource block — same pattern as App Insights creation in the monitoring module.

### Step 7.3 — kube-prometheus-stack + Grafana Dashboard

**What we did:**
- Wrote `helm/values/kube-prometheus-stack.yaml` with annotation-based pod scraping, 20Gi Prometheus PVC, 5Gi Grafana PVC
- Wrote `k8s/grafana-dashboards/azureshop-services.json` — 6-panel dashboard (request rate, error rate, P95 latency, pod count, CPU, memory)
- Wrote `k8s/grafana-dashboards/configmap.yaml` — Kubernetes ConfigMap that Grafana auto-loads via the `grafana_dashboard: "1"` label sidecar

**Files changed:** 3 new files

**Key insight:** The dashboard auto-provisions because kube-prometheus-stack runs a sidecar that watches for ConfigMaps with `grafana_dashboard: "1"` label — no Grafana restart needed.

### Step 7.4 — PrometheusRule Alert Definitions

**What we did:**
- Wrote `k8s/alert-rules/azureshop-alerts.yaml` with 10 alerts in 3 groups
- Group `azureshop.http`: HighErrorRate, HighP95Latency, ServiceReceivingNoTraffic
- Group `azureshop.availability`: PodCrashLoopBackOff, PodNotRunning, DeploymentUnavailable, PodUnschedulable
- Group `azureshop.capacity`: HPAAtMaxReplicas, HighMemoryUsage, HighCPUThrottling

**Files changed:** 1 new file

**Key insight:** The `for:` duration prevents alert flapping. `DeploymentUnavailable` has `for: 2m` (critical — act fast). `HPAAtMaxReplicas` has `for: 10m` (warning — a brief spike at max is normal).

---

## 21. Interview Questions and Answers

**Q1: What is the difference between metrics, logs, and traces? When do you use each?**

Metrics are numbers aggregated over time — cheap to store, fast to query. Use them for dashboards and alerts: "is error rate above 5%?". Logs are timestamped text events with full context. Use them to investigate why something failed: "what was the SQL error message at 14:23?". Traces show how a single request moved across multiple services. Use them to find which service added latency: "user-service took 200ms — where did that time go?". In practice you use all three together: metrics tell you something is wrong, logs tell you what went wrong, traces tell you where.

---

**Q2: What is the difference between a Counter, Gauge, and Histogram in Prometheus?**

A Counter only ever goes up — you use it for things that accumulate over time like request counts or error counts. You never query the raw value; you always wrap it in `rate()` to get per-second rate. A Gauge goes up and down — like memory in use or number of active connections. You query the raw value directly. A Histogram stores the distribution of measured values in predefined buckets. For each request you record its duration, and the histogram counts how many requests fell into each bucket (e.g. how many took less than 100ms). You then use `histogram_quantile(0.95, ...)` to calculate P95. We use Counter for `http_requests_total` and Histogram for `http_request_duration_seconds`.

---

**Q3: Why does Prometheus use a pull model instead of push?**

With pull, Prometheus controls the scrape schedule and scrape targets. This has three important benefits. First, if a service is down, Prometheus immediately knows — the scrape fails. With push, if a service stops sending data, you only notice after some timeout. Second, services don't need to know where Prometheus is — they just expose `/metrics` and Prometheus finds them. Third, if Prometheus itself is briefly down (restart, upgrade), data is not lost — when it comes back up it resumes scraping. The tradeoff is that short-lived jobs (batch jobs that finish in seconds) cannot be scraped — for those you use Pushgateway to push metrics before the job exits.

---

**Q4: What is the `for` field in a PrometheusRule alert and why is it important?**

The `for` field defines how long the alert expression must be continuously true before the alert fires. Without it, a single bad sample (one second of high error rate) would immediately fire the alert. With `for: 5m`, Prometheus waits until 5 full consecutive minutes of high error rate before sending the alert to Alertmanager. This prevents alert fatigue from transient spikes that self-recover. We set different `for` values based on urgency: `DeploymentUnavailable` uses `for: 2m` (zero replicas is always bad — act fast), while `HPAAtMaxReplicas` uses `for: 10m` (briefly hitting max during a traffic spike is normal).

---

**Q5: What is a PrometheusRule and how does the Prometheus Operator use it?**

A PrometheusRule is a Kubernetes Custom Resource Definition (CRD) that contains Prometheus alert rules in YAML format. Before the Operator, you had to edit the Prometheus config file and restart Prometheus to add new rules. The Prometheus Operator (part of kube-prometheus-stack) watches for PrometheusRule objects in Kubernetes and automatically loads them into Prometheus without any restart. The label `release: kube-prometheus-stack` on the PrometheusRule must match the `ruleSelector` in the Prometheus CR — this tells the Operator which PrometheusRules belong to which Prometheus instance. You can verify rules are loaded by checking `http://localhost:9090/alerts`.

---

**Q6: How does Application Insights connect to Log Analytics Workspace? Why put them together?**

Application Insights stores all its telemetry in a Log Analytics Workspace using the workspace-based model (the default since 2021). This means all App Insights data — requests, exceptions, dependencies, traces — is queryable with KQL in the same workspace that holds AKS Container Insights logs, Azure Activity Logs, and diagnostic settings. The benefit is cross-service correlation: you can write one KQL query that joins App Insights request data with AKS pod events, or join SQL slow query logs with the application exceptions that followed them. Without workspace-based App Insights, each type of data would be in a separate silo.

---

**Q7: What is `histogram_quantile()` and what is the `le` label?**

`histogram_quantile(0.95, ...)` calculates the value below which 95% of observations fall — the P95 percentile. It works on Prometheus histogram data. When you record a histogram, Prometheus creates one time-series per bucket: `http_request_duration_seconds_bucket{le="0.1"}` counts how many requests took less than or equal to 0.1 seconds. The `le` label (less than or equal) defines the upper bound of each bucket. To calculate P95, you must include `le` in the `by()` clause so `histogram_quantile` can see all the buckets together. Without `le`, the aggregation would lose the bucket boundaries and the calculation would be incorrect.

---

**Q8: Explain the annotation-based pod scraping approach we used. What are the three annotations?**

We add three annotations to every pod template in our Helm charts. `prometheus.io/scrape: "true"` opts the pod in to scraping — pods without this are ignored. `prometheus.io/port: "3001"` tells Prometheus which port to scrape, since a pod might expose multiple ports. `prometheus.io/path: "/metrics"` tells Prometheus the path — defaults to `/metrics` but can be changed. In our `kube-prometheus-stack.yaml`, the `additionalScrapeConfigs` block uses Kubernetes service discovery (`role: pod`) combined with relabeling rules that read these annotations and dynamically build the scrape target list. When a new service is deployed with these annotations, Prometheus automatically discovers and starts scraping it with no manual configuration.

---

**Q9: What is the difference between Azure Managed Grafana and the embedded Grafana in kube-prometheus-stack?**

Azure Managed Grafana is a fully managed Azure service — Microsoft runs the Grafana server, handles upgrades, and it integrates natively with Azure Monitor as a data source. You access it at a public Azure URL. The embedded Grafana is a pod inside AKS deployed by kube-prometheus-stack. It connects to the in-cluster Prometheus service via ClusterIP — no network exposure needed. We use both because they serve different data sources: embedded Grafana shows Prometheus metrics (custom app metrics, Kubernetes state with 30-second resolution); Azure Managed Grafana shows Azure Monitor data (App Insights distributed traces, Container Insights, historical data with longer retention). They complement each other rather than duplicate.

---

**Q10: What does `optional: true` on a `secretKeyRef` do, and why did we use it?**

`optional: true` on a `secretKeyRef` means the pod will start even if the referenced Kubernetes Secret or key does not exist. Without it, Kubernetes refuses to schedule the pod if the secret is missing. We set `optional: true` on the `APPLICATIONINSIGHTS_CONNECTION_STRING` env var because the connection string lives in Key Vault, which is only provisioned when Azure infrastructure exists. During local development, in CI, and before `terraform apply` creates the Key Vault secrets, the pods must still be able to start. The Application Insights SDK checks for the env var at startup — if it is absent, the SDK skips initialisation and the service runs normally without telemetry. This is the "graceful degradation" pattern: observability is additive, not a hard dependency.

# Phase 7 — Monitoring & Observability: Question Bank

All questions asked during revision, with full detailed answers.
Covers: metrics vs logs vs traces, Counter vs Gauge vs Histogram, pull model, PrometheusRule `for` field, Prometheus Operator, Application Insights + Log Analytics, histogram_quantile and `le` label, annotation-based pod scraping, Azure Managed Grafana vs embedded Grafana, optional secretKeyRef, PromQL, KQL, alerting lifecycle.

---

## Table of Contents

1. [What is the Difference Between Metrics, Logs, and Traces?](#q1-what-is-the-difference-between-metrics-logs-and-traces)
2. [What is the Difference Between a Counter, Gauge, and Histogram in Prometheus?](#q2-what-is-the-difference-between-a-counter-gauge-and-histogram-in-prometheus)
3. [Why Does Prometheus Use a Pull Model Instead of Push?](#q3-why-does-prometheus-use-a-pull-model-instead-of-push)
4. [What is the for Field in a PrometheusRule Alert and Why is it Important?](#q4-what-is-the-for-field-in-a-prometheusrule-alert-and-why-is-it-important)
5. [What is a PrometheusRule and How Does the Prometheus Operator Use It?](#q5-what-is-a-prometheusrule-and-how-does-the-prometheus-operator-use-it)
6. [How Does Application Insights Connect to Log Analytics Workspace?](#q6-how-does-application-insights-connect-to-log-analytics-workspace)
7. [What is histogram_quantile() and What is the le Label?](#q7-what-is-histogram_quantile-and-what-is-the-le-label)
8. [Explain the Annotation-Based Pod Scraping Approach](#q8-explain-the-annotation-based-pod-scraping-approach)
9. [What is the Difference Between Azure Managed Grafana and the Embedded Grafana?](#q9-what-is-the-difference-between-azure-managed-grafana-and-the-embedded-grafana)
10. [What Does optional: true on a secretKeyRef Do and Why Did We Use It?](#q10-what-does-optional-true-on-a-secretkeyref-do-and-why-did-we-use-it)

---

## Q1. What is the Difference Between Metrics, Logs, and Traces?

### The Three Pillars of Observability

These three work together — you use all three to fully understand a system in production. They answer different questions.

### Metrics — Numbers Over Time

Metrics are **aggregated numerical measurements** recorded at intervals. Cheap to store, fast to query, ideal for dashboards and alerts.

```
http_requests_total{service="user-service", status="200"} → 4821
http_requests_total{service="user-service", status="500"} → 3
```

**Use for:** "Is something wrong right now?" — alert when error rate exceeds 5%, dashboard CPU over time.

In AzureShop: every service exposes `/metrics` scraped by Prometheus every 15 seconds. Grafana shows 6-panel dashboard with request rate, error rate, P95 latency, pod count, CPU, memory.

### Logs — Text Events With Context

Logs are **timestamped text records** of discrete events. Rich context, high volume, queryable with full-text search. Expensive to store at scale.

```
2026-05-16T14:23:01Z INFO  user-service: POST /api/users/login 200 42ms userId=101
2026-05-16T14:23:02Z ERROR user-service: SQL connection timeout after 5000ms
```

**Use for:** "What exactly went wrong?" — investigate a specific error after an alert fires.

In AzureShop: Container Insights sends all pod stdout/stderr to Log Analytics. KQL queries in Azure Monitor.

### Traces — Request Journeys Across Services

Traces show how a **single request propagates through multiple services**. Each service adds a span with timing and metadata.

```
[user-service 200ms total]
  └── [SQL query 180ms]       ← found the bottleneck

[api-gateway 350ms total]
  └── [→ user-service 200ms]
      └── [→ SQL 180ms]
```

**Use for:** "Which service is slow?" — distributed latency debugging.

In AzureShop: Application Insights SDK automatically traces requests and dependencies (SQL calls, outbound HTTP).

### When to Use Each

| Scenario | Tool |
|---|---|
| Alert: "error rate > 5%" | Metrics (Prometheus → AlertManager) |
| Investigate: "what was the SQL error at 14:23?" | Logs (Log Analytics / KQL) |
| Debug: "which service added the 200ms latency?" | Traces (Application Insights) |
| Dashboard: "request rate over last 24 hours" | Metrics (Grafana / PromQL) |

---

## Q2. What is the Difference Between a Counter, Gauge, and Histogram in Prometheus?

### Counter — Only Goes Up

A Counter accumulates monotonically. It starts at 0 and only increases. Resets to 0 on process restart.

```javascript
// prom-client (Node.js)
const httpRequests = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});
httpRequests.inc({ method: 'POST', route: '/login', status: '200' });
```

**Never query the raw counter value** — it keeps growing. Always use `rate()` to get per-second rate:
```promql
rate(http_requests_total[5m])   -- requests per second over last 5 minutes
```

Use for: request counts, error counts, bytes transferred.

### Gauge — Goes Up and Down

A Gauge can increase or decrease — it represents a current state.

```javascript
const activeConnections = new Gauge({
  name: 'active_connections',
  help: 'Number of active database connections'
});
activeConnections.set(pool.totalCount);
```

**Query the raw value directly:**
```promql
active_connections{service="user-service"}
```

Use for: memory in use, active connections, queue depth, replica count.

### Histogram — Distribution of Values

A Histogram records individual observations and distributes them across predefined buckets. Used to measure latency distributions and calculate percentiles.

```javascript
const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5]
});
```

For each request, the histogram increments the counter for every bucket whose upper bound exceeds the request duration. A 75ms request increments buckets `le="0.1"`, `le="0.25"`, `le="0.5"`, `le="1"`, `le="2.5"`.

**Use `histogram_quantile()` to get percentiles:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Quick Reference

| Type | Direction | Query | Use for |
|---|---|---|---|
| Counter | Only up | `rate()` | Total counts (requests, errors) |
| Gauge | Up and down | Raw value | Current state (memory, connections) |
| Histogram | Accumulates buckets | `histogram_quantile()` | Latency distributions, percentiles |

---

## Q3. Why Does Prometheus Use a Pull Model Instead of Push?

### Pull Model — Prometheus Scrapes Targets

```
Prometheus                  Services
   │──── GET /metrics ──→   user-service:3001/metrics
   │──── GET /metrics ──→   cart-service:3002/metrics
   │──── GET /metrics ──→   order-service:3003/metrics
   (every 15 seconds)
```

Prometheus controls when and what it scrapes. Services are passive — they just expose `/metrics` and wait.

### Push Model (Not What Prometheus Uses)

```
Services              Metrics Server
user-service ──push──→ [collector]
cart-service ──push──→ [collector]
(services decide when to push)
```

### Why Pull is Better for Kubernetes

**1. Immediate failure detection:**
With pull, if a service is down, Prometheus immediately gets a scrape failure — no metric arrives. With push, you only notice after a configurable timeout (e.g. 60 seconds of no data).

**2. Services don't need to know where Prometheus is:**
Services just expose `/metrics`. Prometheus finds targets via Kubernetes service discovery. If Prometheus moves to a new IP, services don't care — they don't push anywhere.

**3. Prometheus restarts don't lose data:**
If Prometheus is briefly unavailable (upgrade, crash), services keep accumulating counters. When Prometheus comes back, it resumes scraping. The data accumulates in the counter — the gap in scrapes just means less granularity in that window.

**4. Central scrape control:**
Rate-limiting is built-in. Prometheus will never be overwhelmed by a burst of push events from many services simultaneously.

### When Pull Falls Short — Pushgateway

Short-lived batch jobs (a script that runs for 5 seconds) finish before Prometheus scrapes them. For these, use the **Pushgateway**: the job pushes its final metrics to the gateway before exiting, and Prometheus scrapes the gateway.

---

## Q4. What is the for Field in a PrometheusRule Alert and Why is it Important?

### The Problem Without `for`

Without `for`, the alert fires the moment the expression evaluates to true — even for a single bad sample.

```yaml
# Dangerous — fires instantly on one bad second
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
```

If one second of high error rate occurs (a transient spike), an alert fires and wakes someone up at 3am. The spike self-recovers before anyone investigates. This is alert fatigue.

### What `for` Does

```yaml
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
for: 5m    # ← must be continuously true for 5 full minutes
```

The alert goes through two states before firing:
1. **Inactive** → expression first becomes true → **Pending** (timer starts)
2. **Pending** → 5 minutes of continuous truth → **Firing** (alert sent to Alertmanager)

If the expression recovers (drops below 0.05) at any point during the 5 minutes, the timer resets to Pending. The alert fires only if 5 unbroken minutes of high error rate occur.

### Choosing the Right Duration

| Alert | `for` | Reasoning |
|---|---|---|
| `DeploymentUnavailable` | 2m | Zero replicas is always critical — act fast |
| `HighErrorRate` | 5m | Transient spikes happen; 5 min of sustained errors is a real problem |
| `HPAAtMaxReplicas` | 10m | Briefly hitting max during a traffic spike is normal |
| `PodCrashLoopBackOff` | 5m | A pod might restart once legitimately; persistent CrashLoop is the problem |

### In AzureShop

All 10 PrometheusRule alerts in `k8s/alert-rules/azureshop-alerts.yaml` use `for` durations calibrated to their severity. No alert fires on transient conditions.

---

## Q5. What is a PrometheusRule and How Does the Prometheus Operator Use It?

### Before the Operator — Manual Config

```
1. SSH into Prometheus server
2. Edit /etc/prometheus/rules/alerts.yaml
3. Reload Prometheus (or restart)
```

This breaks GitOps principles — you cannot version-control and peer-review the change.

### PrometheusRule — Alert Rules as Kubernetes Resources

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: azureshop-alerts
  namespace: dev
  labels:
    release: kube-prometheus-stack   # ← critical label
spec:
  groups:
    - name: azureshop.http
      rules:
        - alert: HighErrorRate
          expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
          for: 5m
```

This is just a Kubernetes YAML file — committed to git, applied with `kubectl apply` or by Flux.

### How the Prometheus Operator Picks It Up

The **Prometheus Operator** (deployed as part of kube-prometheus-stack) watches for `PrometheusRule` objects cluster-wide. When it detects a new or updated PrometheusRule:

1. Reads the rule definitions
2. Generates a new Prometheus config
3. Writes it to a ConfigMap
4. Triggers a Prometheus config reload (no restart needed)

The `release: kube-prometheus-stack` label must match the `ruleSelector` in the Prometheus CRD — this is how the Operator knows which PrometheusRules belong to which Prometheus instance. Without this label, the Operator ignores the resource.

### Verify Rules Are Loaded

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Browse to http://localhost:9090/alerts
# All PrometheusRule entries should appear there
```

---

## Q6. How Does Application Insights Connect to Log Analytics Workspace?

### Workspace-Based Application Insights (Default Since 2021)

Modern Application Insights instances do not have their own isolated storage. They write all telemetry directly into a **Log Analytics Workspace**. This means App Insights data is in the same place as all other Azure Monitor data.

```
AzureShop App Insights instances (×8)
  ↓ telemetry (requests, exceptions, dependencies, traces)
Log Analytics Workspace (law-azureshop-dev)
  ↓ same workspace also receives:
AKS Container Insights (pod logs, node metrics)
Azure Activity Logs (who did what on Azure)
Azure SQL Diagnostics (slow queries)
```

### The Key Benefit — Cross-Service KQL Queries

Because everything is in one workspace, you can join across data sources in a single KQL query:

```kql
// Find all App Insights exceptions that happened during Kubernetes OOMKilled events
requests
| where timestamp > ago(1h) and resultCode == "500"
| join kind=inner (
    ContainerLog
    | where LogMessage contains "OOMKilled"
) on $left.timestamp == $right.TimeGenerated
```

Without workspace-based App Insights, this join is impossible — App Insights data would be in a separate silo.

### In AzureShop — Terraform Pattern

We use `for_each` to create one App Insights instance per service and one Key Vault secret per connection string:

```hcl
# monitoring module creates 8 App Insights instances
resource "azurerm_application_insights" "services" {
  for_each             = toset(var.service_names)
  name                 = "appi-${each.key}-dev"
  workspace_id         = azurerm_log_analytics_workspace.main.id  # ← same workspace
}

# keyvault module stores each connection string as a secret
resource "azurerm_key_vault_secret" "appinsights_connection_strings" {
  for_each = var.application_insights_connection_strings
  name     = "appinsights-${each.key}-cs"
  value    = each.value
}
```

Services read `APPLICATIONINSIGHTS_CONNECTION_STRING` from the Key Vault secret mounted by the CSI driver.

---

## Q7. What is histogram_quantile() and What is the le Label?

### The Problem — Averages Hide Outliers

```
10 requests: 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10ms, 10000ms
Average: 1009ms — suggests the service is slow
P95: 10ms — 95% of users had a great experience; one user had a terrible one
```

Percentiles (P50, P95, P99) tell you what the experience is for specific cohorts of users. The 95th percentile tells you what 95% of users experience.

### Histogram Buckets and the `le` Label

When you create a Histogram, Prometheus creates one time-series per bucket. The `le` label (less than or equal) is the upper bound:

```
http_request_duration_seconds_bucket{le="0.005"}  = 0
http_request_duration_seconds_bucket{le="0.01"}   = 0
http_request_duration_seconds_bucket{le="0.025"}  = 0
http_request_duration_seconds_bucket{le="0.05"}   = 0
http_request_duration_seconds_bucket{le="0.1"}    = 847   ← 847 requests took ≤ 100ms
http_request_duration_seconds_bucket{le="0.25"}   = 921
http_request_duration_seconds_bucket{le="0.5"}    = 952
http_request_duration_seconds_bucket{le="1"}      = 999
http_request_duration_seconds_bucket{le="+Inf"}   = 1000  ← total requests
```

From this data, Prometheus can calculate: the 95th percentile is between `le="0.25"` and `le="0.5"` (because 92.1% are ≤ 250ms and 95.2% are ≤ 500ms).

### histogram_quantile() Query

```promql
histogram_quantile(
  0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

**Why `by (le)` is required:**
`histogram_quantile()` needs to see all the bucket values together to interpolate the percentile. If you aggregate with `sum()` without `by (le)`, the `le` label is dropped and all buckets collapse into one number — `histogram_quantile` cannot calculate anything meaningful. `by (le)` keeps the bucket structure intact while still summing across pods/instances.

### In AzureShop Grafana Dashboard

The P95 latency panel uses:
```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{service="$service"}[5m]))
  by (le)
)
```

The `$service` template variable lets you select which service to view in the Grafana dropdown.

---

## Q8. Explain the Annotation-Based Pod Scraping Approach

### The Challenge — Dynamic Pod Discovery

In Kubernetes, pods are ephemeral. They start and stop, get new IPs, run on different nodes. You cannot maintain a static list of scrape targets in Prometheus config — by the time you add a new pod's IP, it may have been replaced.

### The Solution — Kubernetes Service Discovery + Annotations

Prometheus's `kubernetes_sd_configs` watches the Kubernetes API for pod changes in real time. But it would scrape everything — including system pods that don't expose metrics.

We use **three annotations** on every pod template to opt in:

```yaml
# In each Helm chart's deployment.yaml template:
annotations:
  prometheus.io/scrape: "true"    # opt in to scraping
  prometheus.io/port: "3001"      # which port (pod may expose multiple)
  prometheus.io/path: "/metrics"  # path (default /metrics, but can differ)
```

### The additionalScrapeConfigs That Reads Them

In `helm/values/kube-prometheus-stack.yaml`:
```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          # Step 1: only keep pods with prometheus.io/scrape: "true"
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: "true"
          # Step 2: use the port annotation as the scrape port
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
          # Step 3: use the path annotation as the metrics path
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
```

### The Flow

```
New pod starts with annotations
  ↓
kubernetes_sd_configs detects new pod via K8s API
  ↓
relabeling: prometheus.io/scrape == "true"? → keep this target
  ↓
relabeling: build scrape URL from pod IP + prometheus.io/port + prometheus.io/path
  ↓
Prometheus scrapes http://10.240.0.7:3001/metrics every 15 seconds
  ↓
Metrics appear in Grafana immediately — no config reload needed
```

Deploying a new service with these annotations is all that's needed for Prometheus to start collecting its metrics automatically.

---

## Q9. What is the Difference Between Azure Managed Grafana and the Embedded Grafana?

### Azure Managed Grafana — Azure Service

```
Azure Portal → Azure Managed Grafana resource (grafana-azureshop-dev)
  └── Microsoft-managed Grafana server
  └── Native Azure Monitor integration (no credentials needed)
  └── Public URL: https://grafana-azureshop-xxxx.grafana.azure.com
  └── Azure AD authentication
```

- Microsoft operates the Grafana server (upgrades, patches, HA)
- Connects natively to Azure Monitor — no data source configuration needed
- Queries App Insights, Log Analytics, Azure Metrics (VM CPU, AKS node metrics)
- Best for Azure-specific data with long retention (up to 90 days App Insights)

### Embedded Grafana — Pod in AKS (from kube-prometheus-stack)

```
AKS cluster → monitoring namespace → grafana pod
  └── Connects to in-cluster Prometheus service via ClusterIP
  └── No external network exposure (ClusterIP only)
  └── Access via: kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80
  └── Dashboard auto-provisioned from ConfigMap with label grafana_dashboard: "1"
```

- Runs inside the cluster alongside Prometheus
- Queries in-cluster Prometheus for **custom application metrics** (request rate, error rate, P95 latency)
- 15-second scrape resolution — ideal for real-time operational dashboards
- Data is ephemeral unless Prometheus PVC is configured (we configure 20GiB)

### Why We Use Both

| | Azure Managed Grafana | Embedded Grafana |
|---|---|---|
| Data source | Azure Monitor (App Insights, LAW) | In-cluster Prometheus |
| Data type | Traces, exceptions, Azure resource metrics | Custom app metrics, K8s state metrics |
| Resolution | Minutes | 15 seconds |
| Retention | 90 days (App Insights) | 15 days (Prometheus retention) |
| Access | Public URL + Azure AD | Port-forward from kubectl |

They complement each other: embedded Grafana for real-time Kubernetes operational metrics; Azure Managed Grafana for distributed traces and historical Azure platform metrics.

---

## Q10. What Does optional: true on a secretKeyRef Do and Why Did We Use It?

### What It Does

Without `optional: true`:
```yaml
env:
  - name: APPLICATIONINSIGHTS_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: user-service-secrets
        key: APPINSIGHTS_CONNECTION_STRING
```

If `user-service-secrets` Kubernetes Secret does not exist, or the key `APPINSIGHTS_CONNECTION_STRING` is missing → **Kubernetes refuses to schedule the pod**. The pod stays in `Pending` state with event: `secret "user-service-secrets" not found`.

With `optional: true`:
```yaml
    valueFrom:
      secretKeyRef:
        name: user-service-secrets
        key: APPINSIGHTS_CONNECTION_STRING
        optional: true    # ← pod starts even if secret/key is missing
```

The env var simply has no value (empty string) if the secret or key is absent. The pod starts normally.

### Why We Need It

The `APPLICATIONINSIGHTS_CONNECTION_STRING` comes from Key Vault, which is only provisioned when `terraform apply` creates the Azure infrastructure.

Without `optional: true`, pods cannot start unless:
1. Azure infrastructure exists
2. `terraform apply` has run
3. CSI driver has fetched secrets from Key Vault
4. Kubernetes Secret exists with the App Insights key

This blocks:
- **Local development** — no Azure infrastructure, no secret
- **CI environment** — pipelines build and test without Azure
- **First-ever deployment** — chicken-and-egg: pods need secret, secret needs CSI, CSI needs pod

### Graceful Degradation

The Application Insights SDK checks for the env var at startup:
```javascript
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING).start();
  // telemetry collection active
} else {
  // no telemetry — service runs normally, just without App Insights
}
```

If the env var is absent → SDK skips initialisation → service works normally without telemetry. Observability is **additive**, not a hard dependency. The service is not degraded from a user perspective — it just doesn't send telemetry to App Insights until the infrastructure is provisioned.

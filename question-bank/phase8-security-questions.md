# Phase 8 — Security & DevSecOps: Question Bank

All questions asked during revision, with full detailed answers.
Covers: Pod Security Standards (privileged/baseline/restricted), Pod Security Admission vs PodSecurityPolicy, readOnlyRootFilesystem + emptyDir, runAsNonRoot + runAsUser, Linux capabilities drop ALL, seccomp RuntimeDefault, automountServiceAccountToken, Trivy --ignore-unfixed vs .trivyignore, SARIF, PSA enforcement on running pods.

---

## Table of Contents

1. [What Are the Three Pod Security Standards and What Does Each Allow?](#q1-what-are-the-three-pod-security-standards-and-what-does-each-allow)
2. [What is Pod Security Admission and How is it Different from PodSecurityPolicy?](#q2-what-is-pod-security-admission-and-how-is-it-different-from-podsecu)
3. [What Does readOnlyRootFilesystem: true Protect Against and What Do You Need to Make It Work?](#q3-what-does-readonlyrootfilesystem-true-protect-against-and-what-do-you-need-to-make-it-work)
4. [Why Do We Set Both runAsNonRoot: true and runAsUser: 1001?](#q4-why-do-we-set-both-runasnonroot-true-and-runasuser-1001)
5. [What is a Linux Capability and Why Do We Drop ALL Capabilities?](#q5-what-is-a-linux-capability-and-why-do-we-drop-all-capabilities)
6. [What is seccomp and What Does RuntimeDefault Do?](#q6-what-is-seccomp-and-what-does-runtimedefault-do)
7. [Why Did We Set automountServiceAccountToken: false? Does It Break CSI or Workload Identity?](#q7-why-did-we-set-automountserviceaccounttoken-false-does-it-break-csi-or-workload-identity)
8. [What is the Difference Between --ignore-unfixed in Trivy and a .trivyignore Entry?](#q8-what-is-the-difference-between---ignore-unfixed-in-trivy-and-a-trivyignore-entry)
9. [What is SARIF and Why Do We Publish It from the Pipeline?](#q9-what-is-sarif-and-why-do-we-publish-it-from-the-pipeline)
10. [How Does Pod Security Admission Enforcement Interact with Already-Running Pods?](#q10-how-does-pod-security-admission-enforcement-interact-with-already-running-pods)

---

## Q1. What Are the Three Pod Security Standards and What Does Each Allow?

### Overview

Pod Security Standards (PSS) are three Kubernetes-defined profiles that describe levels of pod security restriction. They go from no restrictions to maximum restrictions.

### Privileged — No Restrictions

```yaml
# A pod under "privileged" can do anything:
securityContext:
  privileged: true        # container has all capabilities
  hostPID: true           # shares host process namespace
  hostNetwork: true       # uses host network directly
  hostIPC: true           # shares host IPC namespace
```

Appropriate only for cluster-level system components: CNI plugins (must configure network), storage drivers (must access host block devices), monitoring agents that need host access. **Never for application workloads.**

### Baseline — Blocks the Most Dangerous Escalations

Prevents the worst attack vectors while allowing most legacy applications to run without modification:
- Blocks `privileged: true`
- Blocks `hostPID`, `hostIPC`, `hostNetwork`
- Blocks `hostPath` volumes (a common container escape)
- Blocks most dangerous capabilities (`SYS_ADMIN`, `NET_ADMIN`)

**But still allows:**
- Running as root (UID 0)
- Writable root filesystem
- Most capabilities (NET_RAW, SETUID, etc.)

Suitable for most stateless apps that haven't been hardened. A reasonable starting point for teams migrating from no security policy.

### Restricted — Maximum Security

The most strict. Requires all of these:
- `runAsNonRoot: true` — no root processes
- `allowPrivilegeEscalation: false` — cannot gain more privileges
- `capabilities: drop: [ALL]` — no special capabilities
- A seccomp profile (`RuntimeDefault` or custom)
- No privilege escalation
- No hostPath volumes

**This is what we enforce on the `dev` namespace** via Pod Security Admission labels.

### Why We Chose Restricted for AzureShop

Starting with `restricted` forces us to build security in from the beginning. All 8 services were hardened to satisfy `restricted` before the PSA label was applied — so there was no period where the cluster accepted non-compliant pods. Had we started with `privileged` and later tried to tighten, we'd have many security debts to fix under production pressure.

---

## Q2. What is Pod Security Admission and How is it Different from PodSecurityPolicy?

### Pod Security Admission (PSA) — Current Mechanism (Kubernetes 1.23+)

PSA is a **built-in admission controller** — no separate installation required. You apply labels to a namespace and the API server enforces the chosen Pod Security Standard for all pods in that namespace.

```yaml
# k8s/namespaces/dev.yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted    # reject non-compliant pods
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted      # log violations without rejecting
    pod-security.kubernetes.io/warn: restricted       # warn clients without rejecting
```

Three modes:
- **enforce** — API server rejects the pod if it violates the standard
- **audit** — violation is logged in the audit log but pod is created
- **warn** — user gets a warning in their kubectl output but pod is created

**Simplicity:** Three well-defined levels. No RBAC bindings needed. Namespace-level configuration.

### PodSecurityPolicy (PSP) — Old Mechanism (Removed in K8s 1.25)

PSP was a cluster-wide resource that defined allowed pod configurations. You created policies (like "this policy allows non-root pods with no hostPath") and then bound them to ServiceAccounts via RBAC.

Problems with PSP:
- RBAC bindings were error-prone — accidentally binding a permissive policy to all ServiceAccounts undermined all security
- No "levels" — you wrote every rule from scratch
- Complex — a full PSP setup required deep Kubernetes RBAC knowledge
- Often misconfigured — teams frequently set up overly permissive policies just to make pods work

PSP was deprecated in Kubernetes 1.21 and removed in 1.25. PSA is the replacement.

### Comparison

| | PSA | PSP |
|---|---|---|
| Where configured | Namespace labels | Cluster-wide resource + RBAC |
| Levels | 3 (privileged, baseline, restricted) | Custom — you define every rule |
| Enforcement | Built-in admission controller | Admission controller + RBAC |
| Complexity | Low | High |
| Status | Current standard | Removed in K8s 1.25 |

---

## Q3. What Does readOnlyRootFilesystem: true Protect Against and What Do You Need to Make It Work?

### What It Does

```yaml
containerSecurityContext:
  readOnlyRootFilesystem: true
```

Mounts the container's root filesystem as read-only. The container process cannot write to any path — `/usr`, `/opt`, `/app`, `/tmp`, `/var/log` — by default.

### What It Protects Against

If an attacker exploits a vulnerability in your application (remote code execution):

**Without readOnlyRootFilesystem:**
```
Attacker executes code in the container
  → writes a reverse shell script to /tmp/shell.sh
  → downloads additional attack tools with curl to /usr/local/bin/
  → installs a crypto miner
  → modifies application files to persist the backdoor
```

**With readOnlyRootFilesystem:**
```
Attacker executes code in the container
  → tries to write to /tmp → DENIED (read-only filesystem)
  → cannot install tools, cannot write scripts, cannot modify files
  → attack surface is severely limited to what the process can do in memory
```

It does not prevent the initial exploit (that requires fixing the application code), but it dramatically limits what an attacker can do after gaining code execution.

### What You Need to Make It Work — emptyDir Volumes

Applications must write somewhere. Without workarounds, `readOnlyRootFilesystem: true` breaks apps that write to the filesystem at all.

`emptyDir` is a Kubernetes volume that provides a **temporary writable directory** created fresh for each pod and deleted when the pod terminates. It bypasses the read-only root filesystem restriction because it is a separate mount, not part of the container image.

### Per-Service emptyDir Requirements

| Service | Writable paths needed | emptyDir volumes |
|---|---|---|
| user-service, cart-service, order-service, payment-service, notification-service | `/tmp` (temp files) | 1 × `/tmp` |
| product-service | `/tmp` (Python temp) | 1 × `/tmp` |
| api-gateway (NGINX) | `/tmp` (pid file, cache), `/var/log/nginx` (access.log, error.log) | 2 × mounts |
| frontend | `/tmp` | 1 × `/tmp` |

```yaml
# In deployment.yaml (all services except api-gateway)
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}

# api-gateway needs TWO mounts
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: nginx-logs
    mountPath: /var/log/nginx
volumes:
  - name: tmp
    emptyDir: {}
  - name: nginx-logs
    emptyDir: {}
```

Missing the NGINX `/var/log/nginx` emptyDir would cause NGINX to fail to start (it cannot create its log files).

---

## Q4. Why Do We Set Both runAsNonRoot: true and runAsUser: 1001?

### They Serve Different Purposes

This is a "belt and suspenders" approach — two independent controls that together guarantee the container never runs as root.

### runAsUser: 1001 — Active Enforcement

```yaml
podSecurityContext:
  runAsUser: 1001
```

At container startup, the Linux kernel sets the process's UID to 1001 — regardless of what the `Dockerfile` says. Even if the Dockerfile forgot to add `USER` or accidentally set `USER root`, Kubernetes overrides it.

This is **proactive** — it sets the user.

### runAsNonRoot: true — Validation Check

```yaml
podSecurityContext:
  runAsNonRoot: true
```

Kubernetes checks: "would the container start as UID 0 (root)?" If yes, Kubernetes **rejects the pod before the container starts**.

This is **reactive** — it validates the result.

### Why You Need Both

| Scenario | Only runAsUser | Only runAsNonRoot | Both |
|---|---|---|---|
| Typo: `runAsUser: 0` | Container starts as root (bad) | Pod rejected ✅ | Pod rejected ✅ |
| Dockerfile has `USER root` | UID overridden to 1001 ✅ | Pod rejected ✅ | Pod rejected ✅ |
| No USER in Dockerfile | UID overridden to 1001 ✅ | Pod rejected (default is root) | UID set to 1001, non-root validated ✅ |
| Correct setup | Works ✅ | Works ✅ | Works ✅ |

In the typo case (`runAsUser: 0`): `runAsNonRoot` catches it. In the "no USER in Dockerfile" case: `runAsUser` actively sets 1001. Together they cover all cases.

### UID Choices in AzureShop

```yaml
# All Node.js and Python services — UID 1001
# This matches the USER instruction in their Dockerfiles:
#   RUN addgroup --gid 1001 appgroup && adduser --uid 1001 appuser
#   USER appuser
podSecurityContext:
  runAsUser: 1001
  runAsGroup: 1001

# api-gateway (nginx-unprivileged image) — UID 101
# nginx-unprivileged ships with the nginx user at UID 101
podSecurityContext:
  runAsUser: 101
  runAsGroup: 101
```

Using the wrong UID (e.g. specifying 1001 for NGINX) would cause volume mount permission errors at startup — files created by UID 101 cannot be read/written by a process running as 1001.

---

## Q5. What is a Linux Capability and Why Do We Drop ALL Capabilities?

### What Linux Capabilities Are

Traditional Unix permissions: root can do everything, non-root can do almost nothing. Linux capabilities split root's powers into fine-grained permissions that can be granted individually.

### Common Capabilities

| Capability | What it allows |
|---|---|
| `NET_BIND_SERVICE` | Bind to ports below 1024 (like port 80) |
| `NET_RAW` | Send raw network packets (ping, network scanning, spoofing) |
| `SYS_ADMIN` | Mount filesystems, change namespaces, many privileged ops |
| `SYS_CHROOT` | Change root directory (classic container escape technique) |
| `SETUID` | Change user ID — privilege escalation |
| `DAC_OVERRIDE` | Bypass file permission checks |
| `KILL` | Send signals to any process |

Containers running as non-root still receive some of these by default (e.g. `NET_RAW`, `SETUID`, `DAC_OVERRIDE`). They are not root, but they have elevated network and file system powers.

### What drop: ALL Does

```yaml
containerSecurityContext:
  capabilities:
    drop:
      - ALL
```

Every capability in the list above (and all others) is removed. The container process is a completely ordinary user — same as a regular non-root process on a bare OS.

### Why It's Safe for AzureShop Services

Our services don't need any special capabilities:
- They bind to ports above 1024 (3001–3006, 3000, 80 for NGINX internally) → no `NET_BIND_SERVICE` needed for user-space ports
- They don't send raw packets → no `NET_RAW` needed
- They don't mount filesystems → no `SYS_ADMIN` needed
- They don't change root directories → no `SYS_CHROOT` needed

Dropping ALL has **zero functional impact** on our services but removes significant attack surface. If an attacker exploits our Node.js code, the process has no capability to scan the network, escape to the host, or modify other processes.

### If You Need a Capability Back

```yaml
capabilities:
  drop:
    - ALL
  add:
    - NET_BIND_SERVICE   # only add what you explicitly need
```

Always drop ALL first, then add back only the specific capabilities required. This is the principle of least privilege.

---

## Q6. What is seccomp and What Does RuntimeDefault Do?

### What seccomp Is

Seccomp (Secure Computing Mode) is a **Linux kernel feature** that creates a filter on system calls. A seccomp profile defines which syscalls a process is allowed to make — everything else is blocked.

System calls (syscalls) are how user-space programs request services from the Linux kernel: open files, send network data, create processes, read memory. Without seccomp, a container can make any of the ~400+ available Linux syscalls.

### Why This Matters for Security

Many syscalls are dangerous in a container context:

| Syscall | Risk |
|---|---|
| `ptrace` | Attach to other processes, inject code (debugging tool, also attack tool) |
| `mount` | Mount filesystems — container escape technique |
| `kexec_load` | Load a new kernel — full system compromise |
| `unshare` | Create new namespaces — used in container escape techniques |
| `clone3` | Create processes in new namespaces |

### RuntimeDefault Profile

```yaml
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
```

`RuntimeDefault` uses the container runtime's (containerd on AKS) built-in default seccomp profile. This profile:
- Blocks ~300 dangerous syscalls
- Allows the ~100 syscalls that normal application containers genuinely need
- Is maintained by the container runtime team — automatically updated as new attack techniques emerge

### Why RuntimeDefault, Not a Custom Profile?

A custom profile requires auditing every syscall your application makes — complex, fragile, and application-specific. `RuntimeDefault` is the right balance:
- Much more restrictive than "no seccomp" (blocks 300 syscalls)
- Much easier than a custom profile (no auditing needed)
- Safe for all our services — Node.js, Python, NGINX, Next.js all work within the ~100 allowed syscalls

### Why Pod-Level, Not Container-Level?

Seccomp applies to the **pod sandbox** (the shared kernel namespace for all containers in a pod). Setting it at the pod level (`podSecurityContext`) correctly applies it to the entire pod. Container-level seccomp would only apply to that specific container and not to the init containers or other sidecar containers.

---

## Q7. Why Did We Set automountServiceAccountToken: false? Does It Break CSI or Workload Identity?

### What the Token Is

By default, Kubernetes mounts a JWT (ServiceAccount token) into every pod at:
```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

This token allows the pod to authenticate to the **Kubernetes API server**. With the right RBAC permissions, a pod can list secrets, list pods, delete deployments — anything a human with kubectl access could do.

### Why It's a Risk

Our application pods have no business calling the Kubernetes API. They serve HTTP requests and call Azure PaaS services. The mounted token is **unnecessary attack surface**:

```
Attacker exploits a vulnerability in user-service
  → reads /var/run/secrets/kubernetes.io/serviceaccount/token
  → uses token to call Kubernetes API
  → lists all Secrets in the namespace
  → reads SQL_PASSWORD, Redis password, etc.
```

Even if the default ServiceAccount has minimal permissions, leaving the token mounted violates least privilege.

### What We Did

```yaml
# In each Helm chart's serviceaccount.yaml template:
automountServiceAccountToken: false
```

This stops Kubernetes from mounting the token. Any pod using this ServiceAccount starts without the token file at all.

### Does It Break Key Vault CSI?

**No.** The CSI driver does not use the pod's ServiceAccount token to authenticate to Key Vault. It uses the **AKS CSI addon managed identity** (the node's identity, not the pod's). Authentication happens at the node level — the CSI DaemonSet on each node uses its own identity to fetch secrets from Key Vault on behalf of pods. The pod's token is irrelevant.

### Does It Break Workload Identity?

**No.** Workload Identity uses a **projected ServiceAccount token** mounted at a completely different path by the Workload Identity webhook:
```
/var/run/secrets/azure/tokens/azure-identity-token
```

This is a separate projected volume with a different audience (`api://AzureADTokenExchange`), not the auto-mounted ServiceAccount token. Setting `automountServiceAccountToken: false` disables the default auto-mount mechanism, but the Workload Identity webhook's projected volume is independent.

---

## Q8. What is the Difference Between --ignore-unfixed in Trivy and a .trivyignore Entry?

### The Problem Trivy Solves

Trivy scans Docker images for CVEs (Common Vulnerabilities and Exposures) in OS packages and application dependencies. Without filtering, it can report hundreds of findings — many of which are not actionable.

### --ignore-unfixed — Blanket Filter

```bash
docker run aquasec/trivy:latest image \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  $(ACR_LOGIN_SERVER)/user-service:$(imageTag)
```

`--ignore-unfixed` filters out all CVEs where **no patched version of the affected package exists**. If the upstream maintainers haven't released a fix, there is nothing a developer can do — upgrading the package isn't possible.

**Use case:** The pipeline blocking gate. There is no value blocking a deployment on an unfixable vulnerability. The developer cannot act on it. `--ignore-unfixed` reduces pipeline failures to only actionable issues.

### .trivyignore — Named Exception for Known CVEs

```
# .trivyignore
# Format: CVE-ID  [optional reason]

# CVE-2024-12345: Affects readline's interactive mode; user-service never uses interactive input
CVE-2024-12345

# CVE-2024-67890: False positive — our build uses musl libc, not glibc
CVE-2024-67890
```

A `.trivyignore` entry is a **specific, conscious exception** for a CVE where a fix EXISTS but you have reviewed it and decided not to apply it — for a documented reason.

**Use case:** When upgrading a package would break a critical dependency, or when you've assessed the vulnerable code path is not reachable in your configuration.

### Key Differences

| | --ignore-unfixed | .trivyignore |
|---|---|---|
| What it ignores | All CVEs with no available fix | Specific, named CVE IDs |
| Decision type | Automatic — no fix exists | Manual — conscious exception |
| Auditability | Not tracked (blanket rule) | Every entry is a named exception in git |
| Review required | No | Yes — each entry needs justification |
| Expiry | N/A | Add review-date comment to revisit later |

### In AzureShop Build Template

```yaml
# Step 4a: SARIF report — non-blocking, shows everything including unfixed
trivy --exit-code 0 --severity HIGH,CRITICAL --ignore-unfixed --format sarif

# Step 4b: Blocking gate — fails pipeline only on fixable HIGH/CRITICAL CVEs
trivy --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed
```

The SARIF report (Step 4a) is published as a pipeline artifact — security teams can see all findings including unfixed ones for tracking purposes. The gate (Step 4b) only fails on actionable issues.

---

## Q9. What is SARIF and Why Do We Publish It from the Pipeline?

### What SARIF Is

SARIF (Static Analysis Results Interchange Format) is an open JSON standard for security and code analysis tool output. It was designed so that multiple tools (Trivy, Snyk, CodeQL, ESLint) can produce results in a common format that IDEs, CI systems, and dashboards can parse uniformly.

```json
{
  "version": "2.1.0",
  "runs": [{
    "tool": { "driver": { "name": "Trivy" } },
    "results": [{
      "ruleId": "CVE-2024-12345",
      "level": "error",
      "message": { "text": "HIGH severity vulnerability in libc" },
      "locations": [...]
    }]
  }]
}
```

### Why Azure DevOps Displays It

Azure DevOps has a **Security tab** in pipeline runs that parses SARIF files. It shows:
- CVE ID and severity
- Affected package and version
- Fixed version (if available)
- Link to NVD / CVE database
- Count of new vs fixed vs existing findings

Without SARIF, Trivy's results are buried in pipeline text logs — hard to read, hard to track across runs.

### Our Pipeline Implementation

```yaml
# Step 4a: Generate SARIF (non-blocking — exit-code 0)
- script: |
    docker run aquasec/trivy --exit-code 0 --format sarif \
      --output /output/trivy-user-service.sarif
  displayName: 'Trivy SARIF Report'

# Step 4b: Blocking gate (exit-code 1 — fails pipeline on findings)
- script: |
    docker run aquasec/trivy --exit-code 1 --ignore-unfixed
  displayName: 'Trivy Security Gate'

# Step 4c: Publish SARIF — condition: always() — even if gate failed
- task: PublishBuildArtifacts@1
  condition: always()
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)/trivy'
    ArtifactName: trivy-reports
```

`condition: always()` is critical — if the blocking gate fails (Step 4b), without `always()` the publish step would be skipped. With `always()`, the SARIF is published even for failed builds — so engineers can see exactly which CVE caused the failure without re-running the scan.

### Two Reasons We Publish SARIF

1. **Visibility beyond the gate** — even when the gate passes (no unfixed HIGH/CRITICAL), the SARIF shows MEDIUM and LOW findings and unfixed CVEs for tracking
2. **Failure diagnosis** — when the gate fails, the SARIF shows exactly which CVE failed, with full details, without needing to re-run

---

## Q10. How Does Pod Security Admission Enforcement Interact with Already-Running Pods?

### PSA is an Admission Controller

PSA runs at **pod creation time** — it checks new pods as they are submitted to the Kubernetes API server. It does not continuously monitor running pods.

### What Happens When You Add PSA Labels

```bash
kubectl label namespace dev \
  pod-security.kubernetes.io/enforce=restricted
```

**Immediate effect:** All NEW pods created in the `dev` namespace must satisfy the `restricted` standard. Non-compliant pods are rejected with:
```
Error from server (Forbidden): pods "user-service-xxx" is forbidden:
violates PodSecurity "restricted:latest": ...
```

**No immediate effect on existing pods:** Pods already running continue running. PSA does not evict or restart them.

### The Hidden Risk

```
Timeline:
  1. Add PSA enforce: restricted label to dev namespace
  2. Existing 9 pods keep running (no effect yet)
  3. Rolling update triggered (new image pushed, Helm upgrade runs)
  4. Deployment tries to create new pod with old template
  5. PSA rejects new pod — template doesn't satisfy restricted
  6. Old pod is already terminated (Kubernetes deleted it for the rollout)
  7. Result: no running pods for that service → outage
```

### The Correct Approach

Update the pod specs to satisfy `restricted` in the **same PR** as the PSA namespace label:

```
Feature branch commit:
  ├── helm/charts/*/values.yaml      ← add securityContext fields
  ├── helm/charts/*/templates/*.yaml ← wire securityContext into templates
  └── k8s/namespaces/dev.yaml        ← add PSA enforce label
```

This is exactly what we did in Phase 8 — all 8 Helm charts were hardened and the namespace label was added in one PR. The sequence on the live cluster would be:
1. `kubectl apply -f k8s/namespaces/dev.yaml` — PSA label applied
2. `helm upgrade` all 8 services — new pods satisfy restricted, accepted by PSA
3. Old pods terminated as new pods become ready

No window where non-compliant pods would be rejected.

### Verify PSA is Working

```bash
# Try to create a non-compliant pod — should be rejected
kubectl run test --image=nginx --namespace=dev
# Expected: Error from server (Forbidden): violates PodSecurity "restricted:latest"

# Verify the namespace labels are applied
kubectl get namespace dev --show-labels
```

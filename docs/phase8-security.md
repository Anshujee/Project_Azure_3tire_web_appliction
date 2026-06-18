# Phase 8 — Security Hardening
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

Security in Kubernetes is not a single feature — it is a set of layers that work together. Each layer assumes the previous one can be bypassed, so even if an attacker breaks one control, the next one contains the damage. This is called **defence in depth**.

In this phase we hardened three areas:

1. **Step 8.1 — Pod Security** — enforced that every container runs as a non-root user with a read-only filesystem, and told the Kubernetes admission controller to reject any pod that violates these rules
2. **Step 8.2 — RBAC** — removed the Kubernetes API token from every pod that does not need it
3. **Step 8.3 — Trivy enhancements** — added SARIF security reports to Azure DevOps and tightened the scan gate to only block on actionable CVEs

By the end of this phase you will understand: what the Pod Security Standards are, how Kubernetes enforces them at admission time, what each security context field does and why, how RBAC token auto-mounting creates risk, and how Trivy fits into a shift-left security pipeline.

---

## Table of Contents

1. [Defence in Depth — The Security Layers](#1-defence-in-depth--the-security-layers)
2. [Pod Security Standards — Three Levels](#2-pod-security-standards--three-levels)
3. [Pod Security Admission — Enforcement at the Namespace Level](#3-pod-security-admission--enforcement-at-the-namespace-level)
4. [Container Security Context — Field by Field](#4-container-security-context--field-by-field)
5. [Pod Security Context vs Container Security Context](#5-pod-security-context-vs-container-security-context)
6. [runAsNonRoot and runAsUser — Why Both?](#6-runasnonroot-and-runasuser--why-both)
7. [readOnlyRootFilesystem and the emptyDir Pattern](#7-readonlyrootfilesystem-and-the-emptydir-pattern)
8. [seccompProfile — Syscall Filtering](#8-seccompprofile--syscall-filtering)
9. [Linux Capabilities — Drop ALL](#9-linux-capabilities--drop-all)
10. [What We Set Per Service](#10-what-we-set-per-service)
11. [RBAC — automountServiceAccountToken](#11-rbac--automountserviceaccounttoken)
12. [Trivy — How Image Scanning Works](#12-trivy--how-image-scanning-works)
13. [SARIF — Security Reports in Azure DevOps](#13-sarif--security-reports-in-azure-devops)
14. [ignore-unfixed — Reducing Scan Noise](#14-ignore-unfixed--reducing-scan-noise)
15. [The .trivyignore File](#15-the-trivyignore-file)
16. [Security Controls Summary — Before and After Phase 8](#16-security-controls-summary--before-and-after-phase-8)
17. [Commands Reference](#17-commands-reference)
18. [Full Step-by-Step Summary](#18-full-step-by-step-summary)
19. [Interview Questions and Answers](#19-interview-questions-and-answers)

---

## 1. Defence in Depth — The Security Layers

Think of security like an onion. No single layer is perfect, but each layer an attacker must break through gives you more time to detect and respond.

```
Layer 1 — Network: NetworkPolicy blocks pod-to-pod traffic across services
Layer 2 — Identity: Workload Identity / RBAC — pods can only access what they need
Layer 3 — Secrets: Key Vault CSI — secrets never stored in YAML or env files
Layer 4 — Pod security: runAsNonRoot, readOnlyRootFilesystem — limits damage if code is exploited
Layer 5 — Admission: PSA enforcement — cluster rejects misconfigured pods before they start
Layer 6 — Images: Trivy scans — known-vulnerable packages blocked before reaching production
Layer 7 — Runtime: seccomp, capability drop — limits what a compromised process can do at OS level
```

Phases 1-7 built layers 1-3. Phase 8 adds layers 4-7.

### Why This Matters

Suppose an attacker exploits a vulnerability in your Node.js code (e.g. a dependency with a known CVE). Without Phase 8 controls:

- Running as root → attacker has root on the container, can install tools, read all files
- Writable filesystem → attacker writes a backdoor, modifies config files
- API token mounted → attacker can query/modify Kubernetes objects cluster-wide
- No seccomp → attacker can make arbitrary Linux syscalls, attempt kernel exploits

With Phase 8 controls, the same attacker:

- Runs as UID 1001 → limited what they can read/write on the OS
- Read-only filesystem → cannot write files anywhere except `/tmp` (which we mounted as emptyDir — empty at every restart)
- No API token → cannot enumerate pods, secrets, or other Kubernetes resources
- RuntimeDefault seccomp → ~300 dangerous syscalls are blocked at the kernel level

---

## 2. Pod Security Standards — Three Levels

Kubernetes defines three built-in security profiles called Pod Security Standards (PSS). Each one is a set of rules that pods must satisfy.

### Privileged

No restrictions at all. Pods can run as root, mount host paths, use any Linux capability. Only appropriate for system-level pods like monitoring agents or CNI plugins.

### Baseline

Prevents the most obvious privilege escalations. Blocks:
- Pods running as root with `allowPrivilegeEscalation: true`
- `hostPID`, `hostIPC`, `hostNetwork` sharing
- Dangerous volume types (hostPath)
- Dangerous capabilities (NET_ADMIN, SYS_ADMIN, etc.)

Allows: running as root, writable filesystem, no seccomp.

### Restricted

The most secure level. Requires everything in baseline PLUS:
- `runAsNonRoot: true` — container must not run as UID 0
- `allowPrivilegeEscalation: false` — child processes cannot gain more privileges than parent
- `capabilities.drop: [ALL]` — all Linux capabilities removed
- `seccompProfile.type: RuntimeDefault` or `Localhost` — syscall filtering enabled

This is what we enforce on the `dev` namespace.

```
privileged    → baseline    → restricted
(anything)     (no obvious)   (full hardening)
               privilege      runAsNonRoot
               escalation     drop ALL caps
               no hostPath    no privilege esc
               no hostPID     seccomp required
```

---

## 3. Pod Security Admission — Enforcement at the Namespace Level

Pod Security Admission (PSA) is the built-in Kubernetes mechanism that enforces Pod Security Standards. It replaced the deprecated PodSecurityPolicy in Kubernetes 1.25.

### How It Works

PSA is an **admission controller** — a piece of code that runs inside the Kubernetes API server and inspects every pod creation request before the pod is scheduled.

```
kubectl apply / helm upgrade
        ↓
Kubernetes API Server receives pod spec
        ↓
PSA Admission Controller checks:
  Does this pod satisfy the PSS level set on the namespace?
        ↓
If YES → pod is created
If NO  → request is rejected with an error message (enforce mode)
        or warning is printed (warn mode)
        or audit log entry is written (audit mode)
```

### The Three Modes

| Mode | Behaviour | Use case |
|------|-----------|----------|
| `enforce` | Reject non-compliant pods | Production — hard gate |
| `audit` | Allow pod but log violation to audit log | Testing — detect without breaking |
| `warn` | Allow pod but return warning in API response | Dev — surface issues to developers |

We set all three to `restricted` on the dev namespace:

```yaml
# k8s/namespaces/dev.yaml
labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/enforce-version: latest
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/audit-version: latest
  pod-security.kubernetes.io/warn: restricted
  pod-security.kubernetes.io/warn-version: latest
```

### Why `-version: latest`?

The PSS rules are versioned to match Kubernetes releases. `latest` means "use the rules for the current cluster version". If you pin to a specific version (e.g. `v1.28`), the rules do not tighten when you upgrade the cluster — useful for stability. For learning, `latest` is fine.

### Applying the Namespace Update

```bash
kubectl apply -f k8s/namespaces/dev.yaml

# Verify the labels are set
kubectl get namespace dev --show-labels
```

---

## 4. Container Security Context — Field by Field

The `securityContext` block on a container controls what the process inside can do. Here is every field we use and what it means:

### `allowPrivilegeEscalation: false`

Prevents the process from gaining more privileges than it started with. Without this, a process running as UID 1001 could execute a setuid binary and temporarily gain root. This flag sets the `no_new_privs` bit on the process — it can never escalate, even if a setuid binary is present in the image.

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

**Analogy:** Like telling a contractor "you can work in this office, but you cannot use the master key even if you find one."

### `readOnlyRootFilesystem: true`

Mounts the container's root filesystem as read-only. The container process cannot write anywhere on disk except explicitly mounted volumes.

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

**Why this matters for security:** If an attacker exploits your Node.js code, they cannot:
- Write a backdoor script to `/usr/local/bin/`
- Modify your application config files
- Install tools (`curl`, `wget`, `python`) that are not in the image

They can only write to the `emptyDir` volumes you explicitly provide (like `/tmp`), which are empty on every pod restart and not persisted.

### `capabilities.drop: [ALL]`

Linux capabilities are fine-grained permissions that give processes specific root-like powers. By default, containers get a set of capabilities even when running as non-root (e.g. `NET_BIND_SERVICE` to bind ports below 1024). Dropping ALL removes every capability.

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
```

Our services run on ports 3001-3006 and 8080 — all above 1024, so `NET_BIND_SERVICE` is not needed. No capabilities needed at all.

### `runAsNonRoot: true`

Tells Kubernetes to verify that the image's configured user is not UID 0 (root). If the Dockerfile sets `USER root` or does not set a USER at all, Kubernetes refuses to start the pod. This is a safety net — even if a Dockerfile accidentally drops the USER instruction, the pod will not start.

### `runAsUser` and `runAsGroup`

Set the exact UID and GID for the process. These override whatever the Dockerfile sets. We use them to be explicit:

```yaml
podSecurityContext:
  runAsUser: 1001
  runAsGroup: 1001
```

---

## 5. Pod Security Context vs Container Security Context

There are two places you can set security context: on the pod and on the container. They are different scopes.

```yaml
spec:
  securityContext:          # Pod-level — applies to ALL containers in the pod
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    seccompProfile:
      type: RuntimeDefault

  containers:
    - name: my-app
      securityContext:      # Container-level — applies to THIS container only
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
```

### Why Split?

| Setting | Where | Why |
|---------|-------|-----|
| `runAsNonRoot` | Pod | Applies to all containers including init containers |
| `runAsUser/Group` | Pod | Sets the UID/GID for all containers consistently |
| `seccompProfile` | Pod | Seccomp policy applies to the whole pod sandbox |
| `allowPrivilegeEscalation` | Container | Each container has its own privilege escalation setting |
| `readOnlyRootFilesystem` | Container | Each container has its own filesystem |
| `capabilities` | Container | Each container has its own capability set |

### How We Made It Values-Driven

Instead of hardcoding the security context in the deployment template, we put the values in `values.yaml` and reference them with `toYaml`:

```yaml
# values.yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

```yaml
# deployment.yaml template
spec:
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 8 }}
  containers:
    - securityContext:
        {{- toYaml .Values.containerSecurityContext | nindent 12 }}
```

This means you can override security context per environment by passing different values. For example, a debugging environment could relax `readOnlyRootFilesystem` without touching the template.

---

## 6. runAsNonRoot and runAsUser — Why Both?

You might wonder: if `runAsUser: 1001` forces the UID to 1001, why also set `runAsNonRoot: true`? They serve different purposes.

`runAsUser: 1001` — Kubernetes **sets** the UID to 1001. The container runs as 1001 regardless of what the Dockerfile says.

`runAsNonRoot: true` — Kubernetes **validates** that UID 0 is not used. If `runAsUser` is absent and the Dockerfile has `USER root`, `runAsNonRoot` catches this and rejects the pod.

Together they are belt-and-suspenders:
- `runAsUser` actively sets the UID
- `runAsNonRoot` validates as a safety net

### Our UID Choices

We confirmed the UID for every service by reading the Dockerfile before adding the security context:

| Service | Base Image | USER in Dockerfile | UID | GID |
|---------|-----------|-------------------|-----|-----|
| user-service | node:18-alpine | nodejs (created) | 1001 | 1001 |
| cart-service | node:18-alpine | nodejs (created) | 1001 | 1001 |
| order-service | node:18-alpine | nodejs (created) | 1001 | 1001 |
| payment-service | node:18-alpine | nodejs (created) | 1001 | 1001 |
| notification-service | node:18-alpine | nodejs (created) | 1001 | 1001 |
| frontend | node:18-alpine | nodejs (created) | 1001 | 1001 |
| product-service | python:3.11-slim | appuser (created) | 1001 | 1001 |
| api-gateway | nginx-unprivileged | nginx (built-in) | 101 | 101 |

The `nginxinc/nginx-unprivileged` image is specifically designed to run NGINX as a non-root user. Its built-in `nginx` user has UID 101. Setting `runAsUser: 101` matches this exactly.

---

## 7. readOnlyRootFilesystem and the emptyDir Pattern

Making the root filesystem read-only sounds simple, but containers often need to write to disk — even for basic operations. The pattern is:

1. Set `readOnlyRootFilesystem: true`
2. For every directory the container writes to, mount an `emptyDir` volume

An `emptyDir` volume is a temporary directory created fresh for each pod and deleted when the pod stops. It satisfies the write requirement without the security risk of a persistent writable filesystem.

### What Each Service Writes To

| Service | Writes to | emptyDir mounted at |
|---------|-----------|-------------------|
| Node.js services | `/tmp` (temp files, npm) | `/tmp` |
| product-service (FastAPI) | `/tmp` | `/tmp` |
| frontend (Next.js) | `/tmp` | `/tmp` |
| api-gateway (NGINX) | `/tmp` (pid, cache), `/var/log/nginx` | `/tmp`, `/var/log/nginx` |

### NGINX Requires Two Mounts

Our `nginx.conf` already redirected all temp paths to `/tmp` in Phase 3:

```nginx
pid /tmp/nginx.pid;
client_body_temp_path /tmp/client_temp;
proxy_temp_path       /tmp/proxy_temp;
```

But NGINX still writes `access.log` and `error.log` to `/var/log/nginx/`. With `readOnlyRootFilesystem: true`, NGINX fails to start if this path is not writable. So api-gateway gets two emptyDir volumes:

```yaml
# api-gateway deployment.yaml
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

### Template Pattern for Other Services

All other services get just the `/tmp` mount, always present (not conditional):

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
  {{- if .Values.secretProviderClass.enabled }}
  - name: secrets-store
    mountPath: /mnt/secrets-store
    readOnly: true
  {{- end }}
volumes:
  - name: tmp
    emptyDir: {}
  {{- if .Values.secretProviderClass.enabled }}
  - name: secrets-store
    csi: ...
  {{- end }}
```

Note: the `/tmp` mount is always present — it does not need a conditional because every container benefits from a writable `/tmp` even if `readOnlyRootFilesystem` were relaxed.

---

## 8. seccompProfile — Syscall Filtering

Seccomp (Secure Computing Mode) is a Linux kernel feature that restricts which system calls a process can make.

### What Are Syscalls?

Every action a process takes goes through the Linux kernel via system calls:
- Read a file: `open()`, `read()` syscalls
- Make a network connection: `socket()`, `connect()` syscalls
- Fork a child process: `fork()`, `clone()` syscalls
- Change file permissions: `chmod()` syscall

A normal Linux system has ~400 syscalls. Most applications only need ~50-100. The rest are attack surface.

### RuntimeDefault Profile

`seccompProfile.type: RuntimeDefault` uses the container runtime's built-in default profile. For containerd (which AKS uses), this blocks around 300 of the ~400 syscalls, including dangerous ones like:

- `ptrace` — debugging/attaching to other processes
- `mount` — mounting filesystems
- `kexec_load` — loading a new kernel
- `unshare` — creating new namespaces (used in container escape techniques)
- `keyctl` — manipulating kernel keyrings

### Why RuntimeDefault Rather Than a Custom Profile?

Writing a custom seccomp profile (listing every syscall your app needs) is extremely thorough but requires deep knowledge of your application's syscall usage. `RuntimeDefault` gives you ~75% of the benefit with 0% of the work — a good trade for a DevOps learning project.

```yaml
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
```

This is a pod-level setting because seccomp filters the entire process tree in the pod sandbox, not individual containers.

---

## 9. Linux Capabilities — Drop ALL

When a container starts, Docker/containerd grants it a default set of Linux capabilities even if it runs as non-root. These are:

```
CHOWN, DAC_OVERRIDE, FSETID, FOWNER, MKNOD, NET_RAW, SETGID, SETUID,
SETFCAP, SETPCAP, NET_BIND_SERVICE, SYS_CHROOT, KILL, AUDIT_WRITE
```

Most of these are unnecessary for a web service. Some are dangerous:

| Capability | What it allows | Risk |
|-----------|----------------|------|
| `NET_RAW` | Send raw packets, craft ARP/ICMP | Network spoofing |
| `SYS_CHROOT` | Change root directory | Container escape preparation |
| `SETUID` | Change user ID | Privilege escalation |
| `CHOWN` | Change file ownership | Modify sensitive files |

Dropping ALL capabilities removes all of these. If your application genuinely needs one (e.g. `NET_BIND_SERVICE` to bind port 80), you add it back explicitly:

```yaml
securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]  # only if needed
```

Our services run on ports above 1024 — no capabilities needed at all.

---

## 10. What We Set Per Service

The final security context on every service after Phase 8:

### Pod-level (spec.securityContext) — all services except api-gateway

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
```

### Pod-level — api-gateway only

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101     # nginx user in nginx-unprivileged image
  runAsGroup: 101
  seccompProfile:
    type: RuntimeDefault
```

### Container-level — all 8 services

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Values-driven approach

The security context values live in each chart's `values.yaml`. This means:
- A staging environment could have identical values (same security posture)
- A production environment could be even stricter (e.g. a custom seccomp profile)
- A development override file could relax `readOnlyRootFilesystem` for debugging without touching the template

---

## 11. RBAC — automountServiceAccountToken

### What Is a ServiceAccount Token?

Every Kubernetes pod automatically gets a ServiceAccount. By default, Kubernetes mounts a JWT token for that ServiceAccount into every pod at:

```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

This token allows the pod to make authenticated calls to the Kubernetes API server. For example, a pod could call:

```
GET https://kubernetes.default.svc/api/v1/namespaces/dev/secrets
```

And if the ServiceAccount has permissions, it would receive all secrets in the dev namespace.

### The Risk

Most application pods do not need to call the Kubernetes API at all. Mounting the token is unnecessary and creates risk:

- If an attacker exploits your Node.js code, they can read the token from the mounted file
- If the ServiceAccount has overly broad permissions, the attacker can enumerate pods, read secrets, or modify deployments
- Even with narrow permissions, the token proves the pod's identity — useful for lateral movement

### What We Changed

```yaml
# serviceaccount.yaml template — all 8 charts
automountServiceAccountToken: false
```

This tells Kubernetes not to mount the token. Pods start without any API credential.

### CSI Driver Uses the Node Identity, Not the Pod Token

You might wonder: the CSI driver reads secrets from Key Vault — does it need the ServiceAccount token?

No. The Key Vault CSI driver runs as a DaemonSet on each node. It uses the **AKS kubelet managed identity** (the node's identity, not the pod's identity) to authenticate to Key Vault. The pod's ServiceAccount token is irrelevant to this process.

### Workload Identity Still Works

The notification-service uses Workload Identity — its pods need to call Azure APIs. Workload Identity works differently from the Kubernetes API token:

```
Normal ServiceAccount token: JWT for the Kubernetes API
Workload Identity token:     Projected volume at a different path, signed by the OIDC issuer
```

Workload Identity uses a projected token volume (automatically injected by the Workload Identity webhook), not the auto-mounted ServiceAccount token. So `automountServiceAccountToken: false` does not break Workload Identity.

---

## 12. Trivy — How Image Scanning Works

Trivy is a vulnerability scanner for container images. It works by:

1. **Extracting** the image layers from the local Docker daemon or a registry
2. **Identifying** all installed packages (OS packages via dpkg/apk, language packages via package.json, requirements.txt, go.sum, etc.)
3. **Comparing** each package version against vulnerability databases (NVD, GitHub Advisory, OS vendor advisories)
4. **Reporting** matches as CVEs (Common Vulnerabilities and Exposures) with severity levels

### Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| CRITICAL | Easily exploitable, high impact | Fix immediately |
| HIGH | Significant risk, likely exploitable | Fix in next sprint |
| MEDIUM | Moderate risk, harder to exploit | Fix when convenient |
| LOW | Minor risk | Track but low priority |

Our pipeline blocks on HIGH and CRITICAL only.

### Where Trivy Fits in the Pipeline

```
Build image → Trivy SARIF scan (non-blocking, for visibility)
           → Trivy security gate (blocking, HIGH/CRITICAL unfixed CVEs)
           → Push to ACR (only if gate passes)
           → Deploy to AKS
```

The image never reaches ACR if it has a fixable HIGH/CRITICAL CVE. This is **shift-left security** — catching problems as early in the pipeline as possible, before they can reach production.

### Before Phase 8 vs After

**Before Phase 8 (Phase 5):**
```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL --no-progress <image>
```
- Single scan step
- No SARIF output (no security tab in Azure DevOps)
- Blocked on ALL HIGH/CRITICAL including unfixable ones (noise)

**After Phase 8:**
- Step 4a: SARIF report → Azure DevOps Security tab (non-blocking)
- Step 4b: Blocking gate with `--ignore-unfixed` (only actionable CVEs)
- Step 4c: SARIF artifact published even if gate fails

---

## 13. SARIF — Security Reports in Azure DevOps

SARIF (Static Analysis Results Interchange Format) is a JSON format for security scan results. Azure DevOps can parse SARIF files and display them in the Security tab of a pipeline run.

### What the Security Tab Shows

- List of all CVEs found in the image
- Severity, affected package, installed version, fixed version
- Links to CVE details
- Filterable by severity

### How We Implemented It

```yaml
# Step 4a in build-template.yaml
- script: |
    mkdir -p $(Build.ArtifactStagingDirectory)/trivy
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $(Build.ArtifactStagingDirectory)/trivy:/output \
      aquasec/trivy:latest image \
        --exit-code 0 \           # non-blocking — always succeeds
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        --format sarif \          # SARIF output format
        --output /output/trivy-${{ parameters.serviceName }}.sarif \
        --no-progress \
        <image>

# Step 4c — publish as artifact (condition: always — even if gate fails)
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)/trivy'
    ArtifactName: 'trivy-reports'
  condition: always()
```

The `condition: always()` on Step 4c is important — if the security gate (Step 4b) fails, you still want the SARIF report published so you can see what caused the failure.

---

## 14. ignore-unfixed — Reducing Scan Noise

### The Problem Without ignore-unfixed

Without `--ignore-unfixed`, Trivy reports every CVE in the database — including ones where no patched version of the affected package exists. These are CVEs where:

- The upstream vendor has not released a fix yet
- The OS vendor has not backported the fix yet
- The package is unmaintained

When there is no fix available, the only mitigation is to remove the package entirely or wait. Blocking the pipeline on these CVEs is counterproductive — it prevents deployment without giving developers anything they can actually do.

### What --ignore-unfixed Does

`--ignore-unfixed` filters out CVEs that have no available fix. The pipeline only blocks on CVEs where a patched version exists and you could fix the issue by updating the dependency.

### Example

```
Without --ignore-unfixed:
  CRITICAL: CVE-2023-XXXX — openssl 1.1.1k (no fix available) → BLOCKS pipeline ❌

With --ignore-unfixed:
  CRITICAL: CVE-2023-YYYY — lodash 4.17.20 → fix: upgrade to 4.17.21 → BLOCKS ❌
  CRITICAL: CVE-2023-XXXX — openssl 1.1.1k (no fix available) → SKIPPED (visible in SARIF) ✅
```

The unfixed CVE still appears in the SARIF report — you can see it in the Security tab. It just does not block the pipeline.

---

## 15. The .trivyignore File

Sometimes a CVE is reported that:
- You have assessed and accepted the risk (e.g. the vulnerable code path is not reachable in your configuration)
- Has a fix but upgrading would break a dependency
- Is a false positive

For these cases, `.trivyignore` lets you explicitly acknowledge and suppress specific CVE IDs:

```
# .trivyignore
CVE-2023-12345  # Package: some-lib 1.0.0 | Risk: accepted | Review: 2026-08-01
```

### Rules for .trivyignore

Our `.trivyignore` enforces two things:
1. Every entry must have a comment explaining WHY it is ignored
2. Every entry must have a `Review by` date — no entry is permanent

This prevents the file from becoming a graveyard of forgotten suppressions.

### How Trivy Reads It

When run from the repo root, Trivy automatically reads `.trivyignore`. In the pipeline, mount the file into the container:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/.trivyignore:/root/.trivyignore \
  aquasec/trivy:latest image ...
```

---

## 16. Security Controls Summary — Before and After Phase 8

### Before Phase 8 (end of Phase 7)

| Control | Status |
|---------|--------|
| Network policies (pod firewall) | ✅ Phase 6 |
| Key Vault CSI (no secrets in YAML) | ✅ Phase 6 |
| Workload Identity (no credentials) | ✅ Phase 6 |
| Trivy scan in CI (HIGH/CRITICAL) | ✅ Phase 5 |
| allowPrivilegeEscalation: false | ✅ Phase 6 |
| capabilities: drop ALL | ✅ Phase 6 |
| seccompProfile: RuntimeDefault | ✅ Phase 6 |
| runAsNonRoot / runAsUser | ❌ Deferred |
| readOnlyRootFilesystem | ❌ Deferred |
| Pod Security Admission (namespace) | ❌ Not set |
| automountServiceAccountToken: false | ❌ Not set |
| Trivy SARIF output | ❌ Not set |
| Trivy --ignore-unfixed | ❌ Not set |
| .trivyignore process | ❌ Not set |

### After Phase 8

| Control | Status |
|---------|--------|
| Network policies | ✅ |
| Key Vault CSI | ✅ |
| Workload Identity | ✅ |
| Trivy scan + SARIF | ✅ |
| allowPrivilegeEscalation: false | ✅ |
| capabilities: drop ALL | ✅ |
| seccompProfile: RuntimeDefault | ✅ |
| runAsNonRoot: true | ✅ Phase 8 |
| runAsUser: 1001 / 101 | ✅ Phase 8 |
| readOnlyRootFilesystem: true | ✅ Phase 8 |
| /tmp emptyDir for writable space | ✅ Phase 8 |
| Pod Security Admission: restricted | ✅ Phase 8 |
| automountServiceAccountToken: false | ✅ Phase 8 |
| Trivy SARIF in Security tab | ✅ Phase 8 |
| Trivy --ignore-unfixed | ✅ Phase 8 |
| .trivyignore with mandatory comments | ✅ Phase 8 |

---

## 17. Commands Reference

### Verify pod security context is applied

```bash
# Check what security context is running on a pod
kubectl get pod <pod-name> -n dev -o jsonpath='{.spec.securityContext}' | python3 -m json.tool
kubectl get pod <pod-name> -n dev -o jsonpath='{.spec.containers[0].securityContext}' | python3 -m json.tool

# Confirm runAsUser in practice
kubectl exec -n dev <pod-name> -- id
# Expected: uid=1001(nodejs) gid=1001(nodejs) groups=1001(nodejs)

# Confirm filesystem is read-only
kubectl exec -n dev <pod-name> -- touch /test-write
# Expected: touch: /test-write: Read-only file system

# Confirm /tmp is writable
kubectl exec -n dev <pod-name> -- touch /tmp/test-write && echo "writable" || echo "not writable"
```

### Verify PSA enforcement

```bash
# Check namespace labels
kubectl get namespace dev --show-labels

# Try to deploy a pod that violates restricted PSS (runs as root)
kubectl run test-root --image=nginx --restart=Never -n dev
# Expected: Error: pods "test-root" is forbidden: violates PodSecurity "restricted:latest"

# Check PSA audit log entries
kubectl get events -n dev | grep PodSecurity
```

### Verify automountServiceAccountToken is false

```bash
# Check ServiceAccount
kubectl get serviceaccount user-service -n dev -o yaml | grep automount

# Confirm no token file in pod
kubectl exec -n dev <pod-name> -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# Expected: ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory
```

### Run Trivy locally

```bash
# Scan a local image
trivy image acrazureshopdev.azurecr.io/user-service:latest

# With SARIF output
trivy image \
  --format sarif \
  --output trivy-user-service.sarif \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  acrazureshopdev.azurecr.io/user-service:latest

# Using .trivyignore
trivy image \
  --ignorefile .trivyignore \
  --severity HIGH,CRITICAL \
  acrazureshopdev.azurecr.io/user-service:latest
```

### Validate Helm templates render correctly

```bash
# Render and check security context
helm template user-service helm/charts/user-service | \
  grep -A 20 "securityContext"

# Check volumes are present
helm template user-service helm/charts/user-service | \
  grep -A 5 "volumes:"
```

---

## 18. Full Step-by-Step Summary

### Step 8.1 — Pod Security Context Hardening

**What we did:**
- Confirmed the UID/GID for every service by reading each Dockerfile before making any changes
- Added `podSecurityContext` and `containerSecurityContext` blocks to all 8 `values.yaml` files
  - 7 services: `runAsUser: 1001`, `runAsGroup: 1001` (the `nodejs` / `appuser` created in each Dockerfile)
  - api-gateway: `runAsUser: 101`, `runAsGroup: 101` (nginx user in `nginx-unprivileged` image)
- Updated all 8 deployment templates to use `{{ toYaml .Values.podSecurityContext }}` and `{{ toYaml .Values.containerSecurityContext }}` — removing hardcoded values
- Added `/tmp` emptyDir volume + volumeMount to all 8 templates
- Added `/var/log/nginx` emptyDir to api-gateway (nginx writes log files there)
- Added Pod Security Admission labels to `k8s/namespaces/dev.yaml` — `enforce: restricted`, `audit: restricted`, `warn: restricted`

**Files changed:** 17 files (8 values.yaml, 8 deployment.yaml, 1 namespace YAML)

**Key decision:** Verify UIDs from Dockerfiles FIRST. Setting `runAsUser: 1001` on an image that was built with a different UID would cause permission errors at runtime.

### Step 8.2 — RBAC: automountServiceAccountToken

**What we did:**
- Added `automountServiceAccountToken: false` to all 8 ServiceAccount templates

**Files changed:** 8 serviceaccount.yaml files

**Key insight:** The CSI driver uses the AKS node managed identity to read from Key Vault — not the pod's ServiceAccount token. Workload Identity uses a projected token (different path, different mechanism) — not the auto-mounted ServiceAccount token. So disabling auto-mount has zero impact on how secrets or Azure access works, but removes an unnecessary attack surface from every pod.

### Step 8.3 — Trivy Enhancements

**What we did:**
- Split the Trivy step in `pipelines/templates/build-template.yaml` into three steps:
  - Step 4a: SARIF report (non-blocking, `--exit-code 0`) → produces `.sarif` file for Azure DevOps Security tab
  - Step 4b: Blocking gate (blocking, `--exit-code 1`, `--ignore-unfixed`) → only fails on fixable HIGH/CRITICAL CVEs
  - Step 4c: Publish SARIF as pipeline artifact (`condition: always()`)
- Added `--ignore-unfixed` to the blocking gate — reduces noise from CVEs with no available fix
- Created `.trivyignore` at repo root with mandatory comment and review-date policy for any future acknowledged exceptions

**Files changed:** 2 files (`build-template.yaml`, `.trivyignore`)

**Key insight:** `--ignore-unfixed` is not "ignore all vulnerabilities" — it is "only block on vulnerabilities where you can actually do something (upgrade a dependency)". The unfixed CVEs still appear in the SARIF report.

---

## 19. Interview Questions and Answers

**Q1: What are the three Pod Security Standards in Kubernetes and what does each allow?**

The three Pod Security Standards are Privileged, Baseline, and Restricted. Privileged has no restrictions — pods can run as root, mount host paths, use any Linux capability. This is only appropriate for system components like CNI plugins. Baseline prevents the most dangerous escalations — it blocks hostPID, hostIPC, hostNetwork sharing, dangerous volume types like hostPath, and the most dangerous capabilities like SYS_ADMIN, but it still allows pods to run as root with a writable filesystem. Restricted is the most secure — it requires runAsNonRoot, allowPrivilegeEscalation: false, capabilities: drop ALL, and a seccomp profile. This is what we enforce on the dev namespace.

---

**Q2: What is Pod Security Admission and how is it different from PodSecurityPolicy?**

Pod Security Admission (PSA) is the built-in Kubernetes admission controller that enforces Pod Security Standards at the namespace level. You add labels to a namespace specifying which standard to enforce, and the API server rejects any pod that does not comply at creation time. PodSecurityPolicy (PSP) was the old mechanism — it was a cluster-wide resource that defined allowed pod configurations, and you had to bind them to ServiceAccounts via RBAC. PSP was powerful but complex and error-prone: misconfigured bindings often accidentally allowed too much or blocked legitimate workloads. PSP was deprecated in Kubernetes 1.21 and removed in 1.25. PSA replaced it with a simpler model: three well-defined levels applied per-namespace with three modes (enforce, audit, warn).

---

**Q3: What does readOnlyRootFilesystem: true protect against and what do you need to make it work?**

`readOnlyRootFilesystem: true` mounts the container's root filesystem as read-only. If an attacker exploits a vulnerability in your application code, they cannot write files to the container — they cannot install tools, write backdoor scripts, or modify application files. The protection is not complete (they can still use the process's existing capabilities), but it significantly limits what a compromised container can do. To make it work, you need to mount writable `emptyDir` volumes for any directory the container writes to at runtime. For our Node.js services that is `/tmp`. For NGINX that is `/tmp` (for the pid file and cache) and `/var/log/nginx` (for access and error logs). An emptyDir volume is an empty temporary directory created for each pod and deleted when the pod stops — so any attacker writes are cleared on pod restart.

---

**Q4: Why do we set both runAsNonRoot: true and runAsUser: 1001? Isn't one enough?**

They serve different purposes. `runAsUser: 1001` actively sets the UID to 1001 at runtime — the process starts as UID 1001 regardless of what the Dockerfile says. `runAsNonRoot: true` is a validation check — it tells Kubernetes to reject the pod if UID 0 would be used. If you only have `runAsUser: 1001`, a typo (e.g. `runAsUser: 0`) would silently run the container as root. If you only have `runAsNonRoot: true`, a Dockerfile that sets `USER root` is caught, but you have no control over exactly which non-root UID is used. Together they are belt-and-suspenders: `runAsUser` actively enforces the UID and `runAsNonRoot` validates it as a safety net.

---

**Q5: What is a Linux capability and why do we drop ALL capabilities?**

Linux capabilities are fine-grained permissions that split root's power into discrete units. Instead of "run as root to bind port 80", you can grant only `NET_BIND_SERVICE`. Common default capabilities in containers include NET_RAW (send raw packets — useful for network attacks), SYS_CHROOT (change root directory — a container escape technique), and SETUID (change user ID — privilege escalation). By dropping ALL capabilities we remove every one of these. Our services run on ports above 1024, so they do not need `NET_BIND_SERVICE`. They do not make raw network connections, change root directories, or modify user IDs — so dropping ALL has no functional impact but removes significant attack surface. If a service genuinely needs a capability, you add it back explicitly with `capabilities.add`.

---

**Q6: What is seccomp and what does RuntimeDefault do?**

Seccomp (Secure Computing Mode) is a Linux kernel feature that creates a whitelist or blacklist of system calls a process is allowed to make. Without seccomp, a container process can make any of the ~400 Linux syscalls. Many of these are dangerous in a container context — `ptrace` allows attaching to other processes, `mount` can mount filesystems, `kexec_load` can load a new kernel, `unshare` can create new namespaces (used in container escape techniques). `RuntimeDefault` uses the container runtime's built-in default profile. For containerd on AKS, this blocks approximately 300 syscalls while leaving the ~100 needed for normal application operation. It is a pod-level setting because seccomp applies to the entire pod sandbox including all containers.

---

**Q7: Why did we set automountServiceAccountToken: false? Does this break Key Vault secret injection?**

`automountServiceAccountToken: false` prevents Kubernetes from mounting a JWT token into the pod that would allow it to authenticate to the Kubernetes API server. We set this because none of our application pods need to call the Kubernetes API — they serve HTTP requests and access Azure PaaS services. Leaving the token mounted is unnecessary attack surface: if an attacker exploits the Node.js code, they could read the token from `/var/run/secrets/kubernetes.io/serviceaccount/token` and use it to enumerate cluster resources. This does not break Key Vault secret injection because the CSI driver uses the AKS node's managed identity (the kubelet identity) to authenticate to Key Vault — not the pod's ServiceAccount token. It also does not break Workload Identity because that uses a projected token volume mounted at a different path by the Workload Identity webhook — a completely separate mechanism from the auto-mounted ServiceAccount token.

---

**Q8: What is the difference between --ignore-unfixed in Trivy and a .trivyignore entry? When do you use each?**

`--ignore-unfixed` is a global flag that filters out all CVEs where no patched version of the affected package exists. It is the right choice for the pipeline blocking gate — there is no point blocking deployment on a vulnerability that has no fix. It reduces noise without hiding actionable issues. A `.trivyignore` entry is a specific exception for a particular CVE ID where a fix exists but you have consciously decided not to apply it — for example if upgrading would break a critical dependency, or if you have assessed that the vulnerable code path is not reachable in your configuration. `.trivyignore` entries are named exceptions with documented justification, while `--ignore-unfixed` is a blanket filter. Both are valid tools but serve different purposes: `--ignore-unfixed` reduces operational noise; `.trivyignore` handles known, accepted, and reviewed exceptions.

---

**Q9: What is SARIF and why do we publish it from the pipeline?**

SARIF (Static Analysis Results Interchange Format) is an open JSON standard for security and code analysis results. Azure DevOps can parse SARIF files and display them in the Security tab of a pipeline run, showing all CVEs found with severity, affected package, installed version, fixed version, and links to CVE details. We publish the SARIF report from Trivy for two reasons. First, visibility — even when the blocking gate passes (no unfixed HIGH/CRITICAL CVEs), the SARIF report shows all findings including MEDIUM and LOW and unfixed CVEs, so security teams can track the full picture. Second, diagnosis — when the gate fails, the SARIF report shows exactly which CVE caused the failure without having to re-run the scan. We publish it with `condition: always()` so it is available even when the pipeline fails.

---

**Q10: How does the Pod Security Admission enforcement mode interact with existing running pods?**

PSA only evaluates pods at creation time — it is an admission controller, which means it only runs when a new pod is submitted to the API server. Applying the `enforce: restricted` label to a namespace does not immediately evict or terminate existing pods that were already running. However, when those pods are restarted (rolling update, node drain, crash restart), the new pod spec goes through PSA and will be rejected if it does not comply. This means: after adding PSA labels, existing pods continue running, but a `helm upgrade` or pod restart will fail if the templates are not compliant. In our case, we updated all 8 Helm charts to satisfy `restricted` in the same PR as the namespace label change, so the next deployment would succeed. This is why you always update the pod specs before applying the PSA label in a running cluster — otherwise deployments break unexpectedly.

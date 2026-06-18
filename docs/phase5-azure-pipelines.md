# Phase 5 — Azure Pipelines CI/CD
> AzureShop DevOps Project | Learning Reference & Interview Prep Guide

---

## What This Phase Covers

In this phase we built a fully automated CI/CD system using Azure Pipelines. Every time a developer pushes code, pipelines automatically test it, build a Docker image, scan for vulnerabilities, push to ACR, and deploy to AKS — with no manual steps needed.

---

## Table of Contents

1. [What is CI/CD?](#1-what-is-cicd)
2. [Azure Pipelines Fundamentals](#2-azure-pipelines-fundamentals)
3. [Key YAML Concepts](#3-key-yaml-concepts)
4. [Variable Groups](#4-variable-groups)
5. [Environments and Approval Gates](#5-environments-and-approval-gates)
6. [Service Connections](#6-service-connections)
7. [Reusable Templates](#7-reusable-templates)
8. [CI Pipelines](#8-ci-pipelines)
9. [CD Pipelines](#9-cd-pipelines)
10. [Terraform Pipelines](#10-terraform-pipelines)
11. [The Full Pipeline Chain](#11-the-full-pipeline-chain)
12. [File and Folder Structure](#12-file-and-folder-structure)
13. [Security in Pipelines](#13-security-in-pipelines)
14. [Commands Reference](#14-commands-reference)
15. [Interview Questions and Answers](#15-interview-questions-and-answers)

---

## 1. What is CI/CD?

### The Problem Without CI/CD

Before CI/CD, a developer's workflow looked like this:

```
Developer writes code
        ↓
Manually runs tests (or forgets to)
        ↓
Manually builds Docker image
        ↓
Manually pushes to registry
        ↓
Manually SSHs into server and deploys
        ↓
Hopes nothing broke in production
```

This is slow, error-prone, and doesn't scale. Different developers deploy differently. Tests get skipped under deadline pressure. A bad deploy breaks production.

### CI — Continuous Integration

CI means every code change is automatically integrated and verified. The moment you push code:

```
Code pushed to repository
        ↓
Pipeline automatically runs:
  → Pulls the code
  → Installs dependencies
  → Runs all tests
  → Builds Docker image
  → Scans for vulnerabilities
  → Pushes image to registry
```

**The golden rule of CI:** the pipeline either passes completely or fails fast. A failing test stops everything — the broken image never reaches the registry.

### CD — Continuous Delivery / Continuous Deployment

CD means verified code is automatically delivered to environments:

```
CI passes (image in registry)
        ↓
Deploy to dev automatically
        ↓
Deploy to staging automatically
        ↓
Deploy to prod (after human approval)
```

**Continuous Delivery** = deployment to prod requires a human to press a button.
**Continuous Deployment** = deployment to prod is fully automatic (no human gate).

Most companies use Continuous Delivery — automated up to staging, human approval for prod.

### Why CI/CD Matters

| Without CI/CD | With CI/CD |
|---|---|
| Deploys take hours (manual steps) | Deploys take minutes (automated) |
| "Works on my machine" problems | Same environment every time |
| Tests skipped under pressure | Tests always run, cannot be skipped |
| Unknown what is deployed where | Every environment has a tracked version |
| Rollback = manual nightmare | Rollback = re-run pipeline with old tag |
| Security scan forgotten | Trivy runs on every single build |

---

## 2. Azure Pipelines Fundamentals

### What is Azure Pipelines?

Azure Pipelines is Microsoft's CI/CD service inside Azure DevOps. You write pipeline instructions in YAML files stored in your repository. Azure Pipelines reads these files and runs the instructions on a cloud machine called an **agent**.

```
You write YAML file → commit to repo → Azure Pipelines reads it → runs on agent
```

### Pipeline Hierarchy

```
Pipeline
└── Stage (logical grouping, e.g. "Build", "Deploy to Dev")
    └── Job (runs on one agent machine)
        └── Step (individual task or script command)
```

**Pipeline** — the entire automation workflow
**Stage** — a major phase (build, test, deploy). Stages run sequentially by default.
**Job** — a set of steps that run on the same agent. Multiple jobs in a stage run in parallel by default.
**Step** — a single action: run a script, execute a task, checkout code.

### Types of Steps

```yaml
steps:
  # Script step — run any shell command
  - script: echo "Hello from pipeline"
    displayName: 'My script step'

  # Task step — pre-built action from Azure DevOps marketplace
  - task: Docker@2
    displayName: 'Build Docker image'
    inputs:
      command: build
      ...

  # Template step — include steps from another YAML file
  - template: ../templates/build-template.yaml
    parameters:
      serviceName: user-service
```

### Agent — The Machine That Runs Your Pipeline

An agent is a virtual machine (cloud-hosted or self-hosted) that executes your pipeline steps.

```yaml
pool:
  vmImage: ubuntu-latest   # Microsoft-hosted Ubuntu agent (free)
```

Microsoft provides free hosted agents:
- `ubuntu-latest` — Ubuntu Linux (most common)
- `windows-latest` — Windows Server
- `macos-latest` — macOS

Each pipeline run gets a fresh agent — a clean machine with nothing on it. This ensures every run starts from a known state. The agent is destroyed after the run.

### Triggers — What Starts a Pipeline

```yaml
# Trigger on push to specific branches
trigger:
  branches:
    include:
      - dev
      - feature/*
  paths:
    include:
      - services/user-service/**   # only trigger if this folder changed

# Trigger on Pull Request
pr:
  branches:
    include:
      - dev

# Never trigger automatically (only manually or via pipeline completion)
trigger: none
```

**Path-based triggers** are critical in a monorepo. Without them, pushing a change to `user-service` would trigger all 8 CI pipelines. With path triggers, only the `user-service-ci` pipeline runs.

---

## 3. Key YAML Concepts

### Variables

```yaml
variables:
  # Inline variable — plain text, visible in logs
  - name: SERVICE_NAME
    value: user-service

  # Reference a Variable Group — a shared set of variables
  - group: vg-common

  # Use a variable in a step
steps:
  - script: echo "Deploying $(SERVICE_NAME)"
```

Variables are referenced with `$(VARIABLE_NAME)` syntax.

### Conditions

```yaml
stages:
  - stage: ApplyStaging
    dependsOn: ApplyDev          # only run after ApplyDev stage
    condition: succeeded()        # only run if ApplyDev succeeded

  # Other conditions:
  # condition: failed()           — only run if previous stage failed
  # condition: always()           — always run, even if previous failed
```

### Parameters in Templates

Parameters are like function arguments for templates. The template declares what it needs; the caller provides the values.

```yaml
# In the template file:
parameters:
  - name: serviceName
    type: string
  - name: runTests
    type: boolean
    default: true

# In the calling pipeline:
- template: ../templates/build-template.yaml
  parameters:
    serviceName: user-service
    runTests: true
```

### Pipeline Completion Trigger (CD trigger)

```yaml
# In deploy-dev.yaml:
trigger: none   # not triggered by code push

resources:
  pipelines:
    - pipeline: user-service-ci    # name of the triggering pipeline
      source: user-service-ci
      trigger:
        branches:
          include:
            - dev
```

This tells Azure Pipelines: "when `user-service-ci` completes successfully on the `dev` branch, trigger me." This is how CI connects to CD — without any code push needed.

### Build.BuildId — The Unique Identifier

Every pipeline run gets a unique number called `Build.BuildId`. This is used as the Docker image tag.

```
Run #1 → Build.BuildId = 101 → image tagged :101
Run #2 → Build.BuildId = 102 → image tagged :102
```

```yaml
imageTag: $(Build.BuildId)
```

This means every image pushed to ACR has a unique, traceable tag that links directly back to the pipeline run that built it. You can always find exactly which commit produced which image.

---

## 4. Variable Groups

### What Are Variable Groups?

Variable Groups are a shared store of variables in Azure DevOps Library. Instead of defining the same values in every pipeline YAML file, you define them once and reference them in many pipelines.

```
Without Variable Groups:
  user-service-ci.yaml    → ACR_NAME=acrazureshopdev
  product-service-ci.yaml → ACR_NAME=acrazureshopdev
  cart-service-ci.yaml    → ACR_NAME=acrazureshopdev
  ... (8 files, same value)
  Change ACR name → edit 8 files

With Variable Groups:
  vg-common → ACR_NAME=acrazureshopdev
  All 8 pipelines reference vg-common
  Change ACR name → edit 1 place → all 8 pipelines updated
```

### Variable Groups Created in This Project

| Group | Variables | Purpose |
|---|---|---|
| `vg-common` | ACR_NAME, ACR_LOGIN_SERVER, RESOURCE_GROUP, AKS_NAME, PROJECT_NAME | Shared by all pipelines |
| `vg-dev` | ENVIRONMENT, K8S_NAMESPACE, REPLICAS, IMAGE_TAG_PREFIX | Dev-specific values |
| `vg-staging` | ENVIRONMENT, K8S_NAMESPACE, REPLICAS, IMAGE_TAG_PREFIX | Staging-specific values |
| `vg-prod` | ENVIRONMENT, K8S_NAMESPACE, REPLICAS, IMAGE_TAG_PREFIX | Prod-specific values |

### Secret Variables

Some variables must never be visible — passwords, API keys, connection strings. Azure Pipelines supports secret variables that are masked in all pipeline logs.

```yaml
# In the pipeline, reference it like any variable:
env:
  TF_VAR_sql_admin_password: $(TF_VAR_SQL_ADMIN_PASSWORD)

# In the log, if it accidentally prints, it shows as:
# TF_VAR_sql_admin_password: ***
```

Secret variables are stored encrypted. Even pipeline maintainers cannot read the value after it is saved — only the pipeline runtime can use it.

We created `TF_VAR_SQL_ADMIN_PASSWORD` as a secret in `vg-common` for the Terraform apply pipeline.

---

## 5. Environments and Approval Gates

### What Are Environments?

In Azure Pipelines, an **Environment** is a named deployment target (dev, staging, prod). Environments:
- Track deployment history (who deployed what, when, pass/fail)
- Can have approval gates (human must approve before deployment runs)
- Show which version is currently running in each environment

### Environments Created

| Environment | Approval | Purpose |
|---|---|---|
| `dev` | None — auto deploys | Developers test their changes here |
| `staging` | None — auto deploys | Production-like environment for final validation |
| `prod` | Manual approval required | Live production — human must review before deploy |

### How Approval Gates Work

```yaml
# In deploy-prod.yaml:
jobs:
  - deployment: DeployAllServices
    environment: prod    # ← this line is what enforces the gate
```

When this job runs:
1. Pipeline reaches the `deployment` job
2. Azure DevOps checks — does `prod` environment have an approval gate?
3. YES → pipeline **pauses** and sends an email/notification to approvers
4. Approver logs in, reviews staging, clicks **Approve** in Azure DevOps UI
5. Pipeline resumes and deploys to prod

If the approver clicks **Reject** — the pipeline is cancelled. Prod is never touched.

**The key insight:** the approval gate is configured on the Environment in Azure DevOps UI, not in the YAML file. The YAML just references the environment name. This means you can add/remove approvers without changing any code.

### Deployment Job vs Regular Job

```yaml
# Regular job — for building, testing
jobs:
  - job: Build
    steps:
      - script: npm test

# Deployment job — for deploying to environments
jobs:
  - deployment: DeployToAKS
    environment: dev          # links to Azure DevOps environment
    strategy:
      runOnce:
        deploy:
          steps:
            - script: helm upgrade ...
```

A `deployment` job:
- Requires an `environment` to be specified
- Records deployment in Azure DevOps deployment history
- Supports deployment strategies (runOnce, rolling, canary)
- Shows up in the "Environments" view in Azure DevOps

A regular `job` does not record deployment history and cannot use environment approval gates.

---

## 6. Service Connections

### What is a Service Connection?

A Service Connection is a stored, secure link between Azure Pipelines and an external service (Azure subscription, Docker Hub, GitHub, etc.). It stores credentials so pipelines can authenticate without hardcoding secrets.

### The sc-azureshop-azure Service Connection

We created one Service Connection: `sc-azureshop-azure`

- **Type:** Azure Resource Manager
- **Auth method:** Service Principal (automatic — Azure DevOps creates it)
- **Scope:** Full subscription access

When Azure DevOps created this connection, it automatically:
1. Created a Service Principal in Azure AD
2. Assigned it `Contributor` role on your subscription
3. Stored the client ID, secret, and tenant ID securely

### How Pipelines Use It

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure   # ← references the service connection
    scriptType: bash
    inlineScript: |
      az acr login --name $(ACR_NAME)       # authenticated automatically
      az aks get-credentials ...            # no login command needed
```

The pipeline never sees the actual credentials. Azure DevOps injects an authenticated session. This is the same Managed Identity concept — no passwords in code, no passwords in logs.

---

## 7. Reusable Templates

### Why Templates Exist

Without templates, every CI pipeline would copy-paste the same 60 lines of build steps. 8 services × 60 lines = 480 lines of duplicated code. Update Trivy's version → edit 8 files.

With templates, shared steps live in one file. All pipelines reference it. Change once — all 8 update instantly. This is the **DRY principle** (Don't Repeat Yourself) applied to pipelines.

### build-template.yaml

Location: `pipelines/templates/build-template.yaml`

Called by every service CI pipeline. Receives the service name and path as parameters.

```
Step 1: Install dependencies and run tests
        Node.js → npm ci && npm test
        Python  → pip install && pytest
        NGINX   → skipped (runTests: false)

Step 2: Login to ACR
        az acr login --name $(ACR_NAME)
        Gets a short-lived token — no password stored

Step 3: Docker build
        docker build -t $(ACR_LOGIN_SERVER)/user-service:$(Build.BuildId)
        Tags with both build ID (immutable) and latest (convenience)

Step 4: Trivy security scan
        --exit-code 1 means pipeline FAILS if HIGH/CRITICAL CVEs found
        Image is never pushed if this fails

Step 5: Push to ACR
        Only reached if ALL previous steps passed
        Pushes both :$(Build.BuildId) and :latest tags
```

### deploy-template.yaml

Location: `pipelines/templates/deploy-template.yaml`

Called by every CD pipeline for each service. Handles the actual Kubernetes deployment.

```
Step 1: Connect kubectl to AKS
        az aks get-credentials → downloads kubeconfig
        kubectl can now talk to the cluster

Step 2: Create namespace (if not exists)
        kubectl create namespace dev --dry-run | kubectl apply
        Idempotent — safe to run multiple times

Step 3: Helm upgrade/install
        helm upgrade --install user-service ./helm/charts/user-service
        --install means: create if new, upgrade if exists
        Passes image tag and replica count as overrides

Step 4: Verify rollout
        kubectl rollout status deployment/user-service --timeout=5m
        Pipeline fails if pods don't become ready within 5 minutes

Step 5: Smoke test
        Hits /health endpoint inside the cluster
        Confirms the newly deployed service is responding
```

---

## 8. CI Pipelines

### One Pipeline Per Service

Each service has its own CI pipeline file. They are identical in structure — only the service name and path differ.

```yaml
# user-service-ci.yaml structure:

trigger:
  branches:
    include: [dev, feature/*]
  paths:
    include: [services/user-service/**]   # ONLY trigger for this service

pr:
  branches:
    include: [dev]
  paths:
    include: [services/user-service/**]

pool:
  vmImage: ubuntu-latest

variables:
  - group: vg-common
  - name: SERVICE_NAME
    value: user-service
  - name: DOCKERFILE_PATH
    value: services/user-service

stages:
  - stage: CI
    jobs:
      - job: BuildAndPush
        steps:
          - template: ../templates/build-template.yaml
            parameters:
              serviceName: $(SERVICE_NAME)
              dockerfilePath: $(DOCKERFILE_PATH)
              imageTag: $(Build.BuildId)
```

### Why Path-Based Triggers Matter

```
Without path triggers:
  Developer fixes a bug in user-service
  ALL 8 CI pipelines trigger
  8 Docker builds, 8 Trivy scans, 8 ACR pushes
  Wastes 20 minutes and pipeline credits

With path triggers:
  Developer fixes a bug in user-service
  Only user-service-ci triggers
  1 Docker build, 1 Trivy scan, 1 ACR push
  Takes 3 minutes
```

### CI Pipelines in This Project

| Pipeline | Service | Tests |
|---|---|---|
| `user-service-ci` | Node.js / Express | npm test |
| `product-service-ci` | Python / FastAPI | pytest |
| `cart-service-ci` | Node.js / Express | npm test |
| `order-service-ci` | Node.js / Express | npm test |
| `payment-service-ci` | Node.js / Express | npm test |
| `notification-service-ci` | Node.js / Express | npm test |
| `frontend-ci` | Next.js | skipped |
| `api-gateway-ci` | NGINX | skipped |
| `terraform-validate` | Terraform IaC | fmt + validate + plan |

---

## 9. CD Pipelines

### deploy-dev.yaml

**Trigger:** Any CI pipeline completes successfully on `dev` branch
**Action:** Deploy all 8 services to `dev` namespace in AKS
**Approval:** None — auto deploys

```yaml
trigger: none

resources:
  pipelines:
    - pipeline: user-service-ci
      source: user-service-ci
      trigger:
        branches:
          include: [dev]
    # ... same for all 8 CI pipelines

jobs:
  - deployment: DeployAllServices
    environment: dev    # no approval gate on dev
```

### deploy-staging.yaml

**Trigger:** `deploy-dev` completes successfully
**Action:** Deploy all 8 services to `staging` namespace
**Approval:** None — auto deploys after dev

```yaml
resources:
  pipelines:
    - pipeline: deploy-dev
      source: deploy-dev
      trigger:
        branches:
          include: [dev]

variables:
  - name: IMAGE_TAG
    value: $(resources.pipeline.deploy-dev.runID)   # same build ID as dev
```

**Key concept:** `$(resources.pipeline.deploy-dev.runID)` gets the Build.BuildId from the dev deployment that triggered this pipeline. This ensures staging uses the **exact same image** that was validated in dev — not a newly rebuilt one. Same bits, different environment.

### deploy-prod.yaml

**Trigger:** `deploy-staging` completes successfully
**Action:** Deploy all 8 services to `prod` namespace
**Approval:** **Manual — human must approve in Azure DevOps UI**

```yaml
jobs:
  - deployment: DeployAllServices
    environment: prod       # ← approval gate enforced here
    timeoutInMinutes: 120   # cancel if not approved within 2 hours
```

After deploying to prod, all images are additionally tagged `:stable` in ACR:
```bash
docker tag acrazureshopdev.azurecr.io/user-service:101 \
           acrazureshopdev.azurecr.io/user-service:stable
```

`:stable` always points to the last known-good production image — useful for rollbacks.

### Image Promotion — The Same Image Travels Through All Environments

```
CI builds image → tagged :101 → pushed to ACR

dev    deploys :101
staging deploys :101   (same image, not rebuilt)
prod   deploys :101    (same image, not rebuilt)
```

This is called **image promotion**. You never rebuild an image per environment. You build once, test once, promote through environments. This guarantees what you tested in dev is exactly what runs in prod.

---

## 10. Terraform Pipelines

### terraform-validate.yaml (CI)

**Trigger:** PR to dev or feature/* that touches `infra/**`
**Purpose:** Catch infrastructure mistakes before they are merged
**Does NOT apply any changes**

```
Step 1: terraform init    → connects to remote state in Azure Blob
Step 2: terraform fmt     → checks code formatting (fails if not formatted)
Step 3: terraform validate → checks syntax and logic
Step 4: terraform plan    → shows what would change, posts output to PR
```

The plan output is uploaded as a pipeline summary — visible directly in the PR. Reviewers can see exactly what infrastructure will change before approving the merge.

### terraform-apply.yaml (CD)

**Trigger:** Merge to `main` branch touching `infra/**`
**Purpose:** Apply infrastructure changes to all environments
**Requires approval before staging and prod**

```
Stage 1: ApplyDev      → terraform apply to dev (auto, no approval)
Stage 2: ApplyStaging  → terraform apply to staging (manual approval)
Stage 3: ApplyProd     → terraform apply to prod (manual approval)
```

```yaml
stages:
  - stage: ApplyStaging
    dependsOn: ApplyDev          # only runs if dev apply succeeded
    condition: succeeded()        # cancelled if dev failed
```

### Why Trigger on main (not dev)?

Infrastructure changes are **higher risk** than application code changes:
- Deleting a database cannot be undone
- Changing a network CIDR can take down services
- Wrong firewall rule can expose databases to the internet

`main` branch = code that has been reviewed, approved via PR, and is production-ready. We never apply unreviewed infrastructure changes to any environment.

### Plan Before Apply — Always

```yaml
# Step 1: Plan and save the plan
terraform plan -out=tfplan-dev

# Step 2: Apply the saved plan
terraform apply -auto-approve tfplan-dev
```

Applying from a saved plan file means Terraform applies **exactly** what was planned — nothing more, nothing less. Between plan and apply, no configuration can change. This is the production-safe pattern.

---

## 11. The Full Pipeline Chain

### For a Service Code Change

```
Developer pushes fix to services/user-service/
               ↓
[user-service-ci] triggers (path filter matches)
  Step 1: npm ci && npm test
  Step 2: az acr login
  Step 3: docker build → :102
  Step 4: trivy scan → PASS
  Step 5: docker push :102 to ACR
               ↓ (CI pipeline completed successfully on dev)
[deploy-dev] triggers automatically
  Connects to AKS
  helm upgrade user-service → image :102
  kubectl rollout status → pods ready
  smoke test → /health returns 200
               ↓ (dev deployment succeeded)
[deploy-staging] triggers automatically
  Same steps, IMAGE_TAG = 102 (same as dev)
  Deploys to staging namespace
               ↓ (staging deployment succeeded)
[deploy-prod] queued → PAUSES ⏸
  Email sent to approver
  Approver reviews staging, clicks Approve
  Deploys to prod namespace
  Tags :102 as :stable in ACR
```

### For an Infrastructure Change

```
Developer changes infra/modules/databases/main.tf
               ↓
[terraform-validate] triggers on PR
  terraform fmt check → PASS
  terraform validate → PASS
  terraform plan → output posted to PR as comment
  Reviewer reads plan, approves PR
               ↓ (PR merged to main)
[terraform-apply] triggers
  Stage 1: terraform apply → dev
  Stage 2: PAUSES → approver approves → terraform apply → staging
  Stage 3: PAUSES → approver approves → terraform apply → prod
```

---

## 12. File and Folder Structure

```
pipelines/
│
├── templates/                          # Reusable building blocks
│   ├── build-template.yaml             # Test → Build → Trivy → Push
│   └── deploy-template.yaml            # AKS connect → Helm deploy → Verify
│
├── ci/                                 # Continuous Integration pipelines
│   ├── user-service-ci.yaml            # Triggers on services/user-service/**
│   ├── product-service-ci.yaml         # Triggers on services/product-service/**
│   ├── cart-service-ci.yaml            # Triggers on services/cart-service/**
│   ├── order-service-ci.yaml           # Triggers on services/order-service/**
│   ├── payment-service-ci.yaml         # Triggers on services/payment-service/**
│   ├── notification-service-ci.yaml    # Triggers on services/notification-service/**
│   ├── frontend-ci.yaml                # Triggers on services/frontend/**
│   ├── api-gateway-ci.yaml             # Triggers on services/api-gateway/**
│   └── terraform-validate.yaml         # Triggers on infra/** — fmt+validate+plan
│
└── cd/                                 # Continuous Delivery pipelines
    ├── deploy-dev.yaml                 # Deploys all services to dev namespace
    ├── deploy-staging.yaml             # Deploys all services to staging namespace
    ├── deploy-prod.yaml                # Deploys all services to prod (manual approval)
    └── terraform-apply.yaml            # Applies Terraform to dev→staging→prod
```

### How Files Reference Each Other

```
user-service-ci.yaml
    └── calls → templates/build-template.yaml

deploy-dev.yaml
    ├── triggered by → user-service-ci, product-service-ci, ... (all CI pipelines)
    └── calls → templates/deploy-template.yaml (once per service)

deploy-staging.yaml
    ├── triggered by → deploy-dev.yaml
    └── calls → templates/deploy-template.yaml

deploy-prod.yaml
    ├── triggered by → deploy-staging.yaml
    └── calls → templates/deploy-template.yaml

terraform-apply.yaml
    ├── triggered by → merge to main touching infra/**
    └── runs terraform commands directly (no template needed)
```

---

## 13. Security in Pipelines

### Trivy — Shift-Left Security

Every CI pipeline runs Trivy before pushing to ACR:

```yaml
- script: |
    docker run --rm aquasec/trivy:latest image \
      --exit-code 1 \
      --severity HIGH,CRITICAL \
      $(ACR_LOGIN_SERVER)/user-service:$(Build.BuildId)
```

`--exit-code 1` = if any HIGH or CRITICAL vulnerability is found, the pipeline exits with error code 1. Azure Pipelines treats this as a failure. The push step never runs. The vulnerable image never reaches ACR.

This is **shift-left security** — moving security checks left (earlier) in the pipeline so problems are caught before they reach production.

### No Secrets in YAML Files

Secrets are never written in YAML pipeline files. They are stored in Variable Groups as secret variables and injected at runtime:

```yaml
# WRONG — never do this:
- script: terraform apply -var="sql_password=MyP@ssw0rd"

# CORRECT — secret injected from Variable Group:
- task: AzureCLI@2
  env:
    TF_VAR_sql_admin_password: $(TF_VAR_SQL_ADMIN_PASSWORD)  # ← from vg-common
  inputs:
    inlineScript: terraform apply
```

The secret value is masked in all logs: if it appears, it shows as `***`.

### Service Connection — No Hardcoded Azure Credentials

```yaml
# WRONG — never hardcode credentials:
- script: az login --service-principal -u $CLIENT_ID -p $CLIENT_SECRET

# CORRECT — use service connection:
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure   # credentials stored securely in Azure DevOps
```

The pipeline never sees the Service Principal credentials. Azure DevOps injects an authenticated session at runtime.

### Image Immutability

Every image has a unique, immutable tag (`Build.BuildId`). Once pushed, that tag is never overwritten. This means:

- You can always identify exactly what code is running in production
- Rollback = redeploy with a previous build ID tag
- An attacker cannot replace an image and keep the same tag undetected

---

## 14. Commands Reference

### Azure DevOps CLI

```bash
# Set default org and project (run once per session)
az devops configure --defaults \
  organization=https://dev.azure.com/azureshop-org \
  project=AzureShop

# List all pipelines
az pipelines list --output table

# Register a new pipeline
az pipelines create \
  --name "user-service-ci" \
  --repository AzureShop \
  --branch dev \
  --yaml-path pipelines/ci/user-service-ci.yaml \
  --repository-type tfsgit \
  --skip-first-run true

# Manually run a pipeline
az pipelines run --name user-service-ci

# List variable groups
az pipelines variable-group list --output table

# Create a variable group
az pipelines variable-group create \
  --name "vg-common" \
  --variables ACR_NAME=acrazureshopdev

# Add a secret variable to a group
az pipelines variable-group variable create \
  --group-id 1 \
  --name "MY_SECRET" \
  --value "secret-value" \
  --secret true

# List environments
az devops invoke \
  --area distributedtask \
  --resource environments \
  --route-parameters project=AzureShop

# List service connections
az devops service-endpoint list --output table
```

### Pipeline Triggers (manual)

```bash
# Trigger a specific pipeline manually
az pipelines run --name user-service-ci --branch dev

# Trigger with variable override
az pipelines run --name deploy-dev --variables IMAGE_TAG=105
```

---

## 15. Interview Questions and Answers

### CI/CD Fundamentals

**Q: What is the difference between Continuous Integration, Continuous Delivery, and Continuous Deployment?**

A: Continuous Integration (CI) means every code change is automatically built and tested the moment it is pushed. Continuous Delivery (CD) means the verified build is automatically deployed up to staging, but production deployment requires a human to approve. Continuous Deployment goes one step further — every verified build is automatically deployed to production with no human gate. Most companies use Continuous Delivery for production systems where human oversight is required.

---

**Q: What is a CI/CD pipeline?**

A: A CI/CD pipeline is an automated workflow defined in code (YAML) that runs every time code is changed. It typically includes: checkout code, install dependencies, run tests, build a Docker image, scan for vulnerabilities, push to a registry, and deploy to Kubernetes. The pipeline either passes fully or fails fast — a broken test stops the pipeline before anything reaches production.

---

**Q: What does "fail fast" mean in CI/CD?**

A: Fail fast means the pipeline stops immediately at the first failure and reports the error, rather than continuing to run steps that depend on broken earlier steps. For example, if unit tests fail, there is no point building a Docker image from broken code. Stopping early saves time, pipeline credits, and prevents bad code from reaching further stages.

---

### Azure Pipelines

**Q: What is the difference between a job and a deployment job in Azure Pipelines?**

A: A regular job runs steps on an agent and is used for building and testing. A deployment job is a special job type that requires an environment to be specified. It records deployment history in Azure DevOps showing who deployed what, when, and whether it succeeded. Deployment jobs also support environment approval gates — if the environment has an approver configured, the pipeline pauses until the approver clicks Approve in the Azure DevOps UI.

---

**Q: What is a reusable template in Azure Pipelines and why use it?**

A: A template is a separate YAML file containing steps that can be referenced by multiple pipelines. Instead of copying the same 60 lines of build steps into 8 different CI pipelines, you write them once in a template and each pipeline references it with a single line. If you need to update the Trivy scan version, you change it in one place and all 8 pipelines immediately use the new version. This is the DRY (Don't Repeat Yourself) principle applied to pipeline code.

---

**Q: What are Variable Groups in Azure Pipelines?**

A: Variable Groups are a shared collection of variables stored in Azure DevOps Library. Instead of repeating values like the ACR name in every pipeline YAML file, you define them once in a Variable Group and reference the group from each pipeline. If the ACR name changes, you update it in one Variable Group and all pipelines pick up the change. Variable Groups also support secret variables — values that are encrypted and masked in pipeline logs.

---

**Q: How do you pass secrets to Azure Pipelines without hardcoding them?**

A: You store secrets as secret variables in a Variable Group in Azure DevOps Library. In the pipeline YAML, you reference the variable group and inject the secret as an environment variable at the step level: `env: MY_SECRET: $(MY_SECRET_VAR)`. The value is masked in all logs. The YAML file itself contains no secret values — only the variable name reference.

---

**Q: What is a Service Connection in Azure Pipelines?**

A: A Service Connection is a stored, secure link between Azure Pipelines and an external service such as an Azure subscription. When you create an Azure Resource Manager service connection, Azure DevOps creates a Service Principal in Azure AD, assigns it Contributor access on the subscription, and stores the credentials securely. Pipelines reference the service connection by name — they never see the actual credentials. This means no passwords in YAML files and no risk of credential exposure.

---

**Q: How does a CD pipeline know which image version to deploy?**

A: Through image promotion. The CI pipeline builds an image tagged with `$(Build.BuildId)` — for example `user-service:105`. The deploy-dev pipeline deploys tag `:105`. The deploy-staging pipeline uses `$(resources.pipeline.deploy-dev.runID)` to get the exact build ID from the dev deployment that triggered it, ensuring staging deploys the exact same image as dev. The same tag `:105` travels through dev → staging → prod. The image is never rebuilt per environment.

---

**Q: What is an environment approval gate and how does it work?**

A: An approval gate is configured on an Azure Pipelines Environment (not in YAML). When a deployment job references an environment that has approvers configured, the pipeline automatically pauses before that deployment runs and sends a notification to the approvers. The approver logs in to Azure DevOps, reviews the pending deployment, and clicks Approve or Reject. If approved, the deployment continues. If rejected, the pipeline is cancelled. The production environment never gets deployed to without human oversight.

---

**Q: What is path-based triggering and why is it important in a monorepo?**

A: Path-based triggering means a pipeline only fires when specific files or folders change. In a monorepo with 8 services, without path triggers, every code push would trigger all 8 CI pipelines — rebuilding and scanning images that haven't changed. With path triggers, changing `services/user-service/app.js` only triggers `user-service-ci.yaml`. This saves time, reduces pipeline costs, and avoids deploying unchanged services unnecessarily.

---

**Q: What is the difference between `trigger` and `pr` in Azure Pipelines YAML?**

A: `trigger` defines which branch pushes start the pipeline automatically after a merge. `pr` defines which pull request targets start the pipeline as a validation build before the merge is approved. For CI pipelines, both are set so the pipeline runs on PRs (to validate before merge) and on merges to dev (to build and push the image after merge). CD pipelines use `trigger: none` because they should only start from CI pipeline completion, not from direct pushes.

---

**Q: Why do we use `terraform plan -out=tfplan` followed by `terraform apply tfplan` instead of just `terraform apply`?**

A: Running `terraform plan -out=tfplan` saves the exact set of changes Terraform intends to make into a binary file. Then `terraform apply tfplan` applies exactly those saved changes — nothing more, nothing less. If you run `terraform apply` without a saved plan, Terraform re-plans at apply time, and if any state has changed between your review and the apply, you might apply unexpected changes. The plan-then-apply pattern guarantees what you reviewed is exactly what gets applied.

---

*Phase 5 completed: 2026-05-10*
*Next: Phase 6 — AKS Kubernetes Deployment*

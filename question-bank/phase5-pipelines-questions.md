# Phase 5 — Azure Pipelines CI/CD: Question Bank

All questions asked during revision, with full detailed answers.
Covers: CI vs CD vs Continuous Deployment, pipeline structure, fail fast, jobs vs deployment jobs, reusable templates, Variable Groups, secret variables, Service Connections, image promotion, environment approval gates, path-based triggers, trigger vs pr, terraform plan-then-apply, Continuous Delivery vs Continuous Deployment deep dive, agent types, YAML variables/conditions/parameters, path-based triggers deep dive, secret variables real-world usage, Service Connection full detail, Environments vs Environment Variables, Variable Group storage location and runtime reading mechanism.

---

## Table of Contents

1. [What is the Difference Between CI, CD, and Continuous Deployment?](#q1-what-is-the-difference-between-ci-cd-and-continuous-deployment)
2. [What is a CI/CD Pipeline?](#q2-what-is-a-cicd-pipeline)
3. [What Does "Fail Fast" Mean in CI/CD?](#q3-what-does-fail-fast-mean-in-cicd)
4. [What is the Difference Between a Job and a Deployment Job?](#q4-what-is-the-difference-between-a-job-and-a-deployment-job)
5. [What is a Reusable Template in Azure Pipelines and Why Use It?](#q5-what-is-a-reusable-template-in-azure-pipelines-and-why-use-it)
6. [What Are Variable Groups in Azure Pipelines?](#q6-what-are-variable-groups-in-azure-pipelines)
7. [How Do You Pass Secrets to Azure Pipelines Without Hardcoding Them?](#q7-how-do-you-pass-secrets-to-azure-pipelines-without-hardcoding-them)
8. [What is a Service Connection in Azure Pipelines?](#q8-what-is-a-service-connection-in-azure-pipelines)
9. [How Does a CD Pipeline Know Which Image Version to Deploy?](#q9-how-does-a-cd-pipeline-know-which-image-version-to-deploy)
10. [What is an Environment Approval Gate and How Does It Work?](#q10-what-is-an-environment-approval-gate-and-how-does-it-work)
11. [What is the Difference Between Continuous Delivery and Continuous Deployment?](#q11-what-is-the-difference-between-continuous-delivery-and-continuous-deployment)
12. [What is an Agent in Azure Pipelines and What Are the Different Types?](#q12-what-is-an-agent-in-azure-pipelines-and-what-are-the-different-types)
13. [What Are Variables, Conditions, and Parameters in Azure Pipelines YAML?](#q13-what-are-variables-conditions-and-parameters-in-azure-pipelines-yaml)
14. [What is a Path-Based Trigger and How Does It Work in AzureShop?](#q14-what-is-a-path-based-trigger-and-how-does-it-work-in-azureshop)
15. [What is the Concept of Secret Variables and How Are They Used?](#q15-what-is-the-concept-of-secret-variables-and-how-are-they-used)
16. [What is a Service Connection and How Is It Used in AzureShop Pipelines?](#q16-what-is-a-service-connection-and-how-is-it-used-in-azureshop-pipelines)
17. [What is the Difference Between Environments and Environment Variables?](#q17-what-is-the-difference-between-environments-and-environment-variables)
18. [Where Are Variable Groups Stored, How Are They Created, and How Does a Pipeline Read Them?](#q18-where-are-variable-groups-stored-how-are-they-created-and-how-does-a-pipeline-read-them)

---

## Q1. What is the Difference Between CI, CD, and Continuous Deployment?

### Continuous Integration (CI)

Every code push automatically triggers a build-and-test run. The goal: integrate changes from all developers frequently, detect conflicts and bugs immediately.

```
Developer pushes to feature branch
  → Pipeline starts automatically (trigger: pr)
  → Install dependencies
  → Run unit tests
  → Build Docker image
  → Trivy security scan
  → Push image to ACR (if tests pass)
```

In AzureShop: every service has its own CI pipeline. Path-based triggers ensure changing `services/user-service/` only triggers `user-service-ci.yaml`.

### Continuous Delivery (CD)

The verified build is automatically deployed up to a pre-production environment (staging), but **production deployment requires human approval**.

```
CI pipeline passes → deploy to dev (automatic)
                  → deploy to staging (automatic)
                  → deploy to prod (PAUSED — waiting for human approval)
```

This is what AzureShop uses. Production has a manual approval gate configured on the `prod` environment in Azure DevOps.

### Continuous Deployment

No human gate anywhere. Every green build goes to production automatically. Requires extremely high test coverage and confidence. Used by companies like Netflix and Amazon for internal tooling, but rare for customer-facing systems with compliance requirements.

### Summary Table

| | CI | Continuous Delivery | Continuous Deployment |
|---|---|---|---|
| What's automated | Build + test | Build + test + deploy to staging | Build + test + deploy to prod |
| Human gate | None | Required for prod | None |
| Risk | Low | Medium | High |
| AzureShop | ✅ (8 service pipelines) | ✅ (deploy-dev, deploy-staging, manual prod) | ❌ |

---

## Q2. What is a CI/CD Pipeline?

### Definition

A CI/CD pipeline is an **automated workflow defined in YAML** that runs every time code changes. It replaces the manual steps a developer used to do: pull code, run tests, build image, push to registry, deploy.

### AzureShop Pipeline Chain

```
Code push to feature branch
  ↓
user-service-ci.yaml (triggered by PR or push to dev)
  Step 1: npm ci + npm test
  Step 2: az acr login
  Step 3: docker build
  Step 4a: trivy --exit-code 0 (SARIF report)
  Step 4b: trivy --exit-code 1 (blocking gate)
  Step 4c: publish SARIF artifact
  Step 5: docker push → ACR
  ↓
deploy-dev.yaml (triggered by CI pipeline completion)
  Step 1: az acr login
  Step 2: helm upgrade --install user-service
  ↓
deploy-staging.yaml (triggered by deploy-dev completion)
  Step 1: deploys same image tag as dev
  ↓
deploy-prod.yaml (triggered by deploy-staging, PAUSED for approval)
```

### Key Properties

- **Defined in YAML** — the pipeline is code, version-controlled alongside the application
- **Reproducible** — the same pipeline steps run every time, eliminating "it worked on my laptop"
- **All-or-nothing** — a failure at any step stops the pipeline; nothing broken reaches production
- **Auditable** — Azure DevOps records every run: who triggered it, what passed, what failed, what was deployed

---

## Q3. What Does "Fail Fast" Mean in CI/CD?

### The Concept

Fail fast means: **stop the pipeline immediately at the first failure** and report the error. Do not continue running steps that depend on already-broken earlier steps.

### Why It Matters

```
Without fail fast:
  tests fail → pipeline continues → docker build → trivy scan → push → deploy broken code

With fail fast:
  tests fail → pipeline STOPS → error reported → nothing broken is pushed
```

The pipeline only produces an artefact (Docker image) if ALL previous steps passed.

### Practical Benefits

| Benefit | Explanation |
|---|---|
| Save time | No point spending 5 minutes building a Docker image from failing code |
| Save cost | Azure DevOps charges per pipeline minute — don't waste it on doomed builds |
| Clear signal | Developer sees "tests failed" immediately, not buried 10 steps later |
| Prevent bad artefacts | A broken image never reaches ACR |

### In AzureShop

The ordering in `build-template.yaml` is deliberate:
1. Tests run first (cheap, fast, catches logic errors)
2. Docker build runs next (only if tests pass)
3. Trivy scans the image (only if build succeeds)
4. Push to ACR happens last (only if security gate passes)

A failing unit test stops everything at step 1. A CVE in the image stops everything at step 3. Nothing reaches ACR unless all gates pass.

---

## Q4. What is the Difference Between a Job and a Deployment Job?

### Regular Job

```yaml
jobs:
  - job: Build
    steps:
      - script: npm test
      - script: docker build ...
```

Runs steps on an agent. Used for building, testing, scanning. Records pass/fail but has no concept of environments or deployment history.

### Deployment Job

```yaml
jobs:
  - deployment: DeployDev
    environment: dev           # ← key difference
    strategy:
      runOnce:
        deploy:
          steps:
            - script: helm upgrade ...
```

A deployment job:
1. **Requires an environment** — records a deployment event against it (who deployed, when, from which build)
2. **Supports approval gates** — if the environment has approvers, the pipeline pauses and waits
3. **Records deployment history** — in Azure DevOps you can see "dev was last deployed at 14:23 from build #105"
4. **Supports rollback tracking** — you can see which builds were deployed and redeploy a previous one

### In AzureShop

All CD pipelines (`deploy-dev.yaml`, `deploy-staging.yaml`, `deploy-prod.yaml`) use deployment jobs with their respective environments. The `prod` environment has a manual approval gate. The `dev` and `staging` environments have no gates — deployments proceed automatically.

### Why Not Always Use Deployment Jobs?

CI pipelines (`user-service-ci.yaml`, etc.) use regular jobs because they are building, not deploying. They have no environment to record against. Mixing deployment job semantics into CI pipelines would create false deployment history.

---

## Q5. What is a Reusable Template in Azure Pipelines and Why Use It?

### The Problem

Without templates, every CI pipeline has the same 80 lines of build steps:

```
user-service-ci.yaml:    npm install → docker build → trivy → push
cart-service-ci.yaml:    npm install → docker build → trivy → push
order-service-ci.yaml:   npm install → docker build → trivy → push
... (8 times)
```

Update Trivy to a newer version → edit 8 files → 8 separate PRs → easy to miss one.

### The Solution — Template

```yaml
# pipelines/templates/build-template.yaml
parameters:
  - name: serviceName
    type: string
  - name: dockerfilePath
    type: string

steps:
  - script: npm ci && npm test
  - task: AzureCLI@2   # login to ACR
  - script: docker build ...
  - script: docker run aquasec/trivy ... --exit-code 1  # blocking gate
  - script: docker push ...
```

Each CI pipeline becomes 5 lines:
```yaml
# pipelines/ci/user-service-ci.yaml
steps:
  - template: ../templates/build-template.yaml
    parameters:
      serviceName: user-service
      dockerfilePath: services/user-service
```

### Benefits

| Benefit | Example |
|---|---|
| DRY (Don't Repeat Yourself) | Build logic written once, used 8 times |
| Single change point | Update Trivy version in one template → all 8 CI pipelines update |
| Consistency | All services go through identical security gates — no service can "skip" Trivy |
| Readability | Each CI pipeline file is 5 lines, not 80 |

### AzureShop Templates

- `pipelines/templates/build-template.yaml` — install, test, docker build, trivy scan (SARIF + blocking), docker push
- `pipelines/templates/deploy-template.yaml` — az acr login, helm upgrade --install

The `serviceName` parameter drives everything: image name, chart path, and display names in logs.

---

## Q6. What Are Variable Groups in Azure Pipelines?

### What They Are

Variable Groups are **shared collections of name-value pairs** stored in Azure DevOps Library. Pipelines reference a group by name and all variables in the group become available.

### The Problem Without Them

```yaml
# Without variable groups — repeated in every pipeline:
variables:
  ACR_NAME: acrazureshopdev
  ACR_LOGIN_SERVER: acrazureshopdev.azurecr.io
  AKS_CLUSTER: aks-azureshop-dev
  RESOURCE_GROUP: rg-azureshop-dev
```

8 CI pipelines + 4 CD pipelines = 12 files with the same values. Change the ACR name → edit 12 files.

### The Solution

```yaml
# In every pipeline:
variables:
  - group: vg-common   # ACR_NAME, ACR_LOGIN_SERVER
  - group: vg-dev      # AKS_CLUSTER, NAMESPACE, RESOURCE_GROUP
```

Variable groups in AzureShop:
- `vg-common` (ID: 1) — values shared across all environments: `ACR_NAME`, `ACR_LOGIN_SERVER`
- `vg-dev` (ID: 2) — dev-specific: `AKS_CLUSTER`, `NAMESPACE`, `RESOURCE_GROUP`
- `vg-staging` (ID: 3) — staging-specific overrides
- `vg-prod` (ID: 4) — prod-specific overrides

### Secret Variables

Variables marked as **Secret** in Azure DevOps Library are:
- Encrypted at rest
- Masked in all pipeline logs (replaced with `***`)
- Not accessible to forks (for open-source pipelines)
- Only injectable as environment variables into specific steps (cannot be echoed directly)

The pipeline YAML contains no secret values — only the variable name reference. The actual value lives in Azure DevOps Library, accessible only to authorised projects.

---

## Q7. How Do You Pass Secrets to Azure Pipelines Without Hardcoding Them?

### The Rule

**Secrets never appear in YAML files.** YAML is committed to git — anything in YAML is potentially visible to anyone with repo access.

### The Pattern

**Step 1:** Store the secret in Azure DevOps Library as a secret variable in a Variable Group.

```
Azure DevOps Library → Variable Groups → vg-common
  ACR_NAME: acrazureshopdev          (not secret)
  SQL_PASSWORD: ••••••••             (secret — masked)
```

**Step 2:** Reference the variable group in the pipeline:
```yaml
variables:
  - group: vg-common
```

**Step 3:** Inject the secret as an env var into only the step that needs it:
```yaml
- script: deploy.sh
  env:
    SQL_PASSWORD: $(SQL_PASSWORD)   # variable name reference, not the value
```

The `$(SQL_PASSWORD)` resolves to the secret value at runtime. It appears as `***` in all logs.

### Why Not Use Environment Variables Directly?

Azure Pipelines runs on hosted agents that are ephemeral VMs. You cannot pre-configure OS environment variables on them. Variable Groups are the Azure DevOps-native way to inject values into pipeline runs without storing them in code.

### In AzureShop

The most sensitive secrets (SQL password, service principal credentials) are never in YAML. The Service Connection (`sc-azureshop-azure`) handles Azure authentication — pipelines never see the service principal's client secret at all. It is abstracted by the Service Connection mechanism.

---

## Q8. What is a Service Connection in Azure Pipelines?

### The Problem

Pipelines need to authenticate to Azure to:
- Push images to ACR (`az acr login`)
- Deploy to AKS (`helm upgrade`)
- Run Terraform (`terraform apply`)

Hardcoding a service principal's client ID and secret in YAML would expose long-lived credentials in version control.

### What a Service Connection Is

A Service Connection is a **named, secure credential store** inside Azure DevOps that pipelines reference by name. The credentials themselves are never visible in YAML.

### How It Was Created (Azure Resource Manager type)

1. Azure DevOps created a Service Principal in Azure AD: `sp-azureshop-terraform`
2. Assigned it `Contributor` role on the subscription
3. Stored the credentials (client ID + secret) securely in Azure DevOps
4. Named the connection `sc-azureshop-azure`

### How Pipelines Use It

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure   # ← just the name
    scriptType: bash
    inlineScript: |
      az acr login --name $(ACR_NAME)
```

The `AzureCLI@2` task resolves `sc-azureshop-azure` to the stored credentials, authenticates with Azure AD, and runs the script in an authenticated shell session. The pipeline agent never sees the actual client secret.

### Security Properties

- **No credentials in YAML** — YAML only references the connection name
- **Scoped permissions** — the service principal has only the roles it needs
- **Audit trail** — Azure AD logs every action taken by the service principal
- **Rotatable** — if the secret is compromised, update it in the Service Connection without changing any YAML

---

## Q9. How Does a CD Pipeline Know Which Image Version to Deploy?

### The Concept — Image Promotion

The same image tag travels through all environments. It is built once by CI and promoted through dev → staging → prod without rebuilding.

```
CI builds: user-service:105  (tag = Build.BuildId)
           ↓
deploy-dev deploys: user-service:105
           ↓
deploy-staging deploys: user-service:105  (same tag)
           ↓
deploy-prod deploys: user-service:105  (same tag — what you tested is what ships)
```

### How the Tag Is Passed Between Pipelines

**CI pipeline tags the image:**
```yaml
imageTag: $(Build.BuildId)   # e.g. "105"
docker build -t acrazureshopdev.azurecr.io/user-service:105
```

**deploy-dev.yaml is triggered by CI completion:**
```yaml
resources:
  pipelines:
    - pipeline: user-service-ci
      source: user-service-ci
      trigger: true
```

It gets the build ID from the triggering pipeline run.

**deploy-staging.yaml uses the dev run ID:**
```yaml
resources:
  pipelines:
    - pipeline: deploy-dev
      source: deploy-dev
      trigger: true

# Inside the step:
imageTag: $(resources.pipeline.deploy-dev.runID)
```

`$(resources.pipeline.deploy-dev.runID)` resolves to the build ID of the deploy-dev run that triggered this pipeline — which is the same CI build ID.

### Why Not Just Use `latest`?

| | `latest` tag | Build ID tag |
|---|---|---|
| Reproducibility | Different every pull — staging might deploy a different image than dev | Always the exact same image |
| Rollback | Cannot roll back to a specific build | `helm upgrade --set image.tag=103` rolls back to build 103 |
| Audit | No way to know which code is running | Build 105 → git commit SHA → exact code is traceable |
| Race condition | CI builds 106 while staging deploys 105 — `latest` picks up 106 | Build ID is immutable |

---

## Q10. What is an Environment Approval Gate and How Does It Work?

### What It Is

An approval gate is a **human checkpoint** configured on an Azure Pipelines Environment. When a deployment job targets an environment that has approvers, the pipeline automatically pauses and sends a notification before the deployment runs.

### The Flow

```
deploy-staging completes → triggers deploy-prod
                                  ↓
                  PIPELINE PAUSED — waiting for approval
                  Email/Teams notification sent to approvers
                                  ↓
                  Approver logs into Azure DevOps
                  Reviews: which build? what changed? test results?
                  Clicks APPROVE or REJECT
                                  ↓
          APPROVE                          REJECT
             ↓                               ↓
  helm upgrade runs on prod        Pipeline cancelled
                                   No production change
```

### Where It's Configured

The approval gate is **not in YAML** — it is configured in the Azure DevOps UI:
```
Azure DevOps → Pipelines → Environments → prod → Approvals and checks → Add → Approvals
```

This is important: the YAML file just says `environment: prod`. The gate itself is a separate configuration that can be added or removed without any code change.

### Why This Separation Matters

- A developer cannot bypass the approval gate by modifying the pipeline YAML
- The gate is managed by the project administrator, not by developers
- Changing the approver list requires Azure DevOps admin access, not git access

### In AzureShop

- `dev` environment — no approval gate, deploys automatically
- `staging` environment — no approval gate, deploys automatically
- `prod` environment — manual approval gate, pipeline pauses indefinitely until an approver acts

This is **Continuous Delivery** (not Continuous Deployment): everything up to staging is fully automated; production always requires human sign-off.

---

## Q11. What is the Difference Between Continuous Delivery and Continuous Deployment?

### The One-Line Difference

| | Meaning |
|---|---|
| **Continuous Delivery** | Code is always **ready** to deploy to production — but a human presses the button |
| **Continuous Deployment** | Code is automatically **deployed** to production — no human involved at all |

### The Analogy

Think of a pizza factory:

- **Continuous Delivery** — The pizza is fully made, boxed, and quality checked. It is sitting at the counter ready to go. But a manager must approve before the delivery driver leaves.
- **Continuous Deployment** — The pizza is made, boxed, and quality checked. The delivery driver leaves automatically the moment it passes the quality check. No manager approval needed.

The pipeline and quality checks are identical in both cases. The only difference is whether a human approves the final step or not.

### Visual Flow

```
Code Commit → Build → Unit Tests → Integration Tests → Deploy to Staging → ???
```

**Continuous Delivery:**
```
... → Deploy to Staging → ✅ MANUAL APPROVAL GATE → Deploy to Production
                               👆 Human clicks Approve
```

**Continuous Deployment:**
```
... → Deploy to Staging → ✅ All tests pass → Deploy to Production (automatic)
                                               👆 No human involved
```

### When to Use Which

**Use Continuous Delivery when:**
- You are in a regulated industry (banking, healthcare) where a human must sign off before release
- Your product has a marketing/sales release schedule — code is ready but you release on a chosen date
- Your team is not fully confident in automated test coverage yet

**Use Continuous Deployment when:**
- You ship dozens of small changes per day (like Netflix, Amazon)
- Your automated test coverage is very high and fully trusted
- Speed matters more than manual control

### In AzureShop

Your Azure Pipelines setup uses **Continuous Delivery** for production:

```yaml
# deploy-prod.yaml
stages:
  - stage: Deploy_Prod
    jobs:
      - deployment: DeployToProd
        environment: production     # ← this has a manual approval gate configured in Azure DevOps
```

The `environment: production` automatically pauses the pipeline until an approver clicks Approve in Azure DevOps.

For `dev` — it is closer to **Continuous Deployment** because there is no approval gate. Every merge to dev automatically deploys.

### Summary Table

| Feature | Continuous Delivery | Continuous Deployment |
|---|---|---|
| Build automated | ✅ Yes | ✅ Yes |
| Tests automated | ✅ Yes | ✅ Yes |
| Deploy to staging automated | ✅ Yes | ✅ Yes |
| Deploy to production | ❌ Manual approval | ✅ Fully automatic |
| Human involvement | Yes — final approval | No — fully hands-off |
| Risk | Lower | Higher — needs great test coverage |
| Speed | Slightly slower | Fastest possible |
| Used in AzureShop | ✅ Yes (prod gate) | Partially (dev env) |

> **Interview tip:** *"We use Continuous Delivery for production with a manual approval gate in Azure Pipelines, and Continuous Deployment style for the dev environment where every merge auto-deploys."*

---

## Q12. What is an Agent in Azure Pipelines and What Are the Different Types?

### What is an Agent?

When you write a pipeline in Azure DevOps, you are writing a list of instructions — build this code, run these tests, deploy to Kubernetes. Those instructions need to run **somewhere**, on some actual machine.

An **Agent** is that machine. It is a computer that listens for pipeline jobs from Azure DevOps and executes them.

Think of Azure DevOps as a **restaurant manager** and the Agent as a **chef**:
- The manager (Azure DevOps) receives the order (pipeline trigger)
- The manager assigns the order to an available chef (agent)
- The chef (agent) actually cooks the food (runs the build, tests, deploy commands)
- When done, the chef reports back — success or failure

Without an agent, the pipeline can be triggered but nothing runs.

### 2 Main Types of Agents

```
Azure Pipeline Agents
│
├── 1. Microsoft-Hosted Agents  (cloud VM — managed by Microsoft)
│
└── 2. Self-Hosted Agents       (your own machine — managed by you)
```

---

### Type 1 — Microsoft-Hosted Agents

These are virtual machines that **Microsoft creates, manages, and destroys** automatically for you. Every time a pipeline runs, Azure spins up a fresh clean VM, runs your job, then destroys the VM.

**Available images:**

| Agent Image | OS | Common Use |
|---|---|---|
| `ubuntu-latest` | Ubuntu Linux | Most CI/CD work, Docker builds |
| `windows-latest` | Windows Server | .NET apps, Windows-specific builds |
| `macos-latest` | macOS | iOS/macOS app builds |

**How you use it:**
```yaml
pool:
  vmImage: ubuntu-latest    # ← Microsoft-hosted agent
```

**Advantages:**
- Zero setup — Microsoft handles everything
- Always starts clean (no leftover files from previous runs)
- Pre-installed with common tools (Docker, kubectl, Terraform, git, Node.js, Python)
- Free tier: 1,800 minutes/month for private projects

**Disadvantages:**
- Cannot access resources inside a private network
- Limited free minutes — can get expensive at scale
- Slightly slower — VM must be provisioned each time
- Cannot install custom software permanently (it starts fresh every run)

---

### Type 2 — Self-Hosted Agents

These are machines that **you own and manage**. You install the Azure DevOps agent software on your own server or VM. It registers itself with your Azure DevOps organization and waits for jobs.

**How you use it:**
```yaml
pool:
  name: MyCustomPool    # ← your self-hosted agent pool name
```

**Advantages:**
- Full control — install any software you want permanently
- Faster — no VM provisioning time, agent is always running
- Can access private networks (internal databases, private ACR, etc.)
- No minute limits — unlimited jobs
- Can cache dependencies (node_modules, pip packages) between runs for faster builds

**Disadvantages:**
- You maintain it — security patches, updates, disk space
- Not clean by default — previous run's files stay unless you clean up manually
- Costs money to keep the VM running 24/7

### In AzureShop

Your pipelines use **Microsoft-Hosted agents:**
```yaml
# Every CI and CD pipeline in AzureShop
pool:
  vmImage: ubuntu-latest
```

This made sense because:
- ACR is publicly accessible — no private network needed
- Standard tools (Docker, Terraform, kubectl) come pre-installed
- No complex custom software requirements

### Visual Comparison

```
Microsoft-Hosted Agent                Self-Hosted Agent
──────────────────────                ─────────────────
Pipeline triggers                     Pipeline triggers
      │                                     │
Azure spins up fresh                  Your always-on
VM (takes 1-2 min)                    machine picks up job
      │                                     │
Runs your job                         Runs your job
      │                                     │
VM is destroyed                       Machine stays running
(clean for next run)                  (ready for next run)
```

### Summary Table

| Feature | Microsoft-Hosted | Self-Hosted |
|---|---|---|
| Setup required | ❌ None | ✅ Yes — install agent software |
| Maintenance | Microsoft handles | You handle |
| Clean environment | ✅ Every run | ❌ Manual cleanup needed |
| Private network access | ❌ No | ✅ Yes |
| Custom software | ❌ Reinstall every run | ✅ Install once, stays |
| Cost | Free tier then pay/min | Cost of running your own VM |
| Speed | Slightly slower (provision time) | Faster (always on) |
| Used in AzureShop | ✅ Yes (`ubuntu-latest`) | ❌ No |

> **Interview tip:** *"Microsoft-Hosted agents are best for standard CI/CD workloads needing a clean environment. Self-Hosted agents are best when you need private network access, custom tools, or faster builds with dependency caching."*

---

## Q13. What Are Variables, Conditions, and Parameters in Azure Pipelines YAML?

These are three core concepts that make Azure Pipelines flexible, reusable, and intelligent.

---

### Part 1 — Parameters

#### What is a Parameter?

A **Parameter** is an input value you pass INTO a template when calling it — like filling in a form before submitting it.

Think of a template as a **cookie cutter**. The shape is the same every time, but you pass in different dough (parameters) to make different flavoured cookies. The cutter does not change — only what you put into it changes.

#### Why Use Parameters?

Without parameters you would write a separate pipeline for every service:
```
user-service-ci.yaml    — 80 lines of build logic
cart-service-ci.yaml    — 80 lines of identical build logic
order-service-ci.yaml   — 80 lines of identical build logic
... (8 times)
```

With parameters you write ONE template and each service calls it with its own values. Each CI file becomes 5 lines.

#### How Parameters Work in AzureShop

`build-template.yaml` defines 4 parameters:
```yaml
parameters:
  - name: serviceName        # e.g. "user-service"
    type: string

  - name: dockerfilePath     # e.g. "services/user-service"
    type: string

  - name: imageTag
    type: string
    default: $(Build.BuildId) # ← used if caller does not provide this

  - name: runTests
    type: boolean
    default: true             # ← run tests by default
```

`user-service-ci.yaml` calls the template and passes values:
```yaml
- template: ../templates/build-template.yaml
  parameters:
    serviceName: $(SERVICE_NAME)       # → "user-service"
    dockerfilePath: $(DOCKERFILE_PATH) # → "services/user-service"
    imageTag: $(Build.BuildId)         # → "456"
    runTests: true
```

Inside the template, parameters are used with `${{ parameters.name }}` syntax:
```yaml
docker build \
  -t $(ACR_LOGIN_SERVER)/${{ parameters.serviceName }}:${{ parameters.imageTag }}
# becomes:
  -t acrazureshopdev.azurecr.io/user-service:456
```

---

### Part 2 — Variables

A **Variable** is a stored value with a name. Define it once, use it everywhere. If it changes, update one place.

Think of it like a contact saved in your phone — instead of typing a phone number every time, you save it as "Mum". If her number changes, update it once.

#### 3 Types of Variables

**Type A — Inline Variables** (defined in the pipeline YAML file itself)
```yaml
# From user-service-ci.yaml
variables:
  - name: SERVICE_NAME
    value: user-service
  - name: DOCKERFILE_PATH
    value: services/user-service
```
Good for values specific to one pipeline that are not sensitive.

**Type B — Variable Groups** (shared collection stored in Azure DevOps Library)
```yaml
variables:
  - group: vg-common    # loads ACR_NAME, ACR_LOGIN_SERVER, AKS_NAME, RESOURCE_GROUP
  - name: SERVICE_NAME
    value: user-service
```
All 8 CI pipelines load `vg-common`. Change the ACR name → update one Variable Group → all pipelines pick it up automatically.

**Type C — Predefined Variables** (built into Azure DevOps — always available, never defined by you)

| Variable | What it contains | Example value |
|---|---|---|
| `$(Build.BuildId)` | Unique number for this build | `456` |
| `$(Build.SourceBranch)` | Branch that triggered the build | `refs/heads/dev` |
| `$(Build.ArtifactStagingDirectory)` | Folder for storing build outputs | `/home/agent/work/1/a` |

#### Variable Syntax — Two Styles (Important!)

| Syntax | Resolved when | Used for |
|---|---|---|
| `$(variableName)` | **Runtime** — when pipeline is actually running | Variables, Variable Groups |
| `${{ parameters.name }}` | **Compile time** — before pipeline starts | Parameters, conditional logic |

---

### Part 3 — Conditions

A **Condition** is a rule that controls whether a step should run or be skipped — like an if statement in programming but for pipeline steps.

#### Type A — Compile-Time Conditions (`${{ if }}`)

Evaluated BEFORE the pipeline runs. Decides whether to even include a step.

```yaml
# From build-template.yaml
# This entire test step is INCLUDED only if runTests = true
# If runTests = false, this step does not exist in the pipeline at all

- ${{ if eq(parameters.runTests, true) }}:
  - script: |
      cd ${{ parameters.dockerfilePath }}
      npm ci && npm test --if-present
    displayName: 'Install & Test — ${{ parameters.serviceName }}'
```

`eq` means "equals". If `runTests` equals `true` → include the step. If `false` → step does not exist.

#### Type B — Runtime Conditions (`condition:`)

Evaluated WHILE the pipeline is running — based on what happened in previous steps.

```yaml
# From build-template.yaml
# Publish Trivy report ALWAYS — even if the security gate step failed
- task: PublishBuildArtifacts@1
  displayName: 'Publish Trivy SARIF'
  condition: always()    # ← run this step no matter what happened before
```

**Why `condition: always()` here?**
The previous step is the Trivy security gate — it FAILS the pipeline if it finds critical vulnerabilities. Without `condition: always()`, the publish step would be skipped on failure. But we WANT the report published even on failure so we can see WHAT vulnerabilities were found.

**Common condition keywords:**

| Condition | Meaning |
|---|---|
| `succeeded()` | Run only if all previous steps passed (this is the **default**) |
| `failed()` | Run only if a previous step failed |
| `always()` | Run no matter what — pass or fail |
| `eq(variables['Build.SourceBranch'], 'refs/heads/main')` | Run only on main branch |

---

### How All 3 Work Together in AzureShop

```
user-service-ci.yaml
│
│  variables:
│    - group: vg-common           ← Type B variable: shared ACR_NAME, AKS_NAME
│    - SERVICE_NAME: user-service ← Type A variable: inline, this pipeline only
│
│  calls build-template.yaml with:
│    parameters:
│      serviceName: $(SERVICE_NAME)  ← passes variable value as a parameter
│      runTests: true                ← parameter drives a condition inside template
│
▼
build-template.yaml
│
│  ${{ if eq(parameters.runTests, true) }}  ← compile-time condition
│    → test step IS included (runTests=true)
│
│  docker build -t $(ACR_LOGIN_SERVER)/${{ parameters.serviceName }}
│                       ↑                        ↑
│               runtime variable          compile-time parameter
│               from vg-common            passed from caller
│
│  condition: always()  ← runtime condition on the publish step
│    → report published even if security gate fails
```

### Summary Table

| Concept | What it is | Syntax | Resolved when |
|---|---|---|---|
| Inline Variable | Value in YAML file | `$(VAR_NAME)` | Runtime |
| Variable Group | Shared values in Azure DevOps | `$(VAR_NAME)` | Runtime |
| Predefined Variable | Auto-provided by Azure DevOps | `$(Build.BuildId)` | Runtime |
| Parameter | Input value passed to a template | `${{ parameters.name }}` | Compile time |
| Compile-time Condition | Include/exclude step based on parameter | `${{ if eq(...) }}` | Compile time |
| Runtime Condition | Run/skip step based on pipeline state | `condition: always()` | Runtime |

> **Interview tip:** *"Parameters make templates reusable — one template serves all 8 services. Variable Groups centralise shared config so we don't repeat ACR name and AKS name in every pipeline. Conditions control flow — `${{ if }}` to optionally skip tests, and `condition: always()` to ensure Trivy reports are published even when the security gate fails."*

---

## Q14. What is a Path-Based Trigger and How Does It Work in AzureShop?

### What is a Trigger?

A **trigger** is the event that tells Azure Pipelines to start running. Without a trigger, a pipeline only runs when someone manually clicks Run. There are two types:
- **Branch trigger** — runs when code is pushed to a specific branch
- **Path-based trigger** — runs only when code changes inside a specific folder

### The Problem Without Path-Based Triggers

AzureShop has 8 services, each with its own CI pipeline. Without path-based triggers, changing one line in `user-service` would trigger ALL 8 pipelines — 7 unnecessary Docker builds, 7 unnecessary Trivy scans, 7 unnecessary image pushes to ACR. Wasted pipeline minutes and slower feedback.

### How It Works in AzureShop

```yaml
# From user-service-ci.yaml
trigger:
  branches:
    include:
      - dev
      - feature/*
  paths:
    include:
      - services/user-service/**   # only trigger if files here changed
                                   # ** = any file, any subfolder depth
pr:
  branches:
    include:
      - dev
  paths:
    include:
      - services/user-service/**
```

In plain English: "Start this pipeline ONLY when someone pushes to `dev` or a `feature/*` branch AND the changed files are inside `services/user-service/`."

### Visual Example

```
Developer changes services/user-service/src/index.js and pushes to dev:
  user-service-ci.yaml   ✅ TRIGGERS — file inside services/user-service/
  cart-service-ci.yaml   ❌ SKIPPED  — no files changed there
  frontend-ci.yaml       ❌ SKIPPED  — no files changed there
  (all other 5 pipelines also skipped)
```

### `trigger` vs `pr` — What is the Difference?

| | `trigger` | `pr` |
|---|---|---|
| When it fires | Code is **pushed/merged** to a branch | A **Pull Request is opened or updated** |
| Purpose | Run full CI after merge, push image to ACR | Validate code before merge — no push to ACR |
| In AzureShop | Fires on push to `dev` or `feature/*` | Fires when PR targets `dev` |

### Full Flow in AzureShop

```
Push to feature/fix-login (touches services/user-service/)
  → pr: trigger fires → tests + build + trivy (no ACR push) — validates PR
  → PR approved and merged to dev
  → trigger: fires → full CI → image pushed to ACR → deploy-dev triggered
```

> **Interview tip:** *"Path-based triggers ensure only the relevant service pipeline runs when code changes. In AzureShop, changing user-service code only triggers user-service-ci.yaml — not all 8 pipelines. This saves pipeline minutes, speeds up feedback, and prevents unnecessary image builds."*

---

## Q15. What is the Concept of Secret Variables and How Are They Used?

### What is a Secret Variable?

A **Secret Variable** is a variable whose value is:
- **Encrypted** — stored in encrypted form, not plain text
- **Masked in logs** — replaced with `***` in every pipeline log automatically
- **Never visible** — even pipeline authors cannot read the value back after saving it
- **Never in YAML** — the value lives in Azure DevOps, not in your code

Think of it like a bank vault PIN — you can use it to open the vault, but it never gets printed on any receipt.

### The Problem Without Secret Variables

```yaml
# ❌ NEVER DO THIS — credentials hardcoded in YAML
variables:
  SQL_PASSWORD: MyStr0ng@Password123   # visible to everyone with repo access
  # if git repo leaks, your entire Azure subscription is compromised
```

### 3 Ways to Use Secret Variables

**Way 1 — Secret variable in Variable Group (what AzureShop uses):**
- Go to Azure DevOps → Library → Variable Groups → vg-prod
- Add variable, type the value, click the lock icon 🔒 → it becomes a secret
- Reference in YAML: `- group: vg-prod` — only the NAME, never the value

**Way 2 — Variable Group linked to Azure Key Vault (most secure):**
- Azure DevOps fetches the secret directly from Key Vault at pipeline runtime
- Secret never lives in Azure DevOps — only in Key Vault
- One source of truth, full audit trail on every access

**Way 3 — Inline pipeline secret (least secure, avoid for production)**

### The `env:` Block — Most Important Rule

Secret variables are NOT automatically injected into all steps. You must explicitly inject them into only the specific step that needs them:

```yaml
# From terraform-apply.yaml in AzureShop
- task: AzureCLI@2
  displayName: 'terraform plan — dev'
  inputs:
    inlineScript: |
      terraform plan -var-file="environments/dev/terraform.tfvars"
  env:
    TF_VAR_sql_admin_password: $(TF_VAR_SQL_ADMIN_PASSWORD)
    # only THIS step sees the secret — not the whole pipeline
    # logs show: TF_VAR_sql_admin_password=***
```

### In AzureShop — Secret Flow

```
Azure Key Vault → stores sql-admin-password
      ↓ Terraform writes secrets during terraform apply
Variable Group vg-prod → TF_VAR_SQL_ADMIN_PASSWORD = *** (locked)
      ↓ Pipeline loads vg-prod
terraform-apply.yaml → injects via env: block into Terraform steps only
      ↓ Terraform reads it, writes to Key Vault
AKS pods → CSI driver mounts from Key Vault as env vars inside pods
Secret NEVER touches YAML or git at any point
```

### In a Real IT Company

- Dev secrets → Variable Group (vg-dev)
- Staging/prod secrets → Variable Group linked to Key Vault
- Rotation every 90 days — update in Key Vault, no YAML changes needed
- Audit log: every secret access recorded in Key Vault

### Golden Rules

| Rule | Why |
|---|---|
| Never write secrets in YAML | YAML is in git — git history is permanent |
| Never `echo` a secret in a script | Appears in pipeline logs |
| Use `env:` block to inject only into steps that need it | Least privilege |
| Separate Variable Groups per environment | Dev secrets should never reach prod pipelines |
| Link prod Variable Groups to Key Vault | One source of truth, full audit trail |

> **Interview tip:** *"In AzureShop, the SQL admin password is stored as a secret in `vg-prod` Variable Group. It is never written in any YAML file. In terraform-apply pipeline it is injected via the `env:` block only into specific Terraform steps. In logs it always appears as `***`. For production, we link the Variable Group to Azure Key Vault so the secret never lives in Azure DevOps at all."*

---

## Q16. What is a Service Connection and How Is It Used in AzureShop Pipelines?

### What is a Service Connection?

A **Service Connection** is a secure, named bridge between Azure DevOps and an external service (like Azure, GitHub, Docker Hub). It stores credentials encrypted inside Azure DevOps — your pipeline YAML only refers to it by NAME, never by actual credentials.

Think of it like a hotel key card — you swipe the card (`sc-azureshop-azure`) to enter the room (Azure subscription). The card handles authentication. You never carry the master key (client secret).

### The Problem Without It

```yaml
# ❌ NEVER DO THIS
variables:
  AZURE_CLIENT_SECRET: MyS3cretP@ssword  # visible to everyone in repo
  # if leaked, your entire Azure subscription is compromised
```

### How It Works at Runtime

```
Pipeline hits AzureCLI@2 task with azureSubscription: sc-azureshop-azure
      ↓
Azure DevOps resolves the name → fetches encrypted Service Principal credentials
      ↓
Runs az login --service-principal (automatically, invisibly)
      ↓
Gets a short-lived access token (valid ~1 hour)
      ↓
Your script runs in an already-authenticated shell
Pipeline agent NEVER sees the client secret — logs show NO credentials
```

### In AzureShop — `sc-azureshop-azure` Used in 16 Places

**Service Principal behind it:** `sp-azureshop-terraform` with `Contributor` role on the Azure subscription.

**4 main use cases:**

**Use Case 1 — ACR Login (build-template.yaml):**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure
    inlineScript: |
      az acr login --name $(ACR_NAME)
      # Docker is now authenticated to push images to ACR
```

**Use Case 2 — Connect kubectl to AKS (deploy-template.yaml):**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure
    inlineScript: |
      az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(AKS_NAME)
      # kubectl and helm now work — no Kubernetes password in YAML
```

**Use Case 3 — Terraform runs (terraform-apply.yaml, 9 times):**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure
    inlineScript: |
      terraform init && terraform plan && terraform apply
      # Terraform can now create/modify all Azure resources
```

**Use Case 4 — Terraform validate on PRs (terraform-validate.yaml):**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: sc-azureshop-azure
    inlineScript: |
      terraform plan -no-color 2>&1 | tee plan-output.txt
      # Read-only plan — shows what infra would change on every PR
```

### Security Properties

| Property | Benefit |
|---|---|
| Credentials encrypted in Azure DevOps | Never in YAML or git |
| Agent never sees client secret | Cannot be logged or leaked |
| Short-lived access tokens at runtime | Even if intercepted, expires in ~1 hour |
| Scoped to specific subscription | Cannot access other subscriptions |
| Auditable | Azure AD logs every action the SP takes |
| Rotatable | Update secret in Service Connection → all pipelines pick it up, no YAML changes |

### In Real Companies

One Service Connection per environment:
```
sc-azureshop-dev     → Contributor on dev subscription only
sc-azureshop-staging → Contributor on staging subscription only
sc-azureshop-prod    → Contributor on prod subscription only (restricted access)
```
In AzureShop we used one for all environments because it is a learning project. In production, always separate them.

> **Interview tip:** *"A Service Connection is a named, encrypted credential store that allows pipelines to authenticate to Azure without any credentials in YAML. In AzureShop, `sc-azureshop-azure` uses a Service Principal with Contributor role on our subscription. It is referenced 16 times across our pipelines — for ACR login, AKS access, and Terraform runs. The pipeline agent never sees the actual client secret — Azure DevOps handles authentication transparently using short-lived tokens at runtime."*

---

## Q17. What is the Difference Between Environments and Environment Variables?

### The Core Difference in One Line

- **Environment** = the **destination** you are deploying TO (a place in Azure DevOps)
- **Environment Variable** = the **settings** you use WHILE deploying (configuration values)

| | Environment | Environment Variable |
|---|---|---|
| What it is | Deployment target in Azure DevOps UI | A name-value pair used in pipeline steps |
| Lives in | Azure DevOps (Pipelines → Environments) | YAML file or Variable Group |
| Purpose | Track deployments, enforce approval gates | Pass configuration values to steps |
| In YAML | `environment: dev` inside deployment job | `$(VARIABLE_NAME)` anywhere |
| Example | `dev`, `staging`, `prod` | `K8S_NAMESPACE=dev`, `REPLICAS=1` |

### Part 1 — What is an Environment?

An **Environment** in Azure Pipelines is a logical deployment target — a checkpoint in your release journey created in the Azure DevOps UI. It does NOT run any code. It provides:

**1. Deployment History** — every pipeline deployment is recorded:
```
Environments → dev → Deployments
  ✅ Build #456 — deployed by Anshu — 2026-05-20 10:30 — success
  ✅ Build #455 — deployed by Anshu — 2026-05-19 14:15 — success
  ❌ Build #454 — deployed by Anshu — 2026-05-19 09:00 — failed
```

**2. Approval Gates** — configured in the UI, NOT in YAML:
```
dev     → no approval gate → deploys automatically
staging → no approval gate → deploys automatically
prod    → MANUAL APPROVAL  → pipeline pauses, waits for team lead
```
A developer cannot bypass the approval gate by changing YAML — it is enforced by Azure DevOps.

**How Environments are used in AzureShop:**
```yaml
# deploy-dev.yaml
- deployment: DeployAllServices
  environment: dev          # no gate — auto-deploys

# deploy-staging.yaml
- deployment: DeployAllServices
  environment: staging      # no gate — auto-deploys

# deploy-prod.yaml
- deployment: DeployAllServices
  environment: prod         # MANUAL APPROVAL GATE — pauses here
  timeoutInMinutes: 120     # cancels if no approval within 2 hours
```

### Part 2 — What are Environment Variables?

**Environment Variables** are name-value pairs that configure what the pipeline actually does — which cluster to connect to, which namespace to use, how many replicas to run.

**In AzureShop — 3 Variable Groups (one per environment):**

| Variable | vg-dev | vg-staging | vg-prod |
|---|---|---|---|
| `ENVIRONMENT` | dev | staging | prod |
| `K8S_NAMESPACE` | dev | staging | prod |
| `AKS_NAME` | aks-azureshop-dev | aks-azureshop-staging | aks-azureshop-prod |
| `RESOURCE_GROUP` | rg-azureshop-dev | rg-azureshop-staging | rg-azureshop-prod |
| `REPLICAS` | 1 | 2 | 3 |

**How they are used in the pipeline:**
```yaml
# deploy-dev.yaml
variables:
  - group: vg-common   # shared vars
  - group: vg-dev      # loads ENVIRONMENT, K8S_NAMESPACE, AKS_NAME, REPLICAS

# These values flow into every deploy-template call:
- template: ../templates/deploy-template.yaml
  parameters:
    namespace: $(K8S_NAMESPACE)   # → "dev"
    replicas: $(REPLICAS)         # → 1
    helmValuesFile: helm/values/dev.yaml

# And inside the template:
az aks get-credentials --name $(AKS_NAME)          # → aks-azureshop-dev
kubectl create namespace $(K8S_NAMESPACE)           # → dev
helm upgrade --set replicaCount=${{ parameters.replicas }}  # → 1
```

### How Both Work Together — The Complete Picture

```
deploy-staging.yaml
│
│  variables:
│    - group: vg-staging      ← ENVIRONMENT VARIABLES
│      K8S_NAMESPACE=staging     (tells pipeline HOW and WHERE to deploy)
│      AKS_NAME=aks-azureshop-staging
│      REPLICAS=2
│
│  jobs:
│    - deployment: DeployAllServices
│      environment: staging   ← AZURE PIPELINES ENVIRONMENT
│                                (records deployment, checks approval gate)
```

**Why the same deploy template works for all 3 environments:**
- The template logic never changes
- Swap `vg-dev` → `vg-staging` → `vg-prod` and the template automatically deploys to the right cluster, namespace, and replica count
- The `environment:` keyword changes only the checkpoint that Azure DevOps records against

> **Interview tip:** *"In AzureShop, Environments and Environment Variables solve two completely different problems. The Azure Pipelines `environment: dev/staging/prod` tracks deployment history and enforces approval gates — prod has a manual gate, dev and staging auto-deploy. The Variable Groups `vg-dev/vg-staging/vg-prod` configure what the deployment does — which AKS cluster to connect to, which namespace, how many replicas. The same deploy template works for all three environments just by swapping the Variable Group."*

---

## Q18. Where Are Variable Groups Stored, How Are They Created, and How Does a Pipeline Read Them?

> **Note:** Q6 covered WHAT Variable Groups are and WHY we use them. This question is a deeper dive into storage location, creation method, and the runtime reading mechanism.

### 1. Where Are Variable Groups Stored?

Variable Groups are stored **inside Azure DevOps Library** — completely separate from your git repository. They are NOT in any file in your repo, which is why you cannot find them on GitHub or Azure Repos.

```
Azure DevOps
│
└── Project: AzureShop
      │
      └── Pipelines
            │
            └── Library          ← Variable Groups live here
                  │
                  ├── vg-common
                  ├── vg-dev
                  ├── vg-staging
                  └── vg-prod
```

**Exact navigation in Azure DevOps UI:**
```
Pipelines → Library → Variable Groups → select group → view/edit variables
```

**Why NOT in git?**
- Git is visible to anyone with repo access
- Variable Groups can contain secrets (passwords, keys)
- Azure DevOps encrypts values at rest — git cannot do that
- If the repo is ever leaked or made public, no secrets are exposed

---

### 2. How Are Variable Groups Created — Manual or Automatic?

**They are created MANUALLY by the DevOps engineer** in the Azure DevOps UI. Nothing creates them automatically.

Here is exactly how the 4 Variable Groups in AzureShop were created:

**Step 1 — Go to Azure DevOps Library:**
```
Pipelines → Library → + Variable Group
```

**Step 2 — Create `vg-common`:**
```
Name: vg-common
Variables:
  ACR_NAME         = acrazureshopdev
  ACR_LOGIN_SERVER = acrazureshopdev.azurecr.io
```

**Step 3 — Create `vg-dev`:**
```
Name: vg-dev
Variables:
  ENVIRONMENT    = dev
  AKS_NAME       = aks-azureshop-dev
  RESOURCE_GROUP = rg-azureshop-dev
  K8S_NAMESPACE  = dev
  REPLICAS       = 1
```

**Step 4 — Create `vg-staging`:**
```
Name: vg-staging
Variables:
  ENVIRONMENT    = staging
  AKS_NAME       = aks-azureshop-staging
  RESOURCE_GROUP = rg-azureshop-staging
  K8S_NAMESPACE  = staging
  REPLICAS       = 2
```

**Step 5 — Create `vg-prod` with a secret:**
```
Name: vg-prod
Variables:
  ENVIRONMENT                = prod
  AKS_NAME                   = aks-azureshop-prod
  RESOURCE_GROUP             = rg-azureshop-prod
  K8S_NAMESPACE              = prod
  REPLICAS                   = 3
  TF_VAR_SQL_ADMIN_PASSWORD  = MyStr0ng@Pass  🔒 (click lock icon → becomes secret)
```

**Step 6 — Grant pipeline access:**
```
Library → vg-common → Pipeline permissions → + → select pipeline
```
Only authorised pipelines can read the Variable Group. Other pipelines cannot access it.

---

### 3. How Does a Pipeline Read Variable Group Values at Runtime?

Here is the exact step-by-step flow of what happens when a pipeline runs:

**Step 1 — Pipeline is triggered** (code push, PR, or manual run)

**Step 2 — Azure DevOps reads the YAML:**
```yaml
# deploy-dev.yaml
variables:
  - group: vg-common    # ← Azure DevOps sees this
  - group: vg-dev       # ← and this
```

**Step 3 — Azure DevOps fetches values from Library:**
```
"Give me all variables from vg-common"
  → ACR_NAME = acrazureshopdev
  → ACR_LOGIN_SERVER = acrazureshopdev.azurecr.io

"Give me all variables from vg-dev"
  → ENVIRONMENT = dev
  → AKS_NAME = aks-azureshop-dev
  → RESOURCE_GROUP = rg-azureshop-dev
  → K8S_NAMESPACE = dev
  → REPLICAS = 1
```

**Step 4 — All values injected as environment variables into the pipeline run (in memory only — never written to disk)**

**Step 5 — Every step reads them with `$(VARIABLE_NAME)` syntax:**
```yaml
az aks get-credentials \
  --resource-group $(RESOURCE_GROUP)  # → rg-azureshop-dev
  --name $(AKS_NAME)                  # → aks-azureshop-dev

kubectl create namespace $(K8S_NAMESPACE)        # → dev
helm upgrade --set replicaCount=$(REPLICAS)      # → 1
```

**Step 6 — For SECRET variables — extra protection:**

Secret variables are NOT auto-injected into every step. You must explicitly inject them into only the step that needs them:
```yaml
- task: AzureCLI@2
  inputs:
    inlineScript: |
      terraform plan -var-file="environments/dev/terraform.tfvars"
  env:
    TF_VAR_sql_admin_password: $(TF_VAR_SQL_ADMIN_PASSWORD)
    # only THIS step gets the secret — shown as *** in all logs
```

**Step 7 — Pipeline finishes → all values discarded from memory. Never stored anywhere.**

---

### Complete Runtime Flow — Visual

```
Developer pushes code to dev branch
          │
          ▼
Azure DevOps triggers deploy-dev.yaml
          │
          ▼
Reads YAML → sees: - group: vg-common
                   - group: vg-dev
          │
          ▼
Fetches values from Library (Azure DevOps internal)
          │
          ▼
Injects all values as environment variables
into the pipeline run (in memory only)
          │
          ▼
Each step reads $(VARIABLE_NAME) → replaced with actual value
Secret variables → only via env: block in specific steps → *** in logs
          │
          ▼
Pipeline finishes → all variable values discarded
Never written to disk, never stored on agent machine
```

---

### Summary Table

| Question | Answer |
|---|---|
| Where stored? | Azure DevOps Library — NOT in git |
| Created manually or auto? | **Manually** by DevOps engineer in the UI |
| Who can read them? | Only pipelines explicitly granted permission |
| When are they loaded? | At pipeline start — before any step runs |
| How injected? | As environment variables into the pipeline run |
| Secret variables injected differently? | Yes — only via `env:` block into specific steps |
| Values on disk? | Never — only in memory during the pipeline run |
| Visible in logs? | Normal vars: yes. Secret vars: always `***` |

> **Interview tip:** *"Variable Groups are created manually in Azure DevOps Library — never in git. When a pipeline runs, Azure DevOps reads the YAML, fetches the named Variable Group from Library, and injects all values as environment variables into the pipeline run before any step executes. Secret variables must be explicitly injected into specific steps using the `env:` block and always appear as `***` in logs. Values exist only in memory during the run and are discarded when the pipeline finishes."*

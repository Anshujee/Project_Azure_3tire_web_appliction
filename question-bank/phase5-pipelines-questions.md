# Phase 5 — Azure Pipelines CI/CD: Question Bank

All questions asked during revision, with full detailed answers.
Covers: CI vs CD vs Continuous Deployment, pipeline structure, fail fast, jobs vs deployment jobs, reusable templates, Variable Groups, secret variables, Service Connections, image promotion, environment approval gates, path-based triggers, trigger vs pr, terraform plan-then-apply.

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

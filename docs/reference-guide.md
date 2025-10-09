# DevOps Mastery Roadmap - Updated

## Portfolio Structure
```
devops-portfolio/
├── 01-ci-cd-pipelines/
│   ├── github-actions-sample/     ✅ COMPLETED (Labs 1-2)
│   ├── matrix-builds/             ✅ COMPLETED
│   └── gitlab-ci-sample/          ⬜ Phase 2C
├── 02-infra-as-code/
│   ├── terraform/                 ✅ COMPLETED (VPC, EC2, Modules)
│   ├── ansible/                   ⬜ Phase 3B
│   └── cloudformation/            ⬜ Phase 3C (Optional)
├── 03-containers/
│   ├── docker/                    ⬜ Phase 4A - NEXT PRIORITY
│   └── kubernetes/                ⬜ Phase 4B - HIGH PRIORITY
├── 04-automation-scripts/
    ├── bash/
    │   ├── deploy.sh              ✅ COMPLETED
    │   ├── health-check.sh        ✅ COMPLETED
    │   └── backup.sh              ✅ COMPLETED (YOU BUILT THIS!)
    └── python/                    ⬜ Phase 5
```

---

## **Phase 2: CI/CD Pipelines**

### **Phase 2A: GitHub Actions** ✅ COMPLETED
- [x] Reusable workflows (build, deploy, orchestration)
- [x] Workflow triggers (PR, push to main)
- [x] Inputs, outputs, secrets
- [x] Environment validation

### **Phase 2B: Matrix Builds (GitHub)** ✅ COMPLETED
- [x] Matrix strategy in test workflow
- [x] Upload test results as artifacts from each combination
- [x] Display matrix results in orchestration workflow

### **Phase 2C: GitLab CI/CD** ⬜ RECOMMENDED - 2-3 days
**Priority: Do this to show multi-platform expertise**

Mirror your GitHub Actions structure in GitLab format.

**File: `.gitlab-ci.yml`**
```yaml
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "18"

# Reusable template
.build_template:
  image: node:${NODE_VERSION}
  cache:
    paths:
      - node_modules/
  before_script:
    - npm ci

# Build job
build:
  extends: .build_template
  stage: build
  script:
    - npm run build
    - echo "BUILD_TIME=$(date +%s)" >> build.env
  artifacts:
    paths:
      - dist/
    reports:
      dotenv: build.env
    expire_in: 1 hour

# Matrix testing
test:
  extends: .build_template
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ["16", "18", "20"]
        OS: ["debian", "alpine"]
  image: node:${NODE_VERSION}-${OS}
  script:
    - npm test
  coverage: '/Statements\s*:\s*(\d+\.\d+)%/'
  artifacts:
    when: always
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

# Deploy with environment
deploy_staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
  script:
    - echo "Deploying to staging..."
    - ./deploy.sh staging
  needs:
    - build
    - test

deploy_production:
  stage: deploy
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual  # Require manual approval
  script:
    - echo "Deploying to production..."
    - ./deploy.sh production
  needs:
    - build
    - test
```

**File: `.gitlab/ci-templates/build-template.yml`**
```yaml
# Reusable build template
.build_node_app:
  image: node:${NODE_VERSION:-18}
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
```

**GitLab-Specific Features to Showcase:**
- Pipeline templates with `extends` and `include`
- Built-in Container Registry
- Environment deployments with URLs
- Manual approval gates
- Security scanning (SAST, dependency scanning)
- Merge request pipelines
- Pipeline schedules

**Key Differences Document (README.md):**
| Feature | GitHub Actions | GitLab CI/CD |
|---------|---------------|--------------|
| Config File | `.github/workflows/*.yml` | `.gitlab-ci.yml` |
| Reusability | Reusable workflows | Templates with `extends` |
| Matrix | `strategy.matrix` | `parallel.matrix` |
| Secrets | Repository/Environment secrets | CI/CD Variables |
| Runners | GitHub-hosted or self-hosted | GitLab-hosted or self-hosted |
| Artifacts | `actions/upload-artifact` | `artifacts:` keyword |
| Environments | Environment protection rules | `environment:` with manual gates |

---

## **Phase 3: Infrastructure as Code**

### **Phase 3A: Terraform** ✅ COMPLETED
- [x] VPC Module with subnets, IGW, NAT Gateway
- [x] EC2 instances with user data
- [x] Security groups with dynamic blocks
- [x] IAM roles and instance profiles
- [x] Modular structure
- [x] Variables, outputs, tags
- [x] Remote state (S3 backend)

### **Phase 3B: Ansible** ⬜ RECOMMENDED - 3-4 days
**You have experience here, so this is reinforcement**

- Inventory management (dynamic inventory from Terraform outputs)
- Roles structure (common, webserver, database)
- Playbooks with error handling and rollback
- Integration with Terraform (provision → configure)

**Terraform + Ansible Integration:**
```hcl
# In Terraform outputs.tf
output "instance_ips" {
  value = aws_instance.web[*].public_ip
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tpl", {
    web_ips = aws_instance.web[*].public_ip
  })
  filename = "../ansible/inventory/production"
}
```

### **Phase 3C: CloudFormation** ⬜ Optional
**Skip unless targeting AWS-heavy roles**

---

## **Phase 4: Containers & Orchestration** (2-3 weeks)
**🔥 HIGHEST PRIORITY - Start here next**

### **Phase 4A: Docker** ⬜ NEXT - 2-3 days
**Priority: Start immediately**

**Multi-stage Dockerfiles:**
- Node.js app (dependencies → build → production)
- Python app with optimized layers
- Security best practices (non-root user, minimal base images)
- `.dockerignore` optimization

**Docker Compose:**
- Multi-service stack (app + database + cache)
- Volume management
- Health checks
- Networks

**Integration:**
- Build Docker images in CI/CD
- Push to GitHub Container Registry (GHCR)
- Push to GitLab Container Registry
- Scan images with Trivy

### **Phase 4B: Kubernetes** ⬜ CRITICAL - 1-1.5 weeks
**🎯 MOST REQUESTED SKILL IN JOB MARKET**

**Days 1-2: Core Resources**
- Deployments (rolling updates, replicas)
- Services (ClusterIP, NodePort, LoadBalancer)
- ConfigMaps and Secrets
- Health checks (liveness, readiness, startup probes)

**Days 3-4: Advanced Resources**
- Ingress with TLS
- HorizontalPodAutoscaler
- PersistentVolumes and PersistentVolumeClaims
- ResourceQuotas and LimitRanges
- NetworkPolicies

**Days 5-6: Helm Charts**
- Chart structure (templates, values)
- Templating with `_helpers.tpl`
- Multiple environments (values-dev.yaml, values-prod.yaml)
- Chart dependencies

**Day 7: GitOps Integration**
- Deploy to K8s from GitHub Actions
- Deploy to K8s from GitLab CI/CD
- ArgoCD or Flux (optional but impressive)

**Example K8s Deployment Pipeline (GitHub Actions):**
```yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/web-app \
            web-app=ghcr.io/${{ github.repository }}:${{ github.sha }} \
            -n production
          kubectl rollout status deployment/web-app -n production
        env:
          KUBECONFIG: ${{ secrets.KUBECONFIG }}
```

**Example K8s Deployment Pipeline (GitLab CI/CD):**
```yaml
deploy_k8s:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: production
    kubernetes:
      namespace: production
  script:
    - kubectl set image deployment/web-app web-app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - kubectl rollout status deployment/web-app
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

---

## **Phase 5: Automation Scripts**

### **5A: Advanced Bash Scripts** ⚠️ NEEDS ENHANCEMENT - 2-3 days
**Current: Basic scripts exist but need leveling up**

**Enhancement needed:**
- Deployment script with rollback capability
- Error handling and logging
- Retry logic
- Health checks
- Backup and restore functions

### **5B: Python Automation** ⬜ 2-3 days
- Cloud resource management (boto3)
- Cost reporting
- Monitoring and alerting
- Resource cleanup
- Metric collection

### **5C: Script Integration** ⬜ 1 day
- Call scripts from CI/CD pipelines
- Scheduled jobs (cron, K8s CronJobs)
- Notification integrations (Slack, email)

---

## **Phase 6: Monitoring & Observability** (Optional - 1 week)
**Growing requirement in job postings**

- Prometheus + Grafana setup
- Application metrics
- Log aggregation (ELK or Loki)
- Alert rules
- Dashboards

---

## **🎯 YOUR IMMEDIATE NEXT STEPS**

### **This Week (Choose One):**

**Option A: Quick Script Enhancement (2-3 hours) + Docker**
1. Level up bash scripts TODAY (deploy.sh, health-check.sh, backup.sh)
2. Start Docker multi-stage builds
3. Docker Compose stack
4. By end of week: Docker in CI/CD pipeline

**Option B: Docker → Kubernetes Sprint (Most Impactful)**
1. Skip script enhancement for now
2. Docker multi-stage builds (2 days)
3. Kubernetes core + advanced (5-7 days)
4. Come back to scripts later

### **Recommended: Option B**
**Reasoning:** 
- Kubernetes is #1 most-requested skill
- You already have working Terraform + GitHub Actions
- Docker + K8s will make the biggest portfolio impact
- Scripts can be polished alongside K8s work

---

## **Updated Timeline**

### **Week 1-2: Docker + Kubernetes**
- Days 1-2: Docker multi-stage, Compose, CI/CD integration
- Days 3-4: K8s Deployments, Services, ConfigMaps
- Days 5-6: K8s Ingress, HPA, PersistentVolumes
- Days 7-9: Helm charts + K8s CI/CD pipelines

### **Week 3: GitLab + Polish**
- Days 1-3: GitLab CI/CD pipeline (mirror GitHub setup)
- Days 4-5: Enhance bash scripts + Python automation
- Days 6-7: Documentation, README updates

### **Optional Week 4:**
- Ansible + Terraform integration
- Monitoring setup
- Portfolio presentation polish

---

## **Current Portfolio Strength**

### ✅ **What You Have:**
- GitHub Actions with reusable workflows ✅
- Matrix builds ✅
- Terraform (modular, AWS) ✅
- Basic scripting ⚠️

### ⬜ **Critical Gaps:**
- Docker containerization
- Kubernetes orchestration (MOST IMPORTANT)
- GitLab CI/CD (multi-platform proof)
- Advanced automation scripts

### **Market Readiness: 60%**
**After Docker + K8s: 85%**
**After GitLab + Scripts: 95%**

---

## **Job Market Alignment**

**Most Requested Skills (in order):**
1. Kubernetes ⭐⭐⭐⭐⭐ - **Missing**
2. Terraform ⭐⭐⭐⭐⭐ - **✅ Have**
3. Docker ⭐⭐⭐⭐⭐ - **Missing**
4. CI/CD (GitHub Actions, GitLab, Jenkins) ⭐⭐⭐⭐ - **✅ Partial (GitHub only)**
5. AWS/Azure/GCP ⭐⭐⭐⭐ - **✅ Have (Terraform)**
6. Python/Bash scripting ⭐⭐⭐ - **⚠️ Basic**
7. Ansible ⭐⭐⭐ - **⬜ Missing**
8. Monitoring (Prometheus, Grafana) ⭐⭐⭐ - **⬜ Optional**

**Next milestone: Add Docker + K8s = 5/8 top skills complete**
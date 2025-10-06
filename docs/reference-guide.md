# DevOps Mastery Roadmap - Updated

## Portfolio Structure
```
devops-portfolio/
├── 01-ci-cd-pipelines/
│   ├── github-actions-sample/     ✅ COMPLETED (Labs 1-2)
│   └── gitlab-ci-sample/          ⬜ NEW - Phase 2B
├── 02-infra-as-code/
│   ├── terraform/                 ⬜ Phase 3A
│   ├── ansible/                   ⬜ Phase 3B
│   └── cloudformation/            ⬜ Phase 3C (Optional)
├── 03-containers/
│   ├── docker/                    ⬜ Phase 4A
│   └── kubernetes/                ⬜ Phase 4B (HIGH PRIORITY)
└── 04-automation-scripts/
    ├── bash/                      ✅ Basic scripts done
    └── python/                    ⬜ Phase 5
```

---

## **Phase 2: CI/CD Pipelines** (1-2 weeks total)

### **Phase 2A: GitHub Actions** ✅ COMPLETED
- [x] Reusable workflows (build, deploy, orchestration)
- [x] Workflow triggers (PR, push to main)
- [x] Inputs, outputs, secrets
- [x] Environment validation

### **Phase 2B: Matrix Builds (GitHub)** ⬜ NEXT - 1-2 days
**Priority: Do this first**

Add to existing GitHub Actions workflows:
```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node-version: [16, 18, 20]
    exclude:
      - os: macos-latest
        node-version: 16
```

**Deliverables:**
- Matrix strategy in test workflow
- Upload test results as artifacts from each combination
- Display matrix results in orchestration workflow

### **Phase 2C: GitLab CI/CD** ⬜ NEW - 2-3 days
**Priority: Add after Terraform basics**

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

## **Phase 3: Infrastructure as Code** (2-3 weeks)

### **Phase 3A: Terraform** ⬜ 1-1.5 weeks
**Priority: Do this after matrix builds**

**Days 1-2: VPC Module**
- Create modular structure (`modules/vpc/`)
- VPC, subnets (public/private), IGW, NAT Gateway
- Route tables and associations
- Variables, outputs, tags

**Days 3-4: EC2 & Security Modules**
- EC2 instances with user data
- Security groups with dynamic blocks
- IAM roles and instance profiles
- EBS volumes and snapshots

**Days 5-6: Root Configuration**
- Compose modules in `main.tf`
- Use `terraform.tfvars` for environments
- Remote state (S3 backend)
- Outputs for other tools

**Day 7: CI/CD Integration**
- GitHub Actions workflow for Terraform
- `terraform plan` on PRs
- `terraform apply` on merge to main
- State locking with DynamoDB

**Example Workflow:**
```yaml
name: Terraform

on:
  pull_request:
    paths:
      - 'terraform/**'
  push:
    branches:
      - main
    paths:
      - 'terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
        
      - name: Terraform Format
        run: terraform fmt -check
        working-directory: ./terraform
        
      - name: Terraform Validate
        run: terraform validate
        working-directory: ./terraform
        
      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: ./terraform
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        working-directory: ./terraform
```

### **Phase 3B: Ansible** ⬜ 3-4 days
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

### **Phase 4A: Docker** ⬜ 2-3 days
**Priority: After Terraform**

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

### **Phase 4B: Kubernetes** ⬜ 1-1.5 weeks
**HIGH PRIORITY - Most requested skill**

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

## **Phase 5: Automation Scripts** (1 week)

### **5A: Advanced Bash Scripts** ⬜ 2-3 days
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

## **Recommended Execution Order**

### **Week 1:**
1. Matrix builds (GitHub) - 1 day
2. Terraform VPC + EC2 modules - 4 days
3. Terraform in CI/CD - 1 day

### **Week 2:**
4. Docker multi-stage builds - 2 days
5. GitLab CI/CD pipeline - 2-3 days

### **Week 3-4:**
6. Kubernetes core resources - 3 days
7. Kubernetes advanced + Helm - 3 days
8. K8s deployment pipelines (GitHub + GitLab) - 2 days

### **Week 5:**
9. Ansible + Terraform integration - 2 days
10. Python automation scripts - 2 days
11. Polish and document everything - 2 days

---

## **Portfolio Presentation Tips**

### **README.md Structure:**
```markdown
# DevOps Portfolio

## Skills Demonstrated
- ✅ CI/CD: GitHub Actions, GitLab CI/CD
- ✅ IaC: Terraform, Ansible
- ✅ Containers: Docker, Kubernetes, Helm
- ✅ Cloud: AWS (EC2, S3, VPC)
- ✅ Automation: Bash, Python

## Projects

### 1. Multi-Platform CI/CD Pipelines
- GitHub Actions with reusable workflows and matrix builds
- GitLab CI/CD with templates and parallel execution
- Automated testing, building, and deployment

### 2. Infrastructure as Code
- Modular Terraform for AWS (VPC, EC2, Security Groups)
- Ansible playbooks for configuration management
- Terraform + Ansible integration

### 3. Container Orchestration
- Production-ready Kubernetes manifests
- Helm charts for multiple environments
- Automated deployments from CI/CD

### 4. Automation Scripts
- Deployment scripts with rollback capability
- Cloud resource management with Python
- Cost optimization and monitoring
```

### **What Employers Want to See:**
1. **Both GitHub and GitLab** - Shows adaptability
2. **Terraform** - Universal IaC skill
3. **Kubernetes** - Most in-demand container orchestration
4. **Working examples** - Not just code, but documented workflows
5. **Integration** - How tools work together
6. **Best practices** - Security, testing, monitoring

---

## **Job Market Alignment**

**Most Requested Skills (in order):**
1. Kubernetes ⭐⭐⭐⭐⭐
2. Terraform ⭐⭐⭐⭐⭐
3. Docker ⭐⭐⭐⭐⭐
4. CI/CD (GitHub Actions, GitLab, Jenkins) ⭐⭐⭐⭐
5. AWS/Azure/GCP ⭐⭐⭐⭐
6. Python/Bash scripting ⭐⭐⭐
7. Ansible ⭐⭐⭐
8. Monitoring (Prometheus, Grafana) ⭐⭐⭐

**Your Portfolio After This Roadmap:**
- ✅ All top 7 skills covered
- ✅ Enterprise stack (GitLab + Terraform + Kubernetes)
- ✅ Startup stack (GitHub + Docker + AWS)
- ✅ Real integration examples
- ✅ Security and best practices

**Estimated Timeline:** 4-5 weeks of focused work

**Result:** A portfolio that demonstrates enterprise-level DevOps skills across the most in-demand tools and platforms.
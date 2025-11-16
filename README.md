# DevOps Portfolio - Kenneth Howard

Production-grade DevOps projects demonstrating container orchestration, infrastructure automation, observability, and CI/CD expertise.

---

## 👨‍💻 About

Mid-level DevOps Engineer showcasing hands-on experience with modern DevOps tooling and practices. This portfolio emphasizes **production-ready implementations** rather than basic tutorials, with a focus on Kubernetes, containerization, infrastructure as code, and observability.

---

## 🎯 Core Competencies

| Category | Technologies | Proficiency |
|----------|-------------|-------------|
| **Container Orchestration** | Kubernetes, Helm, Docker, Docker Compose | ⭐⭐⭐⭐⭐ |
| **Infrastructure as Code** | Terraform, CloudFormation | ⭐⭐⭐⭐ |
| **CI/CD** | GitHub Actions, Jenkins | ⭐⭐⭐⭐ |
| **Observability / Monitoring** | Prometheus, Grafana, Node.js Metrics | ⭐⭐⭐⭐ |
| **Cloud Platforms** | AWS (via Terraform) | ⭐⭐⭐ |
| **Scripting & Automation** | Bash, Python (learning) | ⭐⭐⭐⭐ |
| **Version Control** | Git, GitHub | ⭐⭐⭐⭐ |

---

## 📁 Featured Projects

### 🐳 [Container Orchestration](./03-containers/)
**Production Kubernetes deployment with Helm charts**

- Multi-service orchestration (Node.js, PostgreSQL, Redis)
- Production-ready Helm chart with dev/prod environments
- Auto-scaling with HorizontalPodAutoscaler
- Container optimization and security scanning

**Technologies:** Docker, Kubernetes, Helm, Docker Compose, Trivy, GHCR

**[View Project →](./03-containers/)**

---

### 📊 [Observability & Monitoring](./05-observability/)
**Node.js application monitored with Prometheus and Grafana on Kubernetes**

- Node.js app exposing metrics via `prom-client`
- Prometheus scrapes metrics, Grafana visualizes:
  - HTTP Request Rate
  - Memory Usage
  - App Status
- Full Kubernetes manifests included
- Grafana dashboard JSON included

**Technologies:** Node.js, Prometheus, Grafana, Kubernetes, Docker

**[View Project →](./05-observability/)**

---

### 🏗️ [Infrastructure as Code](./02-infra-as-code/terraform/)
**Modular Terraform for AWS infrastructure**

- VPC, EC2, Security Groups, IAM roles
- Remote state management (S3 + DynamoDB locking)
- Reusable modules and input validation
- Dynamic security group rules

**Technologies:** Terraform, AWS (VPC, EC2, S3, IAM), HCL

**[View Project →](./02-infra-as-code/terraform/)**

---

### 🔄 [CI/CD Pipelines](./01-ci-cd-pipelines/)
**Enterprise-grade continuous integration and deployment**

- GitHub Actions: reusable workflows, matrix builds, artifact management
- Jenkins Shared Libraries: reusable Groovy pipelines, unit-tested, integration with Ansible

**Technologies:** GitHub Actions, Jenkins, Groovy, YAML

**[View Project →](./01-ci-cd-pipelines/)**

---

### 🔧 [Automation Scripts](./04-automation-scripts/)
**Production-ready deployment and monitoring automation**

- Bash scripts with error handling, logging, retry logic
- Python utilities (in progress)

**Technologies:** Bash, Python, AWS S3, MySQL, PostgreSQL, Redis

**[View Project →](./04-automation-scripts/)**

---

## 🎓 Technical Highlights

### Production Thinking
- ✅ Multi-environment configurations (dev, staging, prod)
- ✅ Security hardening (non-root users, vulnerability scanning)
- ✅ Health checks and monitoring integration
- ✅ Auto-scaling and high availability
- ✅ Error handling and rollback strategies
- ✅ Comprehensive documentation

### DevOps Practices
- ✅ Infrastructure as Code (GitOps-ready)
- ✅ Immutable infrastructure patterns
- ✅ Container optimization techniques
- ✅ Security scanning in CI/CD pipelines
- ✅ Multi-service orchestration
- ✅ Automated deployment workflows

---

## 🛠️ Technology Stack

**Container & Orchestration:**
- Docker 24.x, Docker Compose
- Kubernetes 1.28+, Helm 3.12+
- Minikube (local development)

**Infrastructure & Cloud:**
- Terraform 1.5+
- AWS (VPC, EC2, S3, IAM, CloudWatch)

**CI/CD:**
- GitHub Actions
- Jenkins with Shared Libraries
- GitHub Container Registry (GHCR)

**Languages & Tools:**
- Bash scripting
- Python (learning)
- Git, GitHub
- HCL (Terraform)
- YAML

**Application Stack:**
- Node.js 22
- PostgreSQL 15
- Redis 7
- Express.js

**Security & Monitoring:**
- Trivy (vulnerability scanning)
- AWS CloudWatch
- Container health checks
- Resource monitoring

---

## 🚀 Getting Started

Each project includes comprehensive documentation with:
- Prerequisites and installation steps
- Architecture diagrams
- Usage examples
- Troubleshooting guides
- Production considerations

**Start with:** [Container Orchestration](./03-containers/) - showcases the full stack from Docker optimization through Kubernetes deployment.

---

## 🎯 Portfolio Approach

**Focus:** Quality over quantity
- Production-ready implementations vs. basic tutorials
- Multi-environment thinking throughout
- Security and monitoring integrated from the start
- Complete documentation and operational guides

**Why this approach?**
Demonstrates depth of understanding in core DevOps skills rather than superficial knowledge across many tools.

---

## 📬 Connect

- **GitHub:** [@jedi7910](https://github.com/jedi7910)
- **Portfolio:** [github.com/jedi7910/devops-sre-portfolio](https://github.com/jedi7910/devops-sre-portfolio)

---

## 📄 License

This portfolio is available for viewing and reference. Individual projects may have their own licenses. See project-specific LICENSE files for details.

---

**Built with:** Kubernetes • Helm • Docker • Terraform • GitHub Actions • Jenkins • Bash • AWS

**Last Updated:** November 2025
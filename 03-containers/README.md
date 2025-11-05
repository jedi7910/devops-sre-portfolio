# Container Orchestration Projects

This section demonstrates container expertise from Docker fundamentals through production Kubernetes deployments with Helm.

## 📁 Projects Overview

### 1. [Docker Multi-Stage Builds](./docker-nodejs-demo/)
**Focus:** Container optimization and Docker Compose orchestration

- Multi-stage Dockerfile optimization (950MB → 180MB)
- Docker Compose multi-service stack
- Security scanning and vulnerability remediation
- CI/CD integration with GitHub Container Registry
- Production-ready health checks and monitoring

**Skills:** Docker, Docker Compose, Container Security, Image Optimization

---

### 2. [Kubernetes + Helm Charts](./k8s-helm-demo/)
**Focus:** Production Kubernetes deployment with Helm

- Production-ready Helm chart
- Multi-environment configuration (dev, prod)
- HorizontalPodAutoscaler for auto-scaling
- Multi-service orchestration (Node.js, PostgreSQL, Redis)
- ConfigMaps, Secrets, Ingress, Services
- Complete operational documentation

**Skills:** Kubernetes, Helm, Container Orchestration, Multi-Environment Management

---

## 🎓 Learning Progression

This section follows a natural learning path:
```
Docker Fundamentals
    ↓
Multi-Stage Optimization
    ↓
Docker Compose (multi-service)
    ↓
Kubernetes Core Concepts
    ↓
Helm Charts (production packaging)
    ↓
Multi-Environment Deployment
```

### Docker Project → Kubernetes Project
- **Docker project** builds the container image
- **Kubernetes project** orchestrates that container at scale
- Same application, different deployment strategies

---

## 🏗️ Architecture Evolution

### Phase 1: Docker Compose (Development)
```
┌─────────────────────────────────┐
│     Docker Compose              │
│  ┌─────────┐  ┌──────────┐    │
│  │ Node.js │  │PostgreSQL│    │
│  └─────────┘  └──────────┘    │
│       └──────┬──────┘          │
│           Redis                 │
└─────────────────────────────────┘
```
**Good for:** Local development, testing, small deployments

---

### Phase 2: Kubernetes + Helm (Production)
```
                 ┌─────────────┐
                 │   Ingress   │
                 └──────┬──────┘
                        │
                 ┌──────▼──────┐
                 │   Service   │
                 └──────┬──────┘
                        │
    ┌──────────────────┼──────────────┐
    │                  │              │
┌───▼───┐         ┌───▼───┐     ┌───▼───┐
│ Pod 1 │         │ Pod 2 │     │ Pod 3 │
│NodeJS │         │NodeJS │     │NodeJS │
└───┬───┘         └───┬───┘     └───┬───┘
    │                  │              │
    └──────────────────┼──────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐           ┌────────▼──────┐
│  PostgreSQL    │           │     Redis     │
└────────────────┘           └───────────────┘
```
**Good for:** Production, auto-scaling, high availability, multi-environment

---

## 🔑 Key Differences

| Feature | Docker Compose | Kubernetes + Helm |
|---------|---------------|-------------------|
| **Scale** | Single host | Multi-node cluster |
| **HA** | Manual | Automatic (self-healing) |
| **Auto-scaling** | No | Yes (HPA) |
| **Load Balancing** | Basic | Advanced (Services, Ingress) |
| **Rollback** | Manual | Built-in |
| **Multi-Env** | Multiple files | Values files |
| **Health Checks** | Basic | Advanced (liveness, readiness, startup) |
| **Secrets** | .env files | Kubernetes Secrets |
| **Best For** | Dev/Test | Production |

---

## 🚀 Quick Start

### Docker Project
```bash
cd docker-nodejs-demo
docker-compose up -d
curl http://localhost:3000/health
```

### Kubernetes Project
```bash
cd k8s-helm-demo
minikube start
helm install demo ./nodejs-demo -n demo --create-namespace
kubectl get pods -n demo
```

---

## 📊 Skills Demonstrated

### Docker Skills
- ✅ Multi-stage builds for optimization
- ✅ Non-root users and security contexts
- ✅ Health checks and monitoring
- ✅ Docker Compose orchestration
- ✅ Volume management
- ✅ Container networking
- ✅ Image tagging and registry management
- ✅ Security scanning (Trivy)

### Kubernetes Skills
- ✅ Deployments, Services, ConfigMaps, Secrets
- ✅ Ingress for external access
- ✅ HorizontalPodAutoscaler
- ✅ Health probes (liveness, readiness, startup)
- ✅ Resource requests and limits
- ✅ Multi-service orchestration
- ✅ Service discovery and DNS

### Helm Skills
- ✅ Chart creation and structure
- ✅ Template development with helpers
- ✅ Multi-environment management
- ✅ Values file inheritance
- ✅ Conditional logic and loops
- ✅ Release management

---

## 🎯 Production Considerations

### What's Production-Ready
- ✅ Security hardening (non-root, scanning)
- ✅ Resource limits and requests
- ✅ Health checks and probes
- ✅ Multi-environment configuration
- ✅ Auto-scaling capabilities
- ✅ Operational documentation

### What Would Be Added for Enterprise
- [ ] StatefulSets for databases
- [ ] PersistentVolumes with proper storage classes
- [ ] Network policies
- [ ] Pod disruption budgets
- [ ] Service mesh (Istio/Linkerd)
- [ ] GitOps (ArgoCD/FluxCD)
- [ ] Observability stack (Prometheus/Grafana)

---

## 📚 Technologies Used

**Container Runtime:**
- Docker 24.x
- containerd

**Orchestration:**
- Kubernetes 1.28+
- Helm 3.12+
- Minikube (local development)

**Application Stack:**
- Node.js 22 (Alpine)
- PostgreSQL 15
- Redis 7

**CI/CD:**
- GitHub Actions
- GitHub Container Registry

**Security:**
- Trivy (vulnerability scanning)
- Non-root containers
- Secrets management

---

## 🔗 Related Projects

- **[CI/CD Pipelines](../01-ci-cd-pipelines/)** - Automated builds and deployments
- **[Infrastructure as Code](../02-infra-as-code/)** - Terraform for provisioning
- **[Automation Scripts](../04-automation-scripts/)** - Deployment and monitoring scripts

---

## 📖 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Author:** Kenneth Howard  
**Portfolio:** [github.com/jedi7910/devops-sre-portfolio](https://github.com/jedi7910/devops-sre-portfolio)
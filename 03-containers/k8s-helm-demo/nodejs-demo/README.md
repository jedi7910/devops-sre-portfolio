# Kubernetes Helm Demo

Production-ready Helm chart for deploying a multi-service Node.js application with PostgreSQL and Redis.

## 🎯 Features

- ✅ **Helm Chart** - Reusable, parameterized Kubernetes deployment
- ✅ **Multi-Environment** - Dev, staging, prod configurations via values files
- ✅ **Auto-Scaling** - HorizontalPodAutoscaler based on CPU/memory
- ✅ **Health Checks** - Liveness, readiness, and startup probes
- ✅ **Security** - Non-root containers, secrets management
- ✅ **Multi-Service** - Node.js app + PostgreSQL + Redis

## 📁 Project Structure
```
k8s-helm-demo/
├── manifests/              # Raw K8s YAML (learning phase)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ...
└── nodejs-demo/            # Helm Chart (production-ready)
    ├── Chart.yaml          # Chart metadata
    ├── values.yaml         # Default configuration
    ├── values-dev.yaml     # Development overrides
    ├── values-prod.yaml    # Production overrides
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── configmap.yaml
        ├── secret.yaml
        ├── postgres-deployment.yaml
        ├── postgres-service.yaml
        ├── redis-deployment.yaml
        ├── redis-service.yaml
        ├── hpa.yaml
        └── ingress.yaml
```

## 🚀 Prerequisites

### Required Tools
- Docker Desktop (running)
- Minikube
- kubectl
- Helm 3

### Installation
```bash
# Install Minikube (Linux/WSL2)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 🏗️ Local Setup

### 1. Start Minikube Cluster
```bash
# Start cluster
minikube start --driver=docker --cpus=4 --memory=8192

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Deploy with Helm

#### Development Environment
```bash
helm install nodejs-dev ./nodejs-demo \
  --namespace nodejs-demo-dev \
  --create-namespace \
  -f nodejs-demo/values-dev.yaml

# Watch pods come up
kubectl get pods -n nodejs-demo-dev -w
```

#### Production Environment
```bash
helm install nodejs-prod ./nodejs-demo \
  --namespace nodejs-demo-prod \
  --create-namespace \
  -f nodejs-demo/values-prod.yaml

# Watch pods come up
kubectl get pods -n nodejs-demo-prod -w
```

### 3. Access the Application
```bash
# Get service URL
minikube service nodejs-dev-nodejs-demo-service -n nodejs-demo-dev --url

# Test from inside cluster
kubectl run test-curl --rm -it --image=curlimages/curl -n nodejs-demo-dev -- sh
# Inside pod:
curl http://nodejs-dev-nodejs-demo-service/health
curl http://nodejs-dev-nodejs-demo-service/
```

## 🎛️ Configuration

### Environment Comparison

| Setting | Development | Production |
|---------|------------|------------|
| **Replicas** | 1 (fixed) | 5 (with HPA) |
| **CPU Limit** | 200m | 1000m |
| **Memory Limit** | 256Mi | 1Gi |
| **Auto-scaling** | Disabled | Enabled (3-20 pods) |
| **Log Level** | debug | warn |
| **Image Tag** | main-c599074 | v1.0.0 |

### Key Values
```yaml
# values.yaml (defaults)
replicaCount: 3

image:
  repository: ghcr.io/jedi7910/devops-sre-portfolio/docker-nodejs-demo
  tag: "main-c599074"

resources:
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 50
```

## 📊 Architecture
```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Service   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼───┐          ┌───▼───┐        ┌───▼───┐
    │ Pod 1 │          │ Pod 2 │        │ Pod 3 │
    │NodeJS │          │NodeJS │        │NodeJS │
    └───┬───┘          └───┬───┘        └───┬───┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
    ┌───────▼────────┐           ┌────────▼──────┐
    │  PostgreSQL    │           │     Redis     │
    │  (Deployment)  │           │  (Deployment) │
    └────────────────┘           └───────────────┘
```

## 🔄 Operations

### Upgrade Release
```bash
helm upgrade nodejs-dev ./nodejs-demo \
  --namespace nodejs-demo-dev \
  -f nodejs-demo/values-dev.yaml
```

### Rollback
```bash
# List releases
helm list -n nodejs-demo-dev

# Rollback to previous version
helm rollback nodejs-dev -n nodejs-demo-dev

# Rollback to specific revision
helm rollback nodejs-dev 2 -n nodejs-demo-dev
```

### Scale Manually
```bash
# Override replicas
helm upgrade nodejs-dev ./nodejs-demo \
  --namespace nodejs-demo-dev \
  --set replicaCount=3
```

### View Logs
```bash
# All pods
kubectl logs -f -l app.kubernetes.io/name=nodejs-demo -n nodejs-demo-dev

# Specific pod
kubectl logs -f <pod-name> -n nodejs-demo-dev

# Previous container (if crashed)
kubectl logs <pod-name> -n nodejs-demo-dev --previous
```

### Debug
```bash
# Describe pod
kubectl describe pod <pod-name> -n nodejs-demo-dev

# Check events
kubectl get events -n nodejs-demo-dev --sort-by='.lastTimestamp'

# Exec into pod
kubectl exec -it <pod-name> -n nodejs-demo-dev -- sh
```

## 🎨 Customization

### Override Single Values
```bash
helm install my-release ./nodejs-demo \
  --set replicaCount=5 \
  --set image.tag=v2.0.0 \
  --set env.nodeEnv=staging
```

### Use Different Values File
```bash
helm install my-release ./nodejs-demo \
  -f custom-values.yaml
```

### Disable Components
```bash
# Disable PostgreSQL (use external DB)
helm install my-release ./nodejs-demo \
  --set postgresql.enabled=false

# Disable Redis
helm install my-release ./nodejs-demo \
  --set redisCache.enabled=false

# Disable Ingress
helm install my-release ./nodejs-demo \
  --set ingress.enabled=false
```

## 🔒 Security Notes

### Secrets Management
**Current (Demo):**
```yaml
secrets:
  dbUser: appuser
  dbPassword: changeme_in_production
```

**Production Best Practices:**
- Use external secret management (HashiCorp Vault, AWS Secrets Manager)
- Use Sealed Secrets or External Secrets Operator
- Never commit real credentials to Git
- Rotate secrets regularly

### Image Tags
**Current (Demo):** All environments use `main-c599074`

**Production Strategy:**
```yaml
# Development
image:
  tag: develop  # Auto-built from develop branch

# Staging
image:
  tag: staging  # Or use commit SHA

# Production
image:
  tag: v1.0.0  # Semantic version tags only
```

## 🧹 Cleanup
```bash
# Uninstall release
helm uninstall nodejs-dev -n nodejs-demo-dev

# Delete namespace
kubectl delete namespace nodejs-demo-dev

# Stop Minikube
minikube stop

# Delete cluster (removes all data)
minikube delete
```

## 📚 Learning Path

This project demonstrates:

1. **Raw Manifests** (`manifests/`) - Understanding K8s primitives
2. **Helm Charts** (`nodejs-demo/`) - Production packaging and reusability
3. **Multi-Environment** (values files) - Configuration management
4. **Auto-Scaling** (HPA) - Dynamic resource allocation
5. **Service Mesh** (Ingress) - Traffic routing and TLS

## 🎯 Production Considerations

### What's Missing for Real Production?
- [ ] StatefulSets for PostgreSQL (instead of Deployment)
- [ ] PersistentVolumes with proper storage class
- [ ] Network policies for pod-to-pod communication
- [ ] Pod Disruption Budgets for HA
- [ ] Resource quotas and limit ranges
- [ ] Monitoring (Prometheus + Grafana)
- [ ] Logging (EFK stack or Loki)
- [ ] Service mesh (Istio/Linkerd)
- [ ] GitOps (ArgoCD/FluxCD)

### Enhancements Roadmap
See Phase 7: Strategic Enhancements for planned improvements.

## 🛠️ Troubleshooting

### Common Issues

**Pods in CrashLoopBackOff:**
```bash
# Check logs
kubectl logs <pod-name> -n <namespace>

# Check previous crash
kubectl logs <pod-name> -n <namespace> --previous

# Common causes:
# - Missing database connection
# - Wrong image tag
# - Insufficient resources
```

**Minikube Not Starting:**
```bash
# Ensure Docker is running
docker ps

# Delete and recreate
minikube delete
minikube start --driver=docker
```

**Image Pull Errors:**
```bash
# Check if image exists
docker pull ghcr.io/jedi7910/devops-sre-portfolio/docker-nodejs-demo:main-c599074

# Verify tag in values
cat values.yaml | grep tag
```

**Service Not Accessible:**
```bash
# Check service exists
kubectl get svc -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Test from inside cluster
kubectl run test --rm -it --image=curlimages/curl -n <namespace> -- sh
```

## 🤝 Contributing

This is a portfolio project, but feedback welcome!

## 📄 License

MIT License - See LICENSE file for details

---

**Built with:** Kubernetes, Helm, Docker, Node.js, PostgreSQL, Redis

**Author:** Kevin Howard  
**Portfolio:** [github.com/jedi7910/devops-sre-portfolio](https://github.com/jedi7910/devops-sre-portfolio)
EOF
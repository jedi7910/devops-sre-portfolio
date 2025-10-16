# Kubernetes Lab: Container Orchestration & Helm Charts

## Lab Overview

**Duration:** 1-1.5 weeks  
**Difficulty:** Advanced  
**Prerequisites:** Completed Docker lab, Docker image pushed to GHCR

**Lab Location:** `03-containers/k8s-helm-demo/`

### What You'll Build:
1. Kubernetes cluster (local with Minikube or Kind)
2. Core Kubernetes resources (Deployments, Services, ConfigMaps, Secrets)
3. Advanced resources (Ingress, HPA, PersistentVolumes)
4. Production-ready Helm chart with multi-environment support
5. GitOps CI/CD pipeline for automated deployments

### Skills Demonstrated:
- Kubernetes resource management
- Container orchestration at scale
- Helm templating and packaging
- Multi-environment configuration
- Auto-scaling and self-healing
- CI/CD integration with K8s

---

## Lab Structure

```
03-containers/k8s-helm-demo/
├── manifests/              # Raw Kubernetes YAML
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── pvc.yaml
├── helm-chart/             # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── ingress.yaml
│       └── hpa.yaml
└── README.md
```

---

## Part 1: Setup Local Kubernetes Cluster

### Learning: Why Local Kubernetes?

**Options for learning K8s:**
- **Minikube:** Full K8s cluster in VM (most features)
- **Kind:** K8s in Docker (lightweight, fast)
- **Docker Desktop:** Built-in K8s (easiest, but limited)

We'll use **Minikube** for full feature support.

### Task 1.1: Install Minikube

**On WSL2/Linux:**
```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify installation
minikube version
```

**On macOS:**
```bash
brew install minikube
```

**On Windows:**
```powershell
choco install minikube
```

### Task 1.2: Install kubectl

**On WSL2/Linux:**
```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

**On macOS:**
```bash
brew install kubectl
```

### Task 1.3: Start Minikube Cluster

```bash
# Start cluster with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192

# Verify cluster is running
kubectl cluster-info
kubectl get nodes

# Enable addons we'll need
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# View dashboard (optional)
minikube dashboard
```

**Expected output:**
```
✅ minikube v1.x.x on Ubuntu
✅ Using the docker driver
✅ Starting control plane node minikube in cluster minikube
✅ Kubernetes v1.28.x is now available
```

---

## Part 2: Core Kubernetes Resources

### Task 2.1: Create Namespace

**File: `manifests/namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nodejs-demo
  labels:
    name: nodejs-demo
    environment: development
```

**Why namespaces?**
- Logical isolation between environments/projects
- Resource quotas per namespace
- RBAC policies per namespace
- Cleaner organization

**Apply:**
```bash
kubectl apply -f manifests/namespace.yaml
kubectl get namespaces
```

---

### Task 2.2: Create ConfigMap

**File: `manifests/configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nodejs-app-config
  namespace: nodejs-demo
data:
  # Application configuration
  NODE_ENV: "production"
  PORT: "3000"
  LOG_LEVEL: "info"
  
  # Database configuration (non-sensitive)
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "myapp"
  
  # Redis configuration
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
```

**Why ConfigMaps?**
- Separate configuration from container images
- Update config without rebuilding images
- Share config across multiple pods
- Environment-specific configuration

---

### Task 2.3: Create Secrets

**File: `manifests/secret.yaml`**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nodejs-app-secrets
  namespace: nodejs-demo
type: Opaque
stringData:
  # Database credentials (will be base64 encoded)
  DB_USER: "appuser"
  DB_PASSWORD: "changeme_in_production"
  
  # GHCR credentials (for pulling private images)
  # You'll create this separately with kubectl create secret docker-registry
```

**Create GHCR pull secret:**
```bash
# Create secret for pulling from GitHub Container Registry
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --namespace=nodejs-demo

# Verify secrets
kubectl get secrets -n nodejs-demo
```

**Security Note:** Never commit actual passwords to Git! Use placeholders in manifests.

---

### Task 2.4: Create Deployment

**File: `manifests/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
  namespace: nodejs-demo
  labels:
    app: nodejs-app
    version: v1
spec:
  replicas: 3  # Run 3 pods for high availability
  selector:
    matchLabels:
      app: nodejs-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max 1 extra pod during update
      maxUnavailable: 0  # Keep all pods running during update
  template:
    metadata:
      labels:
        app: nodejs-app
        version: v1
    spec:
      # Use GHCR pull secret
      imagePullSecrets:
        - name: ghcr-secret
      
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      
      containers:
      - name: nodejs-app
        image: ghcr.io/YOUR_USERNAME/devops-sre-portfolio/docker-nodejs-demo:latest
        imagePullPolicy: Always
        
        ports:
        - name: http
          containerPort: 3000
          protocol: TCP
        
        # Environment variables from ConfigMap
        envFrom:
        - configMapRef:
            name: nodejs-app-config
        
        # Sensitive environment variables from Secret
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: nodejs-app-secrets
              key: DB_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nodejs-app-secrets
              key: DB_PASSWORD
        
        # Resource limits (IMPORTANT for production)
        resources:
          requests:
            cpu: 100m      # 0.1 CPU cores
            memory: 128Mi  # 128 MB
          limits:
            cpu: 500m      # 0.5 CPU cores max
            memory: 512Mi  # 512 MB max
        
        # Liveness probe (restart if unhealthy)
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        # Readiness probe (remove from load balancer if not ready)
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        # Startup probe (for slow-starting apps)
        startupProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30  # 30 * 5s = 150s max startup time
```

**Key Concepts:**

**Replicas:** Multiple pod instances for HA
**Rolling Update:** Zero-downtime deployments
**Probes:**
- **Liveness:** Is the app alive? (restart if not)
- **Readiness:** Is the app ready for traffic? (remove from service if not)
- **Startup:** Give slow apps time to start

**Resource Requests/Limits:**
- **Requests:** Guaranteed resources (scheduler uses this)
- **Limits:** Maximum resources (pod gets killed if exceeded)

**Apply:**
```bash
# Apply all resources
kubectl apply -f manifests/

# Watch pods come up
kubectl get pods -n nodejs-demo -w

# Check pod logs
kubectl logs -n nodejs-demo -l app=nodejs-app

# Describe deployment
kubectl describe deployment nodejs-app -n nodejs-demo
```

---

### Task 2.5: Create Service

**File: `manifests/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app-service
  namespace: nodejs-demo
  labels:
    app: nodejs-app
spec:
  type: ClusterIP  # Internal service (change to LoadBalancer for external access)
  selector:
    app: nodejs-app
  ports:
  - name: http
    protocol: TCP
    port: 80        # Service port
    targetPort: 3000  # Container port
  sessionAffinity: None
```

**Service Types:**
- **ClusterIP:** Internal only (default)
- **NodePort:** Exposes on each node's IP
- **LoadBalancer:** Cloud provider load balancer
- **ExternalName:** DNS CNAME

**Apply and test:**
```bash
kubectl apply -f manifests/service.yaml

# Get service details
kubectl get svc -n nodejs-demo

# Test service from within cluster
kubectl run test-pod --rm -it --image=curlimages/curl --namespace=nodejs-demo -- sh
# Inside pod:
curl http://nodejs-app-service/health
```

---

### Task 2.6: Create Ingress (External Access)

**File: `manifests/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nodejs-app-ingress
  namespace: nodejs-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: nodejs-demo.local  # Add to /etc/hosts
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nodejs-app-service
            port:
              number: 80
```

**Setup ingress:**
```bash
kubectl apply -f manifests/ingress.yaml

# Get Minikube IP
minikube ip

# Add to /etc/hosts (Linux/Mac)
echo "$(minikube ip) nodejs-demo.local" | sudo tee -a /etc/hosts

# Test from browser or curl
curl http://nodejs-demo.local/health
```

---

## Part 3: Advanced Resources

### Task 3.1: Horizontal Pod Autoscaler (HPA)

**File: `manifests/hpa.yaml`**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nodejs-app-hpa
  namespace: nodejs-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nodejs-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale at 70% CPU
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # Scale at 80% memory
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 50  # Scale down max 50% of pods at once
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100  # Double pods if needed
        periodSeconds: 15
```

**Test autoscaling:**
```bash
kubectl apply -f manifests/hpa.yaml

# Watch HPA in action
kubectl get hpa -n nodejs-demo -w

# Generate load (in another terminal)
kubectl run load-generator --rm -it --image=busybox --namespace=nodejs-demo -- sh
# Inside pod:
while true; do wget -q -O- http://nodejs-app-service; done
```

---

### Task 3.2: PersistentVolumeClaim

**File: `manifests/pvc.yaml`**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: nodejs-demo
spec:
  accessModes:
    - ReadWriteOnce  # Single node read-write
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # Uses default storage class
```

**Add to deployment:**
```yaml
# In deployment.yaml, add under spec.template.spec:
volumes:
- name: app-data
  persistentVolumeClaim:
    claimName: app-data-pvc

# In containers section:
volumeMounts:
- name: app-data
  mountPath: /app/data
```

---

### Task 3.3: ResourceQuota & LimitRange

**File: `manifests/resourcequota.yaml`**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: nodejs-demo-quota
  namespace: nodejs-demo
spec:
  hard:
    requests.cpu: "4"       # Max 4 CPU cores requested
    requests.memory: "8Gi"  # Max 8GB memory requested
    limits.cpu: "8"         # Max 8 CPU cores limit
    limits.memory: "16Gi"   # Max 16GB memory limit
    pods: "20"              # Max 20 pods
    services: "10"          # Max 10 services
---
apiVersion: v1
kind: LimitRange
metadata:
  name: nodejs-demo-limits
  namespace: nodejs-demo
spec:
  limits:
  - max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

---

## Part 4: Helm Charts

### Learning: Why Helm?

**Problems without Helm:**
- Duplicate YAML for each environment
- Hard to manage values across files
- No versioning of deployments
- Complex variable substitution

**Helm solves:**
- Single source of truth (templates)
- Values files for each environment
- Package management (install/upgrade/rollback)
- Release versioning

### Task 4.1: Create Helm Chart Structure

```bash
# Create chart directory
mkdir -p helm-chart/templates

# Create Chart.yaml
```

**File: `helm-chart/Chart.yaml`**

```yaml
apiVersion: v2
name: nodejs-demo
description: A Helm chart for Node.js demo application
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - nodejs
  - demo
  - microservice
maintainers:
  - name: Your Name
    email: your.email@example.com
```

---

### Task 4.2: Create Values Files

**File: `helm-chart/values.yaml` (Defaults)**

```yaml
# Default values for nodejs-demo
replicaCount: 3

image:
  repository: ghcr.io/YOUR_USERNAME/devops-sre-portfolio/docker-nodejs-demo
  pullPolicy: Always
  tag: "latest"

imagePullSecrets:
  - name: ghcr-secret

nameOverride: ""
fullnameOverride: ""

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: nodejs-demo.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

env:
  nodeEnv: production
  port: "3000"
  logLevel: info
  dbHost: postgres-service
  dbPort: "5432"
  dbName: myapp
  redisHost: redis-service
  redisPort: "6379"

secrets:
  dbUser: appuser
  dbPassword: changeme

probes:
  liveness:
    enabled: true
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    enabled: true
    path: /health
    initialDelaySeconds: 10
    periodSeconds: 5
  startup:
    enabled: true
    path: /health
    failureThreshold: 30
    periodSeconds: 5
```

**File: `helm-chart/values-dev.yaml` (Development overrides)**

```yaml
replicaCount: 1

image:
  tag: "develop"

env:
  nodeEnv: development
  logLevel: debug

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false

ingress:
  hosts:
    - host: nodejs-demo-dev.local
      paths:
        - path: /
          pathType: Prefix
```

**File: `helm-chart/values-prod.yaml` (Production overrides)**

```yaml
replicaCount: 5

image:
  tag: "v1.0.0"  # Use specific version tag

env:
  nodeEnv: production
  logLevel: warn

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

ingress:
  enabled: true
  hosts:
    - host: nodejs-demo.production.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: nodejs-demo-tls
      hosts:
        - nodejs-demo.production.com
```

---

### Task 4.3: Create Helm Templates

**File: `helm-chart/templates/_helpers.tpl`**

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "nodejs-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nodejs-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nodejs-demo.labels" -}}
helm.sh/chart: {{ include "nodejs-demo.chart" . }}
{{ include "nodejs-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nodejs-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nodejs-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nodejs-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

**File: `helm-chart/templates/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nodejs-demo.fullname" . }}
  labels:
    {{- include "nodejs-demo.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "nodejs-demo.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "nodejs-demo.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        env:
        - name: NODE_ENV
          value: {{ .Values.env.nodeEnv | quote }}
        - name: PORT
          value: {{ .Values.env.port | quote }}
        - name: LOG_LEVEL
          value: {{ .Values.env.logLevel | quote }}
        - name: DB_HOST
          value: {{ .Values.env.dbHost | quote }}
        - name: DB_PORT
          value: {{ .Values.env.dbPort | quote }}
        - name: DB_NAME
          value: {{ .Values.env.dbName | quote }}
        - name: REDIS_HOST
          value: {{ .Values.env.redisHost | quote }}
        - name: REDIS_PORT
          value: {{ .Values.env.redisPort | quote }}
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: {{ include "nodejs-demo.fullname" . }}-secrets
              key: dbUser
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "nodejs-demo.fullname" . }}-secrets
              key: dbPassword
        {{- if .Values.probes.liveness.enabled }}
        livenessProbe:
          httpGet:
            path: {{ .Values.probes.liveness.path }}
            port: http
          initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
          periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
        {{- end }}
        {{- if .Values.probes.readiness.enabled }}
        readinessProbe:
          httpGet:
            path: {{ .Values.probes.readiness.path }}
            port: http
          initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
          periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
        {{- end }}
        {{- if .Values.probes.startup.enabled }}
        startupProbe:
          httpGet:
            path: {{ .Values.probes.startup.path }}
            port: http
          failureThreshold: {{ .Values.probes.startup.failureThreshold }}
          periodSeconds: {{ .Values.probes.startup.periodSeconds }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

**Similarly create:** `service.yaml`, `ingress.yaml`, `hpa.yaml`, `configmap.yaml`, `secret.yaml`

---

### Task 4.4: Install Helm Chart

```bash
# Lint chart (check for errors)
helm lint helm-chart/

# Dry run to see what would be created
helm install nodejs-demo helm-chart/ \
  --namespace nodejs-demo \
  --create-namespace \
  --dry-run --debug

# Install for development
helm install nodejs-demo helm-chart/ \
  --namespace nodejs-demo \
  --create-namespace \
  --values helm-chart/values-dev.yaml

# Check installation
helm list -n nodejs-demo
kubectl get all -n nodejs-demo

# Upgrade with production values
helm upgrade nodejs-demo helm-chart/ \
  --namespace nodejs-demo \
  --values helm-chart/values-prod.yaml

# Rollback if needed
helm rollback nodejs-demo -n nodejs-demo
```

---

## Part 5: CI/CD Integration

### Task 5.1: GitHub Actions K8s Deployment

**File: `.github/workflows/k8s-deploy.yml`**

```yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]
    paths:
      - '03-containers/docker-nodejs-demo/**'
      - '03-containers/k8s-helm-demo/**'
      - '.github/workflows/k8s-deploy.yml'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/docker-nodejs-demo

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./03-containers/docker-nodejs-demo
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install kubectl
        uses: azure/setup-kubectl@v3

      - name: Install Helm
        uses: azure/setup-helm@v3
        with:
          version: '3.12.0'

      - name: Configure kubectl
        run: |
          # For production, use: kubectl config from secrets
          # For demo, use Minikube or local cluster
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Deploy with Helm
        run: |
          helm upgrade --install nodejs-demo \
            ./03-containers/k8s-helm-demo/helm-chart \
            --namespace nodejs-demo \
            --create-namespace \
            --values ./03-containers/k8s-helm-demo/helm-chart/values-prod.yaml \
            --set image.tag=${{ github.sha }} \
            --wait

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/nodejs-demo -n nodejs-demo
          kubectl get pods -n nodejs-demo
```

---

## Part 6: Documentation

### Task 6.1: Create README

**File: `README.md`**

```markdown
# Kubernetes Helm Demo

Production-ready Kubernetes deployment with Helm charts.

## Features

- ⚓ Helm charts for package management
- 🔄 Multi-environment support (dev, staging, prod)
- 🎯 Horizontal Pod Autoscaling
- 🏥 Health checks (liveness, readiness, startup)
- 🔒 Security contexts and RBAC
- 📊 Resource quotas and limits
- 🚀 GitOps CI/CD integration

## Quick Start

\`\`\`bash
# Start Minikube
minikube start

# Install with Helm
helm install nodejs-demo helm-chart/ \\
  --namespace nodejs-demo \\
  --create-namespace

# Access application
kubectl port-forward -n nodejs-demo svc/nodejs-demo-service 8080:80
curl http://localhost:8080/health
\`\`\`

## Architecture

\`\`\`
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
    └───────┘          └───────┘        └───────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                    ┌──────▼──────┐
                    │     HPA     │
                    └─────────────┘
\`\`\`

## Environments

### Development
\`\`\`bash
helm install nodejs-demo helm-chart/ -f helm-chart/values-dev.yaml
\`\`\`

### Production
\`\`\`bash
helm install nodejs-demo helm-chart/ -f helm-chart/values-prod.yaml
\`\`\`

## Operations

### Scale manually
\`\`\`bash
kubectl scale deployment nodejs-demo --replicas=5 -n nodejs-demo
\`\`\`

### View logs
\`\`\`bash
kubectl logs -f -l app=nodejs-app -n nodejs-demo
\`\`\`

### Rollback deployment
\`\`\`bash
helm rollback nodejs-demo -n nodejs-demo
\`\`\`
\`\`\`

---

## Verification Checklist

- [ ] Minikube cluster running
- [ ] All manifests applied successfully
- [ ] Pods healthy and running
- [ ] Service accessible
- [ ] Ingress configured
- [ ] HPA monitoring metrics
- [ ] Helm chart installable
- [ ] Multi-environment values work
- [ ] CI/CD pipeline deploys successfully
- [ ] Documentation complete

---

**Estimated completion time:** 1-1.5 weeks

# Node.js Monitoring with Prometheus and Grafana

## Overview
This project demonstrates a full observability stack using Prometheus, Grafana, and a Node.js application deployed on Kubernetes.  
It showcases how to expose custom application metrics, scrape them using Prometheus, and visualize them through Grafana dashboards.

The goal of this project is to prove hands-on knowledge of monitoring setup, metrics collection, and dashboard visualization in a cloud-native environment.

---

## Architecture

```
Node.js App → Prometheus → Grafana Dashboard
        ↑           ↑
   Custom metrics   |
   (prom-client)    |
   └────────────────┘
```

Key components:

- Node.js App – emits HTTP and system metrics via `/metrics` endpoint  
- Prometheus – scrapes the Node.js app and stores time-series data  
- Grafana – visualizes Prometheus data through a custom dashboard  
- Kubernetes – hosts and manages all components via YAML manifests

---

## Tech Stack

| Component       | Technology              |
|-----------------|------------------------|
| Language        | Node.js                |
| Monitoring      | Prometheus             |
| Visualization   | Grafana                |
| Containerization| Docker                 |
| Orchestration   | Kubernetes / Minikube  |

---

## Setup & Deployment

### Prerequisites
- Docker  
- Kubernetes (via Minikube or local cluster)  
- kubectl CLI

### Start Kubernetes cluster
```bash
minikube start
```

### Deploy the monitoring stack
```bash
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/
```

This creates:

- Namespace for the project  
- Deployments and Services for Node.js, Prometheus, and Grafana  
- ConfigMaps for Prometheus and Grafana configurations

### Build and run the Node.js app
```bash
cd nodejs-instrumentation
docker build -t monitored-app:v1 .
```

### Port forwarding (local access)
```bash
kubectl port-forward svc/prometheus 9090:9090
kubectl port-forward svc/grafana 3000:3000
kubectl port-forward svc/nodejs-app 8080:3000
```

Access the services:

- Node.js app → http://localhost:8080  
- Prometheus → http://localhost:9090  
- Grafana → http://localhost:3000

---

## Testing / Generating Traffic

To produce a steady stream of requests so Prometheus collects meaningful metrics, you can run a simple curl loop.

**Local (on your machine, hitting port-forwarded service):**
```bash
# Run in foreground (Ctrl+C to stop)
while true; do curl http://localhost:8080/ > /dev/null 2>&1; sleep 5; done

# Run in background
nohup bash -c 'while true; do curl http://localhost:8080/ > /dev/null 2>&1; sleep 5; done' &>/dev/null &
```

**Inside the Kubernetes cluster (ad-hoc pod):**
```bash
kubectl run load-generator --image=curlimages/curl --restart=Never --command -- \
  sh -c "while true; do curl -s http://nodejs-app:3000/ > /dev/null; sleep 5; done"
```

**Reusable Deployment (recommended for longer tests):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: loadgen
        image: curlimages/curl
        command:
          - sh
          - -c
          - while true; do curl -s http://nodejs-app:3000/ > /dev/null; sleep 5; done
```
Apply with:
```bash
kubectl apply -f manifests/load-generator-deployment.yaml
```

**Stop / Cleanup**
- If you ran the local loop in foreground: `Ctrl+C`  
- If you used `nohup`: find the job with `ps` and `kill`, or `pkill -f 'while true; do curl'`  
- For the ad-hoc pod: `kubectl delete pod load-generator`  
- For the Deployment: `kubectl delete deployment load-generator`

---

## Grafana Dashboard

Grafana dashboard JSON: `dashboards/nodejs-app-dashboard.json`

Panels:

1. HTTP Request Rate – total number of requests per second  
2. Memory Usage – runtime memory consumption of the app  
3. App Status – verifies that the service is responding

---

## Node.js Metrics Example

Metrics are exposed using the `prom-client` library:

```js
// Auto-collect default metrics
client.collectDefaultMetrics({ register });

// Custom counter for HTTP requests
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});
```

---

## Dockerfile

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY metrics.js .
EXPOSE 3000
CMD ["node", "metrics.js"]
```

---

## Learning Outcomes

- Built a fully functional observability stack from scratch  
- Created and exposed custom Prometheus metrics using Node.js  
- Deployed monitoring tools via Kubernetes manifests  
- Designed a Grafana dashboard to visualize key application health data

---

## Future Enhancements

- Add alerting rules for Prometheus  
- Integrate Loki for centralized log management  
- Include Kubernetes resource metrics using kube-state-metrics  
- Extend Node.js app to simulate variable load

---

## Author

Kenneth A. Howard  
Cloud / Platform / Security Engineer

---

## License

This project is released under the MIT License.

const express = require('express');
const client = require('prom-client');

const app = express();
const register = new client.Registry();

// Auto-collect default metrics (CPU, memory, etc)
client.collectDefaultMetrics({ register });

// Custom counter for HTTP requests
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
});

// Middleware to track requests
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.labels(req.method, req.path, res.statusCode).inc();
  });
  next();
});

// Endpoints
app.get('/', (req, res) => res.json({ message: 'Hello from monitored app' }));
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});

app.listen(3000, () => console.log('App running on :3000'));
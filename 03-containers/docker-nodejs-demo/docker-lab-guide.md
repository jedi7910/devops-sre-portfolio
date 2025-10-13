# Docker Lab: Multi-stage Builds & Container Orchestration

## Lab Overview

**Duration:** 2-3 days  
**Difficulty:** Intermediate  
**Prerequisites:** Completed GitHub Actions and Terraform

**Lab Location:** `03-containers/docker-nodejs-demo/`

### What You'll Build:
1. Sample Node.js application
2. Multi-stage Dockerfile with optimizations
3. Docker Compose stack (app + database + cache)
4. CI/CD pipeline for automated builds
5. Security scanning integration

### Skills Demonstrated:
- Container optimization techniques
- Multi-stage build patterns
- Docker Compose orchestration
- Security hardening (non-root users, minimal images)
- CI/CD integration with containers

---

## Lab Structure

```
03-containers/docker-nodejs-demo/
├── Dockerfile              # Multi-stage build
├── .dockerignore          # Optimize build context
├── docker-compose.yml     # Multi-service stack
├── package.json           # Node.js dependencies
├── src/                   # Application code
│   ├── index.js          # Main app
│   └── routes/           # API routes
├── init-scripts/         # Database initialization
│   └── 01-create-tables.sql
├── .env.example          # Environment template
└── README.md             # Documentation
```

---

## Part 1: Create Sample Application

### Task 1.1: Initialize Node.js Project

```bash
cd 03-containers/docker-nodejs-demo

# Initialize project
npm init -y

# Install dependencies
npm install express pg redis dotenv

# Install dev dependencies
npm install --save-dev nodemon jest
```

### Task 1.2: Create Application Code

**File: `src/index.js`**

```javascript
const express = require('express');
const { Client } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.PORT || 3000;

// PostgreSQL client
const pgClient = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'myapp',
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASSWORD || 'password'
});

// Redis client
const redisClient = redis.createClient({
  url: `redis://${process.env.REDIS_HOST || 'localhost'}:6379`
});

// Connect to databases
async function connectDatabases() {
  try {
    await pgClient.connect();
    console.log('✅ Connected to PostgreSQL');
    
    await redisClient.connect();
    console.log('✅ Connected to Redis');
  } catch (err) {
    console.error('❌ Database connection error:', err);
    process.exit(1);
  }
}

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check Postgres
    await pgClient.query('SELECT 1');
    
    // Check Redis
    await redisClient.ping();
    
    res.status(200).json({ 
      status: 'healthy',
      postgres: 'connected',
      redis: 'connected'
    });
  } catch (err) {
    res.status(503).json({ 
      status: 'unhealthy',
      error: err.message 
    });
  }
});

// API endpoints
app.get('/', (req, res) => {
  res.json({ message: 'Docker Node.js Demo API' });
});

app.get('/users', async (req, res) => {
  try {
    const result = await pgClient.query('SELECT * FROM users');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server
async function start() {
  await connectDatabases();
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
}

start();
```

**File: `package.json` (update scripts)**

```json
{
  "name": "docker-nodejs-demo",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "redis": "^4.6.7",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.5.0"
  }
}
```

---

## Part 2: Multi-stage Dockerfile

### Learning: Why Multi-stage Builds?

**Single-stage problems:**
- Dev dependencies in production image
- Source code and build tools included
- Large image size (900MB+)

**Multi-stage solution:**
- Stage 1: Install all dependencies
- Stage 2: Build/compile (if needed)
- Stage 3: Clean production image with only runtime needs

### Task 2.1: Create Multi-stage Dockerfile

**File: `Dockerfile`**

```dockerfile
# =============================================================================
# Stage 1: Dependencies
# =============================================================================
FROM node:18-alpine AS dependencies

# Install dependencies for native modules
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files (leverage Docker layer caching)
COPY package*.json ./

# Install ALL dependencies (needed for potential build steps)
RUN npm ci

# =============================================================================
# Stage 2: Build (if you have TypeScript or build step)
# =============================================================================
FROM dependencies AS build

WORKDIR /app

# Copy source code
COPY . .

# If you had a build step: RUN npm run build
# For plain JS, this stage just validates the setup

# =============================================================================
# Stage 3: Production
# =============================================================================
FROM node:18-alpine AS production

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ONLY production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code with proper ownership
COPY --from=build --chown=nodejs:nodejs /app/src ./src

# Switch to non-root user
USER nodejs

# Expose application port
EXPOSE 3000

# Health check (used by Docker Compose and K8s)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "src/index.js"]
```

**Key Optimizations:**
- ✅ Alpine base (5MB vs 900MB)
- ✅ Layer caching (package.json copied first)
- ✅ Production-only dependencies
- ✅ Non-root user
- ✅ Built-in health check

### Task 2.2: Create .dockerignore

**File: `.dockerignore`**

```
# Dependencies
node_modules/
npm-debug.log*

# Tests
coverage/
*.test.js

# Git
.git/
.gitignore

# IDE
.vscode/
.idea/

# Documentation
*.md
!README.md

# CI/CD
.github/

# Environment files
.env
.env.*
!.env.example

# OS files
.DS_Store
Thumbs.db

# Docker files
Dockerfile*
docker-compose*
```

### Task 2.3: Build and Test

```bash
# Build the image
docker build -t docker-nodejs-demo:latest .

# Check image size
docker images docker-nodejs-demo:latest

# Run container (standalone test)
docker run -d -p 3000:3000 \
  -e DB_HOST=host.docker.internal \
  --name test-app \
  docker-nodejs-demo:latest

# View logs
docker logs -f test-app

# Test health endpoint
curl http://localhost:3000/health

# Check user (should be 'nodejs', not 'root')
docker exec test-app whoami

# Cleanup
docker stop test-app && docker rm test-app
```

**Expected image size:** ~150-180MB

---

## Part 3: Docker Compose Stack

### Task 3.1: Create Docker Compose File

**File: `docker-compose.yml`**

```yaml
version: '3.8'

services:
  # Application
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: nodejs-demo-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=myapp
      - DB_USER=appuser
      - DB_PASSWORD=${DB_PASSWORD:-changeme}
      - REDIS_HOST=redis
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: nodejs-demo-postgres
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=appuser
      - POSTGRES_PASSWORD=${DB_PASSWORD:-changeme}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: nodejs-demo-redis
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: unless-stopped

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

**Key Features:**
- Health check dependencies (app waits for DB)
- Named volumes (data persists)
- Bridge network (services can communicate)
- Restart policies

### Task 3.2: Create Database Init Script

**File: `init-scripts/01-create-tables.sql`**

```sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email) VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com')
ON CONFLICT DO NOTHING;

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Task 3.3: Create Environment File

**File: `.env.example`**

```bash
# Database
DB_PASSWORD=your_secure_password_here

# Application
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
```

```bash
# Create actual .env (don't commit!)
cp .env.example .env
# Edit .env with real values
```

### Task 3.4: Run the Stack

```bash
# Start all services
docker-compose up -d

# Check status (look for "healthy")
docker-compose ps

# View logs
docker-compose logs -f app

# Test the application
curl http://localhost:3000
curl http://localhost:3000/health
curl http://localhost:3000/users

# Access database directly
docker-compose exec postgres psql -U appuser -d myapp
# Run: SELECT * FROM users;

# Test Redis
docker-compose exec redis redis-cli ping

# Stop everything
docker-compose down

# Stop and remove volumes (deletes data)
docker-compose down -v
```

---

## Part 4: CI/CD Integration

### Task 4.1: Create GitHub Actions Workflow

**File: `.github/workflows/docker-build.yml`**

```yaml
name: Docker Build and Push

on:
  push:
    branches: [main, develop]
    paths:
      - '03-containers/docker-nodejs-demo/**'
      - '.github/workflows/docker-build.yml'
  pull_request:
    branches: [main]
    paths:
      - '03-containers/docker-nodejs-demo/**'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/docker-nodejs-demo

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        if: github.event_name != 'pull_request'
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
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./03-containers/docker-nodejs-demo
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

**What this does:**
- Builds on PR (test) and push (deploy)
- Pushes to GitHub Container Registry
- Tags: branch name, commit SHA, latest
- Scans for vulnerabilities
- Uses build cache for speed

### Task 4.2: Test the Pipeline

```bash
# Create feature branch
git checkout -b feature/docker-optimization

# Make a change
echo "# Docker Optimization" >> README.md

# Commit and push
git add .
git commit -m "feat: add Docker multi-stage build"
git push origin feature/docker-optimization

# Create PR on GitHub
# Watch the Actions tab:
# - ✅ Build succeeds
# - ✅ Image size reported
# - ✅ Security scan passes
```

---

## Part 5: Documentation

### Task 5.1: Create README

**File: `README.md`**

```markdown
# Docker Node.js Demo

Multi-stage Docker build demonstrating containerization best practices.

## Features

- 🐳 Multi-stage Dockerfile (optimized to ~180MB)
- 🔒 Security hardened (non-root user, minimal base image)
- 🏥 Health checks for container orchestration
- 🚀 Docker Compose stack (app + PostgreSQL + Redis)
- 📊 CI/CD integration with automated builds
- 🔍 Security scanning with Trivy

## Quick Start

\`\`\`bash
# Clone and navigate
cd 03-containers/docker-nodejs-demo

# Start the stack
docker-compose up -d

# Check health
curl http://localhost:3000/health

# View users
curl http://localhost:3000/users

# Stop
docker-compose down
\`\`\`

## Architecture

\`\`\`
┌─────────────┐
│   Node.js   │ :3000
│     App     │
└──────┬──────┘
       │
   ┌───┴────┬────────┐
   │        │        │
   ▼        ▼        ▼
┌────────┐ ┌──────┐ ┌─────┐
│Postgres│ │Redis │ │     │
│  :5432 │ │ :6379│ │ ... │
└────────┘ └──────┘ └─────┘
\`\`\`

## Image Optimization

| Version | Size | Notes |
|---------|------|-------|
| Unoptimized | 950MB | Full node image, all dependencies |
| Optimized | 180MB | Alpine, multi-stage, prod deps only |

## Security Features

- ✅ Non-root user (nodejs:1001)
- ✅ Minimal base image (alpine)
- ✅ No dev dependencies in production
- ✅ Health checks
- ✅ Automated vulnerability scanning

## Development

\`\`\`bash
# Install dependencies
npm install

# Run locally
npm run dev

# Run tests
npm test
\`\`\`

## Environment Variables

See \`.env.example\` for required configuration.

## CI/CD

Automated builds on push to main:
- Builds multi-stage Docker image
- Pushes to GitHub Container Registry
- Scans for security vulnerabilities
- Tags: branch, SHA, latest
\`\`\`

---

## Verification Checklist

Before moving to Kubernetes:

- [ ] Multi-stage Dockerfile created
- [ ] Image uses non-root user
- [ ] Image size < 200MB
- [ ] .dockerignore configured
- [ ] Docker Compose stack runs successfully
- [ ] All 3 services healthy
- [ ] Health check endpoint works
- [ ] Data persists in volumes
- [ ] CI/CD pipeline builds image
- [ ] Image pushed to registry
- [ ] Security scan passes
- [ ] README documentation complete
- [ ] Can access app at http://localhost:3000
- [ ] Can query users from database

---

## Expected Outcomes

**Image Metrics:**
- Size: ~180MB (vs 950MB unoptimized)
- Build time: ~2-3 minutes (with cache: ~30s)
- Security: Zero critical vulnerabilities

**Runtime:**
- Application starts in ~5 seconds
- Health checks pass
- All services communicate
- Data persists after restart

---

## Next Steps

After completing this lab:
1. ✅ Commit all code to repository
2. ✅ Verify CI/CD pipeline runs
3. ✅ Update portfolio roadmap
4. 🎯 Move to Kubernetes Lab

**Estimated completion time:** 2-3 days

Good luck! 🐳
```

---

**Ready to start?** Begin with Task 1.1 and work through sequentially. Come back when you finish or get stuck!
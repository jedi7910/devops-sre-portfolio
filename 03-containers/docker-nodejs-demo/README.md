# Docker Optimization
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

- [x] Multi-stage Dockerfile created
- [x] Image uses non-root user
- [x] Image size < 200MB
- [x] .dockerignore configured
- [x] Docker Compose stack runs successfully
- [x] All 3 services healthy
- [x] Health check endpoint works
- [x] Data persists in volumes
- [x] CI/CD pipeline builds image
- [x] Image pushed to registry
- [x] Security scan passes
- [x] README documentation complete
- [x] Can access app at http://localhost:3000
- [x] Can query users from database

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

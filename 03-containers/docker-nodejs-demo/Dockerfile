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
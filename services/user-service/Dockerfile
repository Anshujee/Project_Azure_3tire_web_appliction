# ── Stage 1: Install dependencies ──────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# ci = clean install — uses package-lock.json exactly, faster and reproducible
RUN npm ci --only=production

# ── Stage 2: Runtime image ──────────────────────────────────────
FROM node:20-alpine AS runtime

# Create non-root user — containers should never run as root
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

# Copy only production dependencies from stage 1
COPY --from=deps /app/node_modules ./node_modules

# Copy application source
COPY src/ ./src/

# Switch to non-root user before starting
USER nodejs

EXPOSE 3001

# HEALTHCHECK tells Docker (and Kubernetes) when the container is ready
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://localhost:3001/health || exit 1

CMD ["node", "src/index.js"]

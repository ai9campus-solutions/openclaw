FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# Install bun and enable corepack as root
RUN curl -fsSL https://bun.sh/install | bash && \
    corepack enable

ENV PATH="/root/.bun/bin:${PATH}"

# Install required system packages including rsync for state sync
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    rsync \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Create app directory with proper ownership
RUN mkdir -p /app /home/node/.openclaw /data && \
    chown -R node:node /app /home/node /data && \
    chmod 755 /app /home/node /data

WORKDIR /app

# Copy files with proper ownership
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# Install dependencies as node user
USER node
RUN pnpm install --frozen-lockfile

# Switch back to root for additional setup
USER root

# Build as node user
USER node
COPY --chown=node:node . .
RUN pnpm build && \
    pnpm ui:build && \
    rm -rf node_modules/.cache

# Environment configuration for Railway
ENV OPENCLAW_PREFER_PNPM=1 \
    OPENCLAW_NO_BUN=1 \
    NODE_ENV=production \
    HOME=/home/node \
    USER=node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/home/node/workspace \
    PORT=3000

# Create bin directory and copy start script
USER root
RUN mkdir -p /app/bin
COPY --chown=node:node bin/start.sh /app/bin/start.sh

# Final permission fix
RUN chmod +x /app/bin/start.sh && \
    chown -R node:node /app /home/node

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

ENTRYPOINT ["/app/bin/start.sh"]

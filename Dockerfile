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
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Create app directory with proper ownership
RUN mkdir -p /app /home/node/.openclaw /data /app/bin && \
    chown -R node:node /app /home/node /data && \
    chmod 755 /app /home/node /data && \
    chmod 700 /home/node/.openclaw

WORKDIR /app

# Copy files with proper ownership - ORDER MATTERS for layer caching
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# Install dependencies as node user
USER node
RUN pnpm install --frozen-lockfile

# Copy the rest of the application
COPY --chown=node:node . .

# Build the application
RUN pnpm build && \
    pnpm ui:build && \
    rm -rf node_modules/.cache

# Copy and set up start script (must be done as root for proper permissions)
USER root
COPY --chown=root:root bin/start.sh /app/bin/start.sh
RUN chmod +x /app/bin/start.sh && \
    chown -R node:node /app /home/node

# CRITICAL: Create entrypoint wrapper to fix permissions at runtime
RUN echo '#!/bin/bash\n\
chown -R node:node /data /home/node/.openclaw 2>/dev/null || true\n\
chmod -R 755 /data 2>/dev/null || true\n\
exec /app/bin/start.sh "$@"' > /app/bin/entrypoint.sh && \
    chmod +x /app/bin/entrypoint.sh

# Environment configuration for Railway
ENV OPENCLAW_PREFER_PNPM=1 \
    OPENCLAW_NO_BUN=1 \
    NODE_ENV=production \
    HOME=/home/node \
    USER=node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/home/node/workspace \
    BAILEYS_STORE_PATH=/home/node/.opencl

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

# ===========================================================
# FIX 1: Create /data as a proper persistent volume mount point
# owned by node so the app can write directly to it —
# no copy-sync gymnastics needed.
# ===========================================================
RUN mkdir -p /app /home/node/.openclaw /data/.openclaw /data/workspace \
             /data/.openclaw/credentials/whatsapp/default \
             /data/.openclaw/agents /data/.openclaw/store /data/.openclaw/sessions \
             /app/bin && \
    chown -R node:node /app /home/node /data && \
    chmod 755 /app /home/node /data && \
    chmod 700 /home/node/.openclaw /data/.openclaw

WORKDIR /app

# Copy files with proper ownership — ORDER MATTERS for layer caching
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# Install dependencies as node user (no frozen-lockfile for flexibility)
USER node
RUN pnpm install --no-frozen-lockfile

# Copy the rest of the application
COPY --chown=node:node . .

# Build the application
RUN pnpm build && \
    pnpm ui:build && \
    rm -rf node_modules/.cache

# ===========================================================
# FIX 2: Single clean entrypoint as root (to fix volume
# ownership at runtime), then drops to node immediately.
# ===========================================================
USER root
COPY --chown=root:root bin/start.sh /app/bin/start.sh
RUN chmod +x /app/bin/start.sh

# The entrypoint ONLY fixes ownership then hands off to start.sh as node
RUN printf '#!/bin/bash\n\
# Fix ownership of the Railway persistent volume at runtime.\n\
# Railway mounts /data as root — we correct this before dropping privileges.\n\
chown -R node:node /data 2>/dev/null || true\n\
chmod -R 755 /data 2>/dev/null || true\n\
chmod 700 /data/.openclaw 2>/dev/null || true\n\
exec /app/bin/start.sh "$@"\n' > /app/bin/entrypoint.sh && \
    chmod +x /app/bin/entrypoint.sh

# ===========================================================
# FIX 3: Environment variables — all state goes to /data
# directly. Matches Railway env var settings exactly.
# OPENCLAW_HOME=/data is the single source of truth.
# ===========================================================
ENV OPENCLAW_PREFER_PNPM=1 \
    OPENCLAW_NO_BUN=1 \
    NODE_ENV=production \
    HOME=/home/node \
    USER=node \
    OPENCLAW_HOME=/data \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    OPENCLAW_WORKSPACE_DIR=/data/workspace \
    BAILEYS_STORE_PATH=/data/.openclaw/credentials/whatsapp/default \
    PORT=3000

# Health check — must match port app actually listens on
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
  CMD curl -f http://localhost:3000/health || exit 1

ENTRYPOINT ["/app/bin/entrypoint.sh"]

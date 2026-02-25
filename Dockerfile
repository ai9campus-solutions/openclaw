FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# Install bun, corepack, gosu, and system deps
# gosu = purpose-built container privilege dropper (replaces broken `su` in containers)
RUN curl -fsSL https://bun.sh/install | bash && \
    corepack enable

ENV PATH="/root/.bun/bin:${PATH}"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gosu \
    rsync \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Pre-create /data directory tree with node ownership.
# Railway mounts its persistent volume over /data at runtime,
# but pre-creating ensures subdirs exist on a fresh volume.
RUN mkdir -p \
    /app /app/bin \
    /home/node/.openclaw \
    /data/.openclaw/credentials/whatsapp/default \
    /data/.openclaw/agents \
    /data/.openclaw/store \
    /data/.openclaw/sessions \
    /data/workspace && \
    chown -R node:node /app /home/node /data && \
    chmod 755 /app /home/node /data && \
    chmod 700 /home/node/.openclaw /data/.openclaw

# Verify gosu works (fails build early if broken — better than silent runtime failure)
RUN gosu node true

WORKDIR /app

# Copy dependency manifests first (better layer caching)
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# Install dependencies as node user
USER node
RUN pnpm install --no-frozen-lockfile

# Copy full source and build
COPY --chown=node:node . .
RUN pnpm build && \
    pnpm ui:build && \
    rm -rf node_modules/.cache

# Switch back to root to install entrypoint (needs root to chown at runtime)
USER root

# Copy start script
COPY --chown=node:node bin/start.sh /app/bin/start.sh
RUN chmod +x /app/bin/start.sh

# Entrypoint: fixes /data ownership at runtime, then drops to node via gosu.
# gosu is the ONLY reliable privilege-drop mechanism in Railway/container envs.
# 'su' and 'sudo' both require PAM and fail silently in rootless containers.
RUN printf '#!/bin/bash\nset -e\necho "[entrypoint] Fixing /data ownership..."\nchown -R node:node /data 2>/dev/null || true\nchmod -R 755 /data 2>/dev/null || true\nchmod 700 /data/.openclaw 2>/dev/null || true\necho "[entrypoint] Dropping to node user via gosu..."\nexec gosu node /app/bin/start.sh "$@"\n' > /app/bin/entrypoint.sh && \
    chmod +x /app/bin/entrypoint.sh

# ============================================================
# Environment defaults — all state under /data.
# Railway env vars override these at runtime (Railway wins).
# ============================================================
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

# Docker HEALTHCHECK (Railway uses railway.toml instead, but keep this for local testing)
HEALTHCHECK --interval=15s --timeout=10s --start-period=120s --retries=10 \
  CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

ENTRYPOINT ["/app/bin/entrypoint.sh"]

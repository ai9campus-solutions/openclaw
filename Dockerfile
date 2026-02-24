FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935
# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable
WORKDIR /app
RUN chown node:node /app
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts
USER node
RUN pnpm install --frozen-lockfile
# Optionally install Chromium and Xvfb for browser automation.
# Build with: docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 ...
# Adds ~300MB but eliminates the 60-90s Playwright install on every container start.
# Must run after pnpm install so playwright-core is available in node_modules.
USER root
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      mkdir -p /home/node/.cache/ms-playwright && \
      PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      chown -R node:node /home/node/.cache/ms-playwright && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi
USER node
COPY --chown=node:node . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build
ENV NODE_ENV=production
# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

# Create initialization script for API key configuration
RUN mkdir -p /app/bin && cat > /app/bin/init-auth.sh << 'INITEOF'
#!/bin/bash
set -e

# Create OpenClaw config directory
mkdir -p $HOME/.openclaw/agents/main/agent

# Initialize auth-profiles.json from environment variables
if [ -n "$ANTHROPIC_API_KEY" ]; then
  cat > $HOME/.openclaw/agents/main/agent/auth-profiles.json << EOF
{
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "$ANTHROPIC_API_KEY"
    }
  },
  "defaults": {
    "anthropic": "anthropic:default"
  }
}
EOF
  chmod 600 $HOME/.openclaw/agents/main/agent/auth-profiles.json
  echo "[✓] Anthropic API key configured"
else
  echo "[!] WARNING: ANTHROPIC_API_KEY not set - agent will fail to authenticate"
fi

echo "[→] Starting OpenClaw gateway..."
# Execute the main command with verbose output
exec "$@"
INITEOF

RUN chmod +x /app/bin/init-auth.sh

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
ENTRYPOINT ["/app/bin/init-auth.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]

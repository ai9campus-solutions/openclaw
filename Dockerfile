FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app
RUN chown node:node /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; fi

COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

USER node
RUN pnpm install --frozen-lockfile

USER root
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && mkdir -p /home/node/.cache/ms-playwright && PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright node /app/node_modules/playwright-core/cli.js install --with-deps chromium && chown -R node:node /home/node/.cache/ms-playwright && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; fi

USER node
COPY --chown=node:node . .
RUN pnpm build

ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

USER node

RUN mkdir -p /app/bin

# Create init script using a simple approach - just create directories and start gateway
RUN cat > /app/bin/start.sh << 'SCRIPT'
#!/bin/bash
set -e

mkdir -p $HOME/.openclaw/agents/main/agent
mkdir -p $HOME/.openclaw/credentials

if [ -n "$ANTHROPIC_API_KEY" ]; then
  cat > $HOME/.openclaw/agents/main/agent/auth-profiles.json << 'AUTH'
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
AUTH
  chmod 600 $HOME/.openclaw/agents/main/agent/auth-profiles.json
  echo "[✓] Anthropic API key configured"
fi

echo "[→] Starting OpenClaw gateway..."
exec "$@"
SCRIPT

RUN chmod +x /app/bin/start.sh

ENTRYPOINT ["/app/bin/start.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]

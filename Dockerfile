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

RUN echo '#!/bin/bash' > /app/bin/init-auth.sh && \
    echo 'set -e' >> /app/bin/init-auth.sh && \
    echo 'mkdir -p $HOME/.openclaw/agents/main/agent' >> /app/bin/init-auth.sh && \
    echo 'mkdir -p $HOME/.openclaw/credentials' >> /app/bin/init-auth.sh && \
    echo 'if [ -n "$ANTHROPIC_API_KEY" ]; then' >> /app/bin/init-auth.sh && \
    echo '  cat > $HOME/.openclaw/agents/main/agent/auth-profiles.json << EOF' >> /app/bin/init-auth.sh && \
    echo '{' >> /app/bin/init-auth.sh && \
    echo '  "profiles": {' >> /app/bin/init-auth.sh && \
    echo '    "anthropic:default": {' >> /app/bin/init-auth.sh && \
    echo '      "type": "api_key",' >> /app/bin/init-auth.sh && \
    echo '      "provider": "anthropic",' >> /app/bin/init-auth.sh && \
    echo '      "key": "$ANTHROPIC_API_KEY"' >> /app/bin/init-auth.sh && \
    echo '    }' >> /app/bin/init-auth.sh && \
    echo '  },' >> /app/bin/init-auth.sh && \
    echo '  "defaults": {' >> /app/bin/init-auth.sh && \
    echo '    "anthropic": "anthropic:default"' >> /app/bin/init-auth.sh && \
    echo '  }' >> /app/bin/init-auth.sh && \
    echo '}' >> /app/bin/init-auth.sh && \
    echo 'EOF' >> /app/bin/init-auth.sh && \
    echo '  chmod 600 $HOME/.openclaw/agents/main/agent/auth-profiles.json' >> /app/bin/init-auth.sh && \
    echo '  echo "[✓] Anthropic API key configured"' >> /app/bin/init-auth.sh && \
    echo 'else' >> /app/bin/init-auth.sh && \
    echo '  echo "[!] WARNING: ANTHROPIC_API_KEY not set"' >> /app/bin/init-auth.sh && \
    echo 'fi' >> /app/bin/init-auth.sh && \
    echo 'cat > $HOME/.openclaw/openclaw.json << EOF' >> /app/bin/init-auth.sh && \
    echo '{' >> /app/bin/init-auth.sh && \
    echo '  "agent": {' >> /app/bin/init-auth.sh && \
    echo '    "model": "anthropic/claude-opus-4-6"' >> /app/bin/init-auth.sh && \
    echo '  },' >> /app/bin/init-auth.sh && \
    echo '  "channels": {' >> /app/bin/init-auth.sh && \
    echo '    "whatsapp": {' >> /app/bin/init-auth.sh && \
    echo '      "enabled": true,' >> /app/bin/init-auth.sh && \
    echo '      "allowFrom": ["*"],' >> /app/bin/init-auth.sh && \
    echo '      "dmPolicy": "pairing"' >> /app/bin/init-auth.sh && \
    echo '    }' >> /app/bin/init-auth.sh && \
    echo '  }' >> /app/bin/init-auth.sh && \
    echo '}' >> /app/bin/init-auth.sh && \
    echo 'EOF' >> /app/bin/init-auth.sh && \
    echo 'chmod 600 $HOME/.openclaw/openclaw.json' >> /app/bin/init-auth.sh && \
    echo 'echo "[✓] OpenClaw config created"' >> /app/bin/init-auth.sh && \
    echo 'if [ -n "$WHATSAPP_CREDENTIALS_B64" ]; then' >> /app/bin/init-auth.sh && \
    echo '  echo "[→] Decoding WhatsApp credentials..."' >> /app/bin/init-auth.sh && \
    echo '  echo "$WHATSAPP_CREDENTIALS_B64" | base64 -d > $HOME/.openclaw/credentials/whatsapp' >> /app/bin/init-auth.sh && \
    echo '  chmod 600 $HOME/.openclaw/credentials/whatsapp' >> /app/bin/init-auth.sh && \
    echo '  echo "[✓] WhatsApp credentials configured"' >> /app/bin/init-auth.sh && \
    echo 'fi' >> /app/bin/init-auth.sh && \
    echo 'echo "[→] Starting OpenClaw gateway..."' >> /app/bin/init-auth.sh && \
    echo 'exec "$@"' >> /app/bin/init-auth.sh && \
    chmod +x /app/bin/init-auth.sh

ENTRYPOINT ["/app/bin/init-auth.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]

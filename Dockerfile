FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# Install bun and enable corepack as root
RUN curl -fsSL https://bun.sh/install | bash && \
    corepack enable

ENV PATH="/root/.bun/bin:${PATH}"

# Create app directory with proper ownership
RUN mkdir -p /app /home/node/.openclaw && \
    chown -R node:node /app /home/node && \
    chmod 755 /app /home/node

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Copy files with proper ownership
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# Install dependencies as node user
USER node
RUN pnpm install --frozen-lockfile

# Switch back to root for browser installation
USER root
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
    mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Build as node user
USER node
COPY --chown=node:node . .
RUN pnpm build && \
    pnpm ui:build && \
    rm -rf node_modules/.cache

ENV OPENCLAW_PREFER_PNPM=1 \
    OPENCLAW_NO_BUN=1 \
    NODE_ENV=production \
    HOME=/home/node \
    USER=node

# Create bin directory and copy start script
RUN mkdir -p /app/bin
COPY --chown=node:node bin/start.sh /app/bin/start.sh

# Final permission fix and switch to root for entrypoint
USER root
RUN chmod +x /app/bin/start.sh && \
    chown -R node:node /app /home/node

ENTRYPOINT ["/app/bin/start.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]

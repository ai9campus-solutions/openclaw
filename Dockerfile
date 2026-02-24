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
ENV OPENCLAW_NO_BUN=1
RUN pnpm ui:build
ENV NODE_ENV=production
USER node
RUN mkdir -p /app/bin
COPY --chown=node:node bin/start.sh /app/bin/start.sh
RUN chmod +x /app/bin/start.sh
ENTRYPOINT ["/app/bin/start.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]
```

6. Scroll down, click green **"Commit changes"**
7. Click **"Commit changes"** again in the popup

✅ Dockerfile is fixed.

---

## 🟢 STEP 4 — Set environment variables in Railway

1. Go to **railway.com** → open your project → click your **openclaw service**
2. Click **"Variables"** in the top tabs
3. Add these two variables (click **"New Variable"** for each):

| Name | Value |
|---|---|
| `WHATSAPP_ALLOW_FROM` | your WhatsApp number with country code, e.g. `+919876543210` |
| `OPENCLAW_NO_BUN` | `1` |

*(ANTHROPIC_API_KEY should already be there — if not, add it too)*

---

## 🟢 STEP 5 — Add a Volume (so WhatsApp login never gets lost)

1. Still in Railway, click your **openclaw service**
2. Click **"Settings"** tab
3. Scroll down to find **"Volumes"** → click **"Add Volume"**
4. Set the mount path to exactly:
```
   /home/node/.openclaw

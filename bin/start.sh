#!/bin/bash
# =============================================================
# OpenClaw start.sh — runs AS node user (gosu handles the drop)
# =============================================================
# This script is called by entrypoint.sh AFTER:
#   - chown -R node:node /data  (done as root in entrypoint.sh)
#   - exec gosu node ...        (we are now the node user)
# So: NO 'su', NO 'sudo', NO privilege operations here.
# =============================================================
set -e

# ─────────────────────────────────────────────────────────────
# 1. CANONICAL PATHS — all from OPENCLAW_HOME (= /data on Railway)
# ─────────────────────────────────────────────────────────────
export OPENCLAW_HOME="${OPENCLAW_HOME:-/data}"
export OPENCLAW_STATE_DIR="${OPENCLAW_HOME}/.openclaw"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"
export BAILEYS_STORE_PATH="${OPENCLAW_STATE_DIR}/credentials/whatsapp/default"
export NODE_ENV="${NODE_ENV:-production}"
export HOME="/home/node"
export PORT="${PORT:-3000}"

echo "[OpenClaw] ============================================"
echo "[OpenClaw] User:      $(whoami)"
echo "[OpenClaw] Home:      $HOME"
echo "[OpenClaw] State:     $OPENCLAW_STATE_DIR"
echo "[OpenClaw] Workspace: $OPENCLAW_WORKSPACE_DIR"
echo "[OpenClaw] Baileys:   $BAILEYS_STORE_PATH"
echo "[OpenClaw] Port:      $PORT"
echo "[OpenClaw] ============================================"

# ─────────────────────────────────────────────────────────────
# 2. ENSURE DIRECTORY STRUCTURE (as node user, safe to run always)
# ─────────────────────────────────────────────────────────────
mkdir -p \
    "$BAILEYS_STORE_PATH" \
    "${OPENCLAW_STATE_DIR}/agents" \
    "${OPENCLAW_STATE_DIR}/store" \
    "${OPENCLAW_STATE_DIR}/sessions" \
    "$OPENCLAW_WORKSPACE_DIR"

# Fix credential file permissions (Baileys needs these)
find "${OPENCLAW_STATE_DIR}/credentials" -type f -exec chmod 600 {} \; 2>/dev/null || true
find "${OPENCLAW_STATE_DIR}/credentials" -type d -exec chmod 700 {} \; 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# 3. CREDENTIAL CHECK
# ─────────────────────────────────────────────────────────────
if [ -f "${BAILEYS_STORE_PATH}/creds.json" ]; then
    echo "[OK] WhatsApp creds.json found — no QR scan needed"
    echo "[OK] Pre-keys: $(ls ${BAILEYS_STORE_PATH}/pre-key-*.json 2>/dev/null | wc -l)"
else
    echo "[WARN] No creds.json — QR code will appear in logs for WhatsApp pairing"
fi

# ─────────────────────────────────────────────────────────────
# 4. HEALTH PROBE BACKGROUND SERVER
# Starts an instant /health responder using Node.js (no extra
# packages needed). Railway probes immediately on boot — this
# keeps the deployment alive while the full gateway initializes.
# Once the real gateway is up on $PORT it takes over automatically.
# ─────────────────────────────────────────────────────────────
echo "[OpenClaw] Starting health probe server on port $PORT..."
node -e "
const http = require('http');
const port = process.env.PORT || 3000;
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({status:'starting',uptime:process.uptime()}));
  } else {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('OpenClaw starting...');
  }
});
server.listen(port, '0.0.0.0', () => {
  console.log('[health-probe] Listening on port ' + port);
});
// Auto-exit after 3 minutes — the real gateway will have started by then
setTimeout(() => {
  console.log('[health-probe] Handing off to main gateway');
  server.close();
  process.exit(0);
}, 180000);
" &
HEALTH_PROBE_PID=$!
echo "[OpenClaw] Health probe PID: $HEALTH_PROBE_PID"

# Give the probe a moment to bind to the port
sleep 1

# ─────────────────────────────────────────────────────────────
# 5. LAUNCH THE REAL GATEWAY
# Kill health probe first so the port is free for the gateway
# ─────────────────────────────────────────────────────────────
echo "[OpenClaw] Killing health probe, handing port to gateway..."
kill $HEALTH_PROBE_PID 2>/dev/null || true
sleep 1

echo "[OpenClaw] Launching gateway..."
cd /app
exec node openclaw.mjs gateway \
    --allow-unconfigured \
    --host 0.0.0.0 \
    --port "${PORT}"

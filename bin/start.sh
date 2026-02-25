#!/bin/bash
# =============================================================
# OpenClaw Gateway Start Script — Railway + WhatsApp Edition
# =============================================================
# KEY DESIGN DECISION: We write DIRECTLY to /data (the Railway
# persistent volume). NO copy-sync pattern. This eliminates:
#   - Data loss on crash (SIGKILL skips traps)
#   - Path conflicts between Railway env vars and in-script overrides
#   - Ownership race conditions
# =============================================================
set -e

# -----------------------------------------------------------------
# 1. ESTABLISH THE CANONICAL STATE DIRECTORY
#    OPENCLAW_HOME=/data is set in Dockerfile + Railway env vars.
#    Everything derives from it here so there is ONE source of truth.
# -----------------------------------------------------------------
export OPENCLAW_HOME="${OPENCLAW_HOME:-/data}"
export OPENCLAW_STATE_DIR="${OPENCLAW_HOME}/.openclaw"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"
export BAILEYS_STORE_PATH="${OPENCLAW_STATE_DIR}/credentials/whatsapp/default"
export NODE_ENV=production
export HOME=/home/node

echo "[OpenClaw] ============================================"
echo "[OpenClaw] Starting WhatsApp Gateway on Railway"
echo "[OpenClaw] State dir  : $OPENCLAW_STATE_DIR"
echo "[OpenClaw] Workspace  : $OPENCLAW_WORKSPACE_DIR"
echo "[OpenClaw] Baileys    : $BAILEYS_STORE_PATH"
echo "[OpenClaw] Port       : ${PORT:-3000}"
echo "[OpenClaw] ============================================"

# -----------------------------------------------------------------
# 2. ENSURE DIRECTORY STRUCTURE EXISTS
#    Idempotent — safe to run even if dirs already exist.
# -----------------------------------------------------------------
mkdir -p \
    "$BAILEYS_STORE_PATH" \
    "${OPENCLAW_STATE_DIR}/agents" \
    "${OPENCLAW_STATE_DIR}/store" \
    "${OPENCLAW_STATE_DIR}/sessions" \
    "$OPENCLAW_WORKSPACE_DIR"

# -----------------------------------------------------------------
# 3. FIX PERMISSIONS
#    Railway mounts /data as root. entrypoint.sh already did a
#    bulk chown, but we also fix here for safety on re-deploys.
# -----------------------------------------------------------------
chown -R node:node "$OPENCLAW_HOME" 2>/dev/null || true
chmod 755 "$OPENCLAW_HOME" 2>/dev/null || true
chmod 700 "$OPENCLAW_STATE_DIR" 2>/dev/null || true

# Fix credential file permissions (Baileys needs 600 on key files)
find "${OPENCLAW_STATE_DIR}/credentials" -type f -exec chmod 600 {} \; 2>/dev/null || true
find "${OPENCLAW_STATE_DIR}/credentials" -type d -exec chmod 700 {} \; 2>/dev/null || true

# -----------------------------------------------------------------
# 4. DIAGNOSTIC — show what credentials exist
# -----------------------------------------------------------------
echo "[OpenClaw] Checking existing WhatsApp credentials..."
if [ -f "${BAILEYS_STORE_PATH}/creds.json" ]; then
    echo "[OK] Found creds.json — WhatsApp credentials present, no QR scan needed"
    ls -la "${BAILEYS_STORE_PATH}/creds.json" 2>/dev/null || true
    echo "[OK] Pre-key count: $(ls ${BAILEYS_STORE_PATH}/pre-key-*.json 2>/dev/null | wc -l)"
else
    echo "[WARN] No creds.json found — WhatsApp will show QR code for pairing"
    echo "[INFO] After scanning QR, credentials are saved to: $BAILEYS_STORE_PATH"
    echo "[INFO] They will persist across restarts via Railway's /data volume"
fi

# -----------------------------------------------------------------
# 5. LAUNCH — drop to node user and start the gateway
#    We use 'su' with explicit env exports to guarantee correct vars.
#    Note: do NOT use -p flag (preserve), as that would inherit
#    any stale vars from the parent shell.
# -----------------------------------------------------------------
echo "[OpenClaw] Launching gateway..."
cd /app

exec su node -s /bin/bash -c "
    export HOME=/home/node
    export OPENCLAW_HOME=${OPENCLAW_HOME}
    export OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR}
    export OPENCLAW_WORKSPACE_DIR=${OPENCLAW_WORKSPACE_DIR}
    export BAILEYS_STORE_PATH=${BAILEYS_STORE_PATH}
    export NODE_ENV=production
    export PORT=${PORT:-3000}
    export OPENCLAW_NO_BUN=${OPENCLAW_NO_BUN:-1}
    export OPENCLAW_CHANNELS_WHATSAPP_ENABLED=${OPENCLAW_CHANNELS_WHATSAPP_ENABLED:-true}
    export OPENCLAW_CHANNELS_WHATSAPP_DM_POLICY=${OPENCLAW_CHANNELS_WHATSAPP_DM_POLICY:-pairing}
    export NODE_OPTIONS='${NODE_OPTIONS:---max-old-space-size=4096}'
    cd /app && exec node openclaw.mjs gateway \
        --allow-unconfigured \
        --host 0.0.0.0 \
        --port ${PORT:-3000}
"

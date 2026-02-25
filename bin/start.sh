#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

echo "[OpenClaw] Starting WhatsApp Gateway..."

# Create all required directories with proper structure
mkdir -p "$HOME/.openclaw/credentials/whatsapp/default"
mkdir -p "$HOME/.openclaw/agents"
mkdir -p "$HOME/.openclaw/store"
mkdir -p "$HOME/.openclaw/sessions"
mkdir -p "$HOME/workspace"

# Debug: Show current state locations
echo "[DEBUG] Checking for existing credentials..."
ls -la "$HOME/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in HOME"
ls -la "/data/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in /data"

# CRITICAL: Restore credentials from persistent volume (/data) if they exist
if [ -d "/data/.openclaw" ] && [ "$(ls -A /data/.openclaw 2>/dev/null)" ]; then
    echo "[OK] Found existing state in /data, restoring..."
    
    # Backup current state if exists
    if [ -d "$HOME/.openclaw" ] && [ "$(ls -A $HOME/.openclaw 2>/dev/null)" ]; then
        mv "$HOME/.openclaw" "$HOME/.openclaw.backup.$(date +%s)"
    fi
    
    # Copy with preservation of permissions
    cp -r /data/.openclaw "$HOME/"
    
    # CRITICAL: Fix ownership - credentials must be owned by node user
    chown -R node:node "$HOME/.openclaw"
    
    # Ensure proper permissions on credential files
    find "$HOME/.openclaw/credentials" -type f -exec chmod 600 {} \; 2>/dev/null || true
    find "$HOME/.openclaw/credentials" -type d -exec chmod 700 {} \; 2>/dev/null || true
    
    echo "[OK] State restored from /data"
else
    echo "[WARN] No existing state found in /data - WhatsApp will require fresh QR scan"
fi

# Set proper permissions on all directories
chown -R node:node "$HOME/.openclaw" "$HOME/workspace" 2>/dev/null || true
chmod -R 755 "$HOME/.openclaw" 2>/dev/null || true

# Setup graceful shutdown handler to persist state
cleanup() {
    echo "[OpenClaw] Shutting down, syncing state to /data..."
    if [ -d "$HOME/.openclaw" ] && [ -d "/data" ]; then
        chown -R node:node "$HOME/.openclaw" 2>/dev/null || true
        
        # Use rsync for efficient sync, fallback to cp
        rsync -av --delete "$HOME/.openclaw/" "/data/.openclaw/" 2>/dev/null || \
        cp -r "$HOME/.openclaw/"* "/data/.openclaw/" 2>/dev/null
        
        echo "[OK] State synced to /data"
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Export critical environment variables for WhatsApp/Baileys
export OPENCLAW_STATE_DIR=/home/node/.openclaw
export OPENCLAW_WORKSPACE_DIR=/home/node/workspace
export BAILEYS_STORE_PATH="$HOME/.openclaw/credentials/whatsapp/default"
export NODE_ENV=production

echo "[OpenClaw] Launching gateway on port ${PORT:-3000}..."
echo "[OpenClaw] State directory: $OPENCLAW_STATE_DIR"
echo "[OpenClaw] WhatsApp credentials: $BAILEYS_STORE_PATH"

cd /app

# CRITICAL FIX: Run as node user but keep environment variables
# Use 'su' with -p to preserve environment or export vars explicitly
exec su -p node -c "cd /app && \
    export HOME=/home/node && \
    export OPENCLAW_STATE_DIR=/home/node/.openclaw && \
    export OPENCLAW_WORKSPACE_DIR=/home/node/workspace && \
    export BAILEYS_STORE_PATH=/home/node/.openclaw/credentials/whatsapp/default && \
    export NODE_ENV=production && \
    export PORT=${PORT:-3000} && \
    exec node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT:-3000}"

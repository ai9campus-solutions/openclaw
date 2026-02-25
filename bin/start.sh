#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

echo "[OpenClaw] Starting WhatsApp Gateway..."

# CRITICAL: Ensure proper ownership of state directories
echo "[DEBUG] Setting up state directories..."

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
ls -la "/data/" 2>/dev/null || echo "[DEBUG] /data directory not mounted"

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
    echo "[DEBUG] Restored state contents:"
    ls -laR "$HOME/.openclaw/credentials/" 2>/dev/null || true
else
    echo "[WARN] No existing state found in /data - WhatsApp will require fresh QR scan"
fi

# Set proper permissions on all directories
chown -R node:node "$HOME/.openclaw" "$HOME/workspace" 2>/dev/null || true
chmod -R 755 "$HOME/.openclaw" 2>/dev/null || true

# CRITICAL: Ensure WhatsApp credentials directory has correct structure
if [ ! -f "$HOME/.openclaw/credentials/whatsapp/default/creds.json" ]; then
    echo "[WARN] No WhatsApp credentials found - gateway will start but WhatsApp requires pairing"
    echo "[INFO] To pair WhatsApp: Check logs for QR code or run 'openclaw channels login whatsapp'"
fi

# Setup graceful shutdown handler to persist state
cleanup() {
    echo "[OpenClaw] Shutting down, syncing state to /data..."
    if [ -d "$HOME/.openclaw" ] && [ -d "/data" ]; then
        # Ensure node owns everything before sync
        chown -R node:node "$HOME/.openclaw" 2>/dev/null || true
        
        # Use rsync for efficient sync, fallback to cp
        rsync -av --delete "$HOME/.openclaw/" "/data/.openclaw/" 2>/dev/null || \
        cp -r "$HOME/.openclaw/"* "/data/.openclaw/" 2>/dev/null
        
        echo "[OK] State synced to /data"
    fi
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap cleanup SIGTERM SIGINT

# Export critical environment variables for WhatsApp/Baileys
export OPENCLAW_STATE_DIR=/home/node/.openclaw
export OPENCLAW_WORKSPACE_DIR=/home/node/workspace
export NODE_ENV=production

# CRITICAL: Ensure Baileys can find its store
export BAILEYS_STORE_PATH="$HOME/.openclaw/credentials/whatsapp/default"

echo "[OpenClaw] Launching gateway on port ${PORT:-3000}..."
echo "[OpenClaw] State directory: $OPENCLAW_STATE_DIR"
echo "[OpenClaw] WhatsApp credentials: $BAILEYS_STORE_PATH"

cd /app

# Run as node user with full environment
exec su - node -c "cd /app && \
    export HOME=/home/node && \
    export OPENCLAW_STATE_DIR=/home/node/.openclaw && \
    export OPENCLAW_WORKSPACE_DIR=/home/node/workspace && \
    export BAILEYS_STORE_PATH=/home/node/.openclaw/credentials/whatsapp/default && \
    export NODE_ENV=production && \
    export PORT=${PORT:-3000} && \
    exec node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT:-3000}"

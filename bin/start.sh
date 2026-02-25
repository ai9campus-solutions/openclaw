#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

echo "[OpenClaw] Starting WhatsApp Gateway..."

# Debug: Show current state
echo "[DEBUG] Checking for existing credentials..."
ls -la "$HOME/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in HOME"
ls -la "/data/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in /data"

# CRITICAL: Restore credentials from persistent volume (/data) if they exist
if [ -d "/data/.openclaw" ] && [ "$(ls -A /data/.openclaw 2>/dev/null)" ]; then
    echo "[OK] Found existing state in /data, restoring..."
    rm -rf "$HOME/.openclaw"
    cp -r /data/.openclaw "$HOME/"
    chown -R node:node "$HOME/.openclaw"
    echo "[OK] State restored from /data"
fi

# Ensure all required directories exist
mkdir -p "$HOME/.openclaw/credentials/whatsapp/default"
mkdir -p "$HOME/.openclaw/agents"
mkdir -p "$HOME/workspace"

# Set proper permissions
chown -R node:node "$HOME/.openclaw" "$HOME/workspace" 2>/dev/null || true

# Setup graceful shutdown handler to persist state
cleanup() {
    echo "[OpenClaw] Shutting down, syncing state to /data..."
    if [ -d "$HOME/.openclaw" ] && [ -d "/data" ]; then
        # Use rsync for efficient sync, fallback to cp
        rsync -av --delete "$HOME/.openclaw/" "/data/.openclaw/" 2>/dev/null || \
        cp -r "$HOME/.openclaw/"* "/data/.openclaw/" 2>/dev/null
        echo "[OK] State synced to /data"
    fi
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap cleanup SIGTERM SIGINT

# Start the gateway
echo "[OpenClaw] Launching gateway on port ${PORT:-3000}..."
cd /app

# Run as node user
exec su - node -c "cd /app && exec node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT:-3000}"

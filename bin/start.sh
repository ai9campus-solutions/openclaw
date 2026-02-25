#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

# Debug: Show where credentials are
echo "[DEBUG] Credentials location:"
ls -la "$HOME/.openclaw/credentials/whatsapp/default/" 2>/dev/null || echo "[DEBUG] No credentials in HOME"
ls -la "/data/.openclaw/credentials/whatsapp/default/" 2>/dev/null || echo "[DEBUG] No credentials in /data"

# Move credentials if needed (Railway volume -> HOME)
if [ -d "/data/.openclaw" ] && [ ! -d "$HOME/.openclaw" ]; then
  mv /data/.openclaw "$HOME/"
  echo "[OK] Moved credentials to $HOME"
fi

# Ensure state directory exists
mkdir -p "$HOME/.openclaw"
mkdir -p "$HOME/.openclaw/credentials"
mkdir -p "$HOME/.openclaw/agents"
mkdir -p "$HOME/workspace"

# Sync state back to /data for persistence (if volume exists)
if [ -d "/data" ]; then
  mkdir -p /data/.openclaw
  # Create sync script for graceful shutdown
  cat > /tmp/sync-state.sh << 'EOF'
#!/bin/bash
if [ -d "$HOME/.openclaw" ] && [ -d "/data/.openclaw" ]; then
  rsync -av "$HOME/.openclaw/" "/data/.openclaw/" 2>/dev/null || cp -r "$HOME/.openclaw/"* "/data/.openclaw/" 2>/dev/null
  echo "[OK] State synced to /data"
fi
EOF
  chmod +x /tmp/sync-state.sh
fi

# Set proper permissions
chown -R node:node "$HOME/.openclaw" 2>/dev/null || true
chown -R node:node "$HOME/workspace" 2>/dev/null || true

# Switch to node user for running the application
exec su - node -c "cd /app && exec node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT:-3000}"

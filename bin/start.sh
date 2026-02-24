#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

# Debug: Show where credentials are
echo "[DEBUG] Credentials location:"
ls -la "$HOME/.openclaw/credentials/whatsapp/default/" 2>/dev/null || echo "[DEBUG] No credentials in HOME"
ls -la "/data/.openclaw/credentials/whatsapp/default/" 2>/dev/null || echo "[DEBUG] No credentials in /data"

# Move credentials if needed
if [ -d "/data/.openclaw" ] && [ ! -d "$HOME/.openclaw" ]; then
  mv /data/.openclaw "$HOME/"
  echo "[OK] Moved credentials to $HOME"
fi

# ... rest of your start.sh

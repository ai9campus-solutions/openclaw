#!/bin/bash
set -e

# CRITICAL FIX: Ensure we're running as node user with proper home
export HOME=/home/node
export USER=node

# Create necessary directories with proper permissions
mkdir -p "$HOME/.openclaw/agents/main/agent"
mkdir -p "$HOME/.openclaw/credentials"
chmod -R 755 "$HOME/.openclaw"

# CRITICAL FIX: Change to a writable directory for any curl operations
cd "$HOME" || cd /tmp

# Write Anthropic API key
if [ -n "$ANTHROPIC_API_KEY" ]; then
  printf '{\n  "profiles": {\n    "anthropic:default": {\n      "type": "api_key",\n      "provider": "anthropic",\n      "key": "%s"\n    }\n  },\n  "defaults": {\n    "anthropic": "anthropic:default"\n  }\n}\n' "$ANTHROPIC_API_KEY" \
    > "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  chmod 600 "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  echo "[OK] Anthropic API key configured"
fi

# Write openclaw.json only if it doesn't exist yet
if [ ! -f "$HOME/.openclaw/openclaw.json" ] || [ -n "$FORCE_CONFIG_RESET" ]; then
  cat > "$HOME/.openclaw/openclaw.json" << ENDOFCONFIG
{
  "meta": {
    "lastTouchedVersion": "2026.2.2",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "gateway": {
    "bind": "lan",
    "port": ${PORT:-18789},
    "trustedProxies": ["100.64.0.0/10"],
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    },
    "controlUi": {
      "allowedOrigins": ["https://openclaw-production-13dc.up.railway.app "]
    }
  }
}
ENDOFCONFIG
  echo "[OK] Config written"
else
  echo "[OK] Config already exists, skipping"
fi

echo "[->] Starting OpenClaw gateway..."

# CRITICAL FIX: Switch to node user before executing the main command
exec su - node -c "cd /app && exec $*"

#!/bin/bash
set -e

# Set home directory
export HOME=/home/node
cd "$HOME"

# Create directories
mkdir -p "$HOME/.openclaw/agents/main/agent" "$HOME/.openclaw/credentials"

# Write Anthropic API key
if [ -n "$ANTHROPIC_API_KEY" ]; then
  printf '{\n  "profiles": {\n    "anthropic:default": {\n      "type": "api_key",\n      "provider": "anthropic",\n      "key": "%s"\n    }\n  },\n  "defaults": {\n    "anthropic": "anthropic:default"\n  }\n}\n' "$ANTHROPIC_API_KEY" > "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  chmod 600 "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  echo "[OK] Anthropic API key configured"
fi

# Write config if needed
if [ ! -f "$HOME/.openclaw/openclaw.json" ] || [ -n "$FORCE_CONFIG_RESET" ]; then
  cat > "$HOME/.openclaw/openclaw.json" << EOF
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
EOF
  echo "[OK] Config written"
else
  echo "[OK] Config already exists, skipping"
fi

echo "[->] Starting OpenClaw gateway..."

# Run as node user
exec su - node -c "cd /app && exec $*"

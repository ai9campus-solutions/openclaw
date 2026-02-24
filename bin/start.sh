#!/bin/bash
set -e

mkdir -p "$HOME/.openclaw/agents/main/agent"
mkdir -p "$HOME/.openclaw/credentials"

# Write Anthropic API key (safe to overwrite every time)
if [ -n "$ANTHROPIC_API_KEY" ]; then
  printf '{\n  "profiles": {\n    "anthropic:default": {\n      "type": "api_key",\n      "provider": "anthropic",\n      "key": "%s"\n    }\n  },\n  "defaults": {\n    "anthropic": "anthropic:default"\n  }\n}\n' "$ANTHROPIC_API_KEY" \
    > "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  chmod 600 "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  echo "[OK] Anthropic API key configured"
fi

# Write WhatsApp config ONLY if file does not exist yet
# AND include required meta block so gateway doesn't throw missing-meta-before-write
if [ -n "$WHATSAPP_ALLOW_FROM" ] && [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
  cat > "$HOME/.openclaw/openclaw.json" << ENDOFCONFIG
{
  "meta": {
    "lastTouchedVersion": "2026.2.2",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "channels": {
    "whatsapp": {
      "dmPolicy": "allowlist",
      "allowFrom": ["$WHATSAPP_ALLOW_FROM"],
      "sendReadReceipts": true,
      "ackReaction": {
        "emoji": "👀",
        "direct": true,
        "group": "mentions"
      }
    }
  }
}
ENDOFCONFIG
  echo "[OK] WhatsApp config written for $WHATSAPP_ALLOW_FROM"
else
  echo "[OK] WhatsApp config already exists, skipping write"
fi

echo "[->] Starting OpenClaw gateway..."
exec "$@"

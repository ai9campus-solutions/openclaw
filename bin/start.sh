#!/bin/bash
set -e

mkdir -p "$HOME/.openclaw/agents/main/agent"
mkdir -p "$HOME/.openclaw/credentials"

# Write Anthropic API key (always safe to overwrite)
if [ -n "$ANTHROPIC_API_KEY" ]; then
  printf '{\n  "profiles": {\n    "anthropic:default": {\n      "type": "api_key",\n      "provider": "anthropic",\n      "key": "%s"\n    }\n  },\n  "defaults": {\n    "anthropic": "anthropic:default"\n  }\n}\n' "$ANTHROPIC_API_KEY" \
    > "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  chmod 600 "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  echo "[OK] Anthropic API key configured"
fi

# Write WhatsApp config ONLY if file does not exist yet
# (prevents crash loop from overwriting gateway-managed config on every restart)
if [ -n "$WHATSAPP_ALLOW_FROM" ] && [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
  printf '{\n  channels: {\n    whatsapp: {\n      dmPolicy: "allowlist",\n      allowFrom: ["%s"],\n      sendReadReceipts: true,\n      ackReaction: { emoji: "👀", direct: true, group: "mentions" }\n    }\n  }\n}\n' "$WHATSAPP_ALLOW_FROM" \
    > "$HOME/.openclaw/openclaw.json"
  echo "[OK] WhatsApp config written for $WHATSAPP_ALLOW_FROM"
else
  echo "[OK] WhatsApp config already exists, skipping write"
fi

echo "[->] Starting OpenClaw gateway..."
exec "$@"

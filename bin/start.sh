#!/bin/bash
set -e

mkdir -p "$HOME/.openclaw/agents/main/agent"
mkdir -p "$HOME/.openclaw/credentials"

# Write Anthropic API key
if [ -n "$ANTHROPIC_API_KEY" ]; then
  printf '{\n  "profiles": {\n    "anthropic:default": {\n      "type": "api_key",\n      "provider": "anthropic",\n      "key": "%s"\n    }\n  },\n  "defaults": {\n    "anthropic": "anthropic:default"\n  }\n}\n' "$ANTHROPIC_API_KEY" \
    > "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  chmod 600 "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
  echo "[OK] Anthropic API key configured"
fi

# Write openclaw.json only if it doesn't exist yet
if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
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
      "allowedOrigins": ["https://openclaw-production-13dc.up.railway.app"]
    }
  },
  "channels": {
    "whatsapp": {
      "dmPolicy": "allowlist",
      "allowFrom": ["${WHATSAPP_ALLOW_FROM}"],
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
  echo "[OK] Config written"
else
  echo "[OK] Config already exists, skipping"
fi

echo "[->] Starting OpenClaw gateway..."
exec "$@"
```

Commit the change.

---

### Fix 2 — Add 2 new variables in Railway

Go to Railway → your openclaw service → **Variables** → add these:

| Name | Value |
|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | any password you choose e.g. `mysecrettoken123` |
| `PORT` | `18789` |

---

### Fix 3 — Change domain port back to 18789 in Railway Settings

Go to Settings → Networking → edit the domain → set port back to **18789** → Save.

---

### Then Redeploy

Go to Deployments → Redeploy. Once it's running, open:
```
https://openclaw-production-13dc.up.railway.app

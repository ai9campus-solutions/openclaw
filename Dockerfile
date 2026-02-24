RUN cat > /app/bin/start.sh << 'SCRIPT'
#!/bin/bash
set -e
mkdir -p $HOME/.openclaw/agents/main/agent
mkdir -p $HOME/.openclaw/credentials

# Write Anthropic API key config (unquoted heredoc = variable expands)
if [ -n "$ANTHROPIC_API_KEY" ]; then
  cat > $HOME/.openclaw/agents/main/agent/auth-profiles.json << AUTH
{
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "${ANTHROPIC_API_KEY}"
    }
  },
  "defaults": {
    "anthropic": "anthropic:default"
  }
}
AUTH
  chmod 600 $HOME/.openclaw/agents/main/agent/auth-profiles.json
  echo "[✓] Anthropic API key configured"
fi

# Write WhatsApp channel config
if [ -n "$WHATSAPP_ALLOW_FROM" ]; then
  cat > $HOME/.openclaw/openclaw.json << CFGJSON
{
  channels: {
    whatsapp: {
      dmPolicy: "allowlist",
      allowFrom: ["${WHATSAPP_ALLOW_FROM}"],
      sendReadReceipts: true,
      ackReaction: { emoji: "👀", direct: true, group: "mentions" }
    }
  }
}
CFGJSON
  echo "[✓] WhatsApp config written (allowFrom: ${WHATSAPP_ALLOW_FROM})"
fi

echo "[→] Starting OpenClaw gateway..."
exec "$@"
SCRIPT
RUN chmod +x /app/bin/start.sh
ENTRYPOINT ["/app/bin/start.sh"]
CMD ["node","openclaw.mjs","gateway","--allow-unconfigured"]

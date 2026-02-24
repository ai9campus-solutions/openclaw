cat > $HOME/.openclaw/openclaw.json << EOF
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6"
      }
    }
  },
  "channels": {
    "whatsapp": {
      "enabled": true,
      "allowFrom": ["*"],
      "dmPolicy": "pairing"
    }
  }
}
EOF

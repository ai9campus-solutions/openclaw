# In init-auth.sh, after creating directories:

# Create openclaw.json configuration
mkdir -p $HOME/.openclaw

cat > $HOME/.openclaw/openclaw.json << 'EOF'
{
  "agent": {
    "model": "anthropic/claude-opus-4-6"
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

chmod 600 $HOME/.openclaw/openclaw.json
echo "[✓] OpenClaw config created"

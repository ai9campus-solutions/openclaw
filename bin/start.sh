#!/bin/bash
set -e

export HOME=/home/node
cd "$HOME"

echo "[OpenClaw] Starting WhatsApp Gateway..."

# CRITICAL: Ensure proper ownership of state directories
echo "[DEBUG] Setting up state directories..."

# Create all required directories with proper structure
mkdir -p "$HOME/.openclaw/credentials/whatsapp/default"
mkdir -p "$HOME/.openclaw/agents"
mkdir -p "$HOME/.openclaw/store"
mkdir -p "$HOME/.openclaw/sessions"
mkdir -p "$HOME/workspace"

# Debug: Show current state locations
echo "[DEBUG] Checking for existing credentials..."
ls -la "$HOME/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in HOME"
ls -la "/data/.openclaw/" 2>/dev/null || echo "[DEBUG] No existing state in /data"
ls -la "/data/" 2>/dev/null || echo "[DEBUG] /data directory not mounted"

# CRITICAL: Restore credentials from persistent volume (/data) if they exist
if [ -d "/data/.openclaw" ] && [ "$(ls -A /data/.openclaw 2>/dev/null)" ]; then
    echo "[OK] Found existing state in /data, restoring..."
    
    # Backup current state if exists
    if [ -d "$HOME/.openclaw" ] && [ "$(ls -A $HOME/.openclaw 2>/dev/null)" ]; then
        mv "$HOME/.openclaw" "$HOME/.openclaw.backup.$(date +%s)"
    fi
    
    # Copy with preservation of permissions
    cp -r /data/.openclaw "$HOME/"
    
    # CRITICAL: Fix ownership - credentials must be owned by node user
   

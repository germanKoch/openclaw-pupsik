#!/usr/bin/env bash
# Setup zenmoney-mcp on a remote server
# Usage: ./setup-zenmoney-mcp.sh [ssh-host]
# Requires: zenmoney-mcp/.token.json (run zenmoney-mcp locally first to authorize via browser)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"
INSTALL_DIR="/opt/mcp-servers/zenmoney-mcp"
TOKEN_FILE="$REPO_DIR/.token.json"

# Verify token file exists
if [ ! -f "$TOKEN_FILE" ]; then
  echo "Error: $TOKEN_FILE not found."
  echo "Run zenmoney-mcp locally first to complete OAuth login, then re-run this script."
  exit 1
fi

echo "=== Installing zenmoney-mcp on $SSH_HOST ==="

ssh "$SSH_HOST" bash <<'REMOTE'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

# Install uv if missing
if ! command -v uv &>/dev/null; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install mcporter if missing
if ! command -v mcporter &>/dev/null; then
  echo "Installing mcporter..."
  npm install -g mcporter
fi

# Clone or update zenmoney-mcp
INSTALL_DIR="/opt/mcp-servers/zenmoney-mcp"
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating zenmoney-mcp..."
  cd "$INSTALL_DIR" && git pull
else
  echo "Cloning zenmoney-mcp..."
  mkdir -p /opt/mcp-servers
  git clone https://github.com/germanKoch/zenmoney-mcp.git "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Setup Python venv and install
uv venv
uv sync

echo "=== zenmoney-mcp installed at $INSTALL_DIR ==="
REMOTE

# Deploy token file (contains access_token + refresh_token for auto-refresh)
echo "Deploying token file..."
scp "$TOKEN_FILE" "$SSH_HOST:$INSTALL_DIR/.token.json"

# Register with mcporter (no env vars needed — auth via .token.json)
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add zenmoney \
  --command '$INSTALL_DIR/.venv/bin/python' \
  --arg 'main.py' \
  --scope home \
  --description 'ZenMoney finance tracking via MCP' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! zenmoney-mcp is live on $SSH_HOST ==="

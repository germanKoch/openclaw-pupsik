#!/usr/bin/env bash
# Setup ticktick-mcp on a remote server
# Usage: ./setup-ticktick-mcp.sh [ssh-host]
# Requires: .env in repo root with TICKTICK_* credentials
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"
INSTALL_DIR="/opt/mcp-servers/ticktick-mcp"

# Load local .env
if [ -f "$REPO_DIR/.env" ]; then
  source "$REPO_DIR/.env"
else
  echo "Error: $REPO_DIR/.env not found. Copy .env.template to .env and fill in credentials."
  exit 1
fi

echo "=== Installing ticktick-mcp on $SSH_HOST ==="

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

# Clone or update ticktick-mcp
INSTALL_DIR="/opt/mcp-servers/ticktick-mcp"
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating ticktick-mcp..."
  cd "$INSTALL_DIR" && git pull
else
  echo "Cloning ticktick-mcp..."
  mkdir -p /opt/mcp-servers
  git clone https://github.com/jacepark12/ticktick-mcp.git "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Setup Python venv and install
uv venv
source .venv/bin/activate
uv pip install -e .

echo "=== ticktick-mcp installed at $INSTALL_DIR ==="
REMOTE

# Deploy credentials
echo "Deploying credentials..."
ssh "$SSH_HOST" "cat > $INSTALL_DIR/.env << 'ENVEOF'
TICKTICK_ACCESS_TOKEN=${TICKTICK_ACCESS_TOKEN}
TICKTICK_CLIENT_ID=${TICKTICK_CLIENT_ID}
TICKTICK_CLIENT_SECRET=${TICKTICK_CLIENT_SECRET}
ENVEOF"

# Register with mcporter
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add ticktick \
  --command '$INSTALL_DIR/.venv/bin/python' \
  --arg '-m' --arg 'ticktick_mcp.cli' --arg 'run' \
  --env 'TICKTICK_ACCESS_TOKEN=${TICKTICK_ACCESS_TOKEN}' \
  --env 'TICKTICK_CLIENT_ID=${TICKTICK_CLIENT_ID}' \
  --env 'TICKTICK_CLIENT_SECRET=${TICKTICK_CLIENT_SECRET}' \
  --scope home \
  --description 'TickTick task management via MCP' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! ticktick-mcp is live on $SSH_HOST ==="
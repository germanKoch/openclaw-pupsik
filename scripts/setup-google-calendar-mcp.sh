#!/usr/bin/env bash
# Setup google-calendar-mcp on a remote server
# Usage: ./setup-google-calendar-mcp.sh [ssh-host]
# Requires: .env in repo root with GOOGLE_OAUTH_CREDENTIALS_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-${HETZNER_SSH_HOST:-hetzner-main}}"
INSTALL_DIR="/opt/mcp-servers/google-calendar-mcp"
CREDENTIALS_FILE="$INSTALL_DIR/gcp-oauth.keys.json"

# Load local .env
if [ -f "$REPO_DIR/.env" ]; then
  # shellcheck source=/dev/null
  source "$REPO_DIR/.env"
else
  echo "Error: $REPO_DIR/.env not found. Copy .env.template to .env and fill in credentials."
  exit 1
fi

if [ -z "${GOOGLE_OAUTH_CREDENTIALS_FILE:-}" ]; then
  echo "Error: GOOGLE_OAUTH_CREDENTIALS_FILE is empty in .env."
  exit 1
fi

if [ ! -f "$GOOGLE_OAUTH_CREDENTIALS_FILE" ]; then
  RELATIVE_CREDENTIALS_PATH="$REPO_DIR/$GOOGLE_OAUTH_CREDENTIALS_FILE"
  if [ -f "$RELATIVE_CREDENTIALS_PATH" ]; then
    GOOGLE_OAUTH_CREDENTIALS_FILE="$RELATIVE_CREDENTIALS_PATH"
  else
    echo "Error: Google OAuth file not found: $GOOGLE_OAUTH_CREDENTIALS_FILE"
    exit 1
  fi
fi

echo "=== Preparing google-calendar-mcp on $SSH_HOST ==="

ssh "$SSH_HOST" bash <<'REMOTE'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is not installed on remote host. Install Node.js LTS first."
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx is not installed on remote host. Install Node.js LTS first."
  exit 1
fi

if ! command -v mcporter >/dev/null 2>&1; then
  echo "Installing mcporter..."
  npm install -g mcporter
fi

mkdir -p /opt/mcp-servers/google-calendar-mcp
REMOTE

echo "Deploying Google OAuth credentials..."
scp "$GOOGLE_OAUTH_CREDENTIALS_FILE" "$SSH_HOST:$CREDENTIALS_FILE"
ssh "$SSH_HOST" "chmod 600 '$CREDENTIALS_FILE'"

echo "Registering with mcporter..."
if [ -n "${GOOGLE_CALENDAR_ENABLED_TOOLS:-}" ]; then
  ssh "$SSH_HOST" "mcporter config add google-calendar \
    --command 'npx' \
    --arg '-y' --arg '@cocal/google-calendar-mcp' \
    --env 'GOOGLE_OAUTH_CREDENTIALS=$CREDENTIALS_FILE' \
    --env 'ENABLED_TOOLS=${GOOGLE_CALENDAR_ENABLED_TOOLS}' \
    --scope home \
    --description 'Google Calendar integration via MCP' 2>/dev/null || echo 'Already registered'"
else
  ssh "$SSH_HOST" "mcporter config add google-calendar \
    --command 'npx' \
    --arg '-y' --arg '@cocal/google-calendar-mcp' \
    --env 'GOOGLE_OAUTH_CREDENTIALS=$CREDENTIALS_FILE' \
    --scope home \
    --description 'Google Calendar integration via MCP' 2>/dev/null || echo 'Already registered'"
fi

echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! google-calendar-mcp is live on $SSH_HOST ==="
echo "If this is your first run, complete Google OAuth when prompted by the MCP server."
echo "Manual auth command (optional):"
echo "ssh $SSH_HOST \"GOOGLE_OAUTH_CREDENTIALS=$CREDENTIALS_FILE npx -y @cocal/google-calendar-mcp auth\""

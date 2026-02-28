#!/usr/bin/env bash
# Setup @alexarevalo.ai/mcp-server-ticktick on a remote server
# Usage: ./setup-ticktick-mcp.sh [ssh-host]
# Requires: .env in repo root with TICKTICK_CLIENT_ID, TICKTICK_CLIENT_SECRET, TICKTICK_ACCESS_TOKEN
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"

# Read local .env (dotenv style, without sourcing)
if [ ! -f "$REPO_DIR/.env" ]; then
  echo "Error: $REPO_DIR/.env not found. Copy .env.template to .env and fill in credentials."
  exit 1
fi

read_env_var() {
  local key="$1"
  awk -v k="$key" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, k "=") == 1) {
        val = substr(line, length(k) + 2)
        sub(/\r$/, "", val)
        print val
        exit
      }
    }
  ' "$REPO_DIR/.env"
}

strip_quotes() {
  local v="$1"
  case "$v" in
    \"*\") printf '%s' "${v:1:${#v}-2}" ;;
    \'*\') printf '%s' "${v:1:${#v}-2}" ;;
    *) printf '%s' "$v" ;;
  esac
}

TICKTICK_CLIENT_ID="$(strip_quotes "$(read_env_var TICKTICK_CLIENT_ID)")"
TICKTICK_CLIENT_SECRET="$(strip_quotes "$(read_env_var TICKTICK_CLIENT_SECRET)")"
TICKTICK_ACCESS_TOKEN="$(strip_quotes "$(read_env_var TICKTICK_ACCESS_TOKEN)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${TICKTICK_CLIENT_ID:-}" ]; then
  echo "Error: TICKTICK_CLIENT_ID is empty in .env."
  exit 1
fi
if [ -z "${TICKTICK_ACCESS_TOKEN:-}" ]; then
  echo "Error: TICKTICK_ACCESS_TOKEN is empty in .env."
  exit 1
fi

echo "=== Setting up @alexarevalo.ai/mcp-server-ticktick on $SSH_HOST ==="

# Ensure npm/npx available on remote
ssh "$SSH_HOST" bash <<'REMOTE'
set -euo pipefail
if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx is not installed on remote host. Install Node.js LTS first."
  exit 1
fi

if ! command -v mcporter >/dev/null 2>&1; then
  echo "Installing mcporter..."
  npm install -g mcporter
fi
REMOTE

# Register with mcporter
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add ticktick \
  --command 'npx' \
  --arg '-y' --arg '@alexarevalo.ai/mcp-server-ticktick' \
  --env 'TICKTICK_CLIENT_ID=${TICKTICK_CLIENT_ID}' \
  --env 'TICKTICK_CLIENT_SECRET=${TICKTICK_CLIENT_SECRET}' \
  --env 'TICKTICK_ACCESS_TOKEN=${TICKTICK_ACCESS_TOKEN}' \
  --scope home \
  --description 'TickTick task management via MCP' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! @alexarevalo.ai/mcp-server-ticktick is live on $SSH_HOST ==="
echo "Note: Access token expires every 180 days. To refresh:"
echo "  TICKTICK_CLIENT_ID=$TICKTICK_CLIENT_ID TICKTICK_CLIENT_SECRET=<secret> npx @alexarevalo.ai/mcp-server-ticktick ticktick-auth"

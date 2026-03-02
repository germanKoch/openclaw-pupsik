#!/usr/bin/env bash
# Setup telegram-userapi-mcp on a remote server
# Usage: ./setup-telegram-userapi-mcp.sh [ssh-host]
# Requires: .env in repo root with TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_SESSION_STRING
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"
REMOTE_DIR="/opt/mcp-servers/telegram-userapi-mcp"
GIT_REPO="https://github.com/germanKoch/telegram-userapi-mcp.git"
BLOCKLIST_FILE="telegram-blocked-chats.json"

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

TELEGRAM_API_ID="$(strip_quotes "$(read_env_var TELEGRAM_API_ID)")"
TELEGRAM_API_HASH="$(strip_quotes "$(read_env_var TELEGRAM_API_HASH)")"
TELEGRAM_SESSION_STRING="$(strip_quotes "$(read_env_var TELEGRAM_SESSION_STRING)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${TELEGRAM_API_ID:-}" ]; then
  echo "Error: TELEGRAM_API_ID is empty in .env."
  exit 1
fi
if [ -z "${TELEGRAM_API_HASH:-}" ]; then
  echo "Error: TELEGRAM_API_HASH is empty in .env."
  exit 1
fi
if [ -z "${TELEGRAM_SESSION_STRING:-}" ]; then
  echo "Error: TELEGRAM_SESSION_STRING is empty in .env."
  echo "Generate it with: uv run --with telethon scripts/generate-telegram-session.py"
  exit 1
fi

echo "=== Setting up telegram-userapi-mcp on $SSH_HOST ==="

# Install deps, clone repo, create venv — all in one SSH session
echo "Installing dependencies and cloning repository..."
ssh "$SSH_HOST" bash <<REMOTE
set -euo pipefail
export PATH="\$HOME/.local/bin:\$PATH"

# Ensure uv is available
if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="\$HOME/.local/bin:\$PATH"
fi

# Ensure mcporter is available
if ! command -v mcporter >/dev/null 2>&1; then
  echo "Installing mcporter..."
  npm install -g mcporter
fi

# Clone or update the repository
if [ -d "$REMOTE_DIR/.git" ]; then
  cd "$REMOTE_DIR"
  git pull --ff-only
else
  git clone "$GIT_REPO" "$REMOTE_DIR"
fi

# Install Python dependencies
cd "$REMOTE_DIR"
uv venv
uv sync
REMOTE

# Deploy blocklist config if it exists locally
if [ -f "$REPO_DIR/$BLOCKLIST_FILE" ]; then
  echo "Deploying blocklist config..."
  scp "$REPO_DIR/$BLOCKLIST_FILE" "$SSH_HOST:$REMOTE_DIR/blocked-chats.json"
  BLOCKLIST_ENV="--env 'TELEGRAM_BLOCKED_CHATS_FILE=$REMOTE_DIR/blocked-chats.json'"
else
  echo "No $BLOCKLIST_FILE found locally, skipping blocklist deployment."
  BLOCKLIST_ENV=""
fi

# Register with mcporter
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add telegram-userapi \
  --command '$REMOTE_DIR/.venv/bin/python' \
  --arg '-m' --arg 'telegram_userapi_mcp' \
  --env 'TELEGRAM_API_ID=${TELEGRAM_API_ID}' \
  --env 'TELEGRAM_API_HASH=${TELEGRAM_API_HASH}' \
  --env 'TELEGRAM_SESSION_STRING=${TELEGRAM_SESSION_STRING}' \
  ${BLOCKLIST_ENV} \
  --scope home \
  --description 'Telegram personal account messaging via Telethon UserAPI' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! telegram-userapi-mcp is live on $SSH_HOST ==="
echo "Tools: list_chats, read_messages, send_message"

#!/usr/bin/env bash
# Setup ticktick-focus-mcp on a remote server
# Usage: ./setup-ticktick-focus-mcp.sh [ssh-host]
# Requires: .env in repo root with TICKTICK_USERNAME, TICKTICK_PASSWORD
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"
REMOTE_DIR="/opt/mcp-servers/ticktick-focus-mcp"
GIT_REPO="https://github.com/germanKoch/ticktick-focus-mcp.git"

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

TICKTICK_USERNAME="$(strip_quotes "$(read_env_var TICKTICK_USERNAME)")"
TICKTICK_PASSWORD="$(strip_quotes "$(read_env_var TICKTICK_PASSWORD)")"
TICKTICK_TIMEZONE="$(strip_quotes "$(read_env_var TICKTICK_TIMEZONE)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${TICKTICK_USERNAME:-}" ]; then
  echo "Error: TICKTICK_USERNAME is empty in .env."
  exit 1
fi
if [ -z "${TICKTICK_PASSWORD:-}" ]; then
  echo "Error: TICKTICK_PASSWORD is empty in .env."
  exit 1
fi

# Default timezone
TICKTICK_TIMEZONE="${TICKTICK_TIMEZONE:-Europe/Moscow}"

echo "=== Setting up ticktick-focus-mcp on $SSH_HOST ==="

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

# Register with mcporter
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add ticktick-focus \
  --command '$REMOTE_DIR/.venv/bin/python' \
  --arg '-m' --arg 'ticktick_focus_mcp' \
  --env 'TICKTICK_USERNAME=${TICKTICK_USERNAME}' \
  --env 'TICKTICK_PASSWORD=${TICKTICK_PASSWORD}' \
  --env 'TICKTICK_TIMEZONE=${TICKTICK_TIMEZONE}' \
  --scope home \
  --description 'TickTick Focus sessions (Pomodoro/Stopwatch) — timeline, statistics, CRUD via unofficial API' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! ticktick-focus-mcp is live on $SSH_HOST ==="
echo "Tools: get_focus_statistics, get_focus_preferences, get_focus_timeline, get_current_focus, update_focus_record, delete_focus_record"

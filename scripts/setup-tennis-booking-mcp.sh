#!/usr/bin/env bash
# Setup tennis-booking-mcp on a remote server
# Usage: ./setup-tennis-booking-mcp.sh [ssh-host]
# Requires: .env in repo root with TALLANTO_BASE_URL, TALLANTO_USERNAME, TALLANTO_PASSWORD_HASH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"
REMOTE_DIR="/opt/mcp-servers/tennis-booking-mcp"
GIT_REPO="https://github.com/germanKoch/tennis-booking-mcp.git"

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

TALLANTO_BASE_URL="$(strip_quotes "$(read_env_var TALLANTO_BASE_URL)")"
TALLANTO_USERNAME="$(strip_quotes "$(read_env_var TALLANTO_USERNAME)")"
TALLANTO_PASSWORD_HASH="$(strip_quotes "$(read_env_var TALLANTO_PASSWORD_HASH)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${TALLANTO_BASE_URL:-}" ]; then
  echo "Error: TALLANTO_BASE_URL is empty in .env."
  exit 1
fi
if [ -z "${TALLANTO_USERNAME:-}" ]; then
  echo "Error: TALLANTO_USERNAME is empty in .env."
  exit 1
fi
if [ -z "${TALLANTO_PASSWORD_HASH:-}" ]; then
  echo "Error: TALLANTO_PASSWORD_HASH is empty in .env."
  exit 1
fi

echo "=== Setting up tennis-booking-mcp on $SSH_HOST ==="

# Ensure uv and mcporter are available on remote
ssh "$SSH_HOST" bash <<'REMOTE'
set -euo pipefail
if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
if ! command -v mcporter >/dev/null 2>&1; then
  echo "Installing mcporter..."
  npm install -g mcporter
fi
REMOTE

# Clone or update the repository
echo "Cloning/updating repository..."
ssh "$SSH_HOST" bash <<REMOTE
set -euo pipefail
if [ -d "$REMOTE_DIR/.git" ]; then
  cd "$REMOTE_DIR"
  git pull --ff-only
else
  git clone "$GIT_REPO" "$REMOTE_DIR"
fi
cd "$REMOTE_DIR"
uv venv
uv sync
REMOTE

# Register with mcporter
echo "Registering with mcporter..."
ssh "$SSH_HOST" "mcporter config add tennis-booking \
  --command '$REMOTE_DIR/.venv/bin/python' \
  --arg '-m' --arg 'tennis_booking_mcp' \
  --env 'TALLANTO_BASE_URL=${TALLANTO_BASE_URL}' \
  --env 'TALLANTO_USERNAME=${TALLANTO_USERNAME}' \
  --env 'TALLANTO_PASSWORD_HASH=${TALLANTO_PASSWORD_HASH}' \
  --scope home \
  --description 'Tennis court booking via Tallanto API (T14 club)' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! tennis-booking-mcp is live on $SSH_HOST ==="
echo "Tools: list_available_slots, book_court, cancel_booking, get_my_bookings"

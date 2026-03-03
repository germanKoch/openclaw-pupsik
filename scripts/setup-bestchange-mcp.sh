#!/usr/bin/env bash
# Setup bestchange-mcp on a remote server
# Usage: ./setup-bestchange-mcp.sh [ssh-host]
# Requires: .env in repo root with BESTCHANGE_API_KEY
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"
REMOTE_DIR="/opt/mcp-servers/bestchange-mcp"
GIT_REPO="https://github.com/germanKoch/bestchange-mcp.git"

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

BESTCHANGE_API_KEY="$(strip_quotes "$(read_env_var BESTCHANGE_API_KEY)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${BESTCHANGE_API_KEY:-}" ]; then
  echo "Error: BESTCHANGE_API_KEY is empty in .env."
  exit 1
fi

echo "=== Setting up bestchange-mcp on $SSH_HOST ==="

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
ssh "$SSH_HOST" "mcporter config add bestchange \
  --command '$REMOTE_DIR/.venv/bin/python' \
  --arg '-m' --arg 'bestchange_mcp' \
  --env 'BESTCHANGE_API_KEY=${BESTCHANGE_API_KEY}' \
  --scope home \
  --description 'BestChange exchange aggregator — live crypto/fiat rates across 300+ exchangers' 2>/dev/null || echo 'Already registered'"

# Restart OpenClaw gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! bestchange-mcp is live on $SSH_HOST ==="
echo "Tools: search_currencies, get_rates, get_best_rate, get_rates_batch, get_presences, list_currencies, list_changers, list_countries, list_cities"

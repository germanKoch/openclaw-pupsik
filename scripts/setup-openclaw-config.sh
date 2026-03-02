#!/usr/bin/env bash
# Deploy openclaw-config.json.template to a remote server, injecting secrets from .env
# Usage: ./setup-openclaw-config.sh [ssh-host]
# Requires: .env with TELEGRAM_BOT_TOKEN
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"
CONFIG_TEMPLATE="$REPO_DIR/openclaw-config.json.template"

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "Error: $REPO_DIR/.env not found. Copy .env.template to .env and fill in credentials."
  exit 1
fi

if [ ! -f "$CONFIG_TEMPLATE" ]; then
  echo "Error: $CONFIG_TEMPLATE not found."
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

TELEGRAM_BOT_TOKEN="$(strip_quotes "$(read_env_var TELEGRAM_BOT_TOKEN)")"
HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "Error: TELEGRAM_BOT_TOKEN is empty in .env."
  exit 1
fi

echo "=== Deploying OpenClaw config to $SSH_HOST ==="

# Read existing config to preserve gateway.auth.token (generated on first setup)
EXISTING_AUTH_TOKEN=$(ssh "$SSH_HOST" "python3 -c \"
import json, pathlib
p = pathlib.Path.home() / '.openclaw/openclaw.json'
if p.exists():
    c = json.loads(p.read_text())
    print(c.get('gateway',{}).get('auth',{}).get('token',''))
\" 2>/dev/null" || true)

# Build final config by injecting secrets into template
FINAL_CONFIG=$(python3 -c "
import json, sys

with open('$CONFIG_TEMPLATE') as f:
    config = json.load(f)

# Inject bot token
config['channels']['telegram']['botToken'] = '$TELEGRAM_BOT_TOKEN'

# Preserve or generate gateway auth token
auth_token = '$EXISTING_AUTH_TOKEN'
if auth_token:
    config['gateway']['auth'] = {'token': auth_token}

print(json.dumps(config, indent=2))
")

# Deploy config
echo "$FINAL_CONFIG" | ssh "$SSH_HOST" "cat > ~/.openclaw/openclaw.json"

# Restart gateway
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! OpenClaw config deployed to $SSH_HOST ==="

#!/usr/bin/env bash
# Register financial-analysis cron job on a remote server
# Usage: ./setup-financial-analysis-cron.sh [ssh-host]
# Schedule: 1st of each month at 9:00 AM Moscow time
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST_ARG="${1:-}"

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

HETZNER_SSH_HOST="$(strip_quotes "$(read_env_var HETZNER_SSH_HOST)")"

if [ -n "$SSH_HOST_ARG" ]; then
  SSH_HOST="$SSH_HOST_ARG"
elif [ -n "$HETZNER_SSH_HOST" ]; then
  SSH_HOST="$HETZNER_SSH_HOST"
else
  SSH_HOST="hetzner-main"
fi

echo "=== Registering financial-analysis cron on $SSH_HOST ==="

ssh "$SSH_HOST" "openclaw cron add \
  --name 'Ежемесячный финансовый отчёт' \
  --cron '0 9 1 * *' \
  --tz 'Europe/Moscow' \
  --session isolated \
  --message '/financial-analysis' \
  --timeout-seconds 300 \
  --announce \
  2>&1 || echo 'Cron job may already exist'"

echo "=== Done! Cron job registered ==="
echo "Verify with: ssh $SSH_HOST \"openclaw cron list\""

#!/usr/bin/env bash
# Deploy skills to the remote OpenClaw host
# Usage: ./scripts/deploy-skills.sh [ssh-host]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"
REMOTE_SKILLS_DIR="\$HOME/.openclaw/workspace/skills"

echo "=== Deploying skills to $SSH_HOST ==="

# Ensure remote directory exists
ssh "$SSH_HOST" "mkdir -p $REMOTE_SKILLS_DIR"

# Sync skills directory
echo "Copying skills..."
rsync -av --delete "$REPO_DIR/skills/" "$SSH_HOST:~/.openclaw/workspace/skills/"

echo "Skills deployed:"
ssh "$SSH_HOST" "ls -1 $REMOTE_SKILLS_DIR"

# Restart OpenClaw gateway to pick up new skills
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

# Register cron jobs for skills that need them
echo "Registering cron jobs..."

# financial-analysis: 1st of each month at 9:00 AM Moscow time
EXISTING=$(ssh "$SSH_HOST" "openclaw cron list --json" 2>/dev/null \
  | grep -c 'financial-analysis' || true)
if [ "$EXISTING" = "0" ]; then
  ssh "$SSH_HOST" "openclaw cron add \
    --name 'Ежемесячный финансовый отчёт' \
    --cron '0 9 1 * *' \
    --tz 'Europe/Moscow' \
    --session isolated \
    --message '/financial-analysis' \
    --timeout-seconds 300 \
    --announce" \
    && echo "  financial-analysis cron registered" \
    || echo "  financial-analysis cron failed to register"
else
  echo "  financial-analysis cron already exists, skipping"
fi

echo "=== Done! Skills deployed to $SSH_HOST ==="

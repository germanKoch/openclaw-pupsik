#!/usr/bin/env bash
# Deploy skills to the remote OpenClaw host
# Usage: ./scripts/deploy-skills.sh [ssh-host]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"
REMOTE_SKILLS_DIR="\$HOME/.openclaw/skills"

echo "=== Deploying skills to $SSH_HOST ==="

# Ensure remote directory exists
ssh "$SSH_HOST" "mkdir -p $REMOTE_SKILLS_DIR"

# Sync skills directory
echo "Copying skills..."
rsync -av --delete "$REPO_DIR/skills/" "$SSH_HOST:~/.openclaw/skills/"

echo "Skills deployed:"
ssh "$SSH_HOST" "ls -1 $REMOTE_SKILLS_DIR"

# Restart OpenClaw gateway to pick up new skills
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo "=== Done! Skills deployed to $SSH_HOST ==="

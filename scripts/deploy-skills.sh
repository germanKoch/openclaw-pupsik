#!/usr/bin/env bash
# Deploy skills to the remote OpenClaw host
# All skills go to ~/.openclaw/workspace/skills/ (gateway discovery path).
#
# Usage: ./scripts/deploy-skills.sh [ssh-host]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"

echo "=== Deploying skills to $SSH_HOST ==="

deploy_skill() {
    local skill="$1"
    local remote_dir="~/.openclaw/workspace/skills/$skill"

    echo "  $skill"
    ssh "$SSH_HOST" "mkdir -p $remote_dir"
    scp "$REPO_DIR/skills/$skill/SKILL.md" "$SSH_HOST:$remote_dir/SKILL.md"
}

# Deploy each skill directory
for skill_dir in "$REPO_DIR/skills"/*/; do
    skill=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
        deploy_skill "$skill"
    fi
done

echo ""
echo "Skills deployed."

# Restart gateway to pick up new skills
echo "Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

# ── Register cron jobs ────────────────────────────────────────────────────────
echo ""
echo "Registering cron jobs..."

# financial-analysis: 1st of each month at 9:00 AM Moscow time, runs under money agent
EXISTING=$(ssh "$SSH_HOST" "openclaw cron list --json" 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for j in d['jobs'] if 'финансов' in j.get('name','').lower() or 'financial' in j.get('name','').lower()))" \
    || echo "0")

if [ "$EXISTING" = "0" ]; then
    ssh "$SSH_HOST" "openclaw cron add \
        --name 'Ежемесячный финансовый отчёт' \
        --agent money \
        --cron '0 9 1 * *' \
        --tz 'Europe/Moscow' \
        --session isolated \
        --message '/financial-analysis' \
        --thinking high \
        --timeout-seconds 600 \
        --no-deliver" \
        && echo "  financial-analysis cron registered" \
        || echo "  financial-analysis cron failed to register"
else
    echo "  financial-analysis cron already exists"
fi

echo ""
echo "=== Done! Skills deployed to $SSH_HOST ==="

#!/usr/bin/env bash
# Setup multi-agent configuration: money + schedule subagents
# Usage: ./scripts/setup-agents.sh [ssh-host]
#
# What this script does:
#   1. Creates 'money' and 'schedule' agents on the remote host
#   2. Deploys workspace files (AGENTS.md, TOOLS.md) to each agent workspace
#   3. Updates openclaw.json with per-agent tool restrictions
#   4. Migrates relevant cron jobs to target the correct agent
#   5. Restarts the OpenClaw gateway
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HOST="${1:-hetzner-main}"

echo "=== Setting up multi-agent config on $SSH_HOST ==="

# ── 1. Create agents ──────────────────────────────────────────────────────────
echo ""
echo "[1/5] Creating agents..."

ssh "$SSH_HOST" "openclaw agents add money \
  --workspace ~/.openclaw/workspace-money \
  --non-interactive 2>&1 | grep -v '^$' || true"

ssh "$SSH_HOST" "openclaw agents add schedule \
  --workspace ~/.openclaw/workspace-schedule \
  --non-interactive 2>&1 | grep -v '^$' || true"

echo "  Agents created (or already exist)"

# ── 2. Deploy workspace files ─────────────────────────────────────────────────
echo ""
echo "[2/5] Deploying workspace files..."

# money agent
ssh "$SSH_HOST" "mkdir -p ~/.openclaw/workspace-money/skills"
scp "$REPO_DIR/agents/money/AGENTS.md" "$SSH_HOST:~/.openclaw/workspace-money/AGENTS.md"
scp "$REPO_DIR/agents/money/TOOLS.md"  "$SSH_HOST:~/.openclaw/workspace-money/TOOLS.md"

# schedule agent
ssh "$SSH_HOST" "mkdir -p ~/.openclaw/workspace-schedule/skills"
scp "$REPO_DIR/agents/schedule/AGENTS.md" "$SSH_HOST:~/.openclaw/workspace-schedule/AGENTS.md"
scp "$REPO_DIR/agents/schedule/TOOLS.md"  "$SSH_HOST:~/.openclaw/workspace-schedule/TOOLS.md"

echo "  Workspace files deployed"

# ── 3. Update openclaw.json ───────────────────────────────────────────────────
echo ""
echo "[3/5] Updating openclaw.json with tool restrictions..."

ssh "$SSH_HOST" python3 << 'PYEOF'
import json, os

cfg_path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(cfg_path) as f:
    cfg = json.load(f)

# Ensure agents section exists
if "agents" not in cfg:
    cfg["agents"] = {}

# Preserve existing defaults (model, maxConcurrent, subagents, etc.)
defaults = cfg["agents"].get("defaults", {})
defaults["model"] = "openai-codex/gpt-5.3-codex"

# Build agents list (merge with existing to avoid clobbering manual entries)
existing_list = cfg["agents"].get("list", [])
existing_ids = {a["id"]: a for a in existing_list}

money_tools = [
    # ZenMoney
    "get_accounts", "get_transactions", "get_categories",
    "create_transaction", "update_transaction", "delete_transaction",
    "get_budgets", "suggest_category",
    # BestChange
    "search_currencies", "list_currencies", "list_groups",
    "list_countries", "list_cities", "list_changers",
    "get_rates", "get_best_rate", "get_rates_batch", "get_presences",
    # Workspace access
    "read", "write", "edit",
]

schedule_tools = [
    # TickTick
    "get_user_projects", "get_project_by_id", "get_project_with_data",
    "create_project", "update_project", "delete_project",
    "get_task_by_ids", "create_task", "update_task", "complete_task",
    "delete_task", "get_completed_tasks", "batch_update_tasks",
    "get_subtasks", "get_current_user", "get_inbox_tasks",
    # Google Calendar (hyphenated names)
    "list-calendars", "list-events", "search-events", "get-event",
    "list-colors", "create-event", "create-events", "update-event",
    "delete-event", "get-freebusy", "get-current-time",
    "respond-to-event", "manage-accounts",
    # Workspace access
    "read", "write", "edit",
]

# Update main agent: allow spawning money + schedule subagents
main_entry = existing_ids.get("main", {"id": "main", "default": True})
if "subagents" not in main_entry:
    main_entry["subagents"] = {}
main_entry["subagents"]["allowAgents"] = ["money", "schedule"]
existing_ids["main"] = main_entry

# money agent
money_entry = existing_ids.get("money", {"id": "money"})
money_entry["workspace"] = "~/.openclaw/workspace-money"
money_entry["tools"] = {"allow": money_tools}
existing_ids["money"] = money_entry

# schedule agent
schedule_entry = existing_ids.get("schedule", {"id": "schedule"})
schedule_entry["workspace"] = "~/.openclaw/workspace-schedule"
schedule_entry["tools"] = {"allow": schedule_tools}
existing_ids["schedule"] = schedule_entry

# Preserve order: main first, then others
ordered = []
for key in ["main", "money", "schedule"]:
    if key in existing_ids:
        ordered.append(existing_ids.pop(key))
ordered.extend(existing_ids.values())

cfg["agents"]["defaults"] = defaults
cfg["agents"]["list"] = ordered

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("  openclaw.json updated successfully")
PYEOF

# ── 4. Migrate cron jobs to correct agents ────────────────────────────────────
echo ""
echo "[4/5] Migrating cron jobs..."

# Get cron jobs JSON and update agentId for relevant jobs
ssh "$SSH_HOST" python3 << 'PYEOF'
import json, subprocess, sys

result = subprocess.run(
    ["openclaw", "cron", "list", "--json"],
    capture_output=True, text=True
)
if result.returncode != 0:
    print("  Warning: could not list cron jobs:", result.stderr)
    sys.exit(0)

jobs = json.loads(result.stdout).get("jobs", [])

# Map job name keywords to target agent
AGENT_MAP = {
    "финансов": "money",     # Ежемесячный финансовый отчёт
    "financial": "money",
    "вечерний": "schedule",  # Вечерний ревью задач
    "утренний дайджест": "schedule",  # Утренний дайджест статей
}

for job in jobs:
    name = job.get("name", "").lower()
    target_agent = None
    for keyword, agent in AGENT_MAP.items():
        if keyword in name:
            target_agent = agent
            break

    if target_agent and job.get("agentId") != target_agent:
        job_id = job["id"]
        print(f"  Migrating '{job['name']}' → agent:{target_agent}")
        r = subprocess.run(
            ["openclaw", "cron", "edit", job_id, "--agent", target_agent],
            capture_output=True, text=True
        )
        if r.returncode == 0:
            print(f"    OK")
        else:
            print(f"    Failed: {r.stderr.strip()}")
    elif target_agent:
        print(f"  '{job['name']}' already on agent:{target_agent}")
    else:
        print(f"  '{job['name']}' stays on agent:{job.get('agentId','main')}")
PYEOF

# Also update financial-analysis cron: switch to --agent money --thinking high --timeout 600
echo "  Updating financial-analysis cron settings..."
ssh "$SSH_HOST" bash << 'REMOTE'
JOB_ID=$(openclaw cron list --json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for j in d['jobs']:
    if 'финансов' in j.get('name','').lower() or 'financial' in j.get('name','').lower():
        print(j['id'])
        break
" 2>/dev/null || true)

if [ -n "$JOB_ID" ]; then
    openclaw cron edit "$JOB_ID" \
        --agent money \
        --thinking high \
        --timeout-seconds 600 \
        --no-deliver \
        2>&1 | head -3
    echo "  financial-analysis cron updated"
else
    echo "  financial-analysis cron not found (will be registered by deploy-skills.sh)"
fi
REMOTE

# ── 5. Restart gateway ────────────────────────────────────────────────────────
echo ""
echo "[5/5] Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo ""
echo "=== Done! Multi-agent setup complete ==="
echo ""
echo "Agents:"
ssh "$SSH_HOST" "openclaw agents list 2>&1"
echo ""
echo "Cron jobs:"
ssh "$SSH_HOST" "openclaw cron list --json 2>/dev/null | python3 -c \"
import json,sys
d=json.load(sys.stdin)
for j in d['jobs']:
    print(f'  [{j.get(\\\"agentId\\\",\\\"main\\\"):10}] {j[\\\"name\\\"]} — {j[\\\"schedule\\\"][\\\"expr\\\"]}')
\""

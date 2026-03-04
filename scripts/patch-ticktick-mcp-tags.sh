#!/usr/bin/env bash
# Patch the TickTick MCP to add `tags` field support to Zod schemas
#
# Problem: @alexarevalo.ai/mcp-server-ticktick strips `tags` from all task
#          operations (create_task, update_task, get_task_by_ids) because the
#          Zod schemas don't include the field. TickTick API supports tags natively.
#
# Fix: Install the npm package to a fixed path, apply minimal schema patch
#      (3 additions), update mcporter config to use the local install.
#
# Patch is idempotent: safe to rerun after npm package updates.
#
# Usage: ./scripts/patch-ticktick-mcp-tags.sh [ssh-host]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_HOST="${1:-hetzner-main}"
INSTALL_DIR="/opt/mcp-servers/ticktick-mcp"

echo "=== Patching TickTick MCP for tags support on $SSH_HOST ==="

# ── 1. Install npm package to fixed location ───────────────────────────────
echo ""
echo "[1/4] Installing @alexarevalo.ai/mcp-server-ticktick to $INSTALL_DIR..."
ssh "$SSH_HOST" "mkdir -p $INSTALL_DIR && npm install --prefix $INSTALL_DIR @alexarevalo.ai/mcp-server-ticktick --save 2>&1 | tail -3"
echo "  Package installed."

# ── 2. Apply patches to Zod schemas ───────────────────────────────────────
echo ""
echo "[2/4] Applying schema patches..."

ssh "$SSH_HOST" python3 << 'PYEOF'
import os, sys

base = "/opt/mcp-servers/ticktick-mcp/node_modules/@alexarevalo.ai/mcp-server-ticktick/dist"
types_path = f"{base}/common/types.js"
tasks_path = f"{base}/operations/tasks.js"

# ── Patch 1: TickTickTaskSchema in types.js ──────────────────────────────
with open(types_path) as f:
    src = f.read()

TAGS_FIELD = "    tags: z.array(z.string()).optional(),\n"
TAGS_DESC  = '    tags: z.array(z.string()).optional().describe(\'Task tags, e.g. ["DUE/D_2026.12.31"]\'),\n'

TYPES_ANCHOR   = "        .optional(),\n});\nexport const TickTickCheckListItemSchema"
TYPES_REPLACE  = "        .optional(),\n" + TAGS_FIELD + "});\nexport const TickTickCheckListItemSchema"

if "tags: z.array" in src:
    print("  types.js: tags already patched, skipping.")
else:
    if TYPES_ANCHOR not in src:
        print("  ERROR: types.js anchor not found. Package version may have changed.", file=sys.stderr)
        sys.exit(1)
    src = src.replace(TYPES_ANCHOR, TYPES_REPLACE, 1)
    with open(types_path, "w") as f:
        f.write(src)
    print("  types.js: TickTickTaskSchema patched with tags field.")

# ── Patch 2: CreateTaskOptionsSchema in tasks.js ─────────────────────────
with open(tasks_path) as f:
    src = f.read()

CREATE_ANCHOR  = "        .describe('Parent task ID to create this task as a subtask'),\n});\nexport const UpdateTaskOptionsSchema"
CREATE_REPLACE = "        .describe('Parent task ID to create this task as a subtask'),\n" + TAGS_DESC + "});\nexport const UpdateTaskOptionsSchema"

# ── Patch 3: UpdateTaskOptionsSchema in tasks.js ─────────────────────────
UPDATE_ANCHOR  = "        .describe('Parent task ID to make this task a subtask'),\n});\nexport const TasksIdsOptionsSchema"
UPDATE_REPLACE = "        .describe('Parent task ID to make this task a subtask'),\n" + TAGS_DESC + "});\nexport const TasksIdsOptionsSchema"

patched = False
if CREATE_ANCHOR in src:
    src = src.replace(CREATE_ANCHOR, CREATE_REPLACE, 1)
    print("  tasks.js: CreateTaskOptionsSchema patched with tags field.")
    patched = True
else:
    print("  tasks.js: CreateTaskOptionsSchema anchor not found (already patched or version mismatch).")

if UPDATE_ANCHOR in src:
    src = src.replace(UPDATE_ANCHOR, UPDATE_REPLACE, 1)
    print("  tasks.js: UpdateTaskOptionsSchema patched with tags field.")
    patched = True
else:
    print("  tasks.js: UpdateTaskOptionsSchema anchor not found (already patched or version mismatch).")

if patched:
    with open(tasks_path, "w") as f:
        f.write(src)

print("  Schema patches applied.")
PYEOF

# ── 3. Update mcporter config ──────────────────────────────────────────────
echo ""
echo "[3/4] Updating mcporter config to use local install..."

ssh "$SSH_HOST" python3 << PYEOF
import json, os

cfg_path = os.path.expanduser("~/.mcporter/mcporter.json")
with open(cfg_path) as f:
    cfg = json.load(f)

servers = cfg.get("mcpServers", {})

if "ticktick" not in servers:
    print("  ERROR: ticktick entry not found in mcporter.json", flush=True)
    import sys; sys.exit(1)

entry = servers["ticktick"]
local_cli = "$INSTALL_DIR/node_modules/@alexarevalo.ai/mcp-server-ticktick/dist/index.js"

# Check if already patched
if entry.get("command") == "node" and local_cli in (entry.get("args") or []):
    print("  mcporter.json: ticktick entry already uses local install, skipping.")
else:
    entry["command"] = "node"
    local_index = local_cli.replace("/dist/cli.js", "/dist/index.js")
    entry["command"] = "node"
    entry["args"] = [local_index]
    servers["ticktick"] = entry
    cfg["mcpServers"] = servers
    with open(cfg_path, "w") as f:
        json.dump(cfg, f, indent=4, ensure_ascii=False)
    print(f"  mcporter.json: ticktick updated to use local node at {local_index}")
PYEOF

# ── 4. Restart gateway ──────────────────────────────────────────────────────
echo ""
echo "[4/4] Restarting OpenClaw gateway..."
ssh "$SSH_HOST" "openclaw gateway restart"

echo ""
echo "=== TickTick MCP tags patch complete ==="
echo ""
echo "Verification:"
echo "  ssh $SSH_HOST \"mcporter list ticktick --schema --json\" | python3 -c \\"
echo "    \"import json,sys; d=json.load(sys.stdin); tools={t['name']:list(t.get('inputSchema',{}).get('properties',{}).keys()) for t in d['tools']}; print('create_task tags:', 'tags' in tools.get('create_task',[])); print('update_task tags:', 'tags' in tools.get('update_task',[]))\""

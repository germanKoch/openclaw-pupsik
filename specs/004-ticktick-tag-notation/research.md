# Research: TickTick Tag Notation — Phase 0

**Feature**: 004-ticktick-tag-notation
**Date**: 2026-03-04

---

## Question 1: Does the current TickTick MCP support tags in create/update/read?

**Decision**: No. The deployed `@alexarevalo.ai/mcp-server-ticktick` (npm) does NOT support tags.

**Evidence** (verified on hetzner-main):
- `CreateTaskOptionsSchema` has no `tags` field — properties: title, projectId, content, desc, isAllDay, startDate, dueDate, timeZone, reminders, repeatFlag, priority, sortOrder, items, parentId
- `UpdateTaskOptionsSchema` has no `tags` field — same properties + taskId/id
- `TickTickTaskSchema` (response schema) has no `tags` field
- Zod's default `.parse()` strips unknown fields, so passing `tags: [...]` to `create_task` silently discards them
- Tags are stripped from read responses too — `get_task_by_ids`, `get_project_with_data` return objects without `tags`

**Root cause**: The MCP was written without tag support. The underlying TickTick API does support tags (confirmed via `@ticktick/mcp-server` package source: `tags: (object.tags || [])`).

**Required change**: Add `tags: z.array(z.string()).optional()` to 3 places in the MCP source:
1. `CreateTaskOptionsSchema` in `dist/operations/tasks.js`
2. `UpdateTaskOptionsSchema` in `dist/operations/tasks.js`
3. `TickTickTaskSchema` in `dist/common/types.js`

This is a 3-line addition. The existing `createTask()` and `updateTask()` implementations already pass all params through to the TickTick API body (`body: { ...params }`) so no logic changes are needed.

---

## Question 2: What is the TickTick tag format for nested tags?

**Decision**: Slash-separated path string. Parent `DUE` + child `D_2026.12.31` → stored as `"DUE/D_2026.12.31"` in the `tags` string array.

**Evidence**: TickTick API stores tags as `string[]`. Nested tags use `/` as separator — this is consistent with how TickTick displays hierarchical tags in the UI (parent/child). Confirmed via `@ticktick/mcp-server` source structure and TickTick API documentation.

**Tag format examples**:
- `"DUE/D_2026.12.31"` — real deadline Dec 31, 2026
- `"NOT_EARLIER/N_2026.06.01"` — don't start before Jun 1, 2026
- `"PERSON/P_KSENIIA"` — associated with Kseniia
- `"PERSON/P_IVAN_PETROV"` — space replaced with underscore

---

## Question 3: How to deploy the MCP patch without maintaining a full fork?

**Decision**: Install the npm package to a fixed path and apply a minimal in-place patch, then update mcporter to use the local install.

**Rationale**:
- The npx cache path (`/root/.npm/_npx/<hash>/`) includes a hash derived from the command string and changes when the package updates — unreliable as a patch target
- A full GitHub fork adds ongoing maintenance overhead for a 3-line change
- Pinning to a fixed local path + patch script is tracked in the repo, idempotent, and simple

**Approach**:
1. SSH to hetzner-main, install the package at a deterministic location:
   ```bash
   mkdir -p /opt/mcp-servers/ticktick-mcp
   npm install --prefix /opt/mcp-servers/ticktick-mcp @alexarevalo.ai/mcp-server-ticktick
   ```
2. Apply the patch using inline Node.js (modify `tasks.js` and `types.js`)
3. Update mcporter config: change command from `npx -y @alexarevalo.ai/mcp-server-ticktick` to `node /opt/mcp-servers/ticktick-mcp/node_modules/@alexarevalo.ai/mcp-server-ticktick/dist/cli.js`
4. Restart gateway

**Create `scripts/patch-ticktick-mcp-tags.sh`** that performs steps 1–4. Idempotent: can be rerun after package updates.

**Alternatives rejected**:
- `npx` cache patching: fragile, path changes on version bumps
- Full fork on GitHub: overkill for a 3-line patch; adds npm publish step
- Python wrapper MCP: different language, different auth flow, more effort

---

## Question 4: Do existing task-reading tools expose tags after the MCP is patched?

**Decision**: Yes, once `TickTickTaskSchema` includes `tags`, all existing read tools will return tags.

**Tools that benefit from the patch**:
- `get_task_by_ids` → returns raw task, parsed via `TickTickTaskSchema`
- `get_project_with_data` → tasks array parsed via `TickTickTaskSchema`
- `get_inbox_tasks` → uses project data endpoint, same schema
- `batch_update_tasks` → `add`/`update` arrays use `TickTickTaskSchema.partial()`

After the patch, the agent will be able to:
- Read tags from any task
- Write tags when creating tasks
- Update tags when updating tasks

---

## Question 5: Tag parsing rules for the schedule agent

**Decision**: The agent parses and writes tags according to the notation system. Rules encoded in AGENTS.md and TOOLS.md.

**Parsing rules**:

| Tag pattern | Regex | Parse result |
|-------------|-------|--------------|
| `DUE/D_YYYY.MM.DD` | `^DUE\/D_(\d{4})\.(\d{2})\.(\d{2})$` | deadline date |
| `NOT_EARLIER/N_YYYY.MM.DD` | `^NOT_EARLIER\/N_(\d{4})\.(\d{2})\.(\d{2})$` | earliest start date |
| `PERSON/P_NAME` | `^PERSON\/P_([A-Z][A-Z0-9_]*)$` | person name |

**Edge case handling** (per spec):
- Multiple `DUE/*` tags → use nearest, warn user about anomaly
- `NOT_EARLIER > DUE` → warn user at creation/detection
- Invalid date (e.g., `D_2026.13.01`) → ignore silently, notify user
- Person name with space → `P_IVAN_PETROV` (underscore substitution)
- `NOT_EARLIER` future + `DUE` within 7 days → show in "Горящие дедлайны" with freeze note

**Display format** (agent never shows raw tags to user):
- `DUE/D_2026.04.30` → `"дедлайн: 30 апреля 2026"`
- `NOT_EARLIER/N_2026.06.01` → `"заморожена до: 1 июня 2026"`
- `PERSON/P_KSENIIA` → `"связана с: Kseniia"`

---

## Summary of Decisions

| Topic | Decision |
|-------|----------|
| MCP tags support | Patch local install (3 schema additions) |
| Tag storage format | `tags: string[]` with `/`-separated hierarchy |
| Patch deployment | `scripts/patch-ticktick-mcp-tags.sh` → fixed path at `/opt/mcp-servers/ticktick-mcp/` |
| Patch activation | mcporter config updated to use local `node` command instead of `npx` |
| Agent tag parsing | Regex-based, in AGENTS.md + TOOLS.md documentation |
| "Горящий дедлайн" threshold | ≤7 days from current date (per spec) |
| NOT_EARLIER suppression | Fully hidden from plans; shown separately in inbox review |

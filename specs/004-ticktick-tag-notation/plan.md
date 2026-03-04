# Implementation Plan: TickTick Tag Notation System

**Branch**: `004-ticktick-tag-notation` | **Date**: 2026-03-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-ticktick-tag-notation/spec.md`

## Summary

Introduce a structured tag notation system for the TickTick schedule agent: `DUE/D_YYYY.MM.DD` (real deadline), `NOT_EARLIER/N_YYYY.MM.DD` (earliest start), and `PERSON/P_NAME` (person association). The agent reads, writes, and interprets these tags to enrich task planning.

**Critical blocker resolved**: The deployed `@alexarevalo.ai/mcp-server-ticktick` npm package does not expose `tags` in any tool schema — they are silently stripped by Zod. A minimal MCP patch (3 schema additions) is required before skills can use tags. Full research in [research.md](research.md).

Deliverables:
1. `scripts/patch-ticktick-mcp-tags.sh` — installs MCP at fixed path, applies tag schema patch, updates mcporter
2. `skills/daily-planner/SKILL.md` — adds "Горящие дедлайны" section and NOT_EARLIER filtering
3. `skills/ticktick-inbox/SKILL.md` — adds tag suggestion logic and tag-aware prioritization
4. `agents/schedule/AGENTS.md` + `TOOLS.md` — adds tag notation reference

## Technical Context

**Language/Version**: JavaScript/Node.js (MCP patch) + Markdown (SKILL.md agent prompts)
**Primary Dependencies**: `@alexarevalo.ai/mcp-server-ticktick` npm package (patched locally), OpenClaw gateway, mcporter
**Storage**: N/A — tags stored in TickTick tasks via API; no additional workspace files
**Testing**: Manual invocation via OpenClaw; verify tag persistence in TickTick app and agent responses
**Target Platform**: OpenClaw gateway (Linux server, hetzner-main)
**Project Type**: MCP patch + skill prompts (no new application code)
**Performance Goals**: No performance impact; tag parsing is string operations in agent context
**Constraints**: Tags written/read via TickTick API only; agent never adds tags without user confirmation (except during task creation when user specifies deadline/person)
**Scale/Scope**: Single user; typical task has 0–3 notation tags

## Constitution Check

*No constitution file found. Gate passes by default.*

## Project Structure

### Documentation (this feature)

```text
specs/004-ticktick-tag-notation/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: MCP tags research, patch decision
├── data-model.md        # Phase 1: tag entities, task model, parsing rules
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
scripts/
└── patch-ticktick-mcp-tags.sh     # New: installs npm pkg at fixed path, patches schemas, updates mcporter

skills/
├── daily-planner/
│   └── SKILL.md                   # Update: add горящие дедлайны section, NOT_EARLIER filtering
└── ticktick-inbox/
    └── SKILL.md                   # Update: add tag suggestion + tag-aware priority logic

agents/schedule/
├── AGENTS.md                      # Update: add tag notation reference + tag operations guide
└── TOOLS.md                       # Update: add tag notation section with format reference
```

**Structure Decision**: No new application code. The only code artifact is `patch-ticktick-mcp-tags.sh` which patches the deployed npm package. All agent logic lives in Markdown prompt files (SKILL.md, AGENTS.md, TOOLS.md).

## Complexity Tracking

> No constitution violations.

---

## Implementation Notes

### MCP Patch Details

The patch modifies the deployed npm package at a fixed location to avoid npx cache hash instability:

```bash
# Install to fixed location
npm install --prefix /opt/mcp-servers/ticktick-mcp \
  @alexarevalo.ai/mcp-server-ticktick

# Patch: add tags to CreateTaskOptionsSchema and UpdateTaskOptionsSchema
# File: node_modules/@alexarevalo.ai/mcp-server-ticktick/dist/operations/tasks.js
# Add before each "parentId: z.string().optional()":
#   tags: z.array(z.string()).optional().describe('Task tags (e.g., ["DUE/D_2026.12.31"])'),

# Patch: add tags to TickTickTaskSchema
# File: node_modules/@alexarevalo.ai/mcp-server-ticktick/dist/common/types.js
# Add inside TickTickTaskSchema:
#   tags: z.array(z.string()).optional(),

# Update mcporter: change npx command → local node invocation
# Then restart gateway
```

### SKILL.md Changes: daily-planner

Add new **Фаза 0.5** between existing phases 0 and 1:
- Scan all fetched tasks for `DUE/*` tags
- Build "горящие дедлайны" list (deadline ≤ 7 days)
- Tag tasks with `NOT_EARLIER` dates in the future as suppressed

Add **Секция 0 output**: "🔥 Горящие дедлайны" before all other sections, sorted by deadline ASC.

Modify **Фаза 1/2**: Exclude suppressed tasks from recommendations.

### SKILL.md Changes: ticktick-inbox

Add tag detection in **Фаза 3 (разбор)**: For each inbox task:
- Detect deadline mentions → suggest `DUE/D_*` tag
- Detect person mentions → suggest `PERSON/P_*` tag
- Detect "not before" language → suggest `NOT_EARLIER/N_*` tag

Add **NOT_EARLIER display** in **Фаза 7 (отчёт)**:
```
🧊 Заморожено (не раньше [date]): K задач
- «задача» — заморожена до: [дата]
```

Modify **Фаза 3 приоритет**: If task has `DUE/*` within 7 days → auto High priority (per FR-013).

Tag suggestions go in the **Вопросы** block — never auto-applied.

### AGENTS.md + TOOLS.md Changes

Add to `AGENTS.md`:
- Section: "Система тегов-нотации" with the 3 tag types and when to use them
- Tag operations guide: always preserve existing tags when updating (never overwrite all)
- Display rule: always render human-readable, never show raw tags

Add to `TOOLS.md`:
- Section: "Теги-нотация" with format reference table
- Parsing/construction quick reference
- Edge case handling cheat sheet

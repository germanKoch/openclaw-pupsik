# Tasks: TickTick Tag Notation System

**Input**: Design documents from `/specs/004-ticktick-tag-notation/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Organization**: Tasks grouped by user story. Each story is independently testable.
**Tests**: No automated tests (prompt engineering). Manual verification steps included as checkpoints.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)

---

## Phase 1: Setup (Prerequisites Verification)

**Purpose**: Confirm the deployment environment supports the MCP patch before any code is written.

- [ ] T001 Verify hetzner-main has Node.js 18+ and npm available: `ssh hetzner-main "node -v && npm -v"`

---

## Phase 2: Foundational — MCP Tag Support + Agent Context

**Purpose**: The deployed TickTick MCP strips all `tags` fields (Zod schema strips unknowns). Until this phase is complete, the agent cannot read or write tags — no user story can work.

**⚠️ CRITICAL**: All user story phases depend on this phase completing first.

- [ ] T002 Create `scripts/patch-ticktick-mcp-tags.sh` — script that: (1) installs `@alexarevalo.ai/mcp-server-ticktick` to `/opt/mcp-servers/ticktick-mcp/` via npm, (2) patches `dist/common/types.js` to add `tags: z.array(z.string()).optional()` to `TickTickTaskSchema`, (3) patches `dist/operations/tasks.js` to add `tags: z.array(z.string()).optional().describe('Task tags, e.g. ["DUE/D_2026.12.31"]')` to both `CreateTaskOptionsSchema` and `UpdateTaskOptionsSchema`, (4) updates mcporter config to use `node /opt/mcp-servers/ticktick-mcp/node_modules/@alexarevalo.ai/mcp-server-ticktick/dist/cli.js` instead of `npx -y`, (5) restarts gateway

- [ ] T003 [P] Add tag notation reference section to `agents/schedule/TOOLS.md` — include: (a) tag format reference table (type / parent tag / child format / example / semantics), (b) date format `YYYY.MM.DD`, (c) edge case handling cheat sheet (multiple DUE → nearest; NOT_EARLIER > DUE → warn; invalid date → ignore+notify; space in name → underscore), (d) human-readable display mapping table

- [ ] T004 [P] Add tag notation instructions to `agents/schedule/AGENTS.md` — add new section "Система тегов-нотации" with: (a) when to add each tag type (DUE: user states deadline; NOT_EARLIER: user states earliest start; PERSON: user mentions a person), (b) tag construction rules (format, name transliteration, underscore for spaces), (c) tag operations rule: always preserve existing tags — read current `tags[]`, append new tag, pass full array to update_task; never overwrite all tags, (d) display rule: never show raw tags to user, always render human-readable

- [ ] T005 Deploy MCP patch: `./scripts/patch-ticktick-mcp-tags.sh hetzner-main`

- [ ] T006 Verify MCP patch: `ssh hetzner-main "mcporter list ticktick --schema --json"` → confirm `create_task` properties include `tags`, `update_task` includes `tags`, `get_task_by_ids` response schema includes `tags`

- [ ] T007 Deploy updated agent workspace: `./scripts/setup-agents.sh hetzner-main` (to push AGENTS.md + TOOLS.md changes)

**Checkpoint**: MCP reads/writes tags. Agent has tag notation reference. User stories can now be implemented.

---

## Phase 3: US1 — Создание задачи с дедлайном (Priority: P1) 🎯 MVP

**Goal**: When a user specifies a deadline, the agent creates the task with a `DUE/D_YYYY.MM.DD` tag. The `dueDate` field remains the scheduling date (independent from the tag).

**Independent Test**: Ask agent "Создай задачу 'Сдать отчёт' на вторник, дедлайн — пятница 20 марта" → in TickTick app verify: task exists with `dueDate = Tuesday` and tag `DUE/D_2026.03.20`.

- [ ] T008 [US1] Verify scenario 1: ask agent to create task with both scheduling date and explicit deadline → confirm `dueDate` = scheduling date AND tag `DUE/D_*` is present in TickTick app

- [ ] T009 [US1] Verify scenario 2: ask agent to create task with only a deadline (no separate scheduling date) → confirm `dueDate` = deadline AND tag `DUE/D_*` is present

- [ ] T010 [US1] Verify scenario 3: ask agent to create task with only a scheduling date (no deadline mentioned) → confirm NO `DUE/*` tag on the task

- [ ] T011 [US1] Verify scenario 4: ask agent to add a deadline to an existing task → confirm `DUE/D_*` tag added AND other existing tags are preserved (not overwritten)

**Checkpoint**: US1 complete. Agent correctly creates and updates tasks with DUE tags.

---

## Phase 4: US2 — Недельное планирование с учётом дедлайнов (Priority: P1)

**Goal**: When generating a weekly plan, the agent scans `DUE/*` tags and adds a "🔥 Горящие дедлайны" section (deadline ≤ 7 days) at the top of the plan, sorted by deadline ASC, regardless of `dueDate`.

**Independent Test**: Create a task with `DUE/D_<+3 days>` and `dueDate` next week → run `/daily-planner` → task appears in 🔥 Горящие дедлайны section (not buried in regular plan sections).

- [ ] T012 [US2] Update `skills/daily-planner/SKILL.md` — insert new **Фаза 0.5** between Фаза 0 and Фаза 1: (a) scan all fetched tasks for `DUE/D_*` tags, parse deadline date; (b) compute days_until = deadline − today; (c) build горящие_дедлайны list: tasks where 0 ≤ days_until ≤ 7; (d) build просроченные_дедлайны list: tasks where days_until < 0; (e) mark tasks with NOT_EARLIER future date with ⚠️ note

- [ ] T013 [US2] Update `skills/daily-planner/SKILL.md` — add 🔥 **Горящие дедлайны** output block immediately before Фаза 1 output: show overdue first (with "дедлайн СЕГОДНЯ" / "дедлайн ПРОСРОЧЕН N дн."), then upcoming sorted by deadline ASC; display deadline in human-readable format; include NOT_EARLIER note if suppressed; skip section entirely if горящие_дедлайны is empty

- [ ] T014 [US2] Deploy updated daily-planner skill: `./scripts/deploy-skills.sh hetzner-main`

- [ ] T015 [US2] Verify scenario 1: task with `DUE/D_<+3days>` and `dueDate` next week → runs `/daily-planner` → task in 🔥 section

- [ ] T016 [US2] Verify scenario 2: task with `DUE/D_<+30days>` (not горящий) → NOT in 🔥 section

- [ ] T017 [US2] Verify scenario 3: multiple горящих tasks → sorted by deadline ASC, closest first

- [ ] T018 [US2] Verify scenario 4: task with `DUE/D_<today>` → marked "дедлайн СЕГОДНЯ" in 🔥 section

**Checkpoint**: US2 complete. Daily planner surfaces hot deadlines independently of scheduling dates.

---

## Phase 5: US3 — Подавление NOT_EARLIER задач (Priority: P2)

**Goal**: Tasks with `NOT_EARLIER/N_*` where the date is in the future are excluded from plans. In inbox review, they appear separately with a "заморожена до [date]" note.

**Independent Test**: Create task with `NOT_EARLIER/N_<+14 days>` → run `/daily-planner` → task absent from all plan sections. Run `/ticktick-inbox` → task appears under "🧊 Заморожено" with correct date.

- [ ] T019 [US3] Update `skills/daily-planner/SKILL.md` — in Фаза 0.5 (or as additional step): compute suppressed list (tasks where NOT_EARLIER date > today); in Фаза 1 (автоматический блок) and Фаза 2 (рекомендации): exclude suppressed tasks from all sections EXCEPT горящие дедлайны (suppressed горящий tasks shown with ⚠️ freeze note per spec edge case)

- [ ] T020 [US3] Update `skills/ticktick-inbox/SKILL.md` — in Фаза 7 (отчёт): add 🧊 **Заморожено** section listing tasks with NOT_EARLIER date in future, format: "🧊 Заморожено (не раньше [date]): K задач\n- «задача» — заморожена до: [date]"

- [ ] T021 [US3] Deploy both updated skills: `./scripts/deploy-skills.sh hetzner-main`

- [ ] T022 [US3] Verify scenario 1: task with `NOT_EARLIER/N_<+16days>` → excluded from `/daily-planner` plan sections

- [ ] T023 [US3] Verify scenario 2: task with `NOT_EARLIER/N_<yesterday>` (past date) → treated as normal task, included in plan

- [ ] T024 [US3] Verify scenario 3: `/ticktick-inbox` with frozen task → task in 🧊 section with correct human-readable date

- [ ] T025 [US3] Verify scenario 4 (edge): task with `NOT_EARLIER` future AND `DUE` within 7 days → appears in 🔥 Горящие дедлайны with ⚠️ freeze note

**Checkpoint**: US3 complete. Frozen tasks don't pollute plans; inbox review surfaces them separately.

---

## Phase 6: US4 — PERSON теги (Priority: P2)

**Goal**: Agent adds `PERSON/P_NAME` tags when creating tasks mentioning a person. Can filter tasks by person tag on request.

**Independent Test**: Ask agent "Создай задачу 'Обсудить контракт с Ксенией'" → verify `PERSON/P_KSENIIA` tag in TickTick. Then ask "покажи всё связанное с Ксенией" → agent fetches and lists tasks with PERSON/P_KSENIIA.

Note: PERSON tag creation logic is already in AGENTS.md (T004). This phase verifies it works correctly.

- [ ] T026 [US4] Verify scenario 1: create task mentioning one person → `PERSON/P_NAME` tag added (Latin, uppercase)

- [ ] T027 [US4] Verify scenario 2: create task mentioning two people → two `PERSON/P_*` tags added

- [ ] T028 [US4] Verify scenario 3: "покажи всё связанное с Ксенией" → agent calls get_project_with_data or search, filters tasks by PERSON/P_KSENIIA, returns list

**Checkpoint**: US4 complete. Person-linked tasks are tagged and filterable.

---

## Phase 7: US5 — ticktick-inbox Интеграция (Priority: P2)

**Goal**: During inbox review, the agent detects deadline/person/earliest-start signals in task text and suggests notation tags in the questions block. Never adds tags automatically.

**Independent Test**: Inbox task "сдать до 15 апреля" → agent suggests `DUE/D_2026.04.15` in questions block (not auto-applied). Inbox task "Обсудить с Ксенией" → agent suggests `PERSON/P_KSENIIA`.

- [ ] T029 [US5] Update `skills/ticktick-inbox/SKILL.md` — in Фаза 3 (разбор каждой задачи): add tag detection step: (a) scan title + content for deadline phrases ("до [дата]", "дедлайн", "к [дата]", "сдать") → extract date, suggest `DUE/D_YYYY.MM.DD`; (b) scan for person mentions (proper names, mentions) → suggest `PERSON/P_NAME`; (c) scan for "не раньше", "начать с [дата]", "актуально с" → suggest `NOT_EARLIER/N_YYYY.MM.DD`

- [ ] T030 [US5] Update `skills/ticktick-inbox/SKILL.md` — in Фаза 3 приоритет rule: if task has (or has been suggested) `DUE/*` within 7 days → assign High priority (implements FR-013); include in report: "↑ High — горящий дедлайн [date]"

- [ ] T031 [US5] Update `skills/ticktick-inbox/SKILL.md` — in Фаза 4 (вопросы/неоднозначные кейсы): when tag suggestion exists, include it in the question: "Предлагаю добавить тег: `DUE/D_2026.04.15` — добавить? (да/нет)"

- [ ] T032 [US5] Deploy updated ticktick-inbox skill: `./scripts/deploy-skills.sh hetzner-main`

- [ ] T033 [US5] Verify scenario 1: inbox task "сдать до 15 апреля" → agent proposes `DUE/D_2026.04.15` in questions block (NOT auto-applied)

- [ ] T034 [US5] Verify scenario 2: inbox task "Обсудить контракт с Ксенией" → agent proposes `PERSON/P_KSENIIA` in questions

- [ ] T035 [US5] Verify scenario 3: agent proposes tag → user confirms → tag added via update_task (existing tags preserved)

**Checkpoint**: US5 complete. Inbox review surfaces tagging opportunities for user confirmation.

---

## Phase 8: Polish & Edge Cases

**Purpose**: Verify edge case handling from spec and ensure SC-005 (no raw tags shown to user).

- [ ] T036 [P] Verify edge case — multiple DUE tags: create task with two `DUE/*` tags manually (via TickTick app) → agent uses nearest deadline and warns: "Найдено несколько дедлайнов, используется ближайший"

- [ ] T037 [P] Verify edge case — NOT_EARLIER > DUE: create task where NOT_EARLIER date is after DUE date → agent warns at detection/creation: conflict between freeze date and deadline

- [ ] T038 [P] Verify edge case — invalid date tag: manually add tag `DUE/D_2026.13.01` to a task → agent ignores it silently and notifies user: "Невалидный тег DUE/D_2026.13.01, пропущен"

- [ ] T039 [P] Verify SC-005 — no raw tags in responses: trigger all agent flows (daily-planner, ticktick-inbox, task creation); confirm agent NEVER outputs strings like `DUE/D_2026.04.30`; always renders human-readable form

- [ ] T040 Commit all changes on branch `004-ticktick-tag-notation` and push

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational: MCP patch + AGENTS.md + TOOLS.md)  ← BLOCKS ALL
    ↓
Phase 3 (US1: DUE creation verification)   ─┐
Phase 4 (US2: daily-planner горящие)        ├─ can proceed in parallel after Phase 2
Phase 5 (US3: NOT_EARLIER suppression)      │
Phase 6 (US4: PERSON verification)         ─┘
Phase 7 (US5: ticktick-inbox integration)   ← can start after Phase 2; benefits from US3 if concurrent
    ↓
Phase 8 (Polish & edge cases)
```

### User Story Dependencies

- **US1 (P1)**: After Phase 2 — no story dependencies
- **US2 (P1)**: After Phase 2 — no story dependencies
- **US3 (P2)**: After Phase 2 — touches same daily-planner file as US2; sequence US2→US3 for daily-planner edits
- **US4 (P2)**: After Phase 2 — no story dependencies (AGENTS.md already updated)
- **US5 (P2)**: After Phase 2 — benefits from US3 (NOT_EARLIER display already in inbox); can proceed independently

### Within Each Phase

- T003 and T004 (TOOLS.md and AGENTS.md): can run in **parallel** [P]
- T005 (deploy) depends on T002 (script created)
- T006 (verify) depends on T005 (deployed)
- T007 (setup-agents.sh) can run in parallel with T005 [P]
- Daily-planner edits T012, T013 are sequential (same file)
- Ticktick-inbox edits T029, T030, T031 are sequential (same file)

---

## Parallel Example: Phase 2

```bash
# These can run in parallel (different files):
Task T003: Add tag notation section to agents/schedule/TOOLS.md
Task T004: Add tag notation instructions to agents/schedule/AGENTS.md

# Sequential after both complete:
Task T005: Deploy MCP patch → scripts/patch-ticktick-mcp-tags.sh
```

## Parallel Example: US2 + US4 (after Phase 2)

```bash
# These can run in parallel (different concerns):
Phase 4: Update skills/daily-planner/SKILL.md with горящие дедлайны
Phase 6: Verify PERSON tag creation via agent (no file edits needed)
```

---

## Implementation Strategy

### MVP First (US1 + Phase 2 only)

1. Complete Phase 1: Setup verification
2. Complete Phase 2: MCP patch + agent context (CRITICAL)
3. Complete Phase 3: Verify US1 (DUE tag creation)
4. **STOP and VALIDATE**: Agent correctly creates tasks with DUE tags and displays deadlines human-readably
5. Deploy and test with real tasks in TickTick

### Incremental Delivery

1. Phase 1 + Phase 2 → MCP tags working, agent knows notation
2. Phase 3 (US1) → DUE tag creation works ✓
3. Phase 4 (US2) → горящие дедлайны in daily planner ✓
4. Phase 5 (US3) → NOT_EARLIER suppression ✓
5. Phase 6 (US4) → PERSON tags verified ✓
6. Phase 7 (US5) → inbox tag suggestions ✓
7. Phase 8 → edge cases verified, branch merged

---

## Notes

- **No code to write** (besides the shell patch script). All agent logic lives in Markdown SKILL.md and AGENTS.md files.
- **Tag preservation is critical**: All `update_task` calls must READ the current tags first, append new tag, pass full array. Never blind-overwrite.
- **Testing is manual**: Each verify step (T008–T011, T015–T018, etc.) requires interacting with the OpenClaw agent and checking the TickTick app.
- **Patch script is idempotent**: `patch-ticktick-mcp-tags.sh` can be rerun safely after npm package updates.
- **[P] tasks** = different files or read-only verifications, no write conflicts.

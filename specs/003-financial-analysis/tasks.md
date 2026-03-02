# Tasks: Monthly Financial Analysis Skill

**Input**: Design documents from `/specs/003-financial-analysis/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/report-format.md

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create skill directory and workspace file structure

- [X] T001 Create skill directory at skills/financial-analysis/
- [X] T002 [P] Create cron setup script at scripts/setup-financial-analysis-cron.sh

---

## Phase 2: Foundational (SKILL.md Skeleton)

**Purpose**: Create the SKILL.md with frontmatter, context files section, and basic algorithm structure that all user stories build upon

**⚠️ CRITICAL**: All user story sections are added to this single file

- [X] T003 Create SKILL.md skeleton with YAML frontmatter (name, description, user-invocable: true), Russian intro, context files section (`~/.openclaw/workspace/financial-analysis/history.md`), algorithm phases structure, and limitations section in skills/financial-analysis/SKILL.md
- [X] T004 Define Phase 0 (load context) in SKILL.md: load `history.md` from workspace if exists, determine report period (previous month for cron, current month-to-date for manual trigger)
- [X] T005 Define Phase 1 (fetch data) in SKILL.md: call `zenmoney.get_accounts`, `zenmoney.get_categories`, `zenmoney.get_transactions` (with date_from/date_to and limit=500), `zenmoney.get_budgets`; separate transactions by type (expense/income/transfer)

**Checkpoint**: SKILL.md has frontmatter, context loading, and data fetching phases — can be tested by invoking and checking raw data retrieval

---

## Phase 3: User Story 1 — Monthly Financial Report (Priority: P1) 🎯 MVP

**Goal**: Generate a report with income/expense totals, category breakdown, transfers section, and month-over-month comparison

**Independent Test**: Invoke skill manually via Telegram, verify report contains totals, top categories, and MoM comparison with real ZenMoney data

### Implementation for User Story 1

- [X] T006 [US1] Define Phase 2 (aggregate) in SKILL.md: compute total income, total expenses, total transfers per currency; group expenses by category; identify top 5 expense categories; compute category share percentages
- [X] T007 [US1] Define Phase 2 (MoM comparison) in SKILL.md: load previous month from history.md; compute absolute and percentage change for income, expenses, net, and per-category amounts; use arrows (↑↓→) for direction
- [X] T008 [US1] Define Phase 5 (format report) in SKILL.md: output report header, "Итоги" table, "Расходы по категориям" table per contracts/report-format.md; handle multi-currency by separate sub-sections; omit empty sections
- [X] T009 [US1] Define Phase 6 (save history) in SKILL.md: append current month summary as JSON block to `~/.openclaw/workspace/financial-analysis/history.md` following data-model.md schema
- [X] T010 [US1] Define edge case handling in SKILL.md: no transactions → report zero activity; uncategorized transactions → group under "Без категории"
- [X] T011 [US1] Deploy and test: run `./scripts/deploy-skills.sh`, invoke skill via Telegram bot, verify report matches ZenMoney data

**Checkpoint**: User Story 1 complete — monthly report with totals, categories, MoM, transfers is generated and history is saved

---

## Phase 4: User Story 2 — Trend Analysis and Cross-Correlations (Priority: P2)

**Goal**: Add trends section (up/down/stable per category over 3+ months) and cross-correlation observations

**Independent Test**: After 3+ months of history.md data, verify report includes trend arrows per category and at least one correlation observation

### Implementation for User Story 2

- [X] T012 [US2] Define Phase 3 (trends) in SKILL.md: if history.md has 3+ months, compute direction per category (↑ if grew >5%, ↓ if dropped >5%, → otherwise); show last N months amounts; limit to top 10 categories
- [X] T013 [US2] Define Phase 3 (cross-correlations) in SKILL.md: compare category direction vectors across months; report pairs that moved in same/opposite direction 3+ times; phrase as natural language observations in Russian
- [X] T014 [US2] Add trends and correlations sections to Phase 5 (format report) in SKILL.md per contracts/report-format.md; skip sections if fewer than 3 months of history

**Checkpoint**: Trends and correlations are shown when enough history exists, omitted gracefully otherwise

---

## Phase 5: User Story 3 — Personalized Recommendations (Priority: P2)

**Goal**: Generate 3–5 actionable recommendations based on data analysis

**Independent Test**: Verify report contains at least 3 recommendations referencing specific categories and amounts

### Implementation for User Story 3

- [X] T015 [US3] Define Phase 4 (recommendations) in SKILL.md: detect anomalies (transactions >2x category monthly average); flag categories with >20% MoM increase; acknowledge positive trends; suggest review of top growing expense categories
- [X] T016 [US3] Define anomaly detection in Phase 2 in SKILL.md: for each transaction, compare amount against category monthly average; collect anomalies with date, amount, payee, category
- [X] T017 [US3] Add "Аномалии" and "Рекомендации" sections to Phase 5 (format report) in SKILL.md per contracts/report-format.md; ensure each recommendation references specific numbers

**Checkpoint**: Report includes anomaly flags and 3–5 data-driven recommendations

---

## Phase 6: User Story 4 — Budget vs. Actual Comparison (Priority: P3)

**Goal**: Compare spending against ZenMoney budgets when configured

**Independent Test**: With budgets configured in ZenMoney, verify report shows budget utilization table

### Implementation for User Story 4

- [X] T018 [US4] Add budget analysis to Phase 2 in SKILL.md: if `get_budgets` returns data, compute utilization percentage per category; flag categories above 90% utilization
- [X] T019 [US4] Add "Бюджет vs Факт" section to Phase 5 (format report) in SKILL.md per contracts/report-format.md; omit section entirely if no budgets configured

**Checkpoint**: Budget section appears when budgets exist, omitted when not

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cron scheduling, deployment, and final validation

- [X] T020 Implement cron setup in scripts/setup-financial-analysis-cron.sh: SSH into remote, run `openclaw cron add` with schedule `0 9 1 * * @ Europe/Moscow`, name "Ежемесячный финансовый отчёт", target the financial-analysis skill
- [X] T021 Deploy skills and register cron: run `./scripts/deploy-skills.sh` and `./scripts/setup-financial-analysis-cron.sh`
- [X] T022 Run quickstart.md validation: verify cron is registered (`openclaw cron list`), trigger manual run, check history.md was created in workspace

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on T001 — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Phase 2 completion
  - US1 (Phase 3): Independent — MVP
  - US2 (Phase 4): Depends on US1 (needs history.md from Phase 6/save step)
  - US3 (Phase 5): Depends on US1 (needs aggregate data)
  - US4 (Phase 6): Independent from other stories (needs only data from Phase 2 fetch)
- **Polish (Phase 7)**: Depends on at least US1 being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — No dependencies on other stories
- **US2 (P2)**: Requires US1's history saving (T009) to have meaningful trend data
- **US3 (P2)**: Requires US1's aggregation logic (T006) for anomaly baselines
- **US4 (P3)**: Independent — only needs fetch phase data

### Within Each User Story

- Algorithm phase definitions before format/output phases
- Aggregate/analysis before formatting
- Core logic before edge case handling

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)
- US3 and US4 can proceed in parallel after US1 is complete
- T020 (cron script) can be written in parallel with any user story phase

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Foundational (T003–T005)
3. Complete Phase 3: User Story 1 (T006–T011)
4. **STOP and VALIDATE**: Deploy, invoke via Telegram, verify report accuracy
5. Deploy to cron if ready

### Incremental Delivery

1. Setup + Foundational → Skeleton SKILL.md ready
2. Add US1 → Test → Deploy (**MVP!** — monthly report with totals and MoM)
3. Add US2 → Test → Deploy (adds trends after 3+ months of history accumulates)
4. Add US3 → Test → Deploy (adds anomalies and recommendations)
5. Add US4 → Test → Deploy (adds budget comparison when configured)
6. Polish → Register cron → Fully automated

---

## Notes

- All implementation happens in a single file: `skills/financial-analysis/SKILL.md`
- The "phases" in tasks refer to algorithm phases within the SKILL.md prompt, not separate code files
- No Python/Go code needed — the LLM executes analysis by calling ZenMoney MCP tools
- History accumulates over months; trends become available after 3 runs
- Commit after each user story phase for clean incremental delivery

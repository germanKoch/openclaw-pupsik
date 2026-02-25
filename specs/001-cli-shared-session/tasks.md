# Tasks: CLI Access with Shared Session

**Input**: Design documents from `/specs/001-cli-shared-session/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/cli-api.md ✓

**Note**: No tests were requested in the spec. Tasks are implementation-only.

**Two-repo scope**:
- `[gateway]` paths → openclaw gateway Go repo (separate repo running on Hetzner)
- Bare paths → this `openclawd` config repo

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Config Repo Preparation)

**Purpose**: Add new configuration entries required by the CLI feature before any gateway work.

- [ ] T001 Add OPENCLAW_CLI_PORT and OPENCLAW_CLI_SECRET to .env.template

**Checkpoint**: Config repo is ready; gateway development can begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core gateway infrastructure that MUST be complete before any user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T002 Create Session and Message types with JSON load/save in [gateway] internal/session/session.go
- [ ] T003 [P] Create HTTP server with bearer-token auth middleware and router setup in [gateway] internal/api/server.go
- [ ] T004 [P] Implement GET /health endpoint returning status and session message count in [gateway] internal/api/health_handler.go
- [ ] T005 Wire HTTP server startup into gateway main initialization (reads OPENCLAW_CLI_PORT from env) in [gateway] main.go or gateway init file

**Checkpoint**: Foundation ready — HTTP server is up, /health works, session types are defined. User story phases can now begin.

---

## Phase 3: User Story 1 — Send a message from CLI (Priority: P1) 🎯 MVP

**Goal**: User runs `openclaw chat "message"` locally and sees a bot response printed to stdout.

**Independent Test**: Run `openclaw chat "What's on my calendar today?"` — bot processes the message and prints a response. No session history needed; gateway responds correctly to a fresh single message.

### Implementation for User Story 1

- [ ] T006 [P] [US1] Implement POST /chat endpoint: accept user text, call Anthropic, return JSON response in [gateway] internal/api/chat_handler.go
- [ ] T007 [P] [US1] Create CLI config loader: read OPENCLAW_GATEWAY_URL and OPENCLAW_CLI_SECRET from .env or env vars in [gateway] cmd/cli/config.go
- [ ] T008 [US1] Implement single-shot CLI mode: `openclaw chat "<msg>"` sends POST /chat and prints response to stdout in [gateway] cmd/cli/main.go
- [ ] T009 [US1] Add error handling in CLI: connection refused, 401, 503 → human-readable stderr messages in [gateway] cmd/cli/main.go
- [ ] T010 [US1] Add usage help: `openclaw chat` with no args and no interactive flag prints usage to stdout in [gateway] cmd/cli/main.go

**Checkpoint**: `openclaw chat "hello"` works end-to-end. User Story 1 is independently functional. This is the MVP.

---

## Phase 4: User Story 2 — Shared session between CLI and Telegram (Priority: P1)

**Goal**: Context from Telegram conversations is visible in CLI responses and vice versa. The same conversation history is used by both channels.

**Independent Test**: Send a message in Telegram establishing context ("my favourite project is openclaw"), then run `openclaw chat "what is my favourite project?"` from the CLI — bot answers correctly using Telegram history.

**⚠️ Depends on**: Phase 3 complete (POST /chat endpoint exists; CLI binary works).

### Implementation for User Story 2

- [ ] T011 [US2] Wire session load into Telegram message handler: load ~/.openclaw/sessions/default.json before each Anthropic call in [gateway] internal/bot/telegram.go
- [ ] T012 [US2] Wire session save into Telegram message handler: append exchange with channel="telegram" and save after each reply in [gateway] internal/bot/telegram.go
- [ ] T013 [US2] Wire session load into POST /chat handler: pass full message history as Anthropic conversation context in [gateway] internal/api/chat_handler.go
- [ ] T014 [US2] Wire session save into POST /chat handler: append exchange with channel="cli" and save after each reply in [gateway] internal/api/chat_handler.go

**Checkpoint**: Telegram and CLI share the same conversation context. Sending a message in one channel is visible in the other. User Story 2 is independently functional.

---

## Phase 5: User Story 3 — Interactive CLI session (Priority: P2)

**Goal**: Running `openclaw chat` (no args) enters a REPL where each line is a message and responses stream token-by-token.

**Independent Test**: Run `openclaw chat`, type 3 messages, verify responses stream in real time and conversation stays coherent. Type `exit` to quit cleanly.

**⚠️ Depends on**: Phase 4 complete (session sharing works; POST /chat handler exists).

### Implementation for User Story 3

- [ ] T015 [US3] Implement GET /chat/stream endpoint: SSE token-by-token stream, ends with `data: {"done": true}` event in [gateway] internal/api/stream_handler.go
- [ ] T016 [US3] Wire GET /chat/stream into router and register it in [gateway] internal/api/server.go
- [ ] T017 [US3] Implement interactive REPL mode: `openclaw chat` (no args) reads stdin line-by-line, calls GET /chat/stream, prints tokens as they arrive in [gateway] cmd/cli/interactive.go
- [ ] T018 [US3] Add waiting indicator (e.g. `...` or spinner) shown while waiting for first SSE token in [gateway] cmd/cli/interactive.go
- [ ] T019 [US3] Handle Ctrl+C and `exit` input: end REPL loop and exit cleanly with code 0 in [gateway] cmd/cli/interactive.go

**Checkpoint**: Interactive mode works. All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge case resilience, deployment automation, and multi-repo wiring.

- [ ] T020 Add file-level mutex on session JSON read/write to prevent corruption from concurrent Telegram + CLI messages in [gateway] internal/session/session.go
- [ ] T021 Truncate session history to last 50 messages when loading to prevent unbounded Anthropic context growth in [gateway] internal/session/session.go
- [ ] T022 [P] Write scripts/setup-cli.sh: deploy new env vars to gateway, restart gateway, build and install CLI binary to ~/.local/bin/openclaw in scripts/setup-cli.sh
- [ ] T023 [P] Verify quickstart.md end-to-end: SSH tunnel, first message, session-sharing test pass per quickstart.md steps in specs/001-cli-shared-session/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — this is the MVP gate
- **US2 (Phase 4)**: Depends on Phase 3 (POST /chat handler must exist)
- **US3 (Phase 5)**: Depends on Phase 4 (session sharing must work)
- **Polish (Phase 6)**: Depends on Phase 5 — final hardening

### Within Each User Story

- T006 and T007 are parallel (different files); T008 depends on both
- T009, T010 depend on T008 (extend the CLI binary)
- T011 and T013 are parallel (different files); T012 and T014 are parallel
- T015 and T017 are parallel (gateway vs CLI); T016 depends on T015
- T020, T021 extend the same session.go — do sequentially
- T022, T023 are parallel (different files)

### Parallel Opportunities

```bash
# Phase 2 — run in parallel:
T003: HTTP server setup
T004: /health endpoint

# Phase 3 — run in parallel:
T006: POST /chat endpoint (gateway)
T007: CLI config loader

# Phase 4 — run in parallel after T006 exists:
T011: Telegram handler session load
T013: POST /chat session load
# then in parallel:
T012: Telegram handler session save
T014: POST /chat session save

# Phase 6 — run in parallel:
T022: setup-cli.sh
T023: quickstart.md verification
```

---

## Implementation Strategy

### MVP First (User Story 1 Only — Phases 1–3)

1. Complete Phase 1: Update .env.template
2. Complete Phase 2: Session types + HTTP server + /health
3. Complete Phase 3: POST /chat + CLI binary single-shot
4. **STOP and VALIDATE**: `openclaw chat "hello"` works from local machine
5. This is a working, usable CLI assistant even without session sharing

### Incremental Delivery

1. Phases 1–3 → MVP: CLI sends messages, gets responses
2. Phase 4 → Session sharing: Telegram and CLI share history
3. Phase 5 → Ergonomics: Interactive REPL mode
4. Phase 6 → Production-ready: Hardened, deployed, documented

---

## Notes

- [P] tasks = different files, no blocking dependencies
- Story label maps each task to its user story for traceability
- Commit after each phase checkpoint for clean rollback points
- Gateway changes require `openclaw gateway restart` to take effect (handled by setup-cli.sh in T022)
- `[gateway]` prefix in paths = openclaw gateway repo (separate from this openclawd config repo)

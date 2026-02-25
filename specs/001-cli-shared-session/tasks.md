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

- [x] T001 Add OPENCLAW_GATEWAY_TOKEN, OPENCLAW_GATEWAY_PORT, OPENCLAW_SESSION_KEY to .env.template

**Checkpoint**: Config repo is ready; gateway development can begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core gateway infrastructure that MUST be complete before any user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 [SUPERSEDED] — openclaw binary has built-in session management; no Go code needed
- [x] T003 [SUPERSEDED] — openclaw binary has built-in HTTP/WebSocket server
- [x] T004 [SUPERSEDED] — openclaw binary has built-in /health endpoint
- [x] T005 [SUPERSEDED] — openclaw gateway already runs on port 18789 via `openclaw gateway run`

**Checkpoint**: Foundation ready — HTTP server is up, /health works, session types are defined. User story phases can now begin.

---

## Phase 3: User Story 1 — Send a message from CLI (Priority: P1) 🎯 MVP

**Goal**: User runs `openclaw chat "message"` locally and sees a bot response printed to stdout.

**Independent Test**: Run `openclaw chat "What's on my calendar today?"` — bot processes the message and prints a response. No session history needed; gateway responds correctly to a fresh single message.

### Implementation for User Story 1

- [x] T006 [P] [US1] [SUPERSEDED] — POST /chat is the openclaw WebSocket chat.send RPC; already built in
- [x] T007 [P] [US1] Create CLI config loader: read OPENCLAW_GATEWAY_TOKEN, PORT, SESSION_KEY from ~/.openclaw/.env in scripts/openclaw-chat
- [x] T008 [US1] Implement single-shot CLI mode: `openclaw-chat "<msg>"` connects via WebSocket and prints response in scripts/openclaw-chat
- [x] T009 [US1] Add error handling in CLI: missing token, connection refused, NOT_PAIRED → human-readable stderr messages in scripts/openclaw-chat
- [x] T010 [US1] Add usage help and --health flag to scripts/openclaw-chat

**Checkpoint**: `openclaw chat "hello"` works end-to-end. User Story 1 is independently functional. This is the MVP.

---

## Phase 4: User Story 2 — Shared session between CLI and Telegram (Priority: P1)

**Goal**: Context from Telegram conversations is visible in CLI responses and vice versa. The same conversation history is used by both channels.

**Independent Test**: Send a message in Telegram establishing context ("my favourite project is openclaw"), then run `openclaw chat "what is my favourite project?"` from the CLI — bot answers correctly using Telegram history.

**⚠️ Depends on**: Phase 3 complete (POST /chat endpoint exists; CLI binary works).

### Implementation for User Story 2

- [x] T011 [US2] [SUPERSEDED] — openclaw gateway handles session natively via sessionKey parameter
- [x] T012 [US2] [SUPERSEDED] — session persistence is built into openclaw gateway
- [x] T013 [US2] CLI uses same sessionKey as Telegram bot via OPENCLAW_SESSION_KEY in scripts/openclaw-chat (chat.send params)
- [x] T014 [US2] [SUPERSEDED] — session is shared automatically by using the same sessionKey value

**Checkpoint**: Telegram and CLI share the same conversation context. Sending a message in one channel is visible in the other. User Story 2 is independently functional.

---

## Phase 5: User Story 3 — Interactive CLI session (Priority: P2)

**Goal**: Running `openclaw chat` (no args) enters a REPL where each line is a message and responses stream token-by-token.

**Independent Test**: Run `openclaw chat`, type 3 messages, verify responses stream in real time and conversation stays coherent. Type `exit` to quit cleanly.

**⚠️ Depends on**: Phase 4 complete (session sharing works; POST /chat handler exists).

### Implementation for User Story 3

- [x] T015 [US3] [SUPERSEDED] — openclaw WebSocket events stream delta tokens natively (state=delta events)
- [x] T016 [US3] [SUPERSEDED] — streaming is part of the existing WebSocket protocol
- [x] T017 [US3] Implement interactive REPL mode: `openclaw-chat` (no args) reads stdin line-by-line, streams response in scripts/openclaw-chat
- [x] T018 [US3] Streaming delta tokens printed as they arrive via state=delta WebSocket events in scripts/openclaw-chat
- [x] T019 [US3] Handle Ctrl+C and `exit` input: end REPL loop and exit cleanly in scripts/openclaw-chat

**Checkpoint**: Interactive mode works. All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge case resilience, deployment automation, and multi-repo wiring.

- [x] T020 [SUPERSEDED] — concurrent access managed by openclaw gateway internally
- [x] T021 [SUPERSEDED] — context window management handled by openclaw gateway
- [x] T022 [P] Write scripts/setup-cli.sh: install deps, copy openclaw-chat to ~/.local/bin, retrieve token, print SSH tunnel instructions in scripts/setup-cli.sh
- [x] T023 [P] Update quickstart.md to reflect real WebSocket-based implementation in specs/001-cli-shared-session/quickstart.md

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

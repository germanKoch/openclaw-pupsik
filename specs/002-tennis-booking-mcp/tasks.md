# Tasks: Tennis Court Booking MCP

**Input**: Design documents from `/specs/002-tennis-booking-mcp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/mcp-tools.md, quickstart.md

**Tests**: Not requested in the feature specification. Manual testing via MCP Inspector and demo.tallanto.ru.

**Organization**: Tasks grouped by user story. 4 user stories: US1 (View Slots, P1), US2 (Book Court, P1), US3 (Cancel Booking, P2), US4 (View Bookings, P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3, US4
- All source paths relative to the `tennis-booking-mcp/` repository root
- Deployment paths relative to the `openclawd/` repository root

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create the tennis-booking-mcp repository with Python project structure and dependencies

- [x] T001 Create project directory structure: `src/tennis_booking_mcp/` with `__init__.py`, `__main__.py`, `server.py`, `tallanto.py`, `models.py` per plan.md
- [x] T002 Create `pyproject.toml` with dependencies: `mcp>=1.25,<2`, `httpx`, `pydantic`; build system `hatchling`; entry point `tennis-booking-mcp = "tennis_booking_mcp:main"`; requires-python `>=3.11`
- [x] T003 Create `.env.example` in server repo with `TALLANTO_BASE_URL`, `TALLANTO_USERNAME`, `TALLANTO_PASSWORD_HASH` placeholders

---

## Phase 2: Foundational (Tallanto API Client + Core)

**Purpose**: Tallanto API client with auth, Pydantic models, MCP server skeleton. MUST complete before any user story.

**⚠️ CRITICAL**: All 4 MCP tools depend on the Tallanto client and models.

- [x] T004 [P] Implement Pydantic models (`CourtSlot`, `Booking`, `BookingStatus`, `Ticket`) in `src/tennis_booking_mcp/models.py` per data-model.md
- [x] T005 [P] Implement Tallanto API client base in `src/tennis_booking_mcp/tallanto.py`: `TallantoClient` class with `__init__(base_url, username, password_hash)`, async `_request(method, rest_data)` helper, `login()` returning session_id, automatic re-auth on session expiry (~30min), httpx.AsyncClient with connection pooling. Auth uses SugarCRM v4.1 `login` method with MD5-hashed password per research.md
- [x] T006 Create MCP server skeleton in `src/tennis_booking_mcp/server.py`: `FastMCP("tennis-booking")` instance, `logging.basicConfig(stream=sys.stderr)`, load env vars (`TALLANTO_BASE_URL`, `TALLANTO_USERNAME`, `TALLANTO_PASSWORD_HASH`), instantiate `TallantoClient` as module-level singleton. No tools yet — just the server scaffold
- [x] T007 Create entry points: `src/tennis_booking_mcp/__main__.py` with `mcp.run(transport="stdio")`, `src/tennis_booking_mcp/__init__.py` with `main()` function for pyproject.toml entry point
- [x] T008 Verify skeleton runs: `uv sync && uv run mcp dev src/tennis_booking_mcp/server.py` — MCP Inspector should show server with 0 tools

**Checkpoint**: Server starts, connects to MCP Inspector, Tallanto client can authenticate against demo.tallanto.ru

---

## Phase 3: User Story 1 — View Available Court Slots (Priority: P1) 🎯 MVP

**Goal**: User can query available tennis court time slots for a date range via the `list_available_slots` MCP tool

**Independent Test**: Call `list_available_slots` via MCP Inspector with demo.tallanto.ru, verify returned slots match the Tallanto web calendar

### Implementation for User Story 1

- [x] T009 [US1] Implement `get_schedule_classes(date_from, date_to)` method in `src/tennis_booking_mcp/tallanto.py`: query `ScheduleClassEntity` module via `get_entry_list` with WHERE clause for date range and `signup_open=1`, parse response into list of `CourtSlot` models. Include `get_relationships` call to resolve `branch` (court name) and `subject` (activity) names. Handle pagination if needed
- [x] T010 [US1] Implement `list_available_slots` MCP tool in `src/tennis_booking_mcp/server.py`: `@mcp.tool()` decorator, parameters `date: str = ""` (default today, YYYY-MM-DD) and `days: int = 7` (1-14), calls `TallantoClient.get_schedule_classes()`, formats output as per contracts/mcp-tools.md (grouped by day, showing time/court/capacity). Handle: no slots found, date out of range (>14 days), invalid date format, API errors
- [ ] T011 [US1] Test `list_available_slots` against demo.tallanto.ru via MCP Inspector. Verify: slots returned for valid dates, empty result message for dates with no slots, error for invalid date format, error for dates beyond 14-day window

**Checkpoint**: `list_available_slots` tool works end-to-end. This is the minimum viable feature — can be deployed standalone.

---

## Phase 4: User Story 2 — Book a Court Slot (Priority: P1) 🎯 MVP

**Goal**: User can book a specific court time slot via the `book_court` MCP tool

**Independent Test**: Call `list_available_slots` to get a slot_id, then call `book_court` with that ID. Verify booking appears in Tallanto demo web UI.

### Implementation for User Story 2

- [x] T012 [US2] Implement `get_user_ticket()` method in `src/tennis_booking_mcp/tallanto.py`: after login, discover user's `contact_id` and active `Ticket` (subscription) with `num_visit_left > 0`. Cache contact_id and ticket_id on `TallantoClient` instance. Return `Ticket` model
- [x] T013 [US2] Implement `create_visit(slot_id)` method in `src/tennis_booking_mcp/tallanto.py`: create a `Visit` record via `set_entry` linking contact_id to the slot's ScheduleClassEntity using the active ticket_id. Set `self_service=true`. Return `Booking` model. Handle: slot already full (check capacity before creating), no valid ticket, API errors
- [x] T014 [US2] Implement `book_court` MCP tool in `src/tennis_booking_mcp/server.py`: `@mcp.tool()` decorator, parameter `slot_id: str` (required), calls `TallantoClient.create_visit()`, formats output per contracts/mcp-tools.md (booking ID, date, time, court, subscription info). Handle: slot unavailable (suggest alternatives by calling `get_schedule_classes` for same day), no valid subscription, booking limit reached, invalid slot_id
- [ ] T015 [US2] Test `book_court` against demo.tallanto.ru via MCP Inspector. Verify: successful booking creation, error when slot already full, error when invalid slot_id

**Checkpoint**: Users can view slots AND book courts. Together with US1, this is the complete MVP (FR-002 + FR-003).

---

## Phase 5: User Story 3 — Cancel a Booking (Priority: P2)

**Goal**: User can cancel an existing court reservation via the `cancel_booking` MCP tool

**Independent Test**: Book a slot (US2), then cancel it via `cancel_booking`. Verify the booking disappears from Tallanto demo web UI.

### Implementation for User Story 3

- [x] T016 [US3] Implement `cancel_visit(booking_id)` method in `src/tennis_booking_mcp/tallanto.py`: update `Visit` record status to cancelled via `set_entry`, or delete the record (determine correct approach during API discovery). Return updated `Booking` model. Handle: booking not found, past booking, API errors
- [x] T017 [US3] Implement `cancel_booking` MCP tool in `src/tennis_booking_mcp/server.py`: `@mcp.tool()` decorator, parameter `booking_id: str` (required), calls `TallantoClient.cancel_visit()`, formats output per contracts/mcp-tools.md (cancelled booking details, subscription visit restored). Handle: booking not found, past booking, API errors
- [ ] T018 [US3] Test `cancel_booking` against demo.tallanto.ru via MCP Inspector. Verify: successful cancellation, error when booking not found, error when trying to cancel past booking

**Checkpoint**: US1 + US2 + US3 functional. Users can view, book, and cancel.

---

## Phase 6: User Story 4 — View My Bookings (Priority: P2)

**Goal**: User can see their upcoming reservations via the `get_my_bookings` MCP tool

**Independent Test**: Create a booking (US2), then call `get_my_bookings`. Verify the booking appears in the list with correct details.

### Implementation for User Story 4

- [x] T019 [US4] Implement `get_user_visits(include_past)` method in `src/tennis_booking_mcp/tallanto.py`: query `Visit` module via `get_entry_list` with WHERE clause for contact_id and status=confirmed, resolve related ScheduleClassEntity for date/time/court details via `get_relationships`. If `include_past=False`, filter to future dates only. Also fetch active Ticket info. Return list of `Booking` models + `Ticket` model
- [x] T020 [US4] Implement `get_my_bookings` MCP tool in `src/tennis_booking_mcp/server.py`: `@mcp.tool()` decorator, parameter `include_past: bool = False`, calls `TallantoClient.get_user_visits()`, formats output per contracts/mcp-tools.md (numbered booking list with IDs, dates, times, courts + subscription summary). Handle: no bookings found, API errors
- [ ] T021 [US4] Test `get_my_bookings` against demo.tallanto.ru via MCP Inspector. Verify: bookings listed after creating one, empty result when no bookings, subscription info shown

**Checkpoint**: All 4 MCP tools functional (FR-002 through FR-005). All user stories complete.

---

## Phase 7: Deployment & Skill (Cross-Cutting)

**Purpose**: Integrate the MCP server into the OpenClaw gateway and create the booking skill

### Deployment Artifacts (in openclawd repo)

- [x] T022 [P] Add `tennis-booking` entry to `mcp-servers.json` in openclawd per quickstart.md: source repo, install_path `/opt/mcp-servers/tennis-booking-mcp`, command pointing to `.venv/bin/python`, args `["-m", "tennis_booking_mcp"]`, env_vars `["TALLANTO_BASE_URL", "TALLANTO_USERNAME", "TALLANTO_PASSWORD_HASH"]`, mcporter_scope `home`
- [x] T023 [P] Add `TALLANTO_BASE_URL`, `TALLANTO_USERNAME`, `TALLANTO_PASSWORD_HASH` to `.env.template` in openclawd with comments explaining MD5 password requirement. Add actual T14 credentials to `.env`
- [x] T024 Write `scripts/setup-tennis-booking-mcp.sh` in openclawd: follow pattern from `setup-ticktick-mcp.sh` — read credentials from `.env`, SSH to remote, clone/update repo, `uv venv && uv sync`, register with mcporter using env vars, restart gateway via `openclaw gateway restart`
- [x] T025 Create `skills/tennis-booking/SKILL.md` in openclawd with YAML frontmatter (`name: tennis-booking`, `description: Tennis court booking at T14`, `user-invocable: true`) and prompt that orchestrates: (1) ask user what they want (view/book/cancel/list), (2) call appropriate MCP tool, (3) for booking: show slot details and ask for explicit confirmation before calling `book_court`, (4) for cancellation: show booking details and warn about penalties if close to booking time, ask for confirmation before calling `cancel_booking`

### Deploy & Verify

- [ ] T026 Deploy MCP server to hetzner-main: `./scripts/setup-tennis-booking-mcp.sh`
- [ ] T027 Deploy skill to hetzner-main: `./scripts/deploy-skills.sh`
- [ ] T028 End-to-end verification: use the bot via Telegram to view available slots, book a court, view bookings, and cancel — verify all operations match the Tallanto app

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (Phase 2) — no dependency on other stories
- **US2 (Phase 4)**: Depends on Foundational (Phase 2) — logically uses US1 output (slot_id) but implementation is independent
- **US3 (Phase 5)**: Depends on Foundational (Phase 2) — logically uses US4 output (booking_id) but implementation is independent
- **US4 (Phase 6)**: Depends on Foundational (Phase 2) — no dependency on other stories
- **Deployment (Phase 7)**: Depends on at least US1 + US2 being complete (MVP)

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → US1 (P1) ──→ US2 (P1) ──→ Phase 7 (Deploy)
                                          → US3 (P2) ─┐                    ↑
                                          → US4 (P2) ─┴────────────────────┘
```

- **US1 + US2**: Form the MVP, should be completed first in order
- **US3 + US4**: Can be done in parallel after US1+US2 or after Foundational
- **US2 should follow US1** (booking needs slot listing to be meaningful for testing)
- **US3 and US4 are independent** of each other

### Within Each User Story

1. Tallanto client method (tallanto.py)
2. MCP tool (server.py)
3. Manual verification (MCP Inspector)

### Parallel Opportunities

- **Phase 1**: T001, T002, T003 are sequential (project init)
- **Phase 2**: T004 and T005 can run in parallel (models + client are separate files)
- **US1-US4**: After Foundational, US3 and US4 can run in parallel
- **Phase 7**: T022, T023 can run in parallel (different files in openclawd)

---

## Parallel Example: Phase 2

```
# These can run simultaneously (different files):
Task T004: Implement Pydantic models in models.py
Task T005: Implement Tallanto API client in tallanto.py

# Then sequentially:
Task T006: Create MCP server skeleton in server.py (imports from models.py and tallanto.py)
Task T007: Create entry points in __main__.py and __init__.py
```

## Parallel Example: Phase 7

```
# These can run simultaneously (different files in openclawd):
Task T022: Add tennis-booking to mcp-servers.json
Task T023: Add TALLANTO_* to .env.template
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Complete Phase 1: Setup — project structure and dependencies
2. Complete Phase 2: Foundational — Tallanto client + models + server skeleton
3. Complete Phase 3: US1 — `list_available_slots` tool
4. **VALIDATE**: Test slot listing against demo.tallanto.ru
5. Complete Phase 4: US2 — `book_court` tool
6. **VALIDATE**: Test booking flow against demo.tallanto.ru
7. Deploy MVP (Phase 7, T022-T027) — users can view and book
8. **STOP**: Collect feedback before proceeding

### Incremental Delivery

1. MVP (US1 + US2) → Deploy → Users can view slots and book courts
2. Add US4 (View Bookings) → Deploy → Users can see their bookings
3. Add US3 (Cancel Booking) → Deploy → Full feature set
4. Polish: end-to-end Telegram verification (T028)

### API Discovery Gate

**⚠️ IMPORTANT**: Before Phase 2 implementation, the actual Tallanto API must be verified:
1. Test demo.tallanto.ru SugarCRM v4.1 API (quickstart.md has curl commands)
2. Discover module names for scheduling classes and visits
3. If SugarCRM API lacks scheduling modules, fall back to reverse engineering (research.md §5)
4. Module names may differ from the `kettari/tallanto-api` PHP library — verify with `get_available_modules` and `get_module_fields`

This gate is part of T005 (Tallanto client implementation) — if the API doesn't match expectations, adjust the client accordingly.

---

## Notes

- No automated tests generated (not requested in spec). Manual testing via MCP Inspector.
- All tools must never write to stdout (stdio transport constraint). Use `logging` to stderr.
- Russian locale for court/booking terms, ISO dates for structural elements (per contracts).
- The T14 app was delisted from Google Play — use demo.tallanto.ru for development, then switch base URL to T14 instance for production.
- Total tasks: 28 (3 setup + 5 foundational + 3 US1 + 4 US2 + 3 US3 + 3 US4 + 7 deployment)

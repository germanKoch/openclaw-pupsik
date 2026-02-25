# Implementation Plan: CLI Access with Shared Session

**Branch**: `001-cli-shared-session` | **Date**: 2026-02-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-cli-shared-session/spec.md`

## Summary

Add a CLI interface to openclaw that allows the user to send messages to their bot from the terminal, sharing the same conversation session as the Telegram bot. The gateway gains an HTTP listener (localhost-only) serving two endpoints: a single-shot POST and a streaming GET. Session history is persisted as a JSON file on the server and passed as context to every Anthropic API call regardless of originating channel.

## Technical Context

**Language/Version**: Go (gateway + CLI binary), Bash (setup scripts)
**Primary Dependencies**: Anthropic API, Telegram Bot API, mcporter, MCP protocol (existing)
**Storage**: JSON file — `~/.openclaw/sessions/default.json` on the gateway server
**Testing**: `go test` (standard Go toolchain)
**Target Platform**: Linux server (Hetzner, gateway) + macOS/Linux (developer local machine, CLI)
**Project Type**: Server-side service (gateway HTTP extension) + CLI tool
**Performance Goals**: Bot response delivered to CLI in under 30s (matches SC-001)
**Constraints**: Single-user personal bot; single shared session; CLI listens on localhost only
**Scale/Scope**: 1 user, low-volume (personal assistant, < 100 messages/day)

## Constitution Check

No project constitution exists yet. No gates to enforce. Proceeding without gate violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-cli-shared-session/
├── plan.md              ← this file
├── spec.md
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/
│   └── cli-api.md       ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code — Two repositories involved

**1. `openclaw` gateway repo** (separate repo running on Hetzner):

```text
# Changes needed in the gateway repo
internal/session/
├── session.go           # Session + Message types, JSON load/save
└── session_test.go

internal/api/
├── server.go            # HTTP server setup, routes, auth middleware
├── chat_handler.go      # POST /chat handler
├── stream_handler.go    # GET /chat/stream SSE handler
├── health_handler.go    # GET /health handler
└── api_test.go

internal/bot/
└── telegram.go          # EXISTING — wire in session persistence here
```

**2. `openclawd` config repo** (this repo):

```text
scripts/
└── setup-cli.sh         # New: deploy CLI feature to gateway + install local CLI binary

.env.template            # Add: OPENCLAW_CLI_PORT, OPENCLAW_CLI_SECRET, OPENCLAW_SSH_HOST
```

**Structure Decision**: The core session persistence and HTTP API live in the `openclaw` gateway Go codebase. This config repo only adds the deployment script and env var declarations, consistent with how all other MCP server integrations work.

## Complexity Tracking

No constitution violations. Table not applicable.

---

## Phase 0: Research

All unknowns resolved. See [research.md](research.md).

| Question | Decision |
|----------|----------|
| CLI ↔ Gateway transport | HTTP + SSE (localhost only, via SSH tunnel) |
| Session persistence | JSON file on server (`~/.openclaw/sessions/default.json`) |
| Authentication | Bearer token from `.env` (`OPENCLAW_CLI_SECRET`) |
| CLI distribution | Compiled Go binary installed by `setup-cli.sh` |
| Gateway port binding | `localhost:8080` (configurable via `OPENCLAW_CLI_PORT`) |
| Session identity | Single implicit "home" session, shared by all channels |

---

## Phase 1: Design

### Session Persistence (data-model.md)

See [data-model.md](data-model.md) for full entity definitions.

Key points:
- `Session` holds ordered `[]Message` with `channel` field (`telegram` | `cli`)
- Written to disk on every reply completion
- Loaded on gateway startup and on every request (to get latest state)
- Entire message history passed to Anthropic API as conversation context

### HTTP API Contract (contracts/cli-api.md)

See [contracts/cli-api.md](contracts/cli-api.md) for full contract.

Endpoints:
- `POST /chat` — single-shot message → response
- `GET /chat/stream` — streaming SSE response for interactive mode
- `GET /health` — liveness check, no auth required

### CLI Tool Behaviour

The `openclaw` binary installed locally supports:

```
openclaw chat "<message>"     # single-shot
openclaw chat                 # interactive REPL
openclaw health               # connectivity check
```

Config resolution order (for gateway URL and secret):
1. Env vars: `OPENCLAW_GATEWAY_URL`, `OPENCLAW_CLI_SECRET`
2. `.env` file in current directory or `~/.openclaw/.env`

### Telegram Session Wiring

The existing Telegram message handler in the gateway must be updated to:
1. Load the shared session file before processing each message
2. Pass the loaded history as context to the Anthropic API call
3. Append the new exchange to the session and save after each reply

This is a non-breaking change: if the session file doesn't exist, the bot behaves as before (no history).

### New `.env.template` entries

```bash
# CLI access
OPENCLAW_CLI_PORT=8080
OPENCLAW_CLI_SECRET=
OPENCLAW_SSH_HOST=hetzner-main   # reuses HETZNER_SSH_HOST pattern
```

### `scripts/setup-cli.sh` responsibilities

1. Load local `.env`
2. SSH to Hetzner and deploy `OPENCLAW_CLI_PORT` + `OPENCLAW_CLI_SECRET` to gateway env
3. Restart the gateway (`openclaw gateway restart`)
4. Download or build the `openclaw` CLI binary for the local machine
5. Install to `~/.local/bin/openclaw` with execute permission
6. Print SSH tunnel setup instructions

---

## Implementation Order (for /speckit.tasks)

Suggested task sequence:
1. Add session persistence to gateway (load/save JSON, wire into Telegram handler)
2. Add HTTP server to gateway (auth middleware, /health endpoint)
3. Add POST /chat endpoint
4. Add GET /chat/stream SSE endpoint
5. Build the CLI binary (single-shot mode)
6. Add interactive REPL mode to CLI
7. Update `.env.template` with new vars
8. Write `scripts/setup-cli.sh`
9. Write integration tests (session shared between simulated Telegram + CLI calls)

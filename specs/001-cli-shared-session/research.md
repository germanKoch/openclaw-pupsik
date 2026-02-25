# Research: CLI Access with Shared Session

**Feature**: 001-cli-shared-session
**Date**: 2026-02-25

---

## Decision 1: CLI ↔ Gateway Transport

**Decision**: HTTP with Server-Sent Events (SSE) for streaming responses.

**Rationale**:
- The openclaw gateway already runs as a long-lived server process on Hetzner.
- HTTP is the simplest protocol to add: no persistent connection management, works through any firewall or SSH tunnel.
- SSE provides streaming delivery of bot responses (tokens as they arrive) with no extra dependencies — plain HTTP GET with `text/event-stream`.
- Single-shot mode: standard HTTP POST request → response.
- Interactive mode: SSE stream for multi-turn conversation.
- The gateway already handles async I/O (Telegram polling) so adding an HTTP listener is minimal change.

**Alternatives considered**:
- WebSocket: More complex lifecycle management, unnecessary for single-user personal bot.
- Raw SSH pipe: Requires the CLI to have SSH keys configured, couples transport to infrastructure details.
- gRPC: Adds code-generation tooling overhead, overkill for 1 user.

---

## Decision 2: Session Persistence Storage

**Decision**: JSON file storage on the gateway server (`~/.openclaw/sessions/default.json`).

**Rationale**:
- This is a single-user personal assistant. There is exactly one shared session ("home session"). No multi-tenant concerns.
- JSON files are trivially readable, debuggable, and portable. No external database needed.
- The existing project style is minimalist — shell scripts, JSON configs, no ORM/DB setup.
- Session file is written on every exchange, so the latest state survives gateway restarts.
- A single `default` session covers the spec requirement of "reusing one shared session".

**Alternatives considered**:
- SQLite: More queryable, but adds a dependency and is over-engineered for a single file of chat history.
- In-memory only: Would lose history on gateway restart, violating FR-005.
- Redis: External dependency, requires setup, completely disproportionate.

---

## Decision 3: CLI Authentication

**Decision**: Shared secret API key stored in `.env` (`OPENCLAW_CLI_SECRET`).

**Rationale**:
- The gateway already uses an `.env`-based credential pattern for all services (ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN).
- A simple bearer token (e.g., `Authorization: Bearer <secret>`) is sufficient for a single-user personal server that is not exposed to the public internet.
- The CLI reads the secret from the same `.env` file used by all other credentials — no new setup pattern.
- No interactive login flow needed since there's only one user and one server.

**Alternatives considered**:
- mTLS client certificates: Secure but requires certificate management, disproportionate for personal use.
- No authentication: Acceptable only if the HTTP port is never exposed externally (requires SSH tunneling). Rejected to keep the design clean and not force SSH tunnel usage.
- JWT: Adds stateful token validation, unnecessary complexity for one user.

---

## Decision 4: CLI Distribution

**Decision**: A shell script wrapper (`openclaw`) deployed alongside the existing setup scripts, installed locally via `scripts/setup-cli.sh`.

**Rationale**:
- The existing project uses shell scripts for all automation. Adding a `scripts/setup-cli.sh` that installs the CLI tool follows the established pattern exactly.
- The CLI itself can be a compiled Go binary (matching the gateway language) distributed by the setup script, or a thin shell wrapper that calls the gateway's HTTP API via `curl`/`httpie` as a minimal first version.
- Installs to `~/.local/bin/openclaw` on the developer's machine, matching standard user-local install paths.

**Alternatives considered**:
- npm package: Adds Node.js runtime dependency, mixing ecosystems unnecessarily.
- Homebrew formula: Adds distribution/maintenance overhead.
- Python script: Adds another runtime dependency; Go or shell is sufficient.

---

## Decision 5: Gateway HTTP Listener Binding

**Decision**: Listen on `localhost:8080` by default (configurable via `OPENCLAW_CLI_PORT` env var); not exposed to the internet.

**Rationale**:
- Binding to localhost means the CLI must use an SSH tunnel (`ssh -L 8080:localhost:8080 hetzner-main`) to connect remotely. This is consistent with the existing SSH-based workflow.
- Alternatively, the setup script can configure port forwarding or a persistent SSH tunnel.
- Keeping the port localhost-only means no additional firewall rules are needed on Hetzner.
- Port 8080 is a conventional HTTP alternative port; configurable to avoid conflicts.

**Alternatives considered**:
- Expose on public IP with TLS: Requires certificate management (Let's Encrypt or self-signed), significantly more infrastructure.
- Unix socket: Clean but adds complexity when accessing from a remote machine.

---

## Resolved: Session Identity

**Decision**: Single implicit "home" session per gateway instance.

**Rationale**:
- The spec states: "There is one shared session per user; session selection is automatic (most recent active session)."
- A single-user personal bot has exactly one conversation context. No session ID needs to be specified by the user.
- The Telegram channel and CLI channel both read/write the same `default` session file.
- Session reset (start fresh) can be done manually by deleting the session file or via a future `openclaw reset` command (out of scope for this feature).

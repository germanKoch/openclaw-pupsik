# CLI API Contract

**Feature**: 001-cli-shared-session
**Date**: 2026-02-25

The openclaw gateway exposes a minimal HTTP API on `localhost` for the CLI tool. All endpoints require bearer token authentication.

---

## Authentication

All requests must include:

```
Authorization: Bearer <OPENCLAW_CLI_SECRET>
```

On invalid or missing token: `401 Unauthorized`.

---

## Endpoints

### POST /chat

Send a single message and receive the full response.

**Request**:
```
POST /chat HTTP/1.1
Content-Type: application/json
Authorization: Bearer <secret>

{
  "text": "What's on my calendar today?"
}
```

**Response** (200 OK):
```json
{
  "id": "5",
  "text": "You have 2 events today: standup at 10:00 and team review at 15:00.",
  "channel": "cli",
  "replied_at": "2026-02-25T09:01:03Z"
}
```

**Error responses**:

| Status | Condition |
|--------|-----------|
| 400 | `text` field missing or empty |
| 401 | Missing or invalid Authorization header |
| 503 | Gateway cannot reach Anthropic API or MCP servers |

---

### GET /chat/stream

Send a message and receive the response as a Server-Sent Events stream (for interactive mode).

**Request**:
```
GET /chat/stream?text=What+tasks+do+I+have HTTP/1.1
Authorization: Bearer <secret>
Accept: text/event-stream
```

**Response** (200 OK, `Content-Type: text/event-stream`):

Events are streamed as tokens arrive:
```
data: {"token": "You "}

data: {"token": "have "}

data: {"token": "3 tasks."}

data: {"done": true, "message_id": "6"}
```

The stream ends with a `done: true` event. The client should print tokens as they arrive.

**Error event** (if bot fails mid-stream):
```
data: {"error": "Anthropic API timeout"}
```

---

### GET /health

Liveness check. No authentication required.

**Response** (200 OK):
```json
{
  "status": "ok",
  "session_messages": 12
}
```

Used by the CLI to verify it can reach the gateway before starting a conversation.

---

## CLI Usage Patterns

### Single-shot
```bash
openclaw chat "What's on my calendar today?"
# → calls POST /chat
# → prints response to stdout
# → exits 0 on success, 1 on error
```

### Interactive mode
```bash
openclaw chat
# → enters REPL loop
# → each input calls GET /chat/stream
# → tokens printed as they arrive
# → "exit" or Ctrl+C ends the loop
```

### Connectivity check
```bash
openclaw health
# → calls GET /health
# → prints "Connected. Session has N messages." or error
```

---

## SSH Tunnel Setup

Since the gateway listens on `localhost` only, the CLI connects through an SSH tunnel:

```bash
ssh -fNL 8080:localhost:8080 hetzner-main
```

This is configured once and can be started automatically by the `setup-cli.sh` script or managed via a persistent SSH config/autossh setup.

The CLI reads `OPENCLAW_SSH_HOST` from `.env` and can auto-establish the tunnel if not already running.

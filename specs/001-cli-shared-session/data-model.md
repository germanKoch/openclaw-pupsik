# Data Model: CLI Access with Shared Session

**Feature**: 001-cli-shared-session
**Date**: 2026-02-25

---

## Entities

### Session

Represents the single shared conversation thread between the user and the openclaw bot. There is exactly one active session per gateway instance ("home session").

| Field | Type | Description |
|-------|------|-------------|
| id | string | Immutable unique identifier (e.g., `"home"`) |
| created_at | timestamp | When the session was first created |
| updated_at | timestamp | When the last message exchange completed |
| messages | []Message | Ordered list of all exchanges, oldest first |

**Storage**: Persisted as `~/.openclaw/sessions/default.json` on the gateway server.

**State transitions**:
- `empty` → `active`: First message sent from any channel.
- `active` → `active`: Each new message appended.
- `active` → `reset`: Session file deleted (manual operation, out of scope).

---

### Message

Represents a single exchange within a session — one user input and one bot response.

| Field | Type | Description |
|-------|------|-------------|
| id | string | Monotonically increasing integer as string (e.g., `"1"`, `"2"`) |
| user_text | string | The raw text the user sent |
| bot_text | string | The full bot response text |
| channel | Channel | Which interface this message came from |
| sent_at | timestamp | When the user message was received |
| replied_at | timestamp | When the bot response was fully generated |

**Validation rules**:
- `user_text` must be non-empty.
- `bot_text` may be empty only if the bot returned an error (recorded separately).
- `channel` must be one of the defined Channel values.

---

### Channel

Represents the interface through which a message entered the session.

| Value | Description |
|-------|-------------|
| `telegram` | Message originated from the Telegram bot interface |
| `cli` | Message originated from the local CLI tool |

---

## Session File Format (JSON)

The session is stored as a single JSON file. Example:

```json
{
  "id": "home",
  "created_at": "2026-02-25T10:00:00Z",
  "updated_at": "2026-02-25T14:32:00Z",
  "messages": [
    {
      "id": "1",
      "user_text": "Add a task: buy groceries",
      "bot_text": "Done! I've added 'buy groceries' to your TickTick inbox.",
      "channel": "telegram",
      "sent_at": "2026-02-25T10:00:00Z",
      "replied_at": "2026-02-25T10:00:03Z"
    },
    {
      "id": "2",
      "user_text": "What tasks did I add today?",
      "bot_text": "Today you added: 'buy groceries' (added at 10:00 via Telegram).",
      "channel": "cli",
      "sent_at": "2026-02-25T14:32:00Z",
      "replied_at": "2026-02-25T14:32:04Z"
    }
  ]
}
```

---

## Configuration Additions (`.env`)

Two new variables are added to `.env` / `.env.template`:

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENCLAW_CLI_PORT` | Port the gateway HTTP listener binds to (localhost only) | `8080` |
| `OPENCLAW_CLI_SECRET` | Bearer token the CLI uses to authenticate to the gateway | (required, no default) |

---

## Message History Passed to Anthropic API

When constructing the LLM prompt, the full `messages` list from the session is passed as conversation history (user/assistant turn pairs), regardless of which channel each message originated from. This is what enables seamless context sharing.

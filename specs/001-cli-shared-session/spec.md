# Feature Specification: CLI Access with Shared Session

**Feature Branch**: `001-cli-shared-session`
**Created**: 2026-02-25
**Status**: Draft
**Input**: User description: "Как пользователь openclaw, хочу вызывать openclaw бота из консоли, при этом чтобы в телеграме и консоле переиспользовалась одна и та же сессия"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a message to the bot from CLI (Priority: P1)

The user runs a command in their terminal to send a message to their openclaw bot and receives a response — exactly as they would by typing in Telegram. No browser, no Telegram app needed.

**Why this priority**: This is the core capability the feature is about. Without this, nothing else is possible.

**Independent Test**: Run a single CLI command like `openclaw chat "What's on my calendar today?"` and verify the bot responds with a meaningful answer. Delivers immediate value as a standalone CLI assistant.

**Acceptance Scenarios**:

1. **Given** the user has openclaw configured locally, **When** they run `openclaw chat "<message>"`, **Then** the bot processes the message and prints the response to stdout.
2. **Given** the bot is unreachable or the gateway is down, **When** the user sends a CLI message, **Then** a clear error is shown explaining the issue.
3. **Given** the user provides no message, **When** they invoke the CLI command without arguments, **Then** the tool shows usage help.

---

### User Story 2 - CLI conversation continues from where Telegram left off (Priority: P1)

The user was mid-conversation in Telegram ("Add a task to buy groceries — and remind me what tasks I added yesterday"). Later, they open a terminal and continue: "What was the last task I added?" — and the bot answers from context already established in Telegram.

**Why this priority**: This is the defining differentiator of the feature. Without session sharing, the CLI is just a dumb separate channel with no memory.

**Independent Test**: Start a conversation in Telegram, establish context (e.g. mention a specific fact or set a task), then from CLI ask a follow-up that requires that context, and verify the bot answers correctly.

**Acceptance Scenarios**:

1. **Given** the user had a previous Telegram conversation with established context, **When** they send a message via CLI, **Then** the bot's response reflects that context.
2. **Given** the user sent a message via CLI, **When** they open Telegram and continue the conversation, **Then** the bot responds with awareness of the CLI message that was sent.
3. **Given** the user has no prior conversation history, **When** they send a first CLI message, **Then** a new shared session is created and subsequent Telegram messages continue from it.

---

### User Story 3 - Interactive CLI session (Priority: P2)

The user enters an interactive conversation mode in the terminal: a REPL-like prompt where each line is a message, and bot responses are printed below — similar to a chat interface in the terminal.

**Why this priority**: Single-shot `openclaw chat "<msg>"` covers most use cases. Interactive mode is a convenience for multi-turn conversations without re-typing the command.

**Independent Test**: Run `openclaw chat` without arguments to enter interactive mode. Send 3 messages. Verify all 3 responses arrive and the conversation stays coherent. Exit with Ctrl+C or `exit`.

**Acceptance Scenarios**:

1. **Given** the user runs `openclaw chat` with no arguments, **When** the command starts, **Then** an interactive prompt appears (e.g. `> `) and waits for input.
2. **Given** the user is in interactive mode, **When** they type a message and press Enter, **Then** the bot response is printed and a new prompt appears.
3. **Given** the user is in interactive mode, **When** they press Ctrl+C or type `exit`, **Then** the session ends gracefully.
4. **Given** the user is in interactive mode, **When** the bot is processing, **Then** a waiting indicator is shown so the user knows to wait.

---

### Edge Cases

- What happens if the Telegram bot and CLI send messages simultaneously?
- What happens if the session history grows very large — does the CLI slow down or truncate context?
- What happens if the remote gateway is temporarily unavailable mid-conversation?
- What if the user runs the CLI on a machine that has no credentials configured?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a CLI command that sends a single message to the openclaw bot and prints the response.
- **FR-002**: The CLI MUST share the same conversation session as the Telegram bot for the same user, so context established in either channel is visible in the other.
- **FR-003**: The system MUST support an interactive (multi-turn) mode where the user can have a back-and-forth conversation without re-running the command each time.
- **FR-004**: The CLI MUST be invocable on the developer's local machine (not only on the remote Hetzner host).
- **FR-005**: The session state MUST be persisted on the server side so it survives CLI disconnects and Telegram app restarts.
- **FR-006**: The CLI MUST display bot responses without requiring the user to poll separately.
- **FR-007**: The system MUST gracefully handle connection errors and display a human-readable error message.
- **FR-008**: The CLI MUST work with the same credentials already present in the openclaw setup — no separate authentication step for existing users.

### Key Entities

- **Session**: A persistent conversation thread containing ordered message history. Shared across all channels (Telegram, CLI) for a given user. Has a unique ID, creation time, and ordered list of exchanges.
- **Message**: A single user input and bot response pair within a session. Includes content, timestamp, and originating channel (telegram / cli).
- **Channel**: The interface through which a user interacts with the bot (Telegram or CLI). A session can have messages from multiple channels interleaved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can send a message from CLI and receive a response in under 30 seconds under normal conditions.
- **SC-002**: Context established in Telegram is reflected in CLI responses 100% of the time (no session divergence).
- **SC-003**: A user can set up the CLI and send their first message within 5 minutes of reading the setup instructions.
- **SC-004**: The interactive CLI mode maintains a coherent multi-turn conversation across at least 10 exchanges without losing context.
- **SC-005**: CLI setup requires no additional credentials beyond what already exists in the user's openclaw `.env` configuration.

## Assumptions

- The openclaw gateway is already running on the remote Hetzner host and is reachable from the user's local machine.
- There is one shared session per user; session selection is automatic (most recent active session). Named or multiple parallel sessions are out of scope for this feature.
- When CLI and Telegram messages arrive concurrently, they are processed sequentially in arrival order.
- The CLI tool is a local binary or script that communicates with the openclaw gateway over the network (not a direct SSH shell into the server).
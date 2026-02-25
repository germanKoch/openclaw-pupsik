# Quickstart: CLI Access with Shared Session

**Feature**: 001-cli-shared-session
**Date**: 2026-02-25

---

## Prerequisites

- openclaw gateway already running on Hetzner (`hetzner-main`)
- `.env` configured with existing credentials
- SSH access to `hetzner-main`
- Python 3.11+ on your local machine

---

## 1. Add CLI credentials to `.env`

```bash
# Retrieve the gateway token from Hetzner:
ssh hetzner-main "openclaw config get gateway.auth.token"

# Add to your local .env:
OPENCLAW_GATEWAY_TOKEN=<token from above>
OPENCLAW_GATEWAY_PORT=18789          # default, change only if needed
OPENCLAW_SESSION_KEY=home            # must match what the Telegram bot uses
```

---

## 2. Run the setup script

```bash
./scripts/setup-cli.sh [ssh-host]
```

This script:
- Installs `websockets` and `cryptography` Python packages locally
- Copies `openclaw-chat` to `~/.local/bin/openclaw-chat`
- Retrieves the gateway token and writes `~/.openclaw/.env`
- Prints SSH tunnel instructions

---

## 3. Set up the SSH tunnel (first time)

```bash
ssh -fNL 18789:localhost:18789 hetzner-main
```

Or add to `~/.ssh/config` for persistent tunneling:
```
Host hetzner-main
    LocalForward 18789 localhost:18789
```

---

## 4. Test connectivity

```bash
openclaw-chat --health
# → ✓ Connected to openclaw gateway at localhost:18789
#   Session key: home
```

---

## 5. Send your first message

```bash
# Single message
openclaw-chat "What tasks do I have today?"

# Interactive mode
openclaw-chat
```

---

## 6. Verify session sharing

1. Send a message in Telegram: _"Remember: my favorite project is openclaw"_
2. In your terminal: `openclaw-chat "What's my favorite project?"`
3. The bot should answer with awareness of the Telegram context

**Note**: Session sharing works because both the Telegram bot and `openclaw-chat`
use the same `sessionKey` (e.g. `home`) when sending messages to the gateway.
The gateway maintains conversation history per session key.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `connection refused` on localhost:18789 | SSH tunnel not running — run `ssh -fNL 18789:localhost:18789 hetzner-main` |
| `Error: OPENCLAW_GATEWAY_TOKEN is not set` | Run `setup-cli.sh` or set token in `~/.openclaw/.env` |
| `gateway connect failed: NOT_PAIRED` | Run on server: `openclaw config set gateway.auth.autoApproveOperator true` then restart gateway |
| Response missing Telegram context | Wrong `OPENCLAW_SESSION_KEY` — check what key the Telegram bot uses with `ssh hetzner-main "openclaw sessions list"` |
| Gateway unreachable | Check gateway is running: `ssh hetzner-main "openclaw gateway status"` |

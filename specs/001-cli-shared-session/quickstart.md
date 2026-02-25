# Quickstart: CLI Access with Shared Session

**Feature**: 001-cli-shared-session
**Date**: 2026-02-25

---

## Prerequisites

- openclaw gateway already running on Hetzner (`hetzner-main`)
- `.env` configured with existing credentials
- SSH access to `hetzner-main`

---

## 1. Add new credentials to `.env`

```bash
# Add to your local .env
OPENCLAW_CLI_PORT=8080
OPENCLAW_CLI_SECRET=<generate a random secret, e.g. openssl rand -hex 32>
```

---

## 2. Deploy the CLI-enabled gateway update

```bash
./scripts/setup-cli.sh [ssh-host]
```

This script:
- Deploys the new env vars to the gateway on `hetzner-main`
- Restarts the gateway so it picks up the HTTP listener
- Installs the `openclaw` CLI tool to `~/.local/bin/openclaw` on your local machine

---

## 3. Set up the SSH tunnel (first time)

```bash
ssh -fNL 8080:localhost:8080 hetzner-main
```

Or add to `~/.ssh/config` for persistent tunneling:
```
Host hetzner-main
    LocalForward 8080 localhost:8080
```

---

## 4. Send your first message

```bash
# Single message
openclaw chat "What tasks do I have today?"

# Interactive mode
openclaw chat
```

---

## 5. Verify session sharing

1. Send a message in Telegram: _"Remember: my favorite project is openclaw"_
2. In your terminal: `openclaw chat "What's my favorite project?"`
3. The bot should answer: _"Your favorite project is openclaw"_

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `connection refused` on localhost:8080 | SSH tunnel not running — run `ssh -fNL 8080:localhost:8080 hetzner-main` |
| `401 Unauthorized` | Check `OPENCLAW_CLI_SECRET` matches between local `.env` and gateway |
| Response missing Telegram context | Gateway may have restarted without session persistence — check `~/.openclaw/sessions/default.json` on the server |
| Gateway shows `503` | Check MCP servers are running: `ssh hetzner-main "openclaw gateway status"` |

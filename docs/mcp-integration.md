# MCP Server Integration Guide

How we add, deploy, and maintain MCP servers on the OpenClaw gateway.

## Architecture

```
Local (this repo)                    Remote (hetzner-main)
─────────────────                    ─────────────────────
mcp-servers.json  ──(reference)──>   /opt/mcp-servers/<name>/
.env              ──(credentials)──> env vars / token files
scripts/setup-*.sh ──(SSH)────────>  mcporter config add ...
                                     openclaw gateway restart
```

- **mcporter** manages MCP server lifecycle (start/stop/config)
- **OpenClaw gateway** connects to mcporter-registered servers and exposes them to clients (Telegram bot, CLI)
- Each server runs as a **stdio** process spawned by mcporter on demand

## Adding a New MCP Server

### 1. Register in `mcp-servers.json`

```json
"my-server": {
  "source": "https://github.com/author/my-mcp-server",
  "install_path": "/opt/mcp-servers/my-mcp-server",
  "transport": "stdio",
  "command": "/opt/mcp-servers/my-mcp-server/.venv/bin/python",
  "args": ["-m", "my_mcp_server"],
  "env_vars": ["MY_API_KEY"],
  "description": "What this server does",
  "managed_by": "mcporter",
  "mcporter_scope": "home"
}
```

For npx-based servers (no local clone needed):
```json
"command": "npx",
"args": ["-y", "@scope/package-name"]
```

### 2. Add env vars to `.env.template` and `.env`

```bash
# .env.template
MY_API_KEY=

# .env (actual values, gitignored)
MY_API_KEY=your-api-key-here
```

### 3. Write a setup script

Create `scripts/setup-my-server.sh`. The script should:

1. Read credentials from `.env`
2. SSH into remote, install runtime deps (uv/npm)
3. Clone/update the server repo (or skip for npx-based)
4. Deploy credentials (env vars, token files, or OAuth keys)
5. Register with mcporter via `mcporter config add`
6. Restart gateway via `openclaw gateway restart`

See existing scripts for patterns:
- **Python + uv**: `setup-ticktick-mcp.sh`, `setup-zenmoney-mcp.sh`
- **npx (Node)**: `setup-google-calendar-mcp.sh`

### 4. Deploy

```bash
./scripts/setup-my-server.sh [ssh-host]
# default ssh-host: hetzner-main (from .env HETZNER_SSH_HOST)
```

## Auth Patterns

We have three auth patterns across our servers:

### Static tokens (ticktick)

Tokens are env vars passed directly to mcporter. Simplest approach.

```bash
mcporter config add ticktick \
  --env 'TICKTICK_ACCESS_TOKEN=xxx' \
  --env 'TICKTICK_CLIENT_ID=xxx'
```

### Token file (zenmoney)

OAuth token stored as `.token.json` in the server directory. The server handles refresh internally.

```bash
scp .token.json hetzner-main:/opt/mcp-servers/zenmoney-mcp/.token.json
```

### Google OAuth with local callback (google-calendar)

The `@cocal/google-calendar-mcp` package runs a local HTTP server on port 3501 for the OAuth callback. Since the server is headless (no browser), use an SSH tunnel:

```bash
# One command: tunnel + auth
ssh -L 3501:localhost:3501 hetzner-main \
  "GOOGLE_OAUTH_CREDENTIALS=/opt/mcp-servers/google-calendar-mcp/gcp-oauth.keys.json \
   npx -y @cocal/google-calendar-mcp auth"
```

Then open the printed auth URL in your local browser. The callback goes through the tunnel to the server, which exchanges the code for tokens automatically.

Tokens are stored at: `/root/.config/google-calendar-mcp/tokens.json`

## Google OAuth: Testing vs Production

**This is critical.** If the Google Cloud project's OAuth consent screen is in **Testing** mode, refresh tokens expire after **7 days**. This means the calendar integration breaks weekly.

### Fix: publish to Production

1. Go to [Google Cloud Console > Auth Platform > Audience](https://console.cloud.google.com/auth/audience)
2. Select the project (ours: `integrations-487217`)
3. Click **Publish app**
4. Confirm

After publishing, refresh tokens are permanent. The "Google hasn't verified this app" warning still appears (because the calendar scope is restricted), but you can click Advanced > "Go to External (unsafe)" to proceed.

### After switching to Production

Re-authorize to get a new token without the 7-day expiry:

```bash
# Delete old token
ssh hetzner-main "rm /root/.config/google-calendar-mcp/tokens.json"

# Re-auth via SSH tunnel
ssh -L 3501:localhost:3501 hetzner-main \
  "GOOGLE_OAUTH_CREDENTIALS=/opt/mcp-servers/google-calendar-mcp/gcp-oauth.keys.json \
   npx -y @cocal/google-calendar-mcp auth"

# Open auth URL in browser, authorize, then restart gateway
ssh hetzner-main "openclaw gateway restart"
```

You can verify the token is permanent by checking that `refresh_token_expires_in` is **absent** from `tokens.json`:
```bash
ssh hetzner-main "cat /root/.config/google-calendar-mcp/tokens.json"
# Good (Production): no refresh_token_expires_in field
# Bad (Testing): "refresh_token_expires_in": 604799  (7 days)
```

## Troubleshooting

### `invalid_grant` on Google Calendar

The refresh token expired or was revoked. Re-authorize:

```bash
ssh -L 3501:localhost:3501 hetzner-main \
  "GOOGLE_OAUTH_CREDENTIALS=/opt/mcp-servers/google-calendar-mcp/gcp-oauth.keys.json \
   npx -y @cocal/google-calendar-mcp auth"
```

Common causes:
- OAuth consent screen in Testing mode (7-day token expiry)
- Google account password changed
- Access revoked in [Google Account Security](https://myaccount.google.com/permissions)
- Too many tokens issued (Google invalidates old ones)

### Server not responding after deploy

```bash
# Check mcporter knows about it
ssh hetzner-main "mcporter config list"

# Check gateway status
ssh hetzner-main "systemctl status openclaw-gateway"

# Restart gateway
ssh hetzner-main "openclaw gateway restart"
```

### Checking server logs

```bash
ssh hetzner-main "journalctl -u openclaw-gateway -n 50 --no-pager"
```

## File Locations on Remote

| What | Path |
|------|------|
| MCP server code | `/opt/mcp-servers/<name>/` |
| Google Calendar OAuth keys | `/opt/mcp-servers/google-calendar-mcp/gcp-oauth.keys.json` |
| Google Calendar tokens | `/root/.config/google-calendar-mcp/tokens.json` |
| mcporter config | `mcporter config list` |
| Gateway service | `openclaw-gateway.service` (systemd) |

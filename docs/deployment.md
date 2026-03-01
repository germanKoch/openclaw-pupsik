# Full Deployment Guide

Complete guide for deploying all OpenClaw components from scratch on a new server.

## Prerequisites

### Local machine

- SSH access to the server (configured as `hetzner-main` in `~/.ssh/config`, or specify host as arg)
- This repo cloned locally
- `.env` filled from `.env.template` with all credentials

### Remote server

- Debian/Ubuntu with root access
- Node.js 18+ and npm
- Git
- systemd

## Step 0: Initial Server Setup

If deploying to a brand new server:

```bash
# Install Node.js (if not present)
ssh hetzner-main "curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"

# Install OpenClaw gateway (ask @germanKoch for the install script/binary)
# After install, verify:
ssh hetzner-main "openclaw --version"
```

## Step 1: VPN for Tallanto API

The Tallanto API (t14.tallanto.com, IP `37.9.3.178`) blocks connections from Hetzner IPs (and most non-residential European IPs). A WireGuard tunnel through a Lithuanian VPN is required for the tennis-booking MCP to work.

### Setup WireGuard

```bash
# Install WireGuard (if not present)
ssh hetzner-main "apt-get install -y wireguard"

# Create config — route ONLY Tallanto IP through VPN
ssh hetzner-main "cat > /etc/wireguard/tallanto-ru.conf << 'EOF'
[Interface]
PrivateKey = <YOUR_WIREGUARD_PRIVATE_KEY>
Address = <YOUR_VPN_ADDRESS>/32

[Peer]
PublicKey = <VPN_SERVER_PUBLIC_KEY>
AllowedIPs = 37.9.3.178/32
Endpoint = <VPN_SERVER_ENDPOINT>
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/tallanto-ru.conf"
```

**Key point**: `AllowedIPs = 37.9.3.178/32` — only Tallanto traffic goes through the VPN. Everything else is direct.

```bash
# Bring up and enable on boot
ssh hetzner-main "wg-quick up tallanto-ru && systemctl enable wg-quick@tallanto-ru"

# Verify
ssh hetzner-main "wg show tallanto-ru"
# Should show: latest handshake, transfer > 0 B received

# Test Tallanto reachability
ssh hetzner-main "curl -s -o /dev/null -w '%{http_code}' https://t14.tallanto.com/service/v4_client/rest.php"
# Should return: 200
```

### Troubleshooting VPN

If `wg show` shows `0 B received`:
- The VPN config may be invalid or the key is already in use on another device
- Try a different VPN config/server
- Russian VPN servers may also block Hetzner — Lithuanian VPN works

If Tallanto returns timeout even with VPN up:
- Verify the route exists: `ip route get 37.9.3.178` should show `dev tallanto-ru`
- Check DNS: `dig t14.tallanto.com` should resolve to `37.9.3.178`

## Step 2: Deploy MCP Servers

Each server has a setup script. Run them in this order (dependencies first):

### Google Calendar MCP

```bash
./scripts/setup-google-calendar-mcp.sh
```

After deploy, complete OAuth:
```bash
# SSH tunnel for OAuth callback
ssh -L 3501:localhost:3501 hetzner-main \
  "GOOGLE_OAUTH_CREDENTIALS=/opt/mcp-servers/google-calendar-mcp/gcp-oauth.keys.json \
   npx -y @cocal/google-calendar-mcp auth"
# Open the printed URL in your browser, authorize
```

See `docs/mcp-integration.md` for Google OAuth details (Testing vs Production mode).

### TickTick MCP

```bash
./scripts/setup-ticktick-mcp.sh
```

Requires `TICKTICK_ACCESS_TOKEN` in `.env`. Token expires every 180 days — regenerate with:
```bash
npx @alexarevalo.ai/mcp-server-ticktick ticktick-auth
```

### ZenMoney MCP

```bash
./scripts/setup-zenmoney-mcp.sh
```

Requires `.token.json` with OAuth token (copied to remote during setup).

### Tennis Booking MCP

**Requires**: WireGuard VPN (Step 1) — without it, all API calls will timeout.

```bash
./scripts/setup-tennis-booking-mcp.sh
```

Verify:
```bash
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter call 'tennis-booking.list_available_slots(days: 1)'"
```

Should print a schedule with classes. If you see "Ошибка: не удалось подключиться" — check VPN status.

## Step 3: Deploy Skills

Skills are agent prompts that teach the bot how to use MCP tools effectively.

```bash
./scripts/deploy-skills.sh
```

Current skills:
- `tennis-booking` — tennis court booking with calendar integration, level detection, 24h rule
- `ticktick-inbox` — task inbox processing with project context
- `daily-planner` — smart day planning with load control
- `diary-add` — diary entry creation

## Step 4: Verify Everything

```bash
# Check all MCP servers are registered
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter list"

# Check gateway is running
ssh hetzner-main "systemctl status openclaw-gateway"

# Restart gateway (picks up new servers/skills)
ssh hetzner-main "openclaw gateway restart"

# Test each server
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter list tennis-booking --schema"
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter list ticktick --schema"
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter list google-calendar --schema"
ssh hetzner-main "export PATH=\"\$HOME/.local/bin:\$PATH\" && mcporter list zenmoney --schema"
```

## Infrastructure Summary

### Remote file layout

```
/etc/wireguard/
  tallanto-ru.conf              # WireGuard split-tunnel (Tallanto only)

/opt/mcp-servers/
  tennis-booking-mcp/           # Python + uv, Tallanto v4_client API
  google-calendar-mcp/          # OAuth keys file
  zenmoney-mcp/                 # Python + uv, OAuth token file

/root/.mcporter/
  mcporter.json                 # All MCP server configs (command, args, env)

/root/.config/
  google-calendar-mcp/tokens.json  # Google OAuth tokens
```

### systemd services

| Service | Purpose | Auto-start |
|---------|---------|------------|
| `openclaw-gateway` | Main gateway (Telegram bot, MCP routing) | yes |
| `wg-quick@tallanto-ru` | WireGuard VPN for Tallanto API | yes |

### Network routing

```
Normal traffic:  Hetzner → internet (direct)
Tallanto API:    Hetzner → WireGuard (Lithuanian VPN) → 37.9.3.178
```

Only traffic to `37.9.3.178/32` goes through the VPN tunnel. All other traffic is unaffected.

### Known issues

- **Tallanto geo-blocks Hetzner IPs** — requires VPN (Lithuanian works, Russian Blanc VPN servers do not connect from Hetzner)
- **httpx async TLS timeout** — the MCP server uses sync httpx + `asyncio.to_thread()` instead of async client due to TLS handshake issues on certain routes
- **Google OAuth Testing mode** — tokens expire in 7 days; publish the OAuth app to Production to get permanent tokens (see `docs/mcp-integration.md`)

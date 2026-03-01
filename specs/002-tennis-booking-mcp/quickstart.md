# Quickstart: Tennis Court Booking MCP

**Phase**: 1 — Design & Contracts
**Date**: 2026-03-01
**Feature**: [spec.md](spec.md)

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- Access to a Tallanto instance (demo: `demo.tallanto.ru` with `test@tallanto.com` / `12345`)
- SSH access to `hetzner-main` (for deployment)

## Local Development

### 1. Create the server project

```bash
mkdir tennis-booking-mcp && cd tennis-booking-mcp
uv init
uv add "mcp>=1.25,<2" httpx pydantic
```

### 2. Configure credentials

```bash
# Create .env in server project root
cat > .env << 'EOF'
TALLANTO_BASE_URL=https://demo.tallanto.ru/service/v4_1/rest.php
TALLANTO_USERNAME=test@tallanto.com
TALLANTO_PASSWORD_HASH=827ccb0eea8a706c4c34a16891f84e7b
EOF
```

The password hash is MD5 of the password (SugarCRM convention):
```bash
echo -n "12345" | md5
# → 827ccb0eea8a706c4c34a16891f84e7b
```

### 3. Run and test

```bash
# Test with MCP Inspector (interactive browser UI)
uv run mcp dev src/tennis_booking_mcp/server.py

# Run directly via stdio (for integration testing)
uv run python -m tennis_booking_mcp
```

### 4. API Discovery (reverse engineering phase)

Before implementing against the real T14 instance, use the demo system to discover module names:

```bash
# Quick discovery script — test with curl
curl -X POST https://demo.tallanto.ru/service/v4_1/rest.php \
  -d 'method=login&input_type=JSON&response_type=JSON&rest_data={"user_auth":{"user_name":"test@tallanto.com","password":"827ccb0eea8a706c4c34a16891f84e7b"},"application_name":"mcp-discovery"}'

# Then use session_id to list modules:
curl -X POST https://demo.tallanto.ru/service/v4_1/rest.php \
  -d 'method=get_available_modules&input_type=JSON&response_type=JSON&rest_data={"session":"SESSION_ID"}'
```

## Deployment to hetzner-main

### 1. Add to openclawd registry

In `mcp-servers.json`:
```json
"tennis-booking": {
  "source": "https://github.com/germanKoch/tennis-booking-mcp",
  "install_path": "/opt/mcp-servers/tennis-booking-mcp",
  "transport": "stdio",
  "command": "/opt/mcp-servers/tennis-booking-mcp/.venv/bin/python",
  "args": ["-m", "tennis_booking_mcp"],
  "env_vars": ["TALLANTO_BASE_URL", "TALLANTO_USERNAME", "TALLANTO_PASSWORD_HASH"],
  "description": "Tennis court booking via Tallanto API (T14 club)",
  "managed_by": "mcporter",
  "mcporter_scope": "home"
}
```

### 2. Add credentials to .env

```bash
# In openclawd/.env
TALLANTO_BASE_URL=https://<t14-instance>.tallanto.com/service/v4_1/rest.php
TALLANTO_USERNAME=<your-username>
TALLANTO_PASSWORD_HASH=<md5-of-password>
```

### 3. Deploy

```bash
./scripts/setup-tennis-booking-mcp.sh
# Clones repo, installs deps, registers with mcporter, restarts gateway
```

### 4. Deploy the booking skill

```bash
./scripts/deploy-skills.sh
# Syncs skills/tennis-booking/SKILL.md to remote
```

## Testing Checklist

- [ ] `list_available_slots` returns slots from demo system
- [ ] `book_court` creates a Visit record
- [ ] `cancel_booking` cancels the Visit
- [ ] `get_my_bookings` lists active bookings
- [ ] Re-authentication works after session expiry
- [ ] Error messages are clear when API is unavailable
- [ ] MCP Inspector shows all 4 tools with correct schemas
- [ ] Deployed server responds via mcporter on hetzner-main

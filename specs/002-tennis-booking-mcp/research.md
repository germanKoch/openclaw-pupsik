# Research: Tennis Court Booking MCP

**Phase**: 0 — Outline & Research
**Date**: 2026-03-01
**Feature**: [spec.md](spec.md)

## 1. Tallanto CRM API

### Decision: Use SugarCRM v4.1 REST API as primary integration layer

**Rationale**: Tallanto is built on SugarCRM Community Edition (6.x). The mobile app "Клуб Т14" (Ionic 3.9.2 / Angular 5.2.10) communicates with the Tallanto backend via HTTP. The SugarCRM v4.1 REST API is well-documented and provides all necessary CRUD operations for scheduling and booking.

**Alternatives considered**:
- Custom Tallanto REST API (HTTP Basic Auth with `login:api_hash`) — less documented, used by `kettari/tallanto-api` PHP library. May be needed as fallback if v4.1 lacks scheduling modules.
- Public calendar feed (XML via `entryPoint=ProcessCalendarData`) — read-only, no booking capability.
- Direct mobile app traffic interception — still needed for initial API discovery, but the v4.1 API is the implementation target.

### API Details

**Base URL pattern**:
```
POST https://<instance>.tallanto.com/service/v4_1/rest.php
```
Or for custom instances: `POST https://<custom-domain>/service/v4_1/rest.php`

**Request format**:
```
Content-Type: application/x-www-form-urlencoded

method=<method>&input_type=JSON&response_type=JSON&rest_data=<json_payload>
```

**Key methods**:

| Method | Purpose | Use in MCP |
|--------|---------|------------|
| `login` | Authenticate, get session ID | Auth flow |
| `get_entry_list` | Query records with WHERE clause + pagination | List slots, list bookings |
| `get_entry` | Fetch single record by ID | Get booking details |
| `set_entry` | Create or update record | Create/cancel booking |
| `get_relationships` | Fetch related records | Get slots for a court |
| `get_module_fields` | Get field definitions for a module | Initial discovery |
| `get_available_modules` | List all modules | Initial discovery |

**Date/time handling**: Database stores times in UTC. Responses are in user's timezone. Queries must use UTC.

### Tallanto Data Entities (from `kettari/tallanto-api`)

| Entity | Tallanto Module | Booking Relevance |
|--------|----------------|-------------------|
| ScheduleClassEntity | Schedule classes | Available time slots (has `signup_open`, `allow_self_signup`) |
| Visit | Visit records | Booking = a Visit linking Contact to Class via Ticket |
| Ticket | Subscriptions | User's pass/subscription (tracks remaining visits) |
| Contact | Contacts | The user (student/client) |
| Branch | Branches | Physical court/location |
| Subject | Subjects | Activity type (tennis) |

**Booking flow** (inferred from data model):
1. Query `ScheduleClassEntity` with `signup_open=true` for available slots
2. Create a `Visit` record linking the user's `Contact` to the target `ScheduleClassEntity` using their `Ticket`
3. Cancel = update `Visit` status or delete the record

### Authentication

**Login request**:
```json
{
  "user_auth": {
    "user_name": "username",
    "password": "md5_hashed_password"
  },
  "application_name": "tennis-booking-mcp"
}
```

**Response**: Returns a `session_id` used in all subsequent requests.

**Session management**: Sessions expire after inactivity (typically 30 minutes for SugarCRM). The MCP server must handle re-authentication automatically.

**Alternative auth** (Custom API): HTTP Basic Auth with `login:api_hash` — used by the `kettari/tallanto-client-api-bundle`. May be needed if SugarCRM API doesn't expose scheduling modules.

### Demo System

- URL: `https://demo.tallanto.ru`
- Credentials: `test@tallanto.com` / `12345`
- Use for: Initial API exploration, module discovery, testing queries before connecting to T14 instance

### Admin API Setup

To enable API on a Tallanto instance:
1. Administration → Enable API Access → set "Enable API = Yes"
2. Copy the Token value
3. Download Postman collection from the admin panel

---

## 2. Python MCP SDK

### Decision: Use `mcp` package v1.x with FastMCP high-level API

**Rationale**: Official Anthropic SDK, 21.8k GitHub stars, ~88M monthly downloads. FastMCP provides decorator-based tool definitions with automatic JSON Schema generation from type hints.

**Alternatives considered**:
- Raw MCP protocol implementation — unnecessary complexity, no benefits.
- TypeScript MCP SDK — would work but Python is better match for the existing zenmoney pattern in this repo.

### Key Details

- **Package**: `mcp>=1.0.0` (pin `mcp>=1.25,<2` for v1.x stability)
- **Python**: >= 3.10
- **Import**: `from mcp.server.fastmcp import FastMCP`
- **Tool definition**: `@mcp.tool()` decorator with type hints
- **Transport**: `mcp.run(transport="stdio")` — server communicates via stdin/stdout
- **Critical**: Never write to stdout (corrupts JSON-RPC stream). Use `logging` to stderr.

### Minimal server pattern

```python
import logging
import sys
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO, stream=sys.stderr)
mcp = FastMCP("tennis-booking")

@mcp.tool()
async def list_available_slots(date: str) -> str:
    """List available tennis court slots for a given date."""
    # Call Tallanto API
    ...

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

---

## 3. HTTP Client

### Decision: Use `httpx` for async HTTP requests

**Rationale**: Modern Python HTTP library with native async support, connection pooling, and automatic redirect handling. Better fit with async MCP tools than `requests`.

**Alternatives considered**:
- `aiohttp` — heavier, more complex API, less intuitive.
- `requests` — synchronous only, would block the MCP event loop.

---

## 4. Deployment Pattern

### Decision: Follow zenmoney pattern (Python + uv + token file)

**Rationale**: Proven pattern in this repo. The MCP server is cloned to `/opt/mcp-servers/tennis-booking-mcp`, dependencies installed via `uv sync`, and registered with mcporter.

**Deployment flow**:
1. Server repo cloned to `/opt/mcp-servers/tennis-booking-mcp`
2. `uv venv && uv sync` to install dependencies
3. Initial auth: run server locally to get session, save to `.token.json`
4. SCP `.token.json` to remote (or deploy credentials as env vars)
5. Register with mcporter: `mcporter config add tennis-booking --command /opt/mcp-servers/tennis-booking-mcp/.venv/bin/python --arg main.py --scope home`
6. Restart gateway: `openclaw gateway restart`

### Credential storage

Two options for Tallanto credentials:

| Approach | Pros | Cons |
|----------|------|------|
| **Env vars** (username + password hash) | Simple, matches ticktick pattern | Password in plain text in mcporter config |
| **Token file** (session + credentials) | Matches zenmoney pattern, can store session state | Extra file management |

**Decision**: Use env vars (`TALLANTO_USERNAME`, `TALLANTO_PASSWORD_HASH`, `TALLANTO_BASE_URL`) for simplicity. The server handles login/session internally.

---

## 5. Reverse Engineering Strategy

### Decision: Use Android emulator + mitmproxy to discover actual API endpoints

**Rationale**: While the SugarCRM v4.1 API is documented, the Tallanto mobile app may use custom endpoints or a different API layer. Traffic interception reveals the actual endpoints used for booking.

**Steps**:
1. Set up Android emulator (Android Studio AVD) with proxy settings pointing to mitmproxy
2. Install "Клуб Т14" APK (may need to extract from iOS or find alternative source since com.tallanto.t14 was delisted from Google Play)
3. Use the Tallanto demo app (`ru.tallanto.demo`) as alternative if T14 app unavailable
4. Intercept login flow, slot listing, booking, and cancellation requests
5. Document actual endpoint URLs, request/response formats, and auth headers

**Fallback**: If app uses certificate pinning or is unavailable, use the SugarCRM v4.1 API directly with the demo system for testing, then request API access from T14 admin.

### Important finding

The T14 app (`com.tallanto.t14`) was **not found on Google Play** — it may have been delisted or is iOS-only. The iOS version exists (App Store ID: 1533974227, version 0.9.7). Alternatives:
- Use Tallanto demo app (`ru.tallanto.demo`) for API discovery
- Extract iOS app traffic using a Mac-based proxy
- Contact T14 admin for direct API access

---

## 6. Booking Skill

### Decision: Separate skill at `skills/tennis-booking/SKILL.md`

**Rationale**: Per spec clarification, booking/cancellation must be a dedicated skill with explicit confirmation prompts. The MCP tools provide raw API access; the skill orchestrates the user-facing workflow.

**Skill workflow**:
1. User requests booking → skill calls `list_available_slots` tool
2. Skill presents options to user
3. User selects slot → skill shows confirmation with details
4. User confirms → skill calls `book_court` tool
5. Skill reports result

---

## References

- [SuiteCRM v4.1 API docs](https://docs.suitecrm.com/developer/api/api-v4.1-methods/)
- [kettari/tallanto-api (GitHub)](https://github.com/kettari/tallanto-api)
- [kettari/tallanto-client-api-bundle (Packagist)](https://packagist.org/packages/kettari/tallanto-client-api-bundle)
- [Tallanto API Connection Guide](https://tallanto.com/ru/podklyuchenie-api)
- [Python MCP SDK (GitHub)](https://github.com/modelcontextprotocol/python-sdk)
- [MCP Python SDK docs](https://py.sdk.modelcontextprotocol.io/)
- [Клуб Т14 iOS App](https://apps.apple.com/gb/app/%D0%BA%D0%BB%D1%83%D0%B1-%D1%8214/id1533974227)

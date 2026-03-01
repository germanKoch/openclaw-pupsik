# Implementation Plan: Tennis Court Booking MCP

**Branch**: `002-tennis-booking-mcp` | **Date**: 2026-03-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-tennis-booking-mcp/spec.md`

## Summary

Build a Python MCP server that integrates with the Tallanto CRM backend (SugarCRM v4.1 REST API) to provide tennis court booking tools to the OpenClaw gateway. The server exposes 4 tools (list slots, book, cancel, view bookings) over stdio transport and is deployed via the existing mcporter/uv pattern. A dedicated booking skill orchestrates the user-facing workflow with confirmation prompts.

## Technical Context

**Language/Version**: Python 3.11+
**Primary Dependencies**: `mcp>=1.0.0` (MCP SDK with FastMCP), `httpx` (async HTTP client for Tallanto API)
**Storage**: JSON token file (`.token.json`) for Tallanto session credentials
**Testing**: pytest + MCP Inspector (`uv run mcp dev`)
**Target Platform**: Linux server (hetzner-main, deployed via mcporter)
**Project Type**: MCP server (stdio transport)
**Performance Goals**: N/A (single user, low-frequency requests ~10/day)
**Constraints**: Must follow existing deployment pattern (uv + mcporter); no stdout writes (stdio transport); Tallanto API may have undocumented rate limits
**Scale/Scope**: Single user, single tennis club (T14), ~5-10 bookings/week

## Constitution Check

*No constitution file found (`.specify/memory/constitution.md` does not exist). Skipping gate checks.*

## Project Structure

### Documentation (this feature)

```text
specs/002-tennis-booking-mcp/
├── plan.md              # This file
├── research.md          # Phase 0: Tallanto API & technology research
├── data-model.md        # Phase 1: Entity definitions
├── quickstart.md        # Phase 1: Development & deployment guide
├── contracts/           # Phase 1: MCP tool schemas
│   └── mcp-tools.md     # Tool input/output contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (separate repository)

```text
tennis-booking-mcp/
├── pyproject.toml           # Dependencies (mcp, httpx), entry point
├── src/
│   └── tennis_booking_mcp/
│       ├── __init__.py
│       ├── __main__.py      # Entry: mcp.run(transport="stdio")
│       ├── server.py        # FastMCP server + tool definitions
│       ├── tallanto.py      # Tallanto API client (auth, slots, booking)
│       └── models.py        # Pydantic models for API data
└── tests/
    ├── test_tallanto.py     # Unit tests for API client
    └── test_tools.py        # MCP tool contract tests
```

### Deployment artifacts (this repo — openclawd)

```text
openclawd/
├── mcp-servers.json         # + tennis-booking entry
├── .env / .env.template     # + TALLANTO_* credentials
├── scripts/
│   └── setup-tennis-booking-mcp.sh  # Deployment script
└── skills/
    └── tennis-booking/
        └── SKILL.md         # Booking skill (confirmation workflow)
```

**Structure Decision**: Separate repository for the MCP server (matching zenmoney pattern), deployed to `/opt/mcp-servers/tennis-booking-mcp` on remote. Skill and deployment config live in openclawd.

## Complexity Tracking

> No constitution violations to track.

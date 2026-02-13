# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

openclawd is a configuration and deployment repo for MCP (Model Context Protocol) servers used by the OpenClaw gateway. It stores server definitions (`mcp-servers.json`), credentials (`.env`), and setup scripts for provisioning MCP servers on remote hosts (currently Hetzner).

## Key Files

- `mcp-servers.json` — declarative registry of MCP servers (source repo, install path, transport, command, env vars, mcporter scope)
- `.env` / `.env.template` — credentials for MCP servers and infrastructure (TickTick OAuth, Anthropic API key, Telegram bot token, SSH host)
- `scripts/setup-*.sh` — per-server deployment scripts that SSH into the remote host, install dependencies (uv, mcporter), clone/update the server repo, deploy credentials, register with mcporter, and restart the OpenClaw gateway

## Deployment Pattern

Each MCP server follows this flow:
1. Define server in `mcp-servers.json`
2. Add required env vars to `.env.template` and populate `.env`
3. Write a `scripts/setup-<server>.sh` that provisions the server on the remote host
4. The script registers the server with `mcporter` and restarts the gateway via `openclaw gateway restart`

Default SSH target is `hetzner-main` (overridable as first arg to setup scripts).

## Commands

Deploy an MCP server to remote:
```
./scripts/setup-ticktick-mcp.sh [ssh-host]
./scripts/setup-google-calendar-mcp.sh [ssh-host]
./scripts/setup-zenmoney-mcp.sh [ssh-host]
```

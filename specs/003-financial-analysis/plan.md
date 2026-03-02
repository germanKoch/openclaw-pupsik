# Implementation Plan: Monthly Financial Analysis Skill

**Branch**: `003-financial-analysis` | **Date**: 2026-03-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-financial-analysis/spec.md`

## Summary

Create an OpenClaw skill (`financial-analysis`) that generates a monthly financial report from ZenMoney data. The skill is an agent prompt (SKILL.md) that instructs the LLM to call ZenMoney MCP tools, aggregate data, produce trends/correlations/recommendations, and deliver a formatted report. Historical summaries are stored in workspace files for multi-month trend tracking. Scheduled via `openclaw cron` on the 1st of each month.

## Technical Context

**Language/Version**: Markdown (SKILL.md agent prompt) — no application code needed
**Primary Dependencies**: ZenMoney MCP server (8 tools: `get_transactions`, `get_categories`, `get_accounts`, `get_budgets`), OpenClaw cron scheduler
**Storage**: Workspace files at `~/.openclaw/workspace/financial-analysis/` (Markdown + structured data)
**Testing**: Manual invocation via OpenClaw bot; verify report content against ZenMoney data
**Target Platform**: OpenClaw gateway (Linux server, hetzner-main)
**Project Type**: Skill (agent prompt + cron job + workspace files)
**Performance Goals**: Report generation within 60 seconds
**Constraints**: Read-only (no ZenMoney writes); report in Russian; Telegram-compatible Markdown
**Scale/Scope**: Single user, ~50-500 transactions/month, up to 29 categories, multi-currency (RUB primary)

## Constitution Check

*No constitution file found. Gate passes by default.*

## Project Structure

### Documentation (this feature)

```text
specs/003-financial-analysis/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: ZenMoney data model research
├── data-model.md        # Phase 1: workspace file schemas
├── quickstart.md        # Phase 1: how to deploy and test
├── contracts/
│   └── report-format.md # Expected report structure
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
skills/
└── financial-analysis/
    └── SKILL.md          # Agent prompt with analysis algorithm

scripts/
└── setup-financial-analysis-cron.sh  # Register cron job on remote
```

**Structure Decision**: This feature is a skill (agent prompt), not application code. The only files to create are `SKILL.md` (the prompt), a cron setup script, and workspace file templates. No Python/Go code is needed — the LLM executes the analysis algorithm by calling ZenMoney MCP tools directly.

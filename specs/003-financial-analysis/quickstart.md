# Quickstart: Monthly Financial Analysis Skill

## Prerequisites

- OpenClaw gateway running on `hetzner-main`
- ZenMoney MCP server registered and healthy (`mcporter list` shows `zenmoney`)
- Skills deployed to remote (`./scripts/deploy-skills.sh`)

## Deploy

### 1. Create the skill file

```bash
# From openclawd repo root
# Skill file: skills/financial-analysis/SKILL.md
# (Created as part of this feature implementation)
```

### 2. Deploy skills to remote

```bash
./scripts/deploy-skills.sh
```

### 3. Register cron job

```bash
./scripts/setup-financial-analysis-cron.sh
```

This registers a monthly cron job: `0 9 1 * * @ Europe/Moscow` (9 AM on the 1st of each month).

## Test Manually

Send to the OpenClaw Telegram bot:

```
/financial-analysis
```

Or in natural language:

```
Покажи финансовый отчёт за прошлый месяц
```

## Verify

1. Check cron is registered:
   ```bash
   ssh hetzner-main "openclaw cron list"
   ```

2. Run cron job manually:
   ```bash
   ssh hetzner-main "openclaw cron run <job-id>"
   ```

3. Check workspace files were created:
   ```bash
   ssh hetzner-main "cat ~/.openclaw/workspace/financial-analysis/history.md"
   ```

## Troubleshooting

- **No data in report**: Check ZenMoney MCP is healthy — `ssh hetzner-main "mcporter call zenmoney.get_transactions date_from=2026-02-01 date_to=2026-02-28 limit=5"`
- **Cron not firing**: Check `openclaw cron list` for status; verify timezone is `Europe/Moscow`
- **Skill not found**: Re-deploy skills with `./scripts/deploy-skills.sh`

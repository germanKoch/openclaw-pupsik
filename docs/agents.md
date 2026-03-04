# Multi-Agent Architecture

OpenClaw поддерживает несколько агентов с изолированными воркспейсами, тулами и скилами. Главный агент делегирует специализированные задачи суб-агентам через инструмент `sessions_spawn`.

---

## Архитектура

```
Telegram / CLI
      │
      ▼
 [main agent]  ← SOUL.md, USER.md, общие тулы
      │
      ├─ sessions_spawn("...") ──► [money agent]    ← ZenMoney + BestChange
      │                                │ announces back
      │
      └─ sessions_spawn("...") ──► [schedule agent] ← Calendar + TickTick
                                       │ announces back
```

Суб-агент запускается неблокирующе, выполняет задачу, анонсирует результат в чат.

---

## Агенты

### main (по умолчанию)
- **Воркспейс:** `~/.openclaw/workspace/`
- **Тулы:** все (Telegram UserAPI, Tennis, и остальные не принадлежащие суб-агентам)
- **Роль:** приём запросов, делегирование, координация
- **Скилы:** общие / не привязанные к домену

### money
- **Воркспейс:** `~/.openclaw/workspace-money/`
- **Тулы:** ZenMoney (8) + BestChange (10) + read/write/edit
- **Роль:** всё про деньги — расходы, накопления, курсы обмена
- **Скилы:** `financial-analysis`
- **Cron:** ежемесячный финансовый отчёт (1-е числа, 09:00 МСК, thinking=high)

### schedule
- **Воркспейс:** `~/.openclaw/workspace-schedule/`
- **Тулы:** TickTick (16) + Google Calendar (13) + read/write/edit
- **Роль:** всё про время — события, задачи, планирование дня
- **Скилы:** `daily-planner`, `ticktick-inbox`, `diary-add`

---

## Файловая структура (репозиторий)

```
agents/
  money/
    AGENTS.md       ← инструкции для money-агента (роль, тулы, скилы)
    TOOLS.md        ← справочник: ID валют BestChange, форматы ZenMoney
  schedule/
    AGENTS.md       ← инструкции для schedule-агента
    TOOLS.md        ← справочник: проекты TickTick, календари
skills/
  financial-analysis/SKILL.md   → деплоится в workspace-money
  daily-planner/SKILL.md        → деплоится в workspace-schedule
  ticktick-inbox/SKILL.md       → деплоится в workspace-schedule
  diary-add/SKILL.md            → деплоится в workspace-schedule
  tennis-booking/SKILL.md       → деплоится в workspace (main)
```

На удалённом сервере:
```
~/.openclaw/
  workspace/              ← main agent
    skills/
      tennis-booking/
  workspace-money/        ← money agent
    AGENTS.md
    TOOLS.md
    skills/
      financial-analysis/
  workspace-schedule/     ← schedule agent
    AGENTS.md
    TOOLS.md
    skills/
      daily-planner/
      ticktick-inbox/
      diary-add/
```

---

## Ограничения тулов (tool policy)

Конфигурируется в `~/.openclaw/openclaw.json` → `agents.list[].tools.allow`.

Суб-агенты по умолчанию получают все тулы **кроме** запрещённых системой:
`sessions_spawn`, `cron`, `gateway`, `agents_list`, `memory_search`, `memory_get`.

Дополнительно ограничиваем по домену:

**money** видит только:
- ZenMoney: `get_accounts`, `get_transactions`, `get_categories`, `create_transaction`, `update_transaction`, `delete_transaction`, `get_budgets`, `suggest_category`
- BestChange: `search_currencies`, `list_currencies`, `list_groups`, `list_countries`, `list_cities`, `list_changers`, `get_rates`, `get_best_rate`, `get_rates_batch`, `get_presences`
- Воркспейс: `read`, `write`, `edit`

**schedule** видит только:
- TickTick: `get_user_projects`, `get_project_by_id`, `get_project_with_data`, `create_project`, `update_project`, `delete_project`, `get_task_by_ids`, `create_task`, `update_task`, `complete_task`, `delete_task`, `get_completed_tasks`, `batch_update_tasks`, `get_subtasks`, `get_current_user`, `get_inbox_tasks`
- Google Calendar: `list-calendars`, `list-events`, `search-events`, `get-event`, `list-colors`, `create-event`, `create-events`, `update-event`, `delete-event`, `get-freebusy`, `get-current-time`, `respond-to-event`, `manage-accounts`
- Воркспейс: `read`, `write`, `edit`

---

## Cron-задачи

| Название | Агент | Расписание | Скил |
|----------|-------|------------|------|
| Ежемесячный финансовый отчёт | money | 1-е число, 09:00 МСК | `/financial-analysis` |
| Вечерний ревью задач | schedule | 18:00 UTC | *(inline prompt)* |
| Утренний дайджест статей | schedule | 06:00 UTC | *(inline prompt)* |
| Morning focus reminder | main | 09:00 UTC | *(inline prompt)* |

---

## Деплой

### Первичная настройка (новый сервер)

```bash
# 1. Создать агентов, настроить openclaw.json, смигрировать cron
./scripts/setup-agents.sh [ssh-host]

# 2. Задеплоить скилы в правильные воркспейсы
./scripts/deploy-skills.sh [ssh-host]
```

### Обновление промптов агентов

```bash
# Отредактировать agents/money/AGENTS.md или agents/schedule/AGENTS.md
# Задеплоить:
./scripts/setup-agents.sh [ssh-host]
```

### Обновление скилов

```bash
# Отредактировать skills/<name>/SKILL.md
./scripts/deploy-skills.sh [ssh-host]
```

### Добавить новый скил

1. Создать `skills/<name>/SKILL.md`
2. Добавить маппинг в `SKILL_WORKSPACE` в `deploy-skills.sh`
3. Запустить `./scripts/deploy-skills.sh`

---

## Как это работает под капотом

1. Главный агент получает запрос в Telegram
2. Если задача финансовая → вызывает `sessions_spawn(agentId="money", task="...")`
3. OpenClaw создаёт изолированную сессию `agent:money:<uuid>` в отдельном треде очереди
4. money-агент читает свой `AGENTS.md` + `TOOLS.md`, выполняет задачу с ограниченным набором тулов
5. По завершении анонсирует результат обратно в исходный чат
6. Сессия авто-архивируется через 60 минут

Суб-агенты получают **урезанный системный промпт**: только `AGENTS.md`, `TOOLS.md`, тулы, рантайм. `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md` не передаются — суб-агент фокусируется только на задаче.

---

## Изменение конфига openclaw.json

Конфиг правится скриптом `setup-agents.sh` через Python, чтобы не затирать остальные поля. Ключевые добавляемые поля:

```json
{
  "agents": {
    "list": [
      {
        "id": "main",
        "default": true,
        "subagents": { "allowAgents": ["money", "schedule"] }
      },
      {
        "id": "money",
        "workspace": "~/.openclaw/workspace-money",
        "tools": { "allow": ["get_transactions", "get_rates", "..."] }
      },
      {
        "id": "schedule",
        "workspace": "~/.openclaw/workspace-schedule",
        "tools": { "allow": ["create_task", "list-events", "..."] }
      }
    ]
  }
}
```

---

## Troubleshooting

**Суб-агент не видит нужный тул:**
```bash
ssh hetzner-main "openclaw doctor"
# Проверь agents.list[].tools.allow — имя тула должно точно совпадать
# Список точных имён: mcporter list --json | python3 -c "..."
```

**Суб-агент запускается но не находит скил:**
```bash
ssh hetzner-main "ls ~/.openclaw/workspace-money/skills/"
# Если пусто — запусти deploy-skills.sh
```

**Cron запускается под неправильным агентом:**
```bash
ssh hetzner-main "openclaw cron list --json"
# Найди job ID, потом:
ssh hetzner-main "openclaw cron edit <id> --agent money"
```

**openclaw.json невалидный — gateway не стартует:**
```bash
ssh hetzner-main "openclaw doctor"
ssh hetzner-main "openclaw doctor --fix"
```

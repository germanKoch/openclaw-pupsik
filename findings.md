# Findings & Decisions

## Requirements
- Пользователь хочет настроить `openclawd` для работы с Google Calendar.
- Нужен практический результат: рабочий конфиг и понятные шаги запуска.
- Важно не сломать текущую структуру проекта (уже есть TickTick setup).

## Research Findings
- Репозиторий минимальный: `mcp-servers.json`, `.env.template`, `.env`, `scripts/setup-ticktick-mcp.sh`.
- Пока нет существующей настройки Google Calendar.
- В проекте уже используется паттерн с MCP-серверами и setup-скриптом.
- Подтвержден рабочий MCP сервер: `nspady/google-calendar-mcp`, запуск через `npx -y @cocal/google-calendar-mcp`.
- Ключевая runtime-переменная сервера: `GOOGLE_OAUTH_CREDENTIALS` (путь к `gcp-oauth.keys.json`).

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Добавить Google Calendar как отдельный MCP-сервер (не вместо текущего) | Сохраняет обратную совместимость и текущий рабочий поток |
| Вести настройку через `.env` + setup-скрипт | Соответствует текущему стилю репозитория |
| Передавать в `.env` локальный путь `GOOGLE_OAUTH_CREDENTIALS_FILE` | Удобнее для пользователя и не требует base64/ручного экранирования JSON |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Скрипт session-catchup не вернул данных | Продолжили как с новой сессией, создали planning files вручную |

## Resources
- `mcp-servers.json`
- `.env.template`
- `scripts/setup-ticktick-mcp.sh`
- `scripts/setup-google-calendar-mcp.sh`
- `/Users/germankochnev/.agents/skills/planning-with-files/SKILL.md`
- `https://github.com/nspady/google-calendar-mcp`

## Visual/Browser Findings
- N/A (browser/image tools не использовались)

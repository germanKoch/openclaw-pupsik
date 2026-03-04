# Data Model: TickTick Tag Notation

**Feature**: 004-ticktick-tag-notation
**Date**: 2026-03-04

---

## Tag Entity

A parsed representation of a single notation tag extracted from a task's `tags` array.

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'DUE' \| 'NOT_EARLIER' \| 'PERSON'` | Tag category |
| `fullTag` | `string` | Raw tag string as stored in TickTick (e.g., `"DUE/D_2026.12.31"`) |
| `date` | `string \| undefined` | Parsed date in `YYYY.MM.DD` format — only for DUE and NOT_EARLIER |
| `name` | `string \| undefined` | Person name in Latin uppercase — only for PERSON |
| `valid` | `boolean` | False if the tag matches a known prefix but has an invalid value |

**Examples**:

```text
{ type: "DUE",         fullTag: "DUE/D_2026.12.31", date: "2026.12.31",  name: undefined,  valid: true }
{ type: "NOT_EARLIER", fullTag: "NOT_EARLIER/N_2026.06.01", date: "2026.06.01", name: undefined, valid: true }
{ type: "PERSON",      fullTag: "PERSON/P_KSENIIA",   date: undefined,   name: "KSENIIA",  valid: true }
{ type: "PERSON",      fullTag: "PERSON/P_IVAN_PETROV", date: undefined, name: "IVAN_PETROV", valid: true }
{ type: "DUE",         fullTag: "DUE/D_2026.13.01",   date: undefined,  name: undefined,  valid: false }
```

---

## Extended Task Model

The standard TickTick task fields, augmented with derived notation fields.

### Base fields (from TickTick MCP after patch)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Task identifier |
| `title` | `string` | Task title |
| `projectId` | `string` | Project identifier |
| `dueDate` | `string \| undefined` | **Scheduling date** — when the task is planned for execution (`ISO 8601`) |
| `priority` | `0 \| 1 \| 3 \| 5` | Task priority (none/low/medium/high) |
| `status` | `number` | 0 = open, 2 = completed |
| `tags` | `string[]` | Raw TickTick tags array |

### Derived fields (computed from `tags` by the agent)

| Field | Source | Type | Description |
|-------|--------|------|-------------|
| `deadline` | `DUE/D_*` tag | `string \| undefined` | Real deadline (date only, no time). Distinct from `dueDate`. |
| `earliestStart` | `NOT_EARLIER/N_*` tag | `string \| undefined` | Task not actionable before this date. |
| `persons` | `PERSON/P_*` tags | `string[]` | Names of associated people (Latin uppercase). |

**Key semantic distinction**:
```
dueDate   = когда ЗАПЛАНИРОВАНО (scheduling)   → например: вторник
deadline  = когда ДОЛЖНО БЫТЬ ГОТОВО (due)     → например: пятница
```

---

## Tag Construction Rules

### DUE tag

```
Input:  real deadline date D
Output: "DUE/D_" + YYYY + "." + MM + "." + DD

Example: deadline=2026-12-31 → "DUE/D_2026.12.31"
```

**When to create**:
- User explicitly states a deadline different from scheduling date
- User states only a deadline (no separate scheduling date) → also set `dueDate = deadline`
- User adds a deadline to an existing task → add tag, preserve other tags

**When NOT to create**:
- User specifies only a scheduling date without mentioning a deadline

### NOT_EARLIER tag

```
Input:  earliest start date N
Output: "NOT_EARLIER/N_" + YYYY + "." + MM + "." + DD

Example: earliest=2026-06-01 → "NOT_EARLIER/N_2026.06.01"
```

**Validation**: Warn if `earliestStart > deadline` at creation or detection.

### PERSON tag

```
Input:  person name (any case, any language)
Output: "PERSON/P_" + LATINIZE(name).toUpperCase().replace(" ", "_")

Examples:
  "Ксения" → "PERSON/P_KSENIIA"   (transliterate if Cyrillic)
  "Ivan Petrov" → "PERSON/P_IVAN_PETROV"
  "kseniia" → "PERSON/P_KSENIIA"
```

**Note**: For Cyrillic names, use standard transliteration. For ambiguous names, prefer the user's canonical Latin spelling if known.

---

## Tag Parsing Rules

### Detection patterns

```
DUE:          /^DUE\/D_(\d{4})\.(\d{2})\.(\d{2})$/
NOT_EARLIER:  /^NOT_EARLIER\/N_(\d{4})\.(\d{2})\.(\d{2})$/
PERSON:       /^PERSON\/P_([A-Z][A-Z0-9_]*)$/
```

### Date validation

After regex match, validate the date is a real calendar date:
- Month: 01–12
- Day: 01–28/29/30/31 (depends on month/year)
- Invalid dates → `valid: false`, tag is ignored, user is notified

### Conflict resolution

| Conflict | Resolution |
|----------|------------|
| Multiple `DUE/*` tags | Use nearest deadline; warn: "Найдено несколько дедлайнов, используется ближайший" |
| `NOT_EARLIER > DUE` | Warn: "earliest start позже дедлайна — проверь даты" |
| Invalid date in tag | Ignore the tag; warn: "Невалидный тег [tag], пропущен" |

---

## Human-Readable Display

The agent NEVER shows raw tag strings to the user. Always render in natural language:

| Raw tag | Display |
|---------|---------|
| `DUE/D_2026.04.30` | `дедлайн: 30 апр 2026` |
| `NOT_EARLIER/N_2026.06.01` | `заморожена до: 1 июн 2026` |
| `PERSON/P_KSENIIA` | `c Kseniia` |
| `PERSON/P_IVAN_PETROV` | `c Ivan Petrov` (underscore → space) |

---

## Planning Logic: Горящие дедлайны

Threshold: `deadline ≤ today + 7 days`

```
today = current date (from get-current-time or system)

is_burning(task):
  if task.deadline is None: return False
  days_until = (parse_date(task.deadline) - today).days
  return 0 <= days_until <= 7

is_overdue(task):
  return (parse_date(task.deadline) - today).days < 0
```

Section ordering in weekly plan:
1. 🔥 Горящие дедлайны (sorted by deadline ASC, overdue first)
2. ... rest of plan as usual

### NOT_EARLIER suppression in plans

```
is_suppressed(task):
  if task.earliestStart is None: return False
  return parse_date(task.earliestStart) > today
```

- `is_suppressed` AND `is_burning` → show in горящие дедлайны with note `⚠️ заморожена до [date]`
- `is_suppressed` AND NOT burning → exclude from plan entirely
- In inbox review → show separately: "🧊 Заморожено ([date]):"

---

## State Transitions

```
Task lifecycle with tags:

[Inbox]
  → agent suggests DUE/PERSON tags during /ticktick-inbox
  → user confirms → tags written via create_task/update_task

[In plan]
  → agent reads DUE tags → adds to горящие дедлайны if ≤7 days
  → agent checks NOT_EARLIER → suppresses if date is future

[Tag management]
  → Add tag:    update_task with existing tags + new tag
  → Remove tag: update_task with tags filtered (remove target)
  → Never overwrite all tags — always preserve existing
```

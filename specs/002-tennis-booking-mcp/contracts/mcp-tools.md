# MCP Tool Contracts: Tennis Court Booking

**Phase**: 1 — Design & Contracts
**Date**: 2026-03-01
**Feature**: [../spec.md](../spec.md)

## Overview

The tennis-booking MCP server exposes 4 tools over stdio transport. All tools return structured text responses suitable for LLM consumption.

---

## Tool: `list_available_slots`

**Purpose**: Retrieve available tennis court time slots for a date range (FR-002).

### Input

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `date` | string (YYYY-MM-DD) | No | Today | Start date for slot search |
| `days` | integer (1-14) | No | 7 | Number of days to search |

### Output (success)

```text
Available slots for 2026-03-01 to 2026-03-07:

Mon 2026-03-02:
  09:00-10:00 | Корт 1 | Свободно (2/4)
  10:00-11:00 | Корт 1 | Свободно (0/4)
  09:00-10:00 | Корт 2 | Свободно (1/4)

Tue 2026-03-03:
  09:00-10:00 | Корт 1 | Свободно (3/4)
  ...

Total: 15 available slots found.
```

### Output (no slots)

```text
No available slots found for 2026-03-01 to 2026-03-07.
```

### Output (date out of range)

```text
Error: Slots are only available for the next 14 days. Requested date 2026-03-20 is beyond the booking window.
```

### Errors

| Condition | Response |
|-----------|----------|
| API unavailable | `Error: Could not connect to booking system. Please try again later.` |
| Auth failure | `Error: Authentication failed. Server credentials may need updating.` |
| Invalid date format | `Error: Invalid date format. Use YYYY-MM-DD.` |

---

## Tool: `book_court`

**Purpose**: Create a booking for a specific court slot (FR-003). Returns booking details for confirmation — the skill handles user approval.

### Input

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `slot_id` | string | Yes | The CourtSlot ID (from `list_available_slots`) |

### Output (success)

```text
Booking confirmed:
  ID: 12345
  Date: Mon 2026-03-02
  Time: 09:00-10:00
  Court: Корт 1
  Subscription: Абонемент (осталось 8 посещений)
```

### Output (slot unavailable)

```text
Error: Slot is no longer available. It may have been booked by someone else.

Alternative slots on Mon 2026-03-02:
  10:00-11:00 | Корт 1 | Свободно (0/4)
  09:00-10:00 | Корт 2 | Свободно (1/4)
```

### Errors

| Condition | Response |
|-----------|----------|
| Slot already booked (race condition) | Returns alternative slots (see above) |
| No valid subscription | `Error: No active subscription found. Remaining visits: 0.` |
| Booking limit reached | `Error: Daily/weekly booking limit reached. Current bookings: [list].` |
| Invalid slot_id | `Error: Slot not found. It may have expired or been removed.` |
| API unavailable | `Error: Could not connect to booking system. Please try again later.` |

---

## Tool: `cancel_booking`

**Purpose**: Cancel an existing booking (FR-004). Returns cancellation details for confirmation — the skill handles user approval.

### Input

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `booking_id` | string | Yes | The Booking ID (from `get_my_bookings`) |

### Output (success)

```text
Booking cancelled:
  ID: 12345
  Date: Mon 2026-03-02
  Time: 09:00-10:00
  Court: Корт 1
  Subscription visit restored (теперь осталось 9 посещений)
```

### Output (late cancellation warning)

The MCP tool always executes the cancellation. The skill is responsible for warning the user before calling this tool if the booking is within the penalty window.

### Errors

| Condition | Response |
|-----------|----------|
| Booking not found | `Error: Booking not found. It may have already been cancelled.` |
| Past booking | `Error: Cannot cancel a past booking (2026-03-01 09:00).` |
| API unavailable | `Error: Could not connect to booking system. Please try again later.` |

---

## Tool: `get_my_bookings`

**Purpose**: List the user's active bookings (FR-005).

### Input

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `include_past` | boolean | No | false | Include past bookings (last 7 days) |

### Output (has bookings)

```text
Your upcoming bookings:

1. [ID: 12345] Mon 2026-03-02 09:00-10:00 | Корт 1
2. [ID: 12346] Wed 2026-03-04 15:00-16:00 | Корт 2

Subscription: Абонемент (осталось 8 посещений, действует до 2026-06-01)
```

### Output (no bookings)

```text
No upcoming bookings found.

Subscription: Абонемент (осталось 10 посещений, действует до 2026-06-01)
```

### Errors

| Condition | Response |
|-----------|----------|
| API unavailable | `Error: Could not connect to booking system. Please try again later.` |
| Auth failure | `Error: Authentication failed. Server credentials may need updating.` |

---

## Common Patterns

### Error format
All errors follow the pattern: `Error: <human-readable message>.` with optional suggestions.

### Authentication
All tools automatically handle authentication. If the session has expired, tools re-authenticate transparently. Auth errors are only returned if re-authentication fails.

### Locale
Output text uses Russian for court/booking-specific terms (as used in the Tallanto system) and English for structural elements (dates in ISO format, field labels).

### Rate limiting
If the Tallanto API returns rate-limit responses, tools return: `Error: Too many requests. Please wait a moment and try again.`

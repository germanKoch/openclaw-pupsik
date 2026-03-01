# Data Model: Tennis Court Booking MCP

**Phase**: 1 — Design & Contracts
**Date**: 2026-03-01
**Feature**: [spec.md](spec.md)

## Entities

### CourtSlot

A bookable time window on a specific court. Maps to Tallanto's `ScheduleClassEntity`.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `id` | string | API `id` | Tallanto record ID |
| `date` | date | API `date_start` | Date of the slot (YYYY-MM-DD) |
| `start_time` | time | API `date_start` | Start time (HH:MM) |
| `end_time` | time | API `date_finish` | End time (HH:MM) |
| `court_name` | string | API `branch` relationship | Court/location name |
| `court_id` | string | API `branch_id` | Court/location ID |
| `subject` | string | API `subject` relationship | Activity name (e.g., "Теннис") |
| `available` | boolean | Derived | `signup_open == true && allow_self_signup == true && capacity > booked` |
| `capacity` | int | API field | Max participants |
| `booked_count` | int | API field or Visit count | Current number of bookings |
| `teacher_name` | string | API `teacher` relationship | Instructor name (optional) |

**Validation rules**:
- `start_time < end_time`
- `date` must be within the booking window (typically 1-2 weeks ahead)
- Slot duration is 1 hour (enforced by venue, validated client-side)

### Booking

A confirmed reservation linking the user to a court slot. Maps to Tallanto's `Visit` entity.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `id` | string | API `id` | Tallanto Visit record ID |
| `slot_id` | string | API `class_id` | Reference to CourtSlot |
| `contact_id` | string | API `contact_id` | User's Tallanto Contact ID |
| `ticket_id` | string | API `ticket_id` | Subscription/pass used |
| `status` | enum | API `status` | `confirmed`, `cancelled`, `pending` |
| `date` | date | From CourtSlot | Booking date |
| `start_time` | time | From CourtSlot | Start time |
| `end_time` | time | From CourtSlot | End time |
| `court_name` | string | From CourtSlot | Court name |
| `created_at` | datetime | API `date_entered` | When booking was created |
| `self_service` | boolean | API `self_service` | Whether booked via self-service (our MCP) |

**State transitions**:
```
[none] → confirmed    (book_court tool)
confirmed → cancelled  (cancel_booking tool)
```

**Validation rules**:
- Cannot book if `status == cancelled` (must create new booking)
- Cannot cancel past bookings
- User must have a valid Ticket with `num_visit_left > 0`

### UserSession

Authentication state for the Tallanto API. Stored in memory with credentials from env vars.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `session_id` | string | Login response | SugarCRM session token |
| `username` | string | Env var `TALLANTO_USERNAME` | Login username |
| `password_hash` | string | Env var `TALLANTO_PASSWORD_HASH` | MD5 hash of password |
| `base_url` | string | Env var `TALLANTO_BASE_URL` | Instance URL |
| `contact_id` | string | Discovered after login | User's Contact record ID |
| `ticket_id` | string | Discovered after login | Active subscription ID |
| `expires_at` | datetime | Estimated | Session expiry (re-login trigger) |

**Lifecycle**:
```
[init] → authenticated    (login on first API call)
authenticated → expired    (session timeout ~30min inactivity)
expired → authenticated    (automatic re-login)
```

### Ticket (read-only reference)

User's subscription/pass. Not modified by the MCP server, only queried.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `id` | string | API `id` | Ticket record ID |
| `name` | string | API `name` | Subscription name |
| `date_start` | date | API `date_start` | Validity start |
| `date_finish` | date | API `date_finish` | Validity end |
| `num_visit` | int | API `num_visit` | Total visits allowed |
| `num_visit_left` | int | API `num_visit_left` | Remaining visits |
| `is_valid` | boolean | Derived | `date_finish >= today && num_visit_left > 0 && !manual_closed` |

## Relationships

```
UserSession ──1:1──> Contact (the authenticated user)
Contact ──1:N──> Ticket (user's subscriptions)
Contact ──1:N──> Booking (user's reservations via Visit)
Booking ──N:1──> CourtSlot (which slot is booked)
Booking ──N:1──> Ticket (which subscription is consumed)
CourtSlot ──N:1──> Court/Branch (physical location)
CourtSlot ──N:1──> Subject (activity type)
```

## Pydantic Models (implementation reference)

```python
from pydantic import BaseModel
from datetime import date, time, datetime
from enum import Enum

class BookingStatus(str, Enum):
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    PENDING = "pending"

class CourtSlot(BaseModel):
    id: str
    date: date
    start_time: time
    end_time: time
    court_name: str
    court_id: str
    available: bool
    capacity: int
    booked_count: int
    teacher_name: str | None = None

class Booking(BaseModel):
    id: str
    slot_id: str
    status: BookingStatus
    date: date
    start_time: time
    end_time: time
    court_name: str
    created_at: datetime

class Ticket(BaseModel):
    id: str
    name: str
    date_finish: date
    num_visit_left: int
    is_valid: bool
```

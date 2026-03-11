# TickTick Focus API (Reverse-Engineered)

Unofficial API endpoints for TickTick Focus (Pomodoro/Stopwatch) sessions.
These are NOT part of the official TickTick API — they are used by the web app internally.

## Base URLs
- `https://api.ticktick.com` — main API
- `https://ms.ticktick.com` — focus/sync service

## Authentication

### Method: Cookie-based session via `/api/v2/user/signon`

The unofficial API uses HttpOnly cookie `t` for authentication. The official OAuth access token does NOT work for these endpoints (returns `user_not_sign_on`).

**Login request:**
```
POST https://api.ticktick.com/api/v2/user/signon?wc=true&remember=true
Content-Type: application/json
X-Device: {"platform":"web","os":"macOS 10.15.7","device":"Chrome 145.0.0.0","name":"","version":8031,"channel":"website","campaign":""}

{"username":"<email>","password":"<password>"}
```

**Required headers for all requests:**
- Cookie: `t=<token>` (HttpOnly, set by signon response via Set-Cookie)
- `X-Device`: JSON with platform/os/device/version info
- `x-tz`: Timezone string (e.g., `Europe/Moscow`)
- `X-Csrftoken`: CSRF token (from `_csrf_token` cookie)

**Auth notes:**
- The `t` cookie is HttpOnly — cannot be read via JavaScript
- `remember=true` in signon URL gives long-lived session
- MCP server will need to call signon, extract `Set-Cookie: t=...` from response headers, and use it for all subsequent requests
- Env vars needed: `TICKTICK_USERNAME`, `TICKTICK_PASSWORD`

---

## Endpoints

### 1. GET /api/v2/user/preferences/pomodoro
Pomodoro settings for the user.

**Response:**
```json
{
  "id": 121828750,
  "shortBreakDuration": 5,
  "longBreakDuration": 15,
  "longBreakInterval": 4,
  "pomoGoal": 0,
  "focusDuration": 0,
  "mindfulnessEnabled": false,
  "autoPomo": false,
  "autoBreak": false,
  "lightsOn": false,
  "focused": false,
  "soundsOn": true,
  "pomoDuration": 90
}
```

### 2. GET /api/v2/pomodoros/statistics/generalForDesktop
Overview statistics.

**Response:**
```json
{
  "todayPomoCount": 0,
  "totalPomoCount": 137,
  "todayPomoDuration": 0,
  "totalPomoDuration": 57851
}
```
Duration is in minutes.

### 3. GET /api/v2/pomodoros/timeline
Get focus session history (initial load, returns ~31 items, newest first).

**Response:** Array of focus records:
```json
[
  {
    "id": "69b0716cfe7e4d7617414c47",
    "note": "asd",
    "tasks": [
      {
        "startTime": "2026-03-10T19:30:52.000+0000",
        "endTime": "2026-03-10T20:01:24.000+0000"
      }
    ],
    "startTime": "2026-03-10T19:30:52.000+0000",
    "endTime": "2026-03-10T20:01:25.000+0000",
    "status": 1,
    "pauseDuration": 1,
    "adjustTime": 0,
    "etag": "iiky0edz",
    "type": 0,
    "added": false
  }
]
```

#### Fields:
- `type`: 0 = Pomodoro, 1 = Stopwatch
- `status`: 1 = completed, 3 = dropped/abandoned
- `pauseDuration`: seconds paused
- `adjustTime`: manual time adjustment (seconds)
- `note`: user's focus note
- `tasks[]`: may contain `taskId`, `title`, `projectName`, `timerId`, `timerName` when linked to a task
- `added`: boolean

### 4. GET /api/v2/pomodoros/timeline?to={timestamp_ms}
Pagination — get older sessions before the given timestamp (milliseconds).

Returns ~31 items older than `to`.

### 5. GET /api/v2/pomodoros
Returns active pomodoro sessions (empty array when none active).

### 6. GET /api/v2/pomodoros/timing
Returns active timing sessions (empty array when none active).

### 7. GET /api/v2/timer
Returns current timer state (empty object/array when no active timer).

### 8. POST ms.ticktick.com/focus/batch/focusOp
Main focus operation endpoint — start, pause, resume, drop, exit.
Also used for initial sync (empty opList, returns current state).

**Request:**
```json
{
  "lastPoint": 1773180780378,
  "opList": [
    {
      "op": "start",
      "oType": 0,
      "id": "<session-id>",
      "oId": "<operation-id>",
      "duration": 90,
      "firstFocusId": "",
      "focusOnId": "",
      "manual": true,
      "note": "",
      "pomoCount": 0,
      "autoPomoLeft": 0,
      "time": "2026-03-10T22:12:59.199+0000"
    }
  ]
}
```

#### Operations (`op`):
- `start` — start a new focus session
- `pause` — pause current session
- `resume` — resume paused session (inferred)
- `drop` — abandon session (< 5 min, won't be saved)
- `exit` — exit after drop

#### Focus types (`oType` / `type`):
- `0` = Pomodoro
- `1` = Stopwatch

#### Status values in response:
- `0` = running
- `1` = paused
- `2` = break (inferred)
- `3` = dropped/ended

**Response:**
```json
{
  "point": 1773181072289,
  "current": {
    "id": "<session-id>",
    "type": 0,
    "status": 0,
    "valid": true,
    "exited": false,
    "firstId": "",
    "firstDid": "<device-id>",
    "duration": 90,
    "startTime": "2026-03-10T22:12:59.199+0000",
    "endTime": "2026-03-10T23:42:59.199+0000",
    "autoPomoLeft": 5,
    "pomoCount": 1,
    "focusBreak": {},
    "focusOnLogs": [{"id": "", "time": "..."}],
    "pauseLogs": [{"type": 0, "time": "..."}],
    "focusTasks": [{"id": "", "startTime": "...", "endTime": "..."}],
    "etag": "...",
    "autoStart": false
  },
  "updates": [...]
}
```

### 9. POST /api/v2/batch/pomodoro
CRUD operations on focus records (add, update, delete).

**Request:**
```json
{
  "add": [],
  "delete": [],
  "update": [
    {
      "id": "69b0716cfe7e4d7617414c47",
      "note": "updated note",
      "startTime": "2026-03-10T19:30:52.000+0000",
      "endTime": "2026-03-10T20:01:25.000+0000",
      "status": 1,
      "pauseDuration": 1,
      "etag": "iiky0edz",
      "tasks": [
        {
          "startTime": "2026-03-10T19:30:52.000+0000",
          "endTime": "2026-03-10T20:01:24.000+0000"
        }
      ]
    }
  ]
}
```

**Response:**
```json
{
  "id2error": {},
  "id2etag": {
    "69b0716cfe7e4d7617414c47": "newetag123"
  }
}
```

- `id2etag`: new etag values for updated records (use in subsequent updates)
- `id2error`: any errors keyed by record ID
- `add` array can be used to create new records manually
- `delete` array takes record IDs to remove

---

## Notes
- `lastPoint` in focusOp requests is a sync cursor — server returns `point` in response, use it for next request
- All times are UTC with `+0000` offset
- Session IDs are MongoDB ObjectId-like hex strings
- The web app uses XHR (XMLHttpRequest), not fetch
- Duration for pomodoro is in minutes (e.g., 90), for stopwatch it's 0
- Sessions < 5 minutes are dropped and not saved to history
- `etag` must be included in update requests (optimistic concurrency control)

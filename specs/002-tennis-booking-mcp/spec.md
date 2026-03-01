# Feature Specification: Tennis Court Booking MCP

**Feature Branch**: `002-tennis-booking-mcp`
**Created**: 2026-03-01
**Status**: Draft
**Input**: User description: "Бот должен уметь записываться на теннис через Android-приложение Клуб Т14 (com.tallanto.t14). Нужно узнать API приложения и создать MCP-сервер для бронирования кортов."

## Clarifications

### Session 2026-03-01

- Q: Research strategy priority — reverse engineering vs official API? → A: Reverse engineering first (traffic interception via proxy on emulator), official API as fallback.
- Q: Should bot require explicit confirmation before booking/canceling? → A: Yes, always confirm before both booking and cancellation. Booking functionality is a separate skill.
- Q: How should bot behave when Tallanto API is unavailable? → A: Report error and suggest trying again later. No queuing or automatic retries.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Available Court Slots (Priority: P1)

User asks the bot "Покажи свободные слоты на корт на эту неделю" through the Telegram chat. The bot queries the Tallanto booking system and returns a list of available time slots with dates and times.

**Why this priority**: Without seeing available slots, no other functionality is useful. This is the foundation for booking and the minimum viable feature.

**Independent Test**: Can be fully tested by requesting available slots for a specific date range and verifying the returned list matches what the app shows.

**Acceptance Scenarios**:

1. **Given** the bot is connected to the Tallanto API, **When** the user asks for available slots for a specific date, **Then** the bot returns a list of free time slots with court numbers and times.
2. **Given** there are no available slots for a requested date, **When** the user asks, **Then** the bot reports that no slots are available.
3. **Given** the user asks for slots beyond the booking window, **Then** the bot informs the user that slots are only available for the permitted timeframe.

---

### User Story 2 - Book a Court Slot (Priority: P1)

User asks the bot to book a specific time slot (e.g., "Запиши меня на среду 15:00-16:00"). The bot submits the booking request through the Tallanto API and confirms the reservation.

**Why this priority**: Booking is the core action the user wants automated. Together with viewing slots, this forms the MVP.

**Independent Test**: Can be tested by booking a slot and verifying it appears as reserved in the Tallanto app.

**Acceptance Scenarios**:

1. **Given** a time slot is available, **When** the user requests to book it, **Then** the bot shows a confirmation prompt with slot details and asks for explicit approval before submitting.
2. **Given** the user confirms the booking, **When** the bot submits it, **Then** the bot returns a success confirmation.
3. **Given** a time slot is already taken, **When** the user requests to book it, **Then** the bot informs the user the slot is unavailable and suggests alternatives.
4. **Given** the user has reached their booking limit, **When** they try to book more, **Then** the bot informs them of the limit.

---

### User Story 3 - Cancel a Booking (Priority: P2)

User asks the bot to cancel an existing reservation. The bot cancels through the Tallanto API and confirms.

**Why this priority**: Cancellations are important but secondary to the primary booking flow. Users can always cancel manually through the app as a fallback.

**Independent Test**: Can be tested by canceling a previously made booking and verifying it's removed from the schedule.

**Acceptance Scenarios**:

1. **Given** the user has an active booking, **When** they request cancellation, **Then** the bot shows cancellation details and asks for explicit confirmation before proceeding.
2. **Given** the user confirms the cancellation, **When** the bot submits it, **Then** the bot returns a success confirmation.
3. **Given** the cancellation is close to the booking time, **When** the bot processes it, **Then** the bot warns about potential penalties and asks for confirmation before proceeding.

---

### User Story 4 - View My Bookings (Priority: P2)

User asks the bot to show their upcoming reservations. The bot queries the Tallanto system and lists all active bookings.

**Why this priority**: Useful for managing bookings but not critical for the core booking flow.

**Independent Test**: Can be tested by listing bookings after creating one and verifying the list is accurate.

**Acceptance Scenarios**:

1. **Given** the user has active bookings, **When** they ask to see them, **Then** the bot returns a list with dates, times, and court info.
2. **Given** the user has no bookings, **When** they ask, **Then** the bot reports no upcoming reservations.

---

### Edge Cases

- When the Tallanto API is unavailable or returns errors, the bot reports the error to the user and suggests trying again later. No automatic retries or queuing.
- When session/token expires, the system re-authenticates automatically using stored credentials.
- If a booking is confirmed locally but rejected by the backend (race condition), the bot reports the failure and suggests alternative slots.
- If the app updates its API and breaks integration, the MCP server returns clear error messages; manual investigation and update is required.
- If a slot becomes unavailable between checking and booking, the bot reports the conflict and suggests alternatives.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST authenticate with the Tallanto backend to access booking data.
- **FR-002**: System MUST retrieve available court time slots for a given date range.
- **FR-003**: System MUST create bookings for a specific court, date, and time slot, only after receiving explicit user confirmation.
- **FR-004**: System MUST cancel existing bookings, only after receiving explicit user confirmation.
- **FR-005**: System MUST list active bookings for the authenticated user.
- **FR-006**: System MUST handle API errors by reporting a clear message to the user and suggesting to try again later. No automatic retries or request queuing.
- **FR-010**: Booking and cancellation functionality MUST be implemented as a dedicated skill (separate agent prompt).
- **FR-007**: System MUST respect booking constraints (1-hour increments, daily and weekly limits as set by the venue).
- **FR-008**: System MUST store authentication credentials securely on the server.
- **FR-009**: System MUST refresh or re-authenticate sessions automatically when they expire.

### Key Entities

- **Court Slot**: A bookable time window on a specific court (date, start time, end time, court identifier, availability status).
- **Booking**: A confirmed reservation linking a user to a court slot (booking ID, user, court slot, status).
- **User Session**: Authentication state for the Tallanto API (credentials, session token, expiry).
- **Booking Skill**: A dedicated agent skill (`skills/tennis-booking/SKILL.md`) that orchestrates the booking workflow with user confirmation prompts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can view available slots and book a court in under 1 minute via the bot, compared to 3-5 minutes through the app.
- **SC-002**: Bot correctly reflects slot availability that matches the Tallanto app at least 95% of the time.
- **SC-003**: Bookings made through the bot appear correctly in the Tallanto app within 30 seconds.
- **SC-004**: User can manage (view, book, cancel) all court reservations without opening the Tallanto app.

## Assumptions

- The Tallanto mobile app communicates with a REST/HTTP API backend that can be discovered through traffic analysis.
- The API authentication mechanism can be replicated programmatically.
- The tennis center does not actively block automated API access.
- The API endpoints are stable enough for a reliable integration.
- The user's Tallanto account credentials will be stored securely in the MCP server configuration.

## Research Phase (Pre-Implementation)

Before implementation can begin, the following research is required. **Primary approach: reverse engineering via traffic interception.** Official API is a fallback.

1. **API Discovery (primary)**: Set up an Android emulator with a traffic proxy to intercept the app's network traffic. Document all API endpoints, request/response formats, and authentication flow.
2. **Authentication Flow**: Determine how the app authenticates and whether credentials can be reused long-term.
3. **Rate Limits & Terms**: Check for any rate limiting, bot detection, or terms of service that might restrict automated access.
4. **Fallback — Official API**: If reverse engineering proves impractical (e.g., certificate pinning, encrypted payloads), investigate whether Tallanto provides official API access. The Tallanto CRM has an API with Postman collections — check if the center's admin can grant access.

## Scope Boundaries

### In Scope

- Viewing available court slots
- Booking court time
- Canceling bookings
- Viewing active bookings
- MCP server with tools exposed to the OpenClaw gateway

### Out of Scope

- Payment processing (payment is done on-site via QR code)
- Account creation in the Tallanto system
- Push notifications about booking changes
- Multi-user support (single user account per deployment)
- Integration with the Telegram group chat booking workflow
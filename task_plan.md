# Task Plan: Google Calendar Integration for openclawd

## Goal
Enable this `openclawd` project to work with the user's Google Calendar through a configured MCP server and clear setup steps.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define technical approach
- [x] Decide required config and env changes
- [x] Document decisions with rationale
- **Status:** complete

### Phase 3: Implementation
- [x] Update project files for Google Calendar setup
- [x] Add/adjust setup script(s)
- [x] Keep backwards-safe defaults where possible
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Validate config syntax and script behavior
- [ ] Smoke-test setup flow locally
- [x] Document test results in progress.md
- **Status:** in_progress

### Phase 5: Delivery
- [x] Summarize changes and usage steps
- [x] Note any manual actions needed in Google Cloud Console
- [ ] Deliver final instructions to user
- **Status:** in_progress

## Key Questions
1. Which MCP server package for Google Calendar is best aligned with this repo style?
2. Should we keep existing TickTick setup untouched and add Google Calendar as optional?
3. What minimal env vars and script steps are required for OAuth setup?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use file-based planning for this task | Multi-step integration likely exceeds 5 tool calls and benefits from persistent context |
| Use `@cocal/google-calendar-mcp` via `npx` | Official package from `nspady/google-calendar-mcp`, no dedicated server clone/build required |
| Keep TickTick setup untouched and add a new script | Avoid regressions and preserve current deployment workflow |
| Use `GOOGLE_OAUTH_CREDENTIALS_FILE` in local `.env` | Simple and safer than embedding JSON directly in env text |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| None yet | 1 | N/A |

## Notes
- Keep current repo behavior intact; add Google Calendar support without breaking existing setup.

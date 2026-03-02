# Feature Specification: Monthly Financial Analysis Skill

**Feature Branch**: `003-financial-analysis`
**Created**: 2026-03-02
**Status**: Draft
**Input**: User description: "необходимо имплементировать новый скилл openclaw бота. Бот должен производить финансовый анализ на основе данных из zenmoney, и давать рекомендации, строить отчет, смотреть кросскорреляции и так далее. Скил должен вызываться регулярно 1-го числа каждого месяца"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monthly Financial Report (Priority: P1)

On the 1st of each month, the bot automatically generates a financial report for the previous month and sends it to the user via Telegram. The report includes total income, total expenses, breakdown by category, comparison with the previous month, and top spending categories.

**Why this priority**: This is the core value — an automated monthly report that gives the user a clear picture of their finances without any manual effort.

**Independent Test**: Can be fully tested by triggering the skill manually and verifying that the report contains income/expense totals, category breakdown, and month-over-month comparison.

**Acceptance Scenarios**:

1. **Given** it is the 1st of the month, **When** the skill is triggered (automatically or manually), **Then** the bot produces a report covering the previous calendar month with income totals, expense totals, and category breakdown.
2. **Given** the previous month had no transactions, **When** the skill runs, **Then** the bot reports zero activity and notes the absence of data.
3. **Given** a user triggers the skill manually mid-month, **When** the skill runs, **Then** the bot produces a report for the current month-to-date with a note that the month is incomplete.

---

### User Story 2 - Trend Analysis and Cross-Correlations (Priority: P2)

The report includes trends over recent months (3–6 month window): spending trajectory per category, income stability, and notable cross-correlations (e.g., restaurant spending rises when travel spending rises; income dips correlate with increased credit usage).

**Why this priority**: Trends and correlations turn raw data into actionable insights, helping the user understand spending patterns beyond a single month.

**Independent Test**: Can be tested by running the skill with 3+ months of historical data and verifying that the output includes trend direction (up/down/stable) per top category and at least one cross-correlation observation if present.

**Acceptance Scenarios**:

1. **Given** 3+ months of transaction history exist, **When** the skill runs, **Then** the report includes a trends section showing spending direction for at least the top 5 categories.
2. **Given** fewer than 3 months of data exist, **When** the skill runs, **Then** trends are omitted with a note that insufficient history is available.
3. **Given** a notable correlation exists (e.g., two categories consistently move together), **When** the skill runs, **Then** it is highlighted in the report.

---

### User Story 3 - Personalized Recommendations (Priority: P2)

Based on the analysis, the bot provides 3–5 actionable financial recommendations: areas to cut spending, categories exceeding budget, savings opportunities, and alerts about unusual patterns.

**Why this priority**: Recommendations transform a passive report into an active financial advisor, which is the key differentiator from simply looking at ZenMoney directly.

**Independent Test**: Can be tested by running the skill and verifying that the output contains at least 3 concrete recommendations tied to actual data (not generic advice).

**Acceptance Scenarios**:

1. **Given** the user overspent in a category relative to the previous month or budget, **When** the skill runs, **Then** the report recommends reviewing that category with specific numbers.
2. **Given** a spending anomaly is detected (e.g., a single large transaction above 2x the category average), **When** the skill runs, **Then** the report flags it.
3. **Given** the user's overall spending decreased, **When** the skill runs, **Then** the report acknowledges the positive trend.

---

### User Story 4 - Budget vs. Actual Comparison (Priority: P3)

If budgets are configured in ZenMoney, the report compares actual spending against budgets per category, showing percentage used and over/under amounts.

**Why this priority**: Budget tracking adds precision but depends on the user having pre-configured budgets, which may not always be the case.

**Independent Test**: Can be tested by ensuring budgets exist in ZenMoney and verifying the report shows budget utilization percentages.

**Acceptance Scenarios**:

1. **Given** budgets are set for the month, **When** the skill runs, **Then** the report includes a budget vs. actual table with percentages.
2. **Given** no budgets are configured, **When** the skill runs, **Then** the budget section is omitted gracefully.

---

### Edge Cases

- What happens when ZenMoney API is unavailable or returns an error? The skill reports the failure and retries on the next scheduled run.
- What happens when the user has multiple accounts in different currencies? Transactions are grouped by currency; no automatic conversion is performed.
- What happens when categories are not assigned to some transactions? Uncategorized transactions are grouped under "Uncategorized" and flagged in recommendations.
- What happens when the skill is triggered twice in the same day? The skill generates the report again without side effects (idempotent — read-only analysis).

## Clarifications

### Session 2026-03-02

- Q: How should transfers between own accounts be handled in income/expense totals? → A: Exclude transfers from income/expense totals; show separate "Transfers" section in the report. ZenMoney distinguishes transfers from income/expenses natively.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST fetch all transactions for the analysis period using ZenMoney MCP tools (`get_transactions`, `get_categories`, `get_accounts`).
- **FR-002**: System MUST calculate total income and total expenses for the reporting period, grouped by category. Transfers between own accounts MUST be excluded from income/expense totals and shown in a separate "Transfers" section.
- **FR-003**: System MUST compare the current period with the previous period (month-over-month) showing absolute and percentage changes.
- **FR-004**: System MUST identify the top 5 expense categories by amount.
- **FR-005**: System MUST detect spending anomalies — individual transactions exceeding 2x the category's monthly average.
- **FR-006**: System MUST generate 3–5 actionable recommendations based on the data (not generic advice).
- **FR-007**: System MUST produce a trends section when 3+ months of history are available, showing direction (up/down/stable) per category.
- **FR-008**: System MUST identify cross-correlations between categories when 3+ months of data exist (e.g., categories that consistently rise or fall together).
- **FR-009**: System MUST compare spending against ZenMoney budgets when budgets are configured.
- **FR-010**: System MUST handle multiple currencies by grouping analysis per currency without cross-currency conversion.
- **FR-011**: System MUST run automatically on the 1st of each month via OpenClaw cron scheduler.
- **FR-012**: System MUST be invocable manually by the user at any time, analyzing month-to-date when triggered mid-month.
- **FR-013**: System MUST format the report in Russian, using Markdown formatting suitable for Telegram delivery.
- **FR-014**: System MUST store historical analysis summaries in workspace files for trend tracking across months.

### Key Entities

- **Report Period**: Calendar month (previous month for scheduled runs, current month-to-date for manual triggers).
- **Transaction**: ZenMoney transaction with amount, date, category, account, currency.
- **Category**: ZenMoney tag/category tree; used for grouping and trend analysis.
- **Budget**: ZenMoney budget per category per period; optional.
- **Historical Summary**: Stored monthly aggregates (per-category totals, income, expenses) used for trend and correlation analysis.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The report is delivered automatically on the 1st of each month without user intervention.
- **SC-002**: The report covers all accounts and transaction categories present in ZenMoney.
- **SC-003**: Month-over-month comparisons are accurate to within rounding (±1 unit of currency).
- **SC-004**: Trend analysis is available after 3 months of accumulated data.
- **SC-005**: The user can trigger the report manually and receive results within 60 seconds.
- **SC-006**: Recommendations reference specific categories and amounts from the user's data (no generic advice).
- **SC-007**: The report is readable and well-formatted when delivered via Telegram.

## Assumptions

- The user has an active ZenMoney account with transaction history accessible via the ZenMoney MCP server.
- ZenMoney categories are the primary grouping mechanism; the skill does not create or modify categories.
- The skill is read-only with respect to ZenMoney data — it does not create, update, or delete transactions.
- The report language is Russian, matching the user's primary language and ZenMoney locale.
- The timezone for "1st of each month" scheduling is Europe/Moscow.
- Cross-correlation analysis uses Pearson-style directional comparison (both categories rise/fall in the same months), not statistical p-values — the goal is practical insight, not academic rigor.
- Historical summaries are stored in the OpenClaw workspace (`~/.openclaw/workspace/financial-analysis/`) and persist across runs.

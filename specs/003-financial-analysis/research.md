# Research: Monthly Financial Analysis Skill

## ZenMoney MCP Tool Capabilities

### Decision: Use `get_transactions` with pagination for full-month data
- **Rationale**: `get_transactions` has a default `limit=50`. Months with heavy spending may exceed this. The skill must request with a high limit (e.g., `limit=500`) or make multiple calls to cover all transactions.
- **Alternatives considered**: Fetching only top categories first — rejected because accurate totals require all transactions.

### Decision: Use category names (not UUIDs) for report display
- **Rationale**: `get_transactions` returns category names as text labels (e.g., "Health & Fitness", "Transport"). UUIDs are available via `get_categories` but only needed for filtering, not display.
- **Alternatives considered**: Using tag_id for grouping — rejected because category names are human-readable and already included in transaction output.

### Decision: Detect transfers by transaction type, not by category
- **Rationale**: ZenMoney has a `type` field for transactions (`expense`, `income`, `transfer`). The skill filters transfers out of income/expense totals using this field natively.
- **Alternatives considered**: Filtering by category name "Transfer" — rejected because it's language-dependent and unreliable.

### Decision: Store historical summaries as structured Markdown in workspace files
- **Rationale**: Follows the pattern of `daily-planner` and `ticktick-inbox` skills which persist state in `~/.openclaw/workspace/<skill>/`. JSON inside Markdown code blocks provides both human-readability and parseability.
- **Alternatives considered**: Pure JSON file — rejected because it breaks the workspace file convention; database — over-engineering for single-user analysis.

### Decision: Cross-correlations via directional comparison (not statistical)
- **Rationale**: With 3-6 months of data points, statistical correlation (Pearson) is unreliable. Simple directional comparison (both categories went up/down/stable in the same months) is practical and interpretable.
- **Alternatives considered**: Pearson correlation with p-value — rejected due to tiny sample size making results misleading.

## ZenMoney Data Model (Live)

### Accounts (20 active)
- Fields: id (UUID), name (string), balance (number), currency (RUB/EUR/USD/μBTC/֏)
- Multi-currency: grouping by currency required, no cross-currency conversion

### Categories (29 total)
- Fields: id (UUID), name (string), type (array: `[expense]`, `[income]`, or `[income, expense]`)
- Hierarchy: flat (no parent-child nesting observed in live data)
- Bidirectional categories exist (e.g., "Correction" can be both income and expense)

### Transactions
- Fields: id (UUID), date (YYYY-MM-DD), amount (number, negative=expense), category (text label), payee (text), account_id (UUID)
- Amount sign convention: negative = expense, positive = income
- Transfer type: separate from income/expense

### Budgets
- Currently not configured (API returns empty)
- Schema supports: category-level budgets with date ranges
- Skill should gracefully skip budget section when empty

## Cron Scheduling

### Decision: Use `openclaw cron add` with Europe/Moscow timezone
- **Rationale**: Existing cron jobs use UTC and Europe/Moscow. Financial month boundaries are meaningful in the user's local timezone.
- **Schedule**: `cron 0 9 1 * * @ Europe/Moscow` — 9 AM on the 1st of each month
- **Alternatives considered**: UTC midnight — rejected because the user interacts in Moscow time; early morning delivery gives time to review before the workday.

## Skill Architecture

### Decision: Single SKILL.md with phased algorithm
- **Rationale**: Matches existing skill patterns (daily-planner, ticktick-inbox). The LLM can call MCP tools, aggregate data, and format reports within a single prompt execution.
- **Phases**:
  - Phase 0: Load context (workspace history files)
  - Phase 1: Fetch data (transactions, categories, accounts, budgets)
  - Phase 2: Aggregate and analyze (totals, categories, MoM comparison)
  - Phase 3: Trends and correlations (if 3+ months of history)
  - Phase 4: Generate recommendations
  - Phase 5: Format and deliver report
  - Phase 6: Save historical summary to workspace

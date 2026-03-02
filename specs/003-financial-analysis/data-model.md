# Data Model: Monthly Financial Analysis Skill

## Workspace Files

All files stored at `~/.openclaw/workspace/financial-analysis/`.

### `history.md` — Historical Monthly Summaries

Persists aggregated data from each monthly run. Used for trend analysis and cross-correlations.

```markdown
# Financial Analysis History

## 2026-02

```json
{
  "period": "2026-02",
  "generated_at": "2026-03-01T09:00:00+03:00",
  "currencies": {
    "RUB": {
      "total_income": 150000.0,
      "total_expenses": 120000.0,
      "total_transfers": 30000.0,
      "net": 30000.0,
      "categories": {
        "Health & Fitness": -15000.0,
        "Transport": -8000.0,
        "Eating out": -12000.0,
        "Salary": 150000.0
      },
      "top_expenses": [
        {"category": "Health & Fitness", "amount": 15000.0},
        {"category": "Eating out", "amount": 12000.0}
      ]
    }
  }
}
`` `

## 2026-01

```json
{ ... previous month ... }
`` `
```

**Fields per currency per month**:
- `total_income`: Sum of all income transactions
- `total_expenses`: Sum of all expense transactions (absolute value)
- `total_transfers`: Sum of all inter-account transfers (absolute value)
- `net`: income - expenses
- `categories`: Map of category name → total amount (negative=expense, positive=income)
- `top_expenses`: Top 5 expense categories sorted by amount

### `preferences.md` — User Preferences (optional, future)

Reserved for user-configurable thresholds (e.g., anomaly multiplier, trend window). Not created in v1 — uses hardcoded defaults.

## Entities (from ZenMoney, read-only)

### Transaction
| Field    | Type   | Source                | Notes                                    |
| -------- | ------ | --------------------- | ---------------------------------------- |
| id       | UUID   | `get_transactions`    | Unique identifier                        |
| date     | string | `get_transactions`    | Format: YYYY-MM-DD                       |
| amount   | number | `get_transactions`    | Negative=expense, positive=income        |
| category | string | `get_transactions`    | Human-readable label (from tag)          |
| payee    | string | `get_transactions`    | Merchant/description                     |
| type     | string | Transaction context   | `expense`, `income`, or `transfer`       |
| currency | string | Account → currency    | Derived from account_id                  |

### Category
| Field | Type     | Source           | Notes                                  |
| ----- | -------- | ---------------- | -------------------------------------- |
| id    | UUID     | `get_categories` | Unique identifier                      |
| name  | string   | `get_categories` | Display name                           |
| type  | string[] | `get_categories` | `[expense]`, `[income]`, or both       |

### Account
| Field    | Type   | Source         | Notes                    |
| -------- | ------ | -------------- | ------------------------ |
| id       | UUID   | `get_accounts` | Unique identifier        |
| name     | string | `get_accounts` | Display name with emoji  |
| balance  | number | `get_accounts` | Current balance          |
| currency | string | `get_accounts` | RUB, EUR, USD, etc.      |

### Budget (when configured)
| Field    | Type   | Source        | Notes                           |
| -------- | ------ | ------------- | ------------------------------- |
| category | string | `get_budgets` | Category name                   |
| limit    | number | `get_budgets` | Budget limit for the period     |
| spent    | number | `get_budgets` | Actual spending in the period   |

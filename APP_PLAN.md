# Wave — Offline Personal Budget Tracker Plan

**Platform:** Flutter mobile, Android-first and iOS-compatible
**Operation:** Offline-first, local storage only, manual entry
**Default currency:** PHP
**Product promise:** A repeat transaction can be recorded one-handed in under five seconds.

## 1. Vision

Wave is a fast, private personal-finance app with no account requirement, cloud dependency, advertising, or bank connection. It helps users understand where their money goes across daily, weekly, monthly, yearly, and custom periods while keeping the ledger entirely on their device.

## 2. MVP Features

### Ledger

- Multiple accounts, including cash, bank, e-wallet, and savings
- Income and expense entry with amount, category, account, date, and optional note
- Account-to-account transfers that do not affect income or expense totals
- Preset and customizable income and expense categories
- Account and category archival to preserve historical records
- Edit, delete, and reliable Undo behavior

### Expense views by period

Users can review expenses using a consistent period selector:

- **Today** — expenses recorded during the current calendar day
- **Daily** — a selected calendar day
- **This week** — Monday through Sunday by default
- **Weekly** — any selected calendar week
- **This month** — the current calendar month
- **Monthly** — any selected calendar month
- **This year** — the current calendar year
- **Yearly** — any selected calendar year
- **Custom** — an inclusive start and end date

Every period view shows:

- Total expenses
- Total income
- Net cash flow: income minus expenses
- Previous-period comparison when an equivalent previous period exists
- Expense breakdown by category
- Average spending per day for multi-day periods
- Highest-spending category
- Transaction count
- Drill-down to the filtered transaction list

The selected period should persist while moving between Home, Transactions, and Reports when practical. Dates use the device's local timezone and calendar boundaries.

### Budgets

- Monthly limit per expense category for MVP
- Spent, remaining, and percentage-used values
- On track, Near limit, and Over budget states
- Category drill-down to relevant transactions
- Future support for weekly and custom-period budgets without changing the ledger model

### Dashboard

- Total balance across active accounts
- Period selector with quick choices for Today, Week, Month, and Year
- Income, expenses, and net cash flow for the selected period
- Quick actions for Expense, Income, and Transfer
- Budget preview
- Recent activity
- Backup status

### Reports

- Shared Daily, Weekly, Monthly, Yearly, and Custom period selector
- Expense breakdown by category
- Income versus expense comparison
- Spending trend whose grouping adapts to the selected range
- Net-worth history after the core ledger is proven
- Tap any report segment or point to view its underlying transactions

Suggested chart grouping:

| Selected range | Default grouping |
|---|---|
| One day | Time or transaction sequence; avoid an unnecessary chart when data is sparse |
| One week | Day |
| One month | Day or week |
| One year | Month |
| Custom up to 31 days | Day |
| Custom over 31 days | Week or month, selected automatically |

### Backup and restore

- Versioned JSON as the canonical full backup format
- CSV export for viewing and analysis, not as the primary restoration format
- Validate the complete backup before changing live data
- Restore within one atomic database transaction
- Display last successful backup date and a dismissible reminder

## 3. Post-MVP Features

- Recurring transaction rules and scheduled entry suggestions
- Income-source templates
- Savings goals
- Weekly and custom-period budgets
- Search by note or amount
- PIN or biometric lock
- Dark mode refinements
- Home-screen widgets
- Multi-currency with exchange rates and base-currency reporting
- Receipt scanning and OCR
- Optional cloud sync and multi-device support

## 4. Data Model

Money is stored as integer minor units, never floating-point values. For example, PHP 1,250.50 is stored as `125050`.

### Account

```text
id
name
accountTypeId
currencyCode
openingBalanceMinor
openingBalanceDate
iconKey
colorValue
includeInNetWorth
archivedAt?
createdAt
updatedAt
```

### AccountType

```text
id
name
iconKey
isDefault
archivedAt?
```

### Transaction

```text
id
accountId
categoryId
incomeSourceId?
type                 // income | expense
amountMinor
occurredAt           // stored as an absolute timestamp
note?
createdAt
updatedAt
```

### Category

```text
id
name
type                 // income | expense
iconKey
colorValue
isDefault
archivedAt?
```

### Transfer

```text
id
fromAccountId
toAccountId
amountMinor
occurredAt
note?
createdAt
updatedAt
```

Transfer constraints:

- Amount must be greater than zero
- Source and destination accounts must differ
- Both accounts must use the same currency during MVP
- Create, edit, and delete operations must be atomic

### Budget

```text
id
categoryId
periodType            // monthly for MVP
periodStart
periodEnd
limitMinor
createdAt
updatedAt
```

Enforce uniqueness for the category and budget period. Explicit start and end fields allow weekly or custom budgets later.

### Derived balances

Do not store an ordinary mutable current balance. Calculate it from:

```text
opening balance
+ income
- expenses
+ incoming transfers
- outgoing transfers
```

The ledger is the source of truth. Cached summaries may be added later but must be regenerable from ledger entries.

## 5. Date and Period Rules

Create one reusable period-domain model used by database queries, state management, and UI:

```text
ExpensePeriod
- kind: day | week | month | year | custom
- startInclusive
- endExclusive
- displayLabel
- previousPeriod
```

Rules:

- Store transaction timestamps consistently and convert them to the device timezone for display and period boundaries
- Query with a half-open interval: `occurredAt >= start` and `occurredAt < end`
- Make the first day of the week configurable later; use Monday for MVP
- Backdated edits must immediately update every affected total and report
- An empty period displays zero totals and a useful action, never a broken chart
- Previous-period comparisons must use an equivalent duration

## 6. Screens

1. **First launch** — privacy explanation, PHP currency confirmation, and first account setup
2. **Home** — total balance, period selector, selected-period summary, quick actions, budget preview, recent activity
3. **Add entry** — Expense, Income, and Transfer modes optimized for one-handed entry
4. **Transactions** — chronological ledger with period, account, category, and type filters
5. **Budgets** — category budget progress for the selected month
6. **Accounts** — balances, account details, activity, and archive management
7. **Categories** — create, edit, archive, and merge categories
8. **Reports** — adaptive Daily, Weekly, Monthly, Yearly, and Custom expense analysis
9. **More/Settings** — account and category management, reports, backups, appearance, privacy, and about

## 7. Navigation

Use five bottom-navigation destinations:

1. Home
2. Transactions
3. Add
4. Budgets
5. More

Reports and management screens open from More. The Add destination remains the visually prominent central action.

## 8. Technical Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | Flutter | Cross-platform mobile implementation |
| Local database | Drift + SQLite | Relational queries, aggregation, atomic transfers, migrations, and reactive streams |
| State management | Riverpod | Testable state and dependency management |
| Charts | fl_chart | Pie, bar, and line chart support |
| Formatting | intl | PHP currency and localized date formatting |
| Identifiers | uuid | Stable IDs for backup and restore |

## 9. Implementation Phases

1. **Foundation** — Flutter project, Wave theme tokens, Drift schema, repositories, migrations, and seed data
2. **Ledger** — account, category, transaction, and atomic transfer operations with tests
3. **Period engine** — Daily, Weekly, Monthly, Yearly, and Custom period calculations and aggregate query tests
4. **Core entry flow** — Expense, Income, and Transfer screens optimized for speed
5. **Transactions** — list, period filtering, secondary filters, edit, delete, and Undo
6. **Home** — derived balances, selected-period totals, budget preview, and recent activity
7. **Budgets** — monthly category limits and progress
8. **Reports** — period comparison, category breakdown, and adaptive trends
9. **Backup** — versioned JSON export, validated atomic restore, and CSV export
10. **Polish** — accessibility, empty/error states, privacy mode, motion, and dark theme

## 10. Required Tests

- Money calculations never use floating point
- Balance remains correct after create, edit, delete, transfer, and restore
- A transfer never affects income or expense totals
- Daily boundaries are correct around midnight
- Weekly totals use Monday through Sunday
- Monthly totals handle different month lengths and leap years
- Yearly totals include the correct calendar year
- Custom ranges include their start and full final day
- Backdated edits move amounts between periods correctly
- Previous-period comparisons use equivalent ranges
- Archived categories and accounts remain visible in historical entries
- JSON export and restore produce an equivalent ledger

## 11. MVP Acceptance Criteria

- A repeat expense can be recorded in under five seconds
- The user can see today's, this week's, this month's, and this year's expenses in no more than two interactions from Home
- Period totals match the underlying filtered transactions
- Account balances remain correct after all supported ledger operations
- Reports clearly distinguish income, expense, and transfer activity
- The user can export and successfully restore a complete backup without internet access

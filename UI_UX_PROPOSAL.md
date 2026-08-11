# UI/UX Design Proposal — Wave

**Platform:** Flutter mobile (Android-first, iOS-compatible)
**Product character:** Calm, fast, private, and dependable
**Primary UX goal:** A repeat transaction can be recorded one-handed in under five seconds.

## 1. Design Direction

The app should feel like a private financial notebook rather than a banking portal. The interface will be clean and reassuring, using color to communicate meaning without making the dashboard visually noisy.

### Design principles

1. **Fast at the point of entry** — Transaction entry receives the shortest path and strongest visual priority.
2. **Important numbers first** — Balance, spending, and remaining budget are visible before charts or secondary details.
3. **Progressive disclosure** — Common actions stay simple; notes, dates, and other options remain available without crowding the default flow.
4. **Trust through clarity** — Every edit, transfer, deletion, and restore action clearly communicates its effect.
5. **Offline confidence** — The UI confirms that data lives on the device and makes backup status understandable.
6. **Accessible by default** — Meaning is never communicated by color alone, and touch targets and contrast meet mobile accessibility expectations.

## 2. Proposed Visual Style

### Theme: Wave

A modern, minimal interface with airy cool-neutral surfaces, deep navy-gray text, and a soft blue identity. Rounded cards soften the experience, while typography and spacing keep it precise. A simple wave mark reinforces the sense of steady financial movement without making the app feel like a traditional bank.

### Color roles

| Role | Light theme | Purpose |
|---|---:|---|
| Primary | `#5B8DEF` | Main actions and selected navigation |
| Primary strong | `#315FAD` | High-emphasis blue text and controls |
| Primary container | `#E8F0FE` | Selected cards and subtle emphasis |
| Expense | `#D86464` | Expense totals and warnings |
| Income | `#3F8F70` | Income totals and positive movement |
| Transfer | `#5B8DEF` | Transfers between accounts |
| Warning | `#C28732` | Near-budget-limit states and backup reminders |
| Background | `#F5F8FC` | Airy cool-neutral app background |
| Surface | `#FFFFFF` | Cards, sheets, and fields |
| Text | `#1D2A3A` | Primary content |
| Muted text | `#69788C` | Supporting labels |

Dark mode should preserve the same semantic roles rather than simply inverting colors. Category colors are user-selectable, but reports should use a curated, contrast-safe palette.

### Typography

Use the platform-default Flutter/Material typeface for the first release to avoid an unnecessary font dependency.

| Style | Suggested use |
|---|---|
| Display, 30–34 px, semibold | Total balance |
| Title, 20–24 px, semibold | Screen and card headings |
| Body, 15–17 px | Lists, fields, and descriptions |
| Label, 12–14 px, medium | Metadata and navigation |
| Numeric emphasis | Tabular figures where supported, consistent currency alignment |

Amounts must use consistent formatting, such as `₱1,250.00`, with negative signs reserved for expenses in detailed contexts. Income and expense labels should remain visible so users do not have to infer meaning from signs or colors.

### Shape, spacing, and motion

- 8-point spacing grid
- 12–16 px card and field corner radius
- Minimum 48 × 48 logical-pixel interactive targets
- Light elevation or tonal separation rather than strong shadows
- Motion duration of roughly 150–250 ms
- Respect the operating system's reduced-motion preference
- Use animation primarily to confirm state changes, not as decoration

## 3. Information Architecture

Use a five-destination bottom navigation bar:

1. **Home** — Overview, recent activity, budget status
2. **Transactions** — Complete searchable and filterable ledger
3. **Add** — Prominent central action opening transaction entry
4. **Budgets** — Monthly budget progress
5. **More** — Accounts, categories, reports, income sources, backup, and settings

The central Add destination should look visually prominent but retain a standard accessible navigation label. On compact screens, it can appear as a raised circular or rounded-square action.

This structure keeps daily destinations immediately available while preventing lower-frequency management screens from overcrowding navigation.

## 4. Core Screen Proposals

### 4.1 First launch

Keep onboarding to two or three lightweight steps:

1. Welcome and offline privacy explanation
2. Select currency, defaulting to PHP
3. Create the first account with name, type, and opening balance

Seed common expense and income categories automatically. Let users customize them later rather than forcing category setup during onboarding.

The completion action should lead directly to Home, with a clear prompt to record the first transaction.

### 4.2 Home

Recommended top-to-bottom hierarchy:

1. Greeting or current month and a privacy toggle for hiding amounts
2. **Total balance** hero card
3. Period selector with Today, Week, Month, Year, and Custom options
4. Selected period's **Income**, **Expenses**, and **Net** summary
5. Quick actions: Expense, Income, Transfer
6. Budget status, showing the three categories closest to their limits
7. Recent transactions
8. Small backup-status message when relevant

The default dashboard should avoid a large chart. A small spending trend or category bar can appear below the essential figures; detailed charts belong in Reports.

If multiple currencies are added in a future release, the total balance must not combine them without a defined conversion rate.

### 4.3 Add transaction

Open this as a full-height modal sheet or dedicated screen with three segmented modes:

**Expense | Income | Transfer**

#### Expense and income default flow

1. Large amount field with numeric keyboard immediately focused
2. Frequently used category chips or a compact category grid
3. Account selector, prefilled with the last-used account
4. Primary Save action positioned above the keyboard or within thumb reach

Secondary fields sit behind **Add details**:

- Date and time, defaulting to now
- Note
- Income source when applicable

After saving, show a brief confirmation with **Undo**. Keep the user on the previous screen unless they deliberately choose “Save and add another.”

#### Transfer flow

Show:

- Amount
- From account
- To account
- Swap-accounts action
- Optional date and note

Prevent selection of the same source and destination. Explain that transfers do not affect income or expense totals.

### 4.4 Transactions

Use a chronological list grouped by day. Each item shows:

- Category or transfer icon
- Category/title and optional truncated note
- Account name
- Amount
- Transfer, income, or expense indicator

The screen includes a search action and filter chips for type, account, category, and date. Active filters must remain visible and removable individually.

Tapping opens details and edit actions. Swipe may expose Edit and Delete, but deletion requires confirmation or a reliable Undo action. Transfers should be edited and deleted as one paired operation.

### 4.5 Budgets

The header shows the selected month and total planned versus spent. Each category row includes:

- Category icon and name
- Spent amount and limit
- Remaining amount
- Progress bar
- Plain-language state: On track, Near limit, or Over budget

Suggested thresholds:

- Below 75%: normal
- 75–99%: warning
- 100% and above: over budget

Do not rely only on green, amber, and red. Include text and numeric values.

Tapping a category opens its relevant transactions. An empty state should offer **Create a budget** rather than showing an empty chart.

### 4.6 Accounts

Display total balance first, followed by account cards showing:

- Account name and type
- Current balance

- Optional savings goal progress
- Archived status where applicable

The account detail screen shows balance, activity, income, expense, and transfer history. Editing the opening balance after transactions exist should include a clear explanation of how the displayed balance will change.

### 4.7 Reports

Reports should prioritize comparison over decoration:

- Shared Daily, Weekly, Monthly, Yearly, and Custom period selector
- Income versus expense summary
- Expense breakdown by category
- Adaptive cash-flow trend grouped by day, week, or month based on the selected range
- Previous-period comparison
- Average daily spending, highest-spending category, and transaction count
- Net-worth trend when implemented

Pie or donut charts should be accompanied by a sorted legend with names, amounts, and percentages. Bar charts are preferable when many categories need comparison.

Every chart element should lead to the underlying filtered transaction list when tapped.

### 4.8 More and settings

Group destinations by purpose:

**Manage**

- Accounts
- Categories
- Income sources

**Insights**

- Reports

**Data and privacy**

- Backup and restore
- Export CSV
- App lock when implemented

**Preferences**

- Appearance
- Currency
- About

Show the last successful backup date prominently. A reminder should be dismissible and should not appear more often than necessary.

## 5. Important Interaction States

Every feature must define these states before implementation:

- Loading or database initialization
- Empty data
- Populated data
- Validation error
- Recoverable operation failure
- Destructive-action confirmation
- Successful save with Undo where appropriate
- Backup/import progress and completion

For an offline app, avoid generic “Something went wrong” messages. Explain whether the data was saved, left unchanged, or restored.

## 6. Empty-State Strategy

| Screen | Empty-state message | Primary action |
|---|---|---|
| Home | Start building your financial picture | Add transaction |
| Transactions | No transactions for this period | Add transaction |
| Budgets | Set limits for the categories that matter | Create budget |
| Accounts | Add where you keep your money | Add account |
| Reports | Reports appear after transactions are recorded | Add transaction |

Empty states should use small, simple illustrations or icons only if they help explain the next action.

## 7. Accessibility and Privacy

- Support system text scaling without clipping important amounts or actions
- Provide semantic labels for icons and charts
- Maintain at least WCAG AA contrast for ordinary text
- Never use color alone for transaction types or budget warnings
- Provide a hide/show balance control on Home
- Exclude sensitive figures from app-switcher previews when privacy mode is enabled
- Confirm before replacing data during restore
- Avoid displaying full financial details in notifications or widgets by default

## 8. MVP Design Scope

### Design now

- First launch and first-account setup
- Home
- Add expense, income, and transfer
- Transaction list, filters, details, edit, and delete
- Budgets
- Accounts and categories
- Backup and restore states
- Core component and color system

### Design after the ledger is proven

- Advanced reports
- Savings goals
- Income-source templates
- Recurring transactions
- Dark theme refinements
- App lock and widgets
- Multi-currency conversion experiences

## 9. Reusable Component Set

Build a small, consistent UI kit in Flutter:

- App scaffold and bottom navigation
- Amount display and privacy-hidden state
- Money input field
- Transaction-type segmented control
- Account selector
- Category chip/grid selector
- Transaction list tile
- Summary metric card
- Budget progress row
- Filter chip and filter sheet
- Empty state
- Confirmation/Undo message
- Backup status card

Components should use semantic design tokens instead of hard-coded colors or spacing so light and dark themes can evolve safely.

## 10. Validation Plan

Before polishing the complete app, test a clickable prototype of these tasks:

1. Add a first cash expense
2. Add salary income
3. Transfer money from bank to savings
4. Find and correct an earlier transaction
5. Determine how much remains in a food budget
6. Compare today's, this week's, and this month's expenses
7. Export a backup and understand its status

Success measures:

- Repeat expense entry completes in under five seconds
- New users correctly distinguish income, expense, and transfer
- Users can identify remaining category budget without opening details
- Users can change expense periods and understand the active date range
- Period totals match the transactions shown after drill-down
- Users understand whether a backup completed successfully
- No critical task requires hidden gestures

## 11. Recommended Next Design Deliverables

1. Low-fidelity wireframes for the six validation tasks
2. Visual design tokens and reusable component specifications
3. High-fidelity Home, Add Transaction, Transactions, and Budgets screens
4. Clickable prototype for quick-entry usability testing
5. Flutter implementation mapped to the approved components

## Approval Recommendation

Proceed with the **Wave** direction and validate the Add Transaction flow first. Its soft-blue identity expresses calm, steady financial movement while preserving the app's private, offline nature, and it keeps the most important interaction fast enough to support the product promise.

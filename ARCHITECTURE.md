# Wave System Architecture

Wave is an offline-first Flutter application. Financial data stays on the device in SQLite; the app does not require login, cloud sync, or a bank connection.

## System architecture

```mermaid
flowchart TB
    User([User])

    subgraph Presentation["Presentation layer — Flutter"]
        Bootstrap["App bootstrap"]
        Onboarding["Onboarding"]
        Shell["App shell and navigation"]
        Home["Home dashboard"]
        Entry["Income / Expense / Transfer entry"]
        Planned["Planned income and expenses"]
        Transactions["Transactions and filters"]
        Budgets["Budgets"]
        Reports["Reports"]
        Management["Accounts and Categories"]
        Settings["Settings and Backup"]
        Theme["Wave theme and motion system"]
    end

    subgraph State["State and coordination — Riverpod"]
        AsyncProviders["Future / Stream providers"]
        Filters["Period, search, and filter state"]
        Preferences["Privacy and appearance state"]
        Invalidation["Mutation invalidation and refresh"]
    end

    subgraph Domain["Application services"]
        LedgerRepo["LedgerRepository"]
        BudgetRepo["BudgetRepository"]
        ManagementRepo["ManagementRepository"]
        OnboardingRepo["OnboardingRepository"]
        BackupService["BackupService"]
        ScheduleRepo["ScheduleRepository"]
        Money["Integer money calculations"]
        Periods["Daily / Weekly / Monthly / Yearly / Custom periods"]
    end

    subgraph Data["Local data layer — Drift"]
        Database["AppDatabase"]
        Queries["Reactive totals, balances, budget progress, and reports"]
        Seed["Safe default-data seeding"]

        subgraph SQLite["SQLite tables"]
            Accounts[(Accounts)]
            Categories[(Categories)]
            Ledger[(Ledger transactions)]
            Transfers[(Transfers)]
            BudgetTable[(Budgets)]
            Scheduled[(Scheduled transactions)]
            AppPreferences[(App preferences)]
        end
    end

    subgraph Device["Device storage"]
        DBFile[(wave.sqlite)]
        JSON["Versioned JSON backups"]
        CSV["Transaction CSV exports"]
    end

    User --> Bootstrap
    Bootstrap -->|"First launch"| Onboarding
    Bootstrap -->|"Setup complete"| Shell
    Shell --> Home
    Shell --> Entry
    Shell --> Planned
    Shell --> Transactions
    Shell --> Budgets
    Shell --> Reports
    Shell --> Management
    Shell --> Settings
    Theme -.-> Home
    Theme -.-> Entry
    Theme -.-> Transactions
    Theme -.-> Budgets

    Presentation --> AsyncProviders
    Presentation --> Filters
    Presentation --> Preferences
    Entry --> Invalidation
    Management --> Invalidation
    Budgets --> Invalidation

    AsyncProviders --> LedgerRepo
    AsyncProviders --> BudgetRepo
    AsyncProviders --> ManagementRepo
    AsyncProviders --> OnboardingRepo
    AsyncProviders --> BackupService
    AsyncProviders --> ScheduleRepo
    Filters --> Periods
    LedgerRepo --> Money
    BudgetRepo --> Money

    LedgerRepo --> Database
    BudgetRepo --> Database
    ManagementRepo --> Database
    OnboardingRepo --> Database
    OnboardingRepo --> Seed
    BackupService --> Database
    ScheduleRepo --> Database
    AsyncProviders --> Queries
    Queries --> Database
    Invalidation --> AsyncProviders

    Database --> Accounts
    Database --> Categories
    Database --> Ledger
    Database --> Transfers
    Database --> BudgetTable
    Database --> Scheduled
    Database --> AppPreferences
    Database --> DBFile
    BackupService --> JSON
    BackupService --> CSV
    JSON -->|"Validate, then atomic restore"| BackupService
```

## Main application flow

```mermaid
flowchart TD
    Launch([Launch Wave]) --> CheckSetup{"Onboarding complete?"}
    CheckSetup -->|No| PrivacyIntro["Show offline privacy introduction"]
    PrivacyIntro --> FirstAccount["Create first account and opening balance"]
    FirstAccount --> SeedDefaults["Seed default income and expense categories"]
    SeedDefaults --> Dashboard
    CheckSetup -->|Yes| LoadLocal["Open local SQLite database"]
    LoadLocal --> SeedCheck["Idempotent default-data check"]
    SeedCheck --> Dashboard["Home dashboard"]

    Dashboard --> AddChoice{"Add activity"}
    AddChoice -->|Expense| Expense["Select amount, category, and account"]
    AddChoice -->|Income| Income["Select amount, category, and account"]
    AddChoice -->|Transfer| Transfer["Select amount, source, and destination"]

    Expense --> Validate{"Input and references valid?"}
    Income --> Validate
    Transfer --> Validate
    Validate -->|No| InlineError["Show actionable error and keep form open"]
    InlineError --> AddChoice
    Validate -->|Yes| AtomicWrite["Write to SQLite"]
    AtomicWrite --> Refresh["Invalidate affected Riverpod providers"]
    Refresh --> Recalculate["Recalculate balances, totals, budgets, and reports"]
    Recalculate --> Dashboard

    Dashboard --> PlanChoice{"Plan future activity"}
    PlanChoice -->|Future expense| PlanExpense["Set amount, due date, recurrence, account, and category"]
    PlanChoice -->|Upcoming income| PlanIncome["Set amount, expected date, recurrence, account, and category"]
    PlanExpense --> SavePlan["Save as planned — do not change ledger totals"]
    PlanIncome --> SavePlan
    SavePlan --> Upcoming["Upcoming cash-flow forecast"]
    Upcoming --> Due{"Due date reached"}
    Due -->|Manual confirmation| Post["Mark paid or received"]
    Due -->|Auto-post enabled| Post
    Due -->|Not completed| Overdue["Mark overdue, skip, or reschedule"]
    Post --> CreateLedger["Create actual ledger transaction"]
    CreateLedger --> NextOccurrence{"Recurring?"}
    NextOccurrence -->|Yes| Advance["Calculate next due date"]
    NextOccurrence -->|No| CompletePlan["Mark planned item completed"]
    Advance --> Upcoming
    CompletePlan --> Refresh

    Dashboard --> Review["Transactions / Budgets / Reports"]
    Review --> Period{"Choose reporting period"}
    Period --> Day[Daily]
    Period --> Week[Weekly]
    Period --> Month[Monthly]
    Period --> Year[Yearly]
    Period --> Custom[Custom]
    Day --> Query["Run local reactive query"]
    Week --> Query
    Month --> Query
    Year --> Query
    Custom --> Query
    Query --> Review

    Dashboard --> DataTools{"Backup or export"}
    DataTools --> Backup["Create versioned JSON backup"]
    DataTools --> Export["Create transaction CSV"]
    DataTools --> Restore["Choose JSON backup"]
    Restore --> ValidateBackup{"Format and references valid?"}
    ValidateBackup -->|No| Reject["Reject without changing live data"]
    ValidateBackup -->|Yes| Replace["Replace database in one transaction"]
    Replace --> Refresh
```

## Ledger rules

Wave stores money as integer minor units to avoid floating-point rounding errors.

```text
account balance = opening balance
                + income
                - expenses
                + incoming transfers
                - outgoing transfers
```

Transfers are separate records and never count as income or expense. Accounts and categories can be archived while historical records retain their references.

Planned income and expenses are also separate from the ledger. They appear in forecasts but do not affect actual balances, budgets, or reports until they are posted as real transactions.

## Data ownership and boundaries

- SQLite is the source of truth.
- Riverpod providers expose reactive, derived views of local data.
- Repositories validate mutations before writing.
- Backup restore validates the entire payload before changing live data.
- Restore replacement is atomic: either every valid record is restored or none are.
- JSON and CSV files are written to Wave's application documents directory.
- No financial records are intentionally transmitted over the network.

## Proposed dashboard theme and motion integration

The revised UI/UX concept fits entirely inside the presentation layer. It does not require changing the ledger or database model.

```mermaid
flowchart LR
    ThemeState["Theme and motion preference"] --> Tokens["Colors, spacing, radius, elevation"]
    ThemeState --> Motion["Gentle motion enabled?"]
    Tokens --> DashboardCards["Balance, Income, Expenses, Savings cards"]
    Motion -->|Yes| WaveDrift["Balance wave: 4s ambient drift"]
    Motion -->|Yes| CardReveal["Cards: 60ms stagger"]
    Motion -->|Yes| ProgressRipple["Progress: soft ripple"]
    Motion -->|Yes| PageFlow["Navigation: 220ms flow"]
    Motion -->|No| Static["Immediate accessible state changes"]
```

Motion should never delay input, obscure financial values, or be required to understand status. The reduced-motion path presents the same information without animation.

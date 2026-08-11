# Wave

Wave is an offline-first personal budget tracker built with Flutter. It keeps accounts, transactions, transfers, budgets, and reports on the device, with PHP as the MVP currency.

## Current features

- Income, expense, and account-to-account transfer entry
- Multiple accounts with derived balances
- Custom income and expense categories
- Daily, weekly, monthly, and yearly summaries
- Monthly category budgets and progress states
- Spending reports with category breakdowns and trends
- Drift/SQLite local persistence
- Riverpod state management

## Development

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

See [APP_PLAN.md](APP_PLAN.md) and [UI_UX_PROPOSAL.md](UI_UX_PROPOSAL.md) for the product and design specifications.

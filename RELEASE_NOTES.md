# Wave 1.1.0 release candidate

Wave is an offline-first personal budget tracker for Android. Version 1.1.0 expands the original ledger with forward-looking planning and local privacy controls.

## Highlights

- Redesigned dashboard for income, expenses, savings, budgets, and net position
- Savings goals and contribution history
- Upcoming and recurring income or expenses with reminders
- Cash-flow forecast and estimated safe-to-spend guidance
- Editable and deletable activity with confirmation before new records are saved
- PIN lock, one-time recovery code, optional biometric unlock, native screen protection, and lock timeout
- Versioned JSON backup with integrity checks, file import, sharing, and CSV export
- Soft-blue Wave themes and reduced-motion support

## Release-candidate limitations

- The generated Android artifacts are signed with the development debug key and are not Play Store production artifacts.
- Biometric authentication, notifications, file picking, sharing, installation, upgrade, and restore still require physical-device verification.
- Currency is currently fixed to Philippine peso.
- Data is local to the device; there is no cloud synchronization or account recovery.
- Safe to Spend is an estimate based only on information entered in Wave and is not financial advice.

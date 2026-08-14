# Wave 1.1.0 release-candidate checklist

## Automated

- [x] Flutter static analysis
- [x] Unit, repository, and widget tests
- [x] Version 1 database migration preserves accounts and transactions
- [x] Dashboard and activity queries complete with a 5,000-entry ledger
- [x] Narrow-screen account flow supports 200% text scaling
- [x] Release APK build (development/debug signed release candidate)
- [x] Release AAB build (development/debug signed release candidate)

## Manual device verification required

- [ ] Fresh install and onboarding
- [ ] Upgrade from Wave 1.0.1 without data loss
- [ ] Income, expense, transfer, edit, delete, and restore flows
- [ ] Planned activity posting and device notifications
- [ ] PIN timeout, background cover, and biometric unlock
- [ ] JSON share, file import, checksum rejection, and full restore
- [ ] Screen reader and keyboard focus order
- [ ] Large text, contrast, reduced motion, small phone, and tablet layouts
- [ ] Large-ledger scrolling and report performance
- [ ] Rollback and backup-recovery procedure
- [ ] Configure a production signing key outside the repository

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/ledger_repository.dart';

void main() {
  late AppDatabase database;
  late LedgerRepository ledger;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test(
    'report aggregates categories, trends, and previous-period expenses',
    () async {
      await ledger.createEntry(
        type: LedgerEntryType.expense,
        amountMinor: 30000,
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: DateTime(2026, 8, 2),
      );
      await ledger.createEntry(
        type: LedgerEntryType.expense,
        amountMinor: 10000,
        accountId: 'account-cash',
        categoryId: 'category-transport',
        occurredAt: DateTime(2026, 8, 2),
      );
      await ledger.createEntry(
        type: LedgerEntryType.expense,
        amountMinor: 20000,
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: DateTime(2026, 8, 3),
      );
      await ledger.createEntry(
        type: LedgerEntryType.expense,
        amountMinor: 25000,
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: DateTime(2026, 7, 3),
      );

      final report = await database.expenseReport(
        ExpensePeriod.month(DateTime(2026, 8)),
      );

      expect(report.totals.expenseMinor, 60000);
      expect(report.previousTotals.expenseMinor, 25000);
      expect(report.categories.first.name, 'Food');
      expect(report.categories.first.amountMinor, 50000);
      expect(report.trend, hasLength(2));
      expect(report.trend.first.amountMinor, 40000);
      expect(report.transactionCount, 3);
    },
  );
}

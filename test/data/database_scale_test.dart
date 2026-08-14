import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';

void main() {
  test('dashboard and activity queries handle a 5000-entry ledger', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await seedDatabase(database);
    final start = DateTime(2026, 1, 1);

    await database.batch((batch) {
      for (var index = 0; index < 5000; index++) {
        final income = index.isEven;
        batch.insert(
          database.ledgerTransactions,
          LedgerTransactionsCompanion.insert(
            id: 'scale-entry-$index',
            accountId: 'account-cash',
            categoryId: income ? 'category-salary' : 'category-food',
            type: income ? 'income' : 'expense',
            amountMinor: income ? 200 : 100,
            occurredAt: start.add(Duration(days: index % 365)),
            note: const Value('Scale fixture'),
          ),
        );
      }
    });

    final period = ExpensePeriod.year(start);
    final report = await database
        .expenseReport(period)
        .timeout(const Duration(seconds: 10));
    final balances = await database.accountBalances().timeout(
      const Duration(seconds: 10),
    );
    final activity = await database
        .watchActivityEntries(period)
        .first
        .timeout(const Duration(seconds: 10));

    expect(report.totals.incomeMinor, 500000);
    expect(report.totals.expenseMinor, 250000);
    expect(
      balances
          .singleWhere((item) => item.account.id == 'account-cash')
          .balanceMinor,
      250000,
    );
    expect(activity, hasLength(5000));
  });
}

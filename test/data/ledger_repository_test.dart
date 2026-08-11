import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/ledger_repository.dart';

void main() {
  late AppDatabase database;
  late LedgerRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LedgerRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test('income and expense update period totals and account balance', () async {
    final now = DateTime(2026, 8, 10, 12);
    await repository.createEntry(
      type: LedgerEntryType.income,
      amountMinor: 500000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: now,
    );
    await repository.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 125050,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: now,
    );

    final totals = await database.totalsFor(ExpensePeriod.month(now));
    final balances = await database.accountBalances();
    final cash = balances.singleWhere(
      (item) => item.account.id == 'account-cash',
    );

    expect(totals.incomeMinor, 500000);
    expect(totals.expenseMinor, 125050);
    expect(totals.netMinor, 374950);
    expect(cash.balanceMinor, 374950);
  });

  test(
    'transfer moves balances but does not change totals or net worth',
    () async {
      final now = DateTime(2026, 8, 10, 12);
      await repository.createEntry(
        type: LedgerEntryType.income,
        amountMinor: 100000,
        accountId: 'account-cash',
        categoryId: 'category-salary',
        occurredAt: now,
      );
      await repository.createTransfer(
        amountMinor: 30000,
        fromAccountId: 'account-cash',
        toAccountId: 'account-bank',
        occurredAt: now,
      );

      final totals = await database.totalsFor(ExpensePeriod.month(now));
      final balances = await database.accountBalances();
      final cash = balances.singleWhere(
        (item) => item.account.id == 'account-cash',
      );
      final bank = balances.singleWhere(
        (item) => item.account.id == 'account-bank',
      );

      expect(totals.incomeMinor, 100000);
      expect(totals.expenseMinor, 0);
      expect(cash.balanceMinor, 70000);
      expect(bank.balanceMinor, 30000);
      expect(
        balances.fold<int>(0, (sum, item) => sum + item.balanceMinor),
        100000,
      );
    },
  );

  test('transfer rejects the same account on both sides', () async {
    expect(
      () => repository.createTransfer(
        amountMinor: 100,
        fromAccountId: 'account-cash',
        toAccountId: 'account-cash',
        occurredAt: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });

  test('entry rejects a category with the wrong type', () async {
    expect(
      () => repository.createEntry(
        type: LedgerEntryType.income,
        amountMinor: 100,
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });
}

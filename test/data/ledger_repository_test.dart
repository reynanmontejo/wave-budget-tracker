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

  test('activity feed includes transfers and ledger entries', () async {
    final now = DateTime(2026, 8, 10, 12);
    await repository.createEntry(
      type: LedgerEntryType.income,
      amountMinor: 100000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: now,
    );
    await repository.createTransfer(
      amountMinor: 25000,
      fromAccountId: 'account-cash',
      toAccountId: 'account-bank',
      occurredAt: now.add(const Duration(minutes: 1)),
    );

    final activity = await database
        .watchActivityEntries(ExpensePeriod.day(now))
        .first;
    expect(activity, hasLength(2));
    expect(activity.first.kind, 'transfer');
    expect(activity.first.accountName, 'Cash');
    expect(activity.first.destinationName, 'Bank');
    expect(activity.last.kind, 'income');
  });

  test('editing an expense updates amount and account balance', () async {
    final now = DateTime(2026, 8, 10, 12);
    final id = await repository.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 10000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: now,
    );
    await repository.updateEntry(
      id: id,
      type: LedgerEntryType.expense,
      amountMinor: 25000,
      accountId: 'account-bank',
      categoryId: 'category-food',
      occurredAt: now,
      note: 'Updated',
    );

    final balances = await database.accountBalances();
    expect(
      balances
          .singleWhere((item) => item.account.id == 'account-cash')
          .balanceMinor,
      0,
    );
    expect(
      balances
          .singleWhere((item) => item.account.id == 'account-bank')
          .balanceMinor,
      -25000,
    );
  });

  test('editing a transfer recalculates both account balances', () async {
    final now = DateTime(2026, 8, 10, 12);
    await repository.createEntry(
      type: LedgerEntryType.income,
      amountMinor: 100000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: now,
    );
    final id = await repository.createTransfer(
      amountMinor: 20000,
      fromAccountId: 'account-cash',
      toAccountId: 'account-bank',
      occurredAt: now,
    );
    await repository.updateTransfer(
      id: id,
      amountMinor: 35000,
      fromAccountId: 'account-cash',
      toAccountId: 'account-bank',
      occurredAt: now,
      note: 'Updated',
    );

    final balances = await database.accountBalances();
    expect(
      balances
          .singleWhere((item) => item.account.id == 'account-cash')
          .balanceMinor,
      65000,
    );
    expect(
      balances
          .singleWhere((item) => item.account.id == 'account-bank')
          .balanceMinor,
      35000,
    );
  });

  test('deleted activity can be restored with its original ID', () async {
    final now = DateTime(2026, 8, 10, 12);
    final id = await repository.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 5000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: now,
      note: 'Undo me',
    );
    final entry =
        (await database.watchActivityEntries(ExpensePeriod.day(now)).first)
            .single;
    await repository.deleteActivity(id, 'expense');
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    await repository.restoreActivity(entry);
    final restored = await database
        .select(database.ledgerTransactions)
        .getSingle();
    expect(restored.id, id);
    expect(restored.note, 'Undo me');
  });
}

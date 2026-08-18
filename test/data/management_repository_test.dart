import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/ledger_repository.dart';
import 'package:wave/data/management_repository.dart';

void main() {
  late AppDatabase database;
  late ManagementRepository management;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    management = ManagementRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test('creates an account with an integer opening balance', () async {
    final id = await management.createAccount(
      name: 'GCash',
      typeName: 'E-wallet',
      openingBalanceMinor: 123450,
    );
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(account.name, 'GCash');
    expect(account.openingBalanceMinor, 123450);
    expect(account.walletProviderName, 'GCash');
    expect(account.walletProviderKey, 'custom');
    expect(account.walletLastReconciledAt, isNotNull);
  });

  test('creates an e-wallet with provider metadata', () async {
    final id = await management.createAccount(
      name: 'Daily wallet',
      typeName: 'E-wallet',
      openingBalanceMinor: 150000,
      walletProviderName: 'GCash',
      walletProviderKey: 'gcash',
      walletIdentifierSuffix: '42',
      iconKey: 'phone',
    );
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(account.walletProviderName, 'GCash');
    expect(account.walletProviderKey, 'gcash');
    expect(account.walletIdentifierSuffix, '42');
  });

  test('rejects invalid e-wallet provider metadata', () async {
    await expectLater(
      management.createAccount(
        name: 'Wallet',
        typeName: 'E-wallet',
        openingBalanceMinor: 0,
        walletProviderName: 'GCash',
        walletProviderKey: 'unknown-preset',
      ),
      throwsArgumentError,
    );
    await expectLater(
      management.createAccount(
        name: 'Wallet',
        typeName: 'E-wallet',
        openingBalanceMinor: 0,
        walletProviderName: 'GCash',
        walletIdentifierSuffix: '12A4',
      ),
      throwsArgumentError,
    );
  });

  test('reconciles a wallet without changing expense totals', () async {
    final id = await management.createAccount(
      name: 'Daily wallet',
      typeName: 'E-wallet',
      openingBalanceMinor: 100000,
      walletProviderName: 'GCash',
      walletProviderKey: 'gcash',
    );
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 20000,
      accountId: id,
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 18),
    );
    final adjustmentId = await management.reconcileAccountBalance(
      accountId: id,
      observedBalanceMinor: 95000,
      note: 'Matched wallet app',
    );
    expect(adjustmentId, isNotNull);

    var usage = await management.accountUsage(id);
    expect(usage.balanceMinor, 95000);
    expect(usage.adjustments, 1);
    final totals = await database.totalsFor(
      ExpensePeriod.day(DateTime(2026, 8, 18)),
    );
    expect(totals.expenseMinor, 20000);
    expect(totals.incomeMinor, 0);
    final activity = await database.watchAccountActivityEntries(id).first;
    expect(
      activity.any(
        (entry) => entry.kind == 'adjustment_in' && entry.amountMinor == 15000,
      ),
      isTrue,
    );

    await management.reverseBalanceAdjustment(adjustmentId!);
    usage = await management.accountUsage(id);
    expect(usage.balanceMinor, 80000);
    expect(usage.adjustments, 2);
  });

  test('matching wallet reconciliation records no adjustment', () async {
    final id = await management.createAccount(
      name: 'Exact wallet',
      typeName: 'E-wallet',
      openingBalanceMinor: 5000,
    );
    final adjustmentId = await management.reconcileAccountBalance(
      accountId: id,
      observedBalanceMinor: 5000,
    );
    expect(adjustmentId, isNull);
    expect(
      await database.select(database.accountBalanceAdjustments).get(),
      isEmpty,
    );
  });

  test('adjustment history prevents permanent wallet deletion', () async {
    final id = await management.createAccount(
      name: 'Temporary wallet',
      typeName: 'E-wallet',
      openingBalanceMinor: 0,
    );
    await management.reconcileAccountBalance(
      accountId: id,
      observedBalanceMinor: 100,
    );
    await management.reconcileAccountBalance(
      accountId: id,
      observedBalanceMinor: 0,
    );
    final usage = await management.accountUsage(id);
    expect(usage.balanceMinor, 0);
    expect(usage.adjustments, 2);
    await expectLater(management.deleteUnusedAccount(id), throwsStateError);
  });

  test('creates an account with its complete card metadata', () async {
    final opened = DateTime(2026, 8, 1);
    final id = await management.createAccount(
      name: 'Travel fund',
      typeName: 'Savings',
      openingBalanceMinor: 250000,
      openingBalanceDate: opened,
      iconKey: 'savings',
      colorValue: 0xFF269CA3,
      includeInNetWorth: false,
    );
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(account.typeName, 'Savings');
    expect(account.openingBalanceDate, opened);
    expect(account.iconKey, 'savings');
    expect(account.colorValue, 0xFF269CA3);
    expect(account.includeInNetWorth, isFalse);
  });

  test(
    'seeding is safe to repeat with multiple accounts and categories',
    () async {
      await management.createAccount(
        name: 'GCash',
        typeName: 'E-wallet',
        openingBalanceMinor: 123450,
      );

      await seedDatabase(database);

      final accounts = await database.select(database.accounts).get();
      final categories = await database.select(database.categories).get();
      expect(accounts, hasLength(3));
      expect(categories, hasLength(6));
    },
  );

  test('rejects duplicate active account names ignoring case', () async {
    expect(
      () => management.createAccount(
        name: 'cash',
        typeName: 'Cash',
        openingBalanceMinor: 0,
      ),
      throwsArgumentError,
    );
  });

  test('archiving a category preserves its historical transaction', () async {
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 5000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
    );
    await management.archiveCategory('category-food');

    final transactionCount = await database
        .select(database.ledgerTransactions)
        .get();
    final category = await (database.select(
      database.categories,
    )..where((row) => row.id.equals('category-food'))).getSingle();
    expect(transactionCount, hasLength(1));
    expect(category.archivedAt, isNotNull);
  });

  test('cannot archive the final active account', () async {
    await management.archiveAccount('account-bank');
    expect(() => management.archiveAccount('account-cash'), throwsStateError);
  });

  test('updates account metadata and opening balance', () async {
    await management.updateAccount(
      id: 'account-cash',
      name: 'Pocket Cash',
      typeName: 'Cash',
      openingBalanceMinor: 50000,
    );
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account-cash'))).getSingle();
    expect(account.name, 'Pocket Cash');
    expect(account.openingBalanceMinor, 50000);
  });

  test('account update rejects a duplicate active name', () async {
    expect(
      () => management.updateAccount(
        id: 'account-cash',
        name: 'Bank',
        typeName: 'Cash',
        openingBalanceMinor: 0,
      ),
      throwsArgumentError,
    );
  });

  test('updates account card metadata without changing activity', () async {
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.income,
      amountMinor: 10000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: DateTime(2026, 8, 10),
    );
    await management.updateAccount(
      id: 'account-cash',
      name: 'Pocket',
      typeName: 'Cash',
      openingBalanceMinor: 2000,
      openingBalanceDate: DateTime(2026, 8, 1),
      iconKey: 'payments',
      colorValue: 0xFFD86464,
      includeInNetWorth: false,
    );
    final usage = await management.accountUsage('account-cash');
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account-cash'))).getSingle();
    expect(usage.transactions, 1);
    expect(usage.balanceMinor, 12000);
    expect(account.iconKey, 'payments');
    expect(account.includeInNetWorth, isFalse);
  });

  test('reports every account dependency and calculated balance', () async {
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 1500,
      accountId: 'account-bank',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
    );
    await ledger.createTransfer(
      amountMinor: 500,
      fromAccountId: 'account-bank',
      toAccountId: 'account-cash',
      occurredAt: DateTime(2026, 8, 11),
    );
    await database
        .into(database.scheduledTransactions)
        .insert(
          ScheduledTransactionsCompanion.insert(
            id: 'schedule-bank',
            type: 'expense',
            amountMinor: 2000,
            accountId: 'account-bank',
            categoryId: 'category-bills',
            nextDueAt: DateTime(2026, 9, 1),
          ),
        );
    await database
        .into(database.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            id: 'goal-bank',
            name: 'Emergency',
            targetMinor: 100000,
            linkedAccountId: const Value('account-bank'),
          ),
        );

    final usage = await management.accountUsage('account-bank');
    expect(usage.transactions, 1);
    expect(usage.transfers, 1);
    expect(usage.schedules, 1);
    expect(usage.activeSchedules, 1);
    expect(usage.linkedGoals, 1);
    expect(usage.balanceMinor, -2000);
    expect(usage.canDeletePermanently, isFalse);
  });

  test('active schedules prevent account archival', () async {
    await database
        .into(database.scheduledTransactions)
        .insert(
          ScheduledTransactionsCompanion.insert(
            id: 'schedule-bank',
            type: 'expense',
            amountMinor: 2000,
            accountId: 'account-bank',
            categoryId: 'category-bills',
            nextDueAt: DateTime(2026, 9, 1),
          ),
        );
    expect(() => management.archiveAccount('account-bank'), throwsStateError);
  });

  test(
    'archives and restores an account while preserving its identity',
    () async {
      await management.archiveAccount('account-bank');
      var account = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals('account-bank'))).getSingle();
      expect(account.archivedAt, isNotNull);

      await management.restoreAccount('account-bank');
      account = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals('account-bank'))).getSingle();
      expect(account.archivedAt, isNull);
    },
  );

  test('permanently deletes only an unused zero-balance account', () async {
    final id = await management.createAccount(
      name: 'Temporary',
      typeName: 'Cash',
      openingBalanceMinor: 0,
    );
    await management.deleteUnusedAccount(id);
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    expect(account, isNull);
  });

  test('rejects permanent deletion when an account has history', () async {
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 100,
      accountId: 'account-bank',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
    );
    expect(
      () => management.deleteUnusedAccount('account-bank'),
      throwsStateError,
    );
    expect(
      await (database.select(database.ledgerTransactions)).get(),
      hasLength(1),
    );
  });

  test('rejects permanent deletion of a non-zero account', () async {
    final id = await management.createAccount(
      name: 'Non-zero',
      typeName: 'Cash',
      openingBalanceMinor: 1,
    );
    expect(() => management.deleteUnusedAccount(id), throwsStateError);
  });

  test('renaming a category preserves transaction references', () async {
    final ledger = LedgerRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 1000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
    );
    await management.updateCategory(id: 'category-food', name: 'Meals');
    final activity = await database
        .watchTransactionEntries(ExpensePeriod.day(DateTime(2026, 8, 10)))
        .first;
    expect(activity.single.categoryName, 'Meals');
    expect(activity.single.transaction.categoryId, 'category-food');
  });
}

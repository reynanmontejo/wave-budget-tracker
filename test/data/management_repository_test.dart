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
  });

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

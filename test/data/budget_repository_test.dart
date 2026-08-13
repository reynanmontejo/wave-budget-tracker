import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/data/budget_repository.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/ledger_repository.dart';
import 'package:wave/data/management_repository.dart';

void main() {
  late AppDatabase database;
  late BudgetRepository budgets;
  late LedgerRepository ledger;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    budgets = BudgetRepository(database);
    ledger = LedgerRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test('calculates monthly category spending', () async {
    final month = DateTime(2026, 8);
    await budgets.setMonthlyBudget(
      categoryId: 'category-food',
      month: month,
      limitMinor: 100000,
    );
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 25000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
    );
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 99999,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 9, 1),
    );

    final progress = (await database.budgetProgressForMonth(month)).single;
    expect(progress.spentMinor, 25000);
    expect(progress.remainingMinor, 75000);
    expect(progress.fraction, .25);
  });

  test('setting the same category and month updates its limit', () async {
    final month = DateTime(2026, 8);
    await budgets.setMonthlyBudget(
      categoryId: 'category-food',
      month: month,
      limitMinor: 100000,
    );
    await budgets.setMonthlyBudget(
      categoryId: 'category-food',
      month: month,
      limitMinor: 150000,
    );
    final rows = await database.select(database.budgets).get();
    expect(rows, hasLength(1));
    expect(rows.single.limitMinor, 150000);
  });

  test('rejects income categories and zero limits', () async {
    expect(
      () => budgets.setMonthlyBudget(
        categoryId: 'category-salary',
        month: DateTime(2026, 8),
        limitMinor: 1000,
      ),
      throwsArgumentError,
    );
    expect(
      () => budgets.setMonthlyBudget(
        categoryId: 'category-food',
        month: DateTime(2026, 8),
        limitMinor: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects an archived expense category', () async {
    await ManagementRepository(database).archiveCategory('category-food');

    expect(
      () => budgets.setMonthlyBudget(
        categoryId: 'category-food',
        month: DateTime(2026, 8),
        limitMinor: 1000,
      ),
      throwsArgumentError,
    );
  });
}

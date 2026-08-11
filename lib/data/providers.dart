import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/period/expense_period.dart';
import 'database/app_database.dart';
import 'database/seed_data.dart';
import 'ledger_repository.dart';
import 'management_repository.dart';
import 'budget_repository.dart';
import 'backup_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(databaseProvider)),
);

final managementRepositoryProvider = Provider<ManagementRepository>(
  (ref) => ManagementRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(databaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

final backupListProvider = FutureProvider<List<BackupInfo>>((ref) async {
  return ref.watch(backupServiceProvider).listJsonBackups();
});

final selectedBudgetMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final budgetProgressProvider = FutureProvider<List<BudgetProgress>>((
  ref,
) async {
  await ref.watch(seedProvider.future);
  return ref
      .watch(databaseProvider)
      .budgetProgressForMonth(ref.watch(selectedBudgetMonthProvider));
});

final homeBudgetProgressProvider = FutureProvider<List<BudgetProgress>>((
  ref,
) async {
  await ref.watch(seedProvider.future);
  final now = DateTime.now();
  return ref
      .watch(databaseProvider)
      .budgetProgressForMonth(DateTime(now.year, now.month));
});

final expenseReportProvider = FutureProvider<ExpenseReport>((ref) async {
  await ref.watch(seedProvider.future);
  return ref
      .watch(databaseProvider)
      .expenseReport(ref.watch(selectedPeriodProvider));
});

final seedProvider = FutureProvider<void>((ref) async {
  await seedDatabase(ref.watch(databaseProvider));
});

final selectedPeriodKindProvider = StateProvider<ExpensePeriodKind>(
  (ref) => ExpensePeriodKind.month,
);

final selectedPeriodProvider = Provider<ExpensePeriod>((ref) {
  final now = DateTime.now();
  return switch (ref.watch(selectedPeriodKindProvider)) {
    ExpensePeriodKind.day => ExpensePeriod.day(now),
    ExpensePeriodKind.week => ExpensePeriod.week(now),
    ExpensePeriodKind.month => ExpensePeriod.month(now),
    ExpensePeriodKind.year => ExpensePeriod.year(now),
    ExpensePeriodKind.custom => ExpensePeriod.month(now),
  };
});

final totalsProvider = FutureProvider<PeriodTotals>((ref) async {
  await ref.watch(seedProvider.future);
  return ref
      .watch(databaseProvider)
      .totalsFor(ref.watch(selectedPeriodProvider));
});

final accountBalancesProvider = FutureProvider<List<AccountBalanceSummary>>((
  ref,
) async {
  await ref.watch(seedProvider.future);
  return ref.watch(databaseProvider).accountBalances();
});

final transactionEntriesProvider = StreamProvider<List<TransactionEntry>>((
  ref,
) async* {
  await ref.watch(seedProvider.future);
  yield* ref
      .watch(databaseProvider)
      .watchTransactionEntries(ref.watch(selectedPeriodProvider));
});

final accountsProvider = StreamProvider<List<Account>>((ref) async* {
  await ref.watch(seedProvider.future);
  yield* ref.watch(databaseProvider).watchActiveAccounts();
});

final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  await ref.watch(seedProvider.future);
  yield* ref.watch(databaseProvider).watchActiveCategories('expense');
});

final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  await ref.watch(seedProvider.future);
  yield* ref.watch(databaseProvider).watchActiveCategories('income');
});

final allCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  await ref.watch(seedProvider.future);
  yield* ref.watch(databaseProvider).watchAllActiveCategories();
});

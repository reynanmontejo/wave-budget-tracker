import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/period/expense_period.dart';
import '../core/dashboard/dashboard_metrics.dart';
import '../core/theme/appearance_preferences.dart';
import 'database/app_database.dart';
import 'database/seed_data.dart';
import 'ledger_repository.dart';
import 'management_repository.dart';
import 'budget_repository.dart';
import 'backup_service.dart';
import 'onboarding_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(databaseProvider)),
);

final onboardingCompleteProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isComplete();
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

final selectedCustomPeriodProvider = StateProvider<ExpensePeriod?>(
  (ref) => null,
);
final balancesVisibleProvider =
    StateNotifierProvider<BalanceVisibilityController, bool>(
      (ref) => BalanceVisibilityController(ref.watch(databaseProvider)),
    );

final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppearancePreferences>(
      (ref) => AppearanceController(ref.watch(databaseProvider)),
    );

final class AppearanceController extends StateNotifier<AppearancePreferences> {
  AppearanceController(this.database) : super(const AppearancePreferences()) {
    _load();
  }

  static const themeKey = 'appearance_theme';
  static const motionKey = 'gentle_motion';
  final AppDatabase database;

  Future<void> _load() async {
    final storedTheme = await database.preference(themeKey);
    final theme = WaveThemeChoice.values
        .where((item) => item.name == storedTheme)
        .firstOrNull;
    final motion = await database.preference(motionKey);
    state = AppearancePreferences(
      theme: theme ?? WaveThemeChoice.oceanLight,
      gentleMotion: motion != 'false',
    );
  }

  Future<void> setTheme(WaveThemeChoice theme) async {
    state = state.copyWith(theme: theme);
    await database.setPreference(themeKey, theme.name);
  }

  Future<void> setGentleMotion(bool enabled) async {
    state = state.copyWith(gentleMotion: enabled);
    await database.setPreference(motionKey, enabled.toString());
  }
}

final class BalanceVisibilityController extends StateNotifier<bool> {
  BalanceVisibilityController(this.database) : super(true) {
    _load();
  }

  static const preferenceKey = 'balances_visible';
  final AppDatabase database;

  Future<void> _load() async {
    state = await database.preference(preferenceKey) != 'false';
  }

  Future<void> toggle() async {
    state = !state;
    await database.setPreference(preferenceKey, state.toString());
  }
}

final selectedPeriodProvider = Provider<ExpensePeriod>((ref) {
  final now = DateTime.now();
  return switch (ref.watch(selectedPeriodKindProvider)) {
    ExpensePeriodKind.day => ExpensePeriod.day(now),
    ExpensePeriodKind.week => ExpensePeriod.week(now),
    ExpensePeriodKind.month => ExpensePeriod.month(now),
    ExpensePeriodKind.year => ExpensePeriod.year(now),
    ExpensePeriodKind.custom =>
      ref.watch(selectedCustomPeriodProvider) ?? ExpensePeriod.month(now),
  };
});

final totalsProvider = FutureProvider<PeriodTotals>((ref) async {
  await ref.watch(seedProvider.future);
  return ref
      .watch(databaseProvider)
      .totalsFor(ref.watch(selectedPeriodProvider));
});

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  await ref.watch(seedProvider.future);
  final database = ref.watch(databaseProvider);
  final period = ref.watch(selectedPeriodProvider);
  final current = await database.totalsFor(period);
  final previous = await database.totalsFor(period.previous);
  return DashboardMetrics.calculate(
    current: current,
    previous: previous,
    period: period,
  );
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

final activityTypeFilterProvider = StateProvider<String?>((ref) => null);
final activityAccountFilterProvider = StateProvider<String?>((ref) => null);
final activityCategoryFilterProvider = StateProvider<String?>((ref) => null);
final activitySearchProvider = StateProvider<String>((ref) => '');

final activityEntriesProvider = StreamProvider<List<ActivityEntry>>((
  ref,
) async* {
  await ref.watch(seedProvider.future);
  final type = ref.watch(activityTypeFilterProvider);
  final account = ref.watch(activityAccountFilterProvider);
  final category = ref.watch(activityCategoryFilterProvider);
  final search = ref.watch(activitySearchProvider).trim().toLowerCase();
  yield* ref
      .watch(databaseProvider)
      .watchActivityEntries(ref.watch(selectedPeriodProvider))
      .map(
        (items) => items.where((item) {
          if (type != null && item.kind != type) return false;
          if (account != null &&
              item.accountId != account &&
              item.destinationAccountId != account) {
            return false;
          }
          if (category != null && item.categoryId != category) return false;
          if (search.isNotEmpty) {
            final haystack =
                '${item.title} ${item.accountName} ${item.destinationName ?? ''} ${item.note ?? ''} ${item.amountMinor} ${(item.amountMinor / 100).toStringAsFixed(2)}'
                    .toLowerCase();
            if (!haystack.contains(search)) return false;
          }
          return true;
        }).toList(),
      );
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

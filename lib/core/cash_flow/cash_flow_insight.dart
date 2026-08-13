import '../../data/database/app_database.dart';
import '../../data/schedule_repository.dart';
import '../../data/savings_repository.dart';

final class CashFlowInsight {
  const CashFlowInsight({
    required this.availableBalanceMinor,
    required this.actual,
    required this.forecast,
    required this.protectedSavingsMinor,
  });

  factory CashFlowInsight.calculate({
    required List<AccountBalanceSummary> balances,
    required PeriodTotals actual,
    required ScheduleForecast forecast,
    required List<SavingsGoalProgress> goals,
  }) => CashFlowInsight(
    availableBalanceMinor: balances.fold(
      0,
      (sum, item) => sum + item.balanceMinor,
    ),
    actual: actual,
    forecast: forecast,
    protectedSavingsMinor: goals
        .where((item) => item.goal.status == SavingsGoalStatus.active.name)
        .fold(0, (sum, item) => sum + item.savedMinor),
  );

  final int availableBalanceMinor;
  final PeriodTotals actual;
  final ScheduleForecast forecast;
  final int protectedSavingsMinor;

  int get safeToSpendMinor =>
      availableBalanceMinor - forecast.expenseMinor - protectedSavingsMinor;

  int get projectedBalanceMinor =>
      availableBalanceMinor + forecast.incomeMinor - forecast.expenseMinor;

  bool get isAtRisk => safeToSpendMinor < 0;
}

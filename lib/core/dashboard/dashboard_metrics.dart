import '../../data/database/app_database.dart';
import '../period/expense_period.dart';

final class DashboardMetrics {
  const DashboardMetrics({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.previousExpenseMinor,
    required this.averageExpenseMinor,
    required this.elapsedDays,
  });

  factory DashboardMetrics.calculate({
    required PeriodTotals current,
    required PeriodTotals previous,
    required ExpensePeriod period,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final totalDays = period.endExclusive
        .difference(period.startInclusive)
        .inDays;
    final elapsedDays = normalizedToday.isBefore(period.startInclusive)
        ? 1
        : normalizedToday.isBefore(period.endExclusive)
        ? normalizedToday.difference(period.startInclusive).inDays + 1
        : totalDays;
    final safeElapsedDays = elapsedDays.clamp(1, totalDays);

    return DashboardMetrics(
      incomeMinor: current.incomeMinor,
      expenseMinor: current.expenseMinor,
      previousExpenseMinor: previous.expenseMinor,
      averageExpenseMinor: current.expenseMinor ~/ safeElapsedDays,
      elapsedDays: safeElapsedDays,
    );
  }

  final int incomeMinor;
  final int expenseMinor;
  final int previousExpenseMinor;
  final int averageExpenseMinor;
  final int elapsedDays;

  int get netSavedMinor => incomeMinor - expenseMinor;

  double get savingsRate => incomeMinor <= 0
      ? 0
      : (netSavedMinor.clamp(0, incomeMinor) / incomeMinor);

  double? get expenseChange {
    if (previousExpenseMinor == 0) {
      return expenseMinor == 0 ? 0 : null;
    }
    return (expenseMinor - previousExpenseMinor) / previousExpenseMinor;
  }
}

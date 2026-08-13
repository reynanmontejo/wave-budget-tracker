import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/dashboard/dashboard_metrics.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';

void main() {
  test('calculates net saved, savings rate, and elapsed-day average', () {
    final metrics = DashboardMetrics.calculate(
      current: const PeriodTotals(incomeMinor: 100000, expenseMinor: 40000),
      previous: const PeriodTotals(incomeMinor: 0, expenseMinor: 50000),
      period: ExpensePeriod.month(DateTime(2026, 8)),
      now: DateTime(2026, 8, 10, 18),
    );

    expect(metrics.netSavedMinor, 60000);
    expect(metrics.savingsRate, .6);
    expect(metrics.elapsedDays, 10);
    expect(metrics.averageExpenseMinor, 4000);
    expect(metrics.expenseChange, -.2);
  });

  test('uses the full duration for a completed historical period', () {
    final metrics = DashboardMetrics.calculate(
      current: const PeriodTotals(incomeMinor: 0, expenseMinor: 31000),
      previous: const PeriodTotals(incomeMinor: 0, expenseMinor: 0),
      period: ExpensePeriod.month(DateTime(2026, 7)),
      now: DateTime(2026, 8, 10),
    );

    expect(metrics.elapsedDays, 31);
    expect(metrics.averageExpenseMinor, 1000);
    expect(metrics.savingsRate, 0);
    expect(metrics.expenseChange, isNull);
  });
}

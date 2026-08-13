import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(expenseReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          const _PeriodSelector(),
          const SizedBox(height: 16),
          report.when(
            loading: () => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to build this report. Your data was not changed.',
                ),
              ),
            ),
            data: (value) => _ReportBody(report: value),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodKindProvider);
    final period = ref.watch(selectedPeriodProvider);
    return DropdownButtonFormField<ExpensePeriodKind>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Report period',
        prefixIcon: Icon(Icons.date_range_outlined),
      ),
      items: ExpensePeriodKind.values
          .map(
            (kind) => DropdownMenuItem(
              value: kind,
              child: Text(switch (kind) {
                ExpensePeriodKind.day => 'Today',
                ExpensePeriodKind.week => 'This week',
                ExpensePeriodKind.month => 'This month',
                ExpensePeriodKind.year => 'This year',
                ExpensePeriodKind.custom => 'Custom range',
              }),
            ),
          )
          .toList(),
      onChanged: (value) async {
        if (value == null) return;
        if (value != ExpensePeriodKind.custom) {
          ref.read(selectedPeriodKindProvider.notifier).state = value;
          return;
        }
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDateRange: DateTimeRange(
            start: period.startInclusive,
            end: period.endExclusive.subtract(const Duration(days: 1)),
          ),
        );
        if (range == null) return;
        ref.read(selectedCustomPeriodProvider.notifier).state =
            ExpensePeriod.custom(range.start, range.end);
        ref.read(selectedPeriodKindProvider.notifier).state =
            ExpensePeriodKind.custom;
      },
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final ExpenseReport report;

  @override
  Widget build(BuildContext context) {
    final change = report.expenseChange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Expenses',
                value: Money(report.totals.expenseMinor).format(),
                color: WaveColors.expense,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Income',
                value: Money(report.totals.incomeMinor).format(),
                color: WaveColors.income,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  change > 0
                      ? Icons.trending_up_rounded
                      : change < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
                  color: change > 0 ? WaveColors.expense : WaveColors.income,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${(change.abs() * 100).round()}% ${change > 0
                        ? 'more'
                        : change < 0
                        ? 'less'
                        : 'change'} than the previous period',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${report.transactionCount} entries',
                  style: const TextStyle(color: WaveColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Spending trend',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: _TrendChart(points: report.trend),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'By category',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (report.categories.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No expenses in this period.')),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final category in report.categories)
                    _CategoryRow(
                      category: category,
                      total: report.totals.expenseMinor,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: WaveColors.muted)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<SpendingTrendPoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('No spending to chart.')),
      );
    }
    return SizedBox(
      height: 170,
      child: CustomPaint(
        painter: _BarChartPainter(points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.points);
  final List<SpendingTrendPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points
        .map((item) => item.amountMinor)
        .reduce(math.max)
        .toDouble();
    final count = points.length;
    final slot = size.width / count;
    final paint = Paint()..color = WaveColors.primary;
    final labelStyle = const TextStyle(color: WaveColors.muted, fontSize: 9);
    for (var i = 0; i < count; i++) {
      final height = maxValue == 0
          ? 0.0
          : (points[i].amountMinor / maxValue) * (size.height - 28);
      final width = math.min(slot * .58, 24.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * slot + (slot - width) / 2,
          size.height - 22 - height,
          width,
          height,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, paint);
      if (count <= 12 || i.isEven) {
        final painter = TextPainter(
          text: TextSpan(text: points[i].label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: slot);
        painter.paint(
          canvas,
          Offset(i * slot + (slot - painter.width) / 2, size.height - 16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.total});
  final CategorySpending category;
  final int total;
  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : category.amountMinor / total;
    final color = Color(category.colorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(Money(category.amountMinor).format()),
              const SizedBox(width: 8),
              Text(
                '${(fraction * 100).round()}%',
                style: const TextStyle(color: WaveColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: fraction,
            color: color,
            backgroundColor: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

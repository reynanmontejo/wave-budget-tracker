import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/cash_flow/cash_flow_insight.dart';
import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/providers.dart';
import '../../data/schedule_repository.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(cashFlowDaysProvider);
    final insight = ref.watch(cashFlowInsightProvider);
    final visible = ref.watch(balancesVisibleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cash flow')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashFlowInsightProvider);
          await ref.read(cashFlowInsightProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {days},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  ref.read(cashFlowDaysProvider.notifier).state = value.first,
            ),
            const SizedBox(height: 16),
            insight.when(
              loading: () => const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Unable to calculate your cash-flow estimate.'),
                ),
              ),
              data: (value) =>
                  _CashFlowBody(insight: value, visible: visible, days: days),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowBody extends StatelessWidget {
  const _CashFlowBody({
    required this.insight,
    required this.visible,
    required this.days,
  });
  final CashFlowInsight insight;
  final bool visible;
  final int days;

  String money(int value) => visible ? Money(value).format() : '••••';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: insight.isAtRisk
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  insight.isAtRisk
                      ? Icons.warning_amber_rounded
                      : Icons.water_drop_outlined,
                ),
                const SizedBox(width: 8),
                const Text('Estimated safe to spend'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              money(insight.safeToSpendMinor),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              insight.isAtRisk
                  ? 'Planned expenses and protected savings exceed your available balance.'
                  : 'After planned expenses and protected savings for the next $days days.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _ValueCard(
              label: 'Available now',
              value: money(insight.availableBalanceMinor),
              color: WaveColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ValueCard(
              label: 'Projected balance',
              value: money(insight.projectedBalanceMinor),
              color: insight.projectedBalanceMinor < 0
                  ? WaveColors.expense
                  : WaveColors.savings,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _Heading('Actual activity · previous $days days'),
      const SizedBox(height: 10),
      _ComparisonCard(
        income: insight.actual.incomeMinor,
        expense: insight.actual.expenseMinor,
        visible: visible,
        forecast: false,
      ),
      const SizedBox(height: 24),
      _Heading('Forecast activity · next $days days'),
      const SizedBox(height: 10),
      _ComparisonCard(
        income: insight.forecast.incomeMinor,
        expense: insight.forecast.expenseMinor,
        visible: visible,
        forecast: true,
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(
            Icons.savings_outlined,
            color: WaveColors.savings,
          ),
          title: const Text('Protected savings allocations'),
          subtitle: const Text(
            'Active goal contributions kept outside safe-to-spend.',
          ),
          trailing: Text(
            money(insight.protectedSavingsMinor),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const _Heading('Upcoming timeline'),
      const SizedBox(height: 10),
      if (insight.forecast.occurrences.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No upcoming income or expenses in this window.'),
          ),
        )
      else
        Card(
          child: Column(
            children: [
              for (final occurrence in insight.forecast.occurrences)
                _OccurrenceTile(occurrence: occurrence, visible: visible),
            ],
          ),
        ),
      const SizedBox(height: 18),
      Text(
        'Safe to Spend is an estimate based on the information entered in Wave. It is not financial advice and does not reserve or move money.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.income,
    required this.expense,
    required this.visible,
    required this.forecast,
  });
  final int income;
  final int expense;
  final bool visible;
  final bool forecast;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _FlowValue(
              label: forecast ? 'Expected income' : 'Recorded income',
              amount: income,
              color: WaveColors.income,
              visible: visible,
            ),
          ),
          Expanded(
            child: _FlowValue(
              label: forecast ? 'Planned expenses' : 'Recorded expenses',
              amount: expense,
              color: WaveColors.expense,
              visible: visible,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FlowValue extends StatelessWidget {
  const _FlowValue({
    required this.label,
    required this.amount,
    required this.color,
    required this.visible,
  });
  final String label;
  final int amount;
  final Color color;
  final bool visible;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      FittedBox(
        child: Text(
          visible ? Money(amount).format() : '••••',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence, required this.visible});
  final ScheduleForecastOccurrence occurrence;
  final bool visible;
  @override
  Widget build(BuildContext context) {
    final income = occurrence.schedule.type == 'income';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (income ? WaveColors.income : WaveColors.expense)
            .withValues(alpha: .12),
        child: Icon(
          income ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: income ? WaveColors.income : WaveColors.expense,
        ),
      ),
      title: Text(
        occurrence.schedule.note ??
            (income ? 'Upcoming income' : 'Planned expense'),
      ),
      subtitle: Text(DateFormat.yMMMd().format(occurrence.dueAt)),
      trailing: Text(
        visible ? Money(occurrence.schedule.amountMinor).format() : '••••',
        style: TextStyle(
          color: income ? WaveColors.income : WaveColors.expense,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

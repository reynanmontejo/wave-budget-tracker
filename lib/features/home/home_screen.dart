import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../transactions/add_transaction_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider);
    final balances = ref.watch(accountBalancesProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(totalsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            _BalanceCard(
              totals: totals,
              balances: balances,
              visible: ref.watch(balancesVisibleProvider),
            ),
            const SizedBox(height: 16),
            const _PeriodSelector(),
            const SizedBox(height: 24),
            Text(
              'Quick actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _QuickActions(),
            const SizedBox(height: 24),
            Text(
              'Budget preview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _BudgetPreview(),
            const SizedBox(height: 24),
            Text(
              'Recent activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balancesVisibleProvider);
    return Row(
      children: [
        const Icon(Icons.waves_rounded, color: WaveColors.primary, size: 32),
        const SizedBox(width: 10),
        Text(
          'Wave',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: WaveColors.primaryStrong,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => ref.read(balancesVisibleProvider.notifier).toggle(),
          tooltip: visible ? 'Hide balances' : 'Show balances',
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.totals,
    required this.balances,
    required this.visible,
  });
  final AsyncValue<PeriodTotals> totals;
  final AsyncValue<List<AccountBalanceSummary>> balances;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: WaveColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: totals.when(
        loading: () => const SizedBox(
          height: 118,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (error, _) => const SizedBox(
          height: 118,
          child: Center(
            child: Text(
              'Unable to load totals',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total balance',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            balances.when(
              loading: () => const Text(
                '—',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              error: (_, _) => const Text(
                'Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              data: (items) => Text(
                visible
                    ? Money(
                        items.fold<int>(
                          0,
                          (total, item) => total + item.balanceMinor,
                        ),
                      ).format()
                    : '••••••',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Income',
                    amount: visible
                        ? Money(value.incomeMinor).format()
                        : '••••',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Metric(
                    label: 'Expenses',
                    amount: visible
                        ? Money(value.expenseMinor).format()
                        : '••••',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.amount});
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        amount,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodKindProvider);
    const options = <(ExpensePeriodKind, String)>[
      (ExpensePeriodKind.day, 'Today'),
      (ExpensePeriodKind.week, 'Week'),
      (ExpensePeriodKind.month, 'Month'),
      (ExpensePeriodKind.year, 'Year'),
    ];
    return SegmentedButton<ExpensePeriodKind>(
      segments: [
        for (final option in options)
          ButtonSegment(value: option.$1, label: Text(option.$2)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (value) =>
          ref.read(selectedPeriodKindProvider.notifier).state = value.first,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Action(
          icon: Icons.remove_rounded,
          label: 'Expense',
          color: WaveColors.expense,
          onTap: () => _openEntry(context, EntryMode.expense),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Action(
          icon: Icons.add_rounded,
          label: 'Income',
          color: WaveColors.income,
          onTap: () => _openEntry(context, EntryMode.income),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Action(
          icon: Icons.swap_horiz_rounded,
          label: 'Transfer',
          color: WaveColors.primary,
          onTap: () => _openEntry(context, EntryMode.transfer),
        ),
      ),
    ],
  );

  Future<void> _openEntry(BuildContext context, EntryMode mode) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionSheet(initialMode: mode),
      );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: WaveColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: WaveColors.primaryStrong),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: WaveColors.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BudgetPreview extends ConsumerWidget {
  const _BudgetPreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(homeBudgetProgressProvider);
    return budgets.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const _EmptyCard(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Budget preview unavailable',
        message: 'Your budget data was not changed.',
      ),
      data: (items) => items.isEmpty
          ? const _EmptyCard(
              icon: Icons.pie_chart_outline_rounded,
              title: 'No budgets yet',
              message: 'Set a monthly limit to see your progress here.',
            )
          : Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in items.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.categoryName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${Money(item.spentMinor).format()} / ${Money(item.budget.limitMinor).format()}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              value: item.fraction.clamp(0, 1),
                              borderRadius: BorderRadius.circular(6),
                              color: item.fraction >= 1
                                  ? WaveColors.expense
                                  : item.fraction >= .75
                                  ? WaveColors.warning
                                  : WaveColors.primary,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(transactionEntriesProvider);
    return entries.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const _EmptyCard(
        icon: Icons.receipt_long_outlined,
        title: 'Activity unavailable',
        message: 'Your transaction data was not changed.',
      ),
      data: (items) => items.isEmpty
          ? const _EmptyCard(
              icon: Icons.waves_rounded,
              title: 'Ready for your first entry',
              message: 'Tap Add to record an expense, income, or transfer.',
            )
          : Card(
              child: Column(
                children: [
                  for (final item in items.take(4))
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            (item.transaction.type == 'income'
                                    ? WaveColors.income
                                    : WaveColors.expense)
                                .withValues(alpha: .12),
                        foregroundColor: item.transaction.type == 'income'
                            ? WaveColors.income
                            : WaveColors.expense,
                        child: Icon(
                          item.transaction.type == 'income'
                              ? Icons.add_rounded
                              : Icons.remove_rounded,
                        ),
                      ),
                      title: Text(
                        item.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.accountName),
                      trailing: Text(
                        '${item.transaction.type == 'income' ? '+' : '-'}${Money(item.transaction.amountMinor).format()}',
                        style: TextStyle(
                          color: item.transaction.type == 'income'
                              ? WaveColors.income
                              : WaveColors.expense,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

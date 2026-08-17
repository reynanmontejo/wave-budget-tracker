import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_page_route.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../budgets/budgets_screen.dart';
import '../more/more_screen.dart';
import '../planned/planned_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(totalsProvider);
          ref.invalidate(accountBalancesProvider);
          ref.invalidate(homeBudgetProgressProvider);
          ref.invalidate(recentActivityProvider);
          await Future.wait([
            ref.read(totalsProvider.future),
            ref.read(accountBalancesProvider.future),
            ref.read(homeBudgetProgressProvider.future),
            ref.read(recentActivityProvider.future),
          ]);
        },
        child: ListView(
          key: const PageStorageKey('light-home'),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const _HomeHeader(),
            const SizedBox(height: 14),
            const _BalanceHero(),
            const SizedBox(height: 12),
            const _PeriodSummary(),
            const _PriorityAlert(),
            const SizedBox(height: 20),
            const _SectionTitle('Recent activity'),
            const SizedBox(height: 10),
            const _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balancesVisibleProvider);
    final motionEnabled =
        ref.watch(
          appearanceProvider.select((preferences) => preferences.gentleMotion),
        ) &&
        !MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.waves_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wave',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ref.read(balancesVisibleProvider.notifier).toggle(),
          tooltip: visible ? 'Hide balances' : 'Show balances',
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            WavePageRoute<void>(
              motionEnabled: motionEnabled,
              builder: (_) => const MoreScreen(),
            ),
          ),
          tooltip: 'Accounts and settings',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _BalanceHero extends ConsumerWidget {
  const _BalanceHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    final visible = ref.watch(balancesVisibleProvider);
    return Container(
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WaveColors.primaryStrong, WaveColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: balances.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (_, _) => const Center(
          child: Text(
            'Unable to load your balance.',
            style: TextStyle(color: Colors.white),
          ),
        ),
        data: (items) {
          final total = items.fold<int>(
            0,
            (sum, item) => sum + item.balanceMinor,
          );
          final formatted = visible ? Money(total).format() : 'hidden';
          return Semantics(
            container: true,
            label:
                'Total balance $formatted, across ${items.length} active ${items.length == 1 ? 'account' : 'accounts'}',
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _QuietWavePainter()),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL BALANCE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          visible ? Money(total).format() : '••••••',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${items.length} active ${items.length == 1 ? 'account' : 'accounts'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuietWavePainter extends CustomPainter {
  const _QuietWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height * .72)
      ..quadraticBezierTo(
        size.width * .25,
        size.height * .58,
        size.width * .52,
        size.height * .72,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .85,
        size.width,
        size.height * .66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = Colors.white.withValues(alpha: .09));

    final front = Path()
      ..moveTo(0, size.height * .82)
      ..quadraticBezierTo(
        size.width * .32,
        size.height * .69,
        size.width * .62,
        size.height * .83,
      )
      ..quadraticBezierTo(
        size.width * .84,
        size.height * .91,
        size.width,
        size.height * .78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      front,
      Paint()..color = Colors.white.withValues(alpha: .08),
    );
  }

  @override
  bool shouldRepaint(covariant _QuietWavePainter oldDelegate) => false;
}

class _PeriodSummary extends ConsumerWidget {
  const _PeriodSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodKindProvider);
    final period = ref.watch(selectedPeriodProvider);
    final totals = ref.watch(totalsProvider);
    final visible = ref.watch(balancesVisibleProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _periodLabel(selected, period),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<ExpensePeriodKind>(
                  tooltip: 'Change summary period',
                  icon: const Icon(Icons.calendar_month_outlined),
                  initialValue: selected,
                  onSelected: (kind) =>
                      _selectPeriod(context, ref, kind, period),
                  itemBuilder: (_) => ExpensePeriodKind.values
                      .map(
                        (kind) => PopupMenuItem(
                          value: kind,
                          child: Text(_menuLabel(kind)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const Divider(height: 12),
            totals.when(
              loading: () => const SizedBox(
                height: 58,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(
                height: 58,
                child: Center(
                  child: Text('Summary unavailable. Pull to retry.'),
                ),
              ),
              data: (value) => _SummaryValues(totals: value, visible: visible),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPeriod(
    BuildContext context,
    WidgetRef ref,
    ExpensePeriodKind kind,
    ExpensePeriod period,
  ) async {
    if (kind != ExpensePeriodKind.custom) {
      ref.read(selectedPeriodKindProvider.notifier).state = kind;
      return;
    }
    final today = DateTime.now();
    final initialStart = period.startInclusive.isAfter(today)
        ? DateTime(today.year, today.month)
        : period.startInclusive;
    final requestedEnd = period.endExclusive.subtract(const Duration(days: 1));
    final initialEnd = requestedEnd.isAfter(today) ? today : requestedEnd;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (range == null) return;
    ref.read(selectedCustomPeriodProvider.notifier).state =
        ExpensePeriod.custom(range.start, range.end);
    ref.read(selectedPeriodKindProvider.notifier).state =
        ExpensePeriodKind.custom;
  }

  static String _periodLabel(
    ExpensePeriodKind kind,
    ExpensePeriod period,
  ) => switch (kind) {
    ExpensePeriodKind.day => 'Today',
    ExpensePeriodKind.week => 'This week',
    ExpensePeriodKind.month => 'This month',
    ExpensePeriodKind.year => 'This year',
    ExpensePeriodKind.custom =>
      '${DateFormat.MMMd().format(period.startInclusive)} – ${DateFormat.MMMd().format(period.endExclusive.subtract(const Duration(days: 1)))}',
  };

  static String _menuLabel(ExpensePeriodKind kind) => switch (kind) {
    ExpensePeriodKind.day => 'Today',
    ExpensePeriodKind.week => 'This week',
    ExpensePeriodKind.month => 'This month',
    ExpensePeriodKind.year => 'This year',
    ExpensePeriodKind.custom => 'Custom range',
  };
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.label,
    required this.amount,
    required this.visible,
    required this.color,
  });

  final String label;
  final int amount;
  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatted = visible ? Money(amount).format() : 'hidden';
    return Semantics(
      container: true,
      label: '$label: $formatted',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  visible ? Money(amount).format() : '••••',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValues extends StatelessWidget {
  const _SummaryValues({required this.totals, required this.visible});

  final PeriodTotals totals;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 21;
    final values = [
      _SummaryAmount(
        label: 'Income',
        amount: totals.incomeMinor,
        visible: visible,
        color: WaveColors.income,
      ),
      _SummaryAmount(
        label: 'Expenses',
        amount: totals.expenseMinor,
        visible: visible,
        color: WaveColors.expense,
      ),
      _SummaryAmount(
        label: 'Net',
        amount: totals.netMinor,
        visible: visible,
        color: totals.netMinor >= 0 ? WaveColors.savings : WaveColors.expense,
      ),
    ];
    if (largeText) {
      return Column(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            SizedBox(width: double.infinity, child: values[index]),
            if (index != values.length - 1) const Divider(height: 8),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: values[0]),
        const _SummaryDivider(),
        Expanded(child: values[1]),
        const _SummaryDivider(),
        Expanded(child: values[2]),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: Theme.of(context).dividerColor);
}

class _PriorityAlert extends ConsumerWidget {
  const _PriorityAlert();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(scheduledTransactionsProvider);
    final budgets = ref.watch(homeBudgetProgressProvider);
    final visible = ref.watch(balancesVisibleProvider);
    final motionEnabled =
        ref.watch(
          appearanceProvider.select((preferences) => preferences.gentleMotion),
        ) &&
        !MediaQuery.disableAnimationsOf(context);
    return schedules.when(
      data: (items) {
        final alert = _scheduledAlert(items, visible);
        return alert == null
            ? _budgetAlert(budgets, motionEnabled)
            : _HomeAlertTile(
                alert: alert,
                onTap: () => Navigator.push(
                  context,
                  WavePageRoute<void>(
                    motionEnabled: motionEnabled,
                    builder: (_) => const PlannedScreen(),
                  ),
                ),
              );
      },
      loading: () => _budgetAlert(budgets, motionEnabled),
      error: (_, _) => _budgetAlert(budgets, motionEnabled),
    );
  }

  _HomeAlert? _scheduledAlert(List<ScheduledTransaction> items, bool visible) {
    final today = DateUtils.dateOnly(DateTime.now());
    final limit = today.add(const Duration(days: 3));
    final relevant =
        items
            .where((item) => item.status == 'active')
            .where((item) => !DateUtils.dateOnly(item.nextDueAt).isAfter(limit))
            .toList()
          ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    if (relevant.isEmpty) return null;

    final item = relevant.first;
    final due = DateUtils.dateOnly(item.nextDueAt);
    final days = due.difference(today).inDays;
    final overdue = days < 0;
    final income = item.type == 'income';
    final kind = income ? 'income' : 'expense';
    final amount = visible ? Money(item.amountMinor).format() : '••••';
    final dueLabel = overdue
        ? 'was due ${DateFormat.MMMd().format(due)}'
        : days == 0
        ? 'is due today'
        : days == 1
        ? 'is due tomorrow'
        : 'is due ${DateFormat.MMMd().format(due)}';
    return _HomeAlert(
      title: overdue
          ? 'Planned $kind overdue'
          : days == 0
          ? 'Planned $kind due today'
          : 'Upcoming planned $kind',
      message: '$amount $dueLabel.',
      icon: overdue
          ? Icons.event_busy_outlined
          : income
          ? Icons.payments_outlined
          : Icons.receipt_long_outlined,
      color: overdue
          ? WaveColors.expense
          : income
          ? WaveColors.income
          : WaveColors.warning,
    );
  }

  Widget _budgetAlert(
    AsyncValue<List<BudgetProgress>> budgets,
    bool motionEnabled,
  ) => budgets.when(
    loading: () => const SizedBox.shrink(),
    error: (_, _) => const SizedBox.shrink(),
    data: (items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final sorted = [...items]
        ..sort((a, b) => b.fraction.compareTo(a.fraction));
      final focus = sorted.first;
      if (focus.fraction < .75) return const SizedBox.shrink();
      final over = focus.fraction >= 1;
      final color = over ? WaveColors.expense : WaveColors.warning;
      return Builder(
        builder: (context) => _HomeAlertTile(
          alert: _HomeAlert(
            title: over ? 'Budget exceeded' : 'Budget getting close',
            message:
                '${focus.categoryName} is ${(focus.fraction * 100).round()}% used.',
            icon: over ? Icons.error_outline_rounded : Icons.speed_rounded,
            color: color,
          ),
          onTap: () => Navigator.push(
            context,
            WavePageRoute<void>(
              motionEnabled: motionEnabled,
              builder: (_) => const BudgetsScreen(),
            ),
          ),
        ),
      );
    },
  );
}

class _HomeAlert {
  const _HomeAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class _HomeAlertTile extends StatelessWidget {
  const _HomeAlertTile({required this.alert, required this.onTap});

  final _HomeAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      button: true,
      excludeSemantics: true,
      label: '${alert.title}. ${alert.message}',
      child: Material(
        color: alert.color.withValues(alpha: .09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: alert.color.withValues(alpha: .28)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Icon(alert.icon, color: alert.color),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(alert.message),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
  );
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balancesVisibleProvider);
    return ref
        .watch(recentActivityProvider)
        .when(
          loading: () => const Card(
            child: SizedBox(
              height: 112,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Recent activity is unavailable. Pull to retry.'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: WaveColors.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap Add to record your first transaction.',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final recent = items.take(3).toList();
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < recent.length; index++) ...[
                    _ActivityRow(item: recent[index], visible: visible),
                    if (index != recent.length - 1)
                      const Divider(height: 1, indent: 64),
                  ],
                ],
              ),
            );
          },
        );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.visible});

  final ActivityEntry item;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.kind == 'income';
    final isTransfer = item.kind == 'transfer';
    final color = isTransfer
        ? WaveColors.primary
        : isIncome
        ? WaveColors.income
        : WaveColors.expense;
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : isIncome
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final account = isTransfer
        ? '${item.accountName} → ${item.destinationName ?? ''}'
        : item.accountName;
    final prefix = isTransfer ? '' : (isIncome ? '+' : '-');
    final semanticsAmount = visible
        ? '$prefix${Money(item.amountMinor).format()}'
        : 'amount hidden';
    final semanticsLabel = isTransfer
        ? 'Transfer, $account, $semanticsAmount'
        : '${isIncome ? 'Income' : 'Expense'}, ${item.title}, $account, $semanticsAmount';
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 21;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: .11),
      foregroundColor: color,
      child: Icon(icon, size: 18),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(account, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (largeText) ...[
          const SizedBox(height: 3),
          Text(
            visible ? '$prefix${Money(item.amountMinor).format()}' : '••••',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ],
    );
    if (largeText) {
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: semanticsLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 11),
              Expanded(child: details),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: avatar,
        title: details,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              visible ? '$prefix${Money(item.amountMinor).format()}' : '••••',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

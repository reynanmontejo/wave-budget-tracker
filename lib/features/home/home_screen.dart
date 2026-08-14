import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dashboard/dashboard_metrics.dart';
import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_theme.dart';
import '../../core/theme/wave_page_route.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../data/schedule_repository.dart';
import '../../data/savings_repository.dart';
import '../budgets/budgets_screen.dart';
import '../transactions/add_transaction_sheet.dart';
import '../more/more_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(accountBalancesProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final motionEnabled =
        ref.watch(appearanceProvider).gentleMotion &&
        !MediaQuery.disableAnimationsOf(context);
    if (motionEnabled && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!motionEnabled && _waveController.isAnimating) {
      _waveController.stop();
    }
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(totalsProvider);
          ref.invalidate(accountBalancesProvider);
          ref.invalidate(homeBudgetProgressProvider);
          ref.invalidate(transactionEntriesProvider);
          ref.invalidate(expenseReportProvider);
          ref.invalidate(dashboardMetricsProvider);
          await Future.wait([
            ref.read(totalsProvider.future),
            ref.read(accountBalancesProvider.future),
            ref.read(homeBudgetProgressProvider.future),
            ref.read(transactionEntriesProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            _BalanceCard(
              balances: balances,
              visible: ref.watch(balancesVisibleProvider),
              waveAnimation: motionEnabled ? _waveController : null,
            ),
            const SizedBox(height: 16),
            const _PeriodSelector(),
            const SizedBox(height: 16),
            _Reveal(
              animation: _revealController,
              enabled: motionEnabled,
              interval: const Interval(0, .65, curve: Curves.easeOutCubic),
              child: _FinancialHighlights(
                metrics: metrics,
                visible: ref.watch(balancesVisibleProvider),
              ),
            ),
            const SizedBox(height: 24),
            const _DashboardSectionHeader('Quick actions'),
            const SizedBox(height: 12),
            _Reveal(
              animation: _revealController,
              enabled: motionEnabled,
              interval: const Interval(.12, .76, curve: Curves.easeOutCubic),
              child: const _QuickActions(),
            ),
            const SizedBox(height: 24),
            const _DashboardSectionHeader('Coming up'),
            const SizedBox(height: 12),
            _UpcomingForecast(
              forecast: ref.watch(scheduleForecastProvider),
              visible: ref.watch(balancesVisibleProvider),
              days: ref.watch(forecastDaysProvider),
              onDaysChanged: (days) =>
                  ref.read(forecastDaysProvider.notifier).state = days,
            ),
            const SizedBox(height: 24),
            const _DashboardSectionHeader('One thing to watch'),
            const SizedBox(height: 12),
            _Reveal(
              animation: _revealController,
              enabled: motionEnabled,
              interval: const Interval(.24, .88, curve: Curves.easeOutCubic),
              child: const _BudgetInsight(),
            ),
            const SizedBox(height: 24),
            const _DashboardSectionHeader('Recent activity'),
            const SizedBox(height: 12),
            _Reveal(
              animation: _revealController,
              enabled: motionEnabled,
              interval: const Interval(.36, 1, curve: Curves.easeOutCubic),
              child: const _RecentActivity(),
            ),
          ],
        ),
      ),
    );
  }
}

// Retained as a small reusable preview for future dashboard customization.
// ignore: unused_element
class _SavingsGoalsPreview extends StatelessWidget {
  const _SavingsGoalsPreview({required this.goals, required this.visible});
  final AsyncValue<List<SavingsGoalProgress>> goals;
  final bool visible;

  @override
  Widget build(BuildContext context) => goals.when(
    loading: () => const SizedBox.shrink(),
    error: (_, _) => const SizedBox.shrink(),
    data: (items) {
      final active = items
          .where((item) => item.goal.status == SavingsGoalStatus.active.name)
          .toList();
      if (active.isEmpty) return const SizedBox.shrink();
      final saved = active.fold<int>(0, (sum, item) => sum + item.savedMinor);
      final target = active.fold<int>(
        0,
        (sum, item) => sum + item.goal.targetMinor,
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.savings_outlined, color: WaveColors.savings),
                  SizedBox(width: 8),
                  Text(
                    'Savings goals',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: target == 0 ? 0 : (saved / target).clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: WaveColors.savings,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visible
                          ? '${Money(saved).format()} allocated'
                          : '•••• allocated',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${active.length} active'),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _UpcomingForecast extends StatelessWidget {
  const _UpcomingForecast({
    required this.forecast,
    required this.visible,
    required this.days,
    required this.onDaysChanged,
  });

  final AsyncValue<ScheduleForecast> forecast;
  final bool visible;
  final int days;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) => forecast.when(
    loading: () => const SizedBox(
      height: 74,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => const SizedBox.shrink(),
    data: (value) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_outlined,
                  color: WaveColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next $days days',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                  ],
                  selected: {days},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) => onDaysChanged(value.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ForecastAmount(
                    label: 'Upcoming income',
                    amount: value.incomeMinor,
                    color: WaveColors.income,
                    visible: visible,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ForecastAmount(
                    label: 'Planned expenses',
                    amount: value.expenseMinor,
                    color: WaveColors.expense,
                    visible: visible,
                  ),
                ),
              ],
            ),
            if (value.items.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Nothing planned yet. Open Plan to add future income or expenses.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ForecastAmount extends StatelessWidget {
  const _ForecastAmount({
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
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          visible ? Money(amount).format() : '••••',
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(balancesVisibleProvider);
    final motionEnabled =
        ref.watch(appearanceProvider).gentleMotion &&
        !MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        Icon(
          Icons.waves_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        const SizedBox(width: 10),
        Text(
          'Wave',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balances,
    required this.visible,
    required this.waveAnimation,
  });
  final AsyncValue<List<AccountBalanceSummary>> balances;
  final bool visible;
  final Animation<double>? waveAnimation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: WaveColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: balances.when(
        loading: () => const SizedBox(
          height: 104,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (_, _) => const SizedBox(
          height: 104,
          child: Center(
            child: Text(
              'Unable to load balance',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        data: (items) => Stack(
          children: [
            Positioned.fill(
              child: waveAnimation == null
                  ? CustomPaint(painter: const _WavePainter())
                  : AnimatedBuilder(
                      animation: waveAnimation!,
                      builder: (_, _) => CustomPaint(
                        painter: _WavePainter(phase: waveAnimation!.value),
                      ),
                    ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Total balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  '${items.length} active ${items.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({this.phase = 0});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var layer = 0; layer < 3; layer++) {
      final baseline = size.height * (.68 + layer * .07);
      final path = Path()..moveTo(0, baseline);
      for (double x = 0; x <= size.width; x += 4) {
        path.lineTo(
          x,
          baseline +
              math.sin(
                    (x / size.width * math.pi * 2) +
                        layer +
                        phase * math.pi * 2,
                  ) *
                  (8 - layer * 2),
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: .12 - layer * .025),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.enabled,
    required this.interval,
    required this.child,
  });

  final AnimationController animation;
  final bool enabled;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final curved = CurvedAnimation(parent: animation, curve: interval);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
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
        labelText: 'Dashboard period',
        prefixIcon: Icon(Icons.date_range_outlined),
      ),
      items: ExpensePeriodKind.values
          .map(
            (kind) => DropdownMenuItem(
              value: kind,
              child: Text(
                kind == ExpensePeriodKind.custom
                    ? _customLabel(period)
                    : _periodLabel(kind),
              ),
            ),
          )
          .toList(),
      onChanged: (kind) async {
        if (kind == null) return;
        if (kind != ExpensePeriodKind.custom) {
          ref.read(selectedPeriodKindProvider.notifier).state = kind;
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

  static String _periodLabel(ExpensePeriodKind kind) => switch (kind) {
    ExpensePeriodKind.day => 'Today',
    ExpensePeriodKind.week => 'This week',
    ExpensePeriodKind.month => 'This month',
    ExpensePeriodKind.year => 'This year',
    ExpensePeriodKind.custom => 'Custom range',
  };

  static String _customLabel(ExpensePeriod period) {
    if (period.kind != ExpensePeriodKind.custom) return 'Custom range';
    final end = period.endExclusive.subtract(const Duration(days: 1));
    return '${DateFormat.MMMd().format(period.startInclusive)} – ${DateFormat.MMMd().format(end)}';
  }
}

class _FinancialHighlights extends StatelessWidget {
  const _FinancialHighlights({required this.metrics, required this.visible});

  final AsyncValue<DashboardMetrics> metrics;
  final bool visible;

  @override
  Widget build(BuildContext context) => metrics.when(
    loading: () => const SizedBox(
      height: 168,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => const _EmptyCard(
      icon: Icons.insights_outlined,
      title: 'Highlights unavailable',
      message: 'Pull down to try loading your summary again.',
    ),
    data: (value) {
      final comparison = value.expenseChange;
      final comparisonText = comparison == null
          ? 'No previous spending'
          : comparison == 0
          ? 'Same as previous period'
          : '${(comparison.abs() * 100).round()}% ${comparison < 0 ? 'less' : 'more'} spending';
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HighlightCard(
                  label: 'Income',
                  value: visible ? Money(value.incomeMinor).format() : '••••',
                  icon: Icons.trending_up_rounded,
                  color: WaveColors.income,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HighlightCard(
                  label: 'Expenses',
                  value: visible ? Money(value.expenseMinor).format() : '••••',
                  icon: Icons.trending_down_rounded,
                  color: WaveColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HighlightCard(
                  label: 'Net saved',
                  value: visible ? Money(value.netSavedMinor).format() : '••••',
                  icon: Icons.savings_outlined,
                  color: value.netSavedMinor >= 0
                      ? WaveColors.savings
                      : WaveColors.expense,
                  supporting:
                      '${(value.savingsRate * 100).round()}% savings rate',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HighlightCard(
                  label: 'Daily average',
                  value: visible
                      ? Money(value.averageExpenseMinor).format()
                      : '••••',
                  icon: Icons.calendar_today_outlined,
                  color: WaveColors.primary,
                  supporting: comparisonText,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.supporting,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? supporting;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
          if (supporting != null) ...[
            const SizedBox(height: 5),
            Text(
              supporting!,
              maxLines: 2,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    ),
  );
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
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
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BudgetInsight extends ConsumerWidget {
  const _BudgetInsight();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(homeBudgetProgressProvider);
    final motionEnabled =
        ref.watch(appearanceProvider).gentleMotion &&
        !MediaQuery.disableAnimationsOf(context);
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
      data: (items) {
        if (items.isEmpty) {
          return _DashboardInsightTile(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Create your first budget',
            message: 'Set one monthly limit to start tracking spending.',
            color: WaveColors.primary,
            onTap: () => _openBudgets(context, motionEnabled),
          );
        }
        final item = [...items]
          ..sort((a, b) => b.fraction.compareTo(a.fraction));
        final focus = item.first;
        final percent = (focus.fraction * 100).round();
        final color = focus.fraction >= 1
            ? WaveColors.expense
            : focus.fraction >= .75
            ? WaveColors.warning
            : WaveColors.primary;
        final status = focus.fraction >= 1
            ? 'over its monthly limit'
            : focus.fraction >= .75
            ? 'approaching its monthly limit'
            : 'currently on track';
        return _DashboardInsightTile(
          icon: Icons.pie_chart_rounded,
          title: '${focus.categoryName}: $percent% used',
          message: 'This budget is $status.',
          color: color,
          progress: focus.fraction.clamp(0, 1),
          motionEnabled: motionEnabled,
          onTap: () => _openBudgets(context, motionEnabled),
        );
      },
    );
  }

  void _openBudgets(BuildContext context, bool motionEnabled) {
    Navigator.push(
      context,
      WavePageRoute<void>(
        motionEnabled: motionEnabled,
        builder: (_) => const BudgetsScreen(),
      ),
    );
  }
}

class _DashboardInsightTile extends StatelessWidget {
  const _DashboardInsightTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.onTap,
    this.progress,
    this.motionEnabled = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final VoidCallback onTap;
  final double? progress;
  final bool motionEnabled;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .13),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: motionEnabled ? 0 : progress,
                        end: progress,
                      ),
                      duration: motionEnabled
                          ? const Duration(milliseconds: 500)
                          : Duration.zero,
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
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

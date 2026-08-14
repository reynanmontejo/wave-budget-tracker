import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/wave_theme.dart';
import '../../core/theme/wave_page_route.dart';
import '../../data/providers.dart';
import '../cash_flow/cash_flow_screen.dart';
import '../reports/reports_screen.dart';

class InsightsHubScreen extends ConsumerWidget {
  const InsightsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motionEnabled =
        ref.watch(appearanceProvider).gentleMotion &&
        !MediaQuery.disableAnimationsOf(context);
    void open(Widget screen) => Navigator.push(
      context,
      WavePageRoute<void>(motionEnabled: motionEnabled, builder: (_) => screen),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text(
            'Insights',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Understand past spending and prepare for future cash flow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: WaveColors.primaryContainer.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 34,
                  color: WaveColors.primaryStrong,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Actual records explain where you have been. Forecasts estimate what may come next.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InsightCard(
            icon: Icons.water_drop_outlined,
            title: 'Cash flow',
            subtitle: 'Upcoming timeline and estimated safe to spend',
            badge: 'FORECAST',
            onTap: () => open(const CashFlowScreen()),
          ),
          const SizedBox(height: 12),
          _InsightCard(
            icon: Icons.bar_chart_rounded,
            title: 'Reports',
            subtitle: 'Actual income, expenses, trends, and categories',
            badge: 'ACTUAL',
            onTap: () => open(const ReportsScreen()),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: WaveColors.primaryContainer,
              foregroundColor: WaveColors.primaryStrong,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: WaveColors.primaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: WaveColors.primaryStrong,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

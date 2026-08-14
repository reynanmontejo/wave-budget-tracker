import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/wave_theme.dart';
import '../../core/theme/wave_page_route.dart';
import '../../data/providers.dart';
import '../budgets/budgets_screen.dart';
import '../planned/planned_screen.dart';
import '../savings/savings_goals_screen.dart';

class PlanHubScreen extends ConsumerWidget {
  const PlanHubScreen({super.key});

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
            'Plan',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Prepare for what is coming and give your money a purpose.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const _PlanHero(),
          const SizedBox(height: 18),
          _PlanCard(
            icon: Icons.event_note_rounded,
            title: 'Upcoming activity',
            subtitle: 'Future expenses, expected income, and reminders',
            accent: WaveColors.primary,
            onTap: () => open(const PlannedScreen()),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            icon: Icons.pie_chart_rounded,
            title: 'Budgets',
            subtitle: 'Set spending limits and follow monthly progress',
            accent: const Color(0xFFF39B45),
            onTap: () => open(const BudgetsScreen()),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            icon: Icons.savings_rounded,
            title: 'Savings goals',
            subtitle: 'Build targets and record contributions',
            accent: const Color(0xFF269CA3),
            onTap: () => open(const SavingsGoalsScreen()),
          ),
        ],
      ),
    );
  }
}

class _PlanHero extends StatelessWidget {
  const _PlanHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [WaveColors.primaryStrong, WaveColors.primary],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white24,
          foregroundColor: Colors.white,
          child: Icon(Icons.waves_rounded, size: 30),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Small plans create calmer months',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Planned values stay separate from actual balances until you post them.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      minVerticalPadding: 18,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: .13),
        foregroundColor: accent,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

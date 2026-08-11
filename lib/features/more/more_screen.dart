import 'package:flutter/material.dart';

import '../../core/theme/wave_theme.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/backup_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'More',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Manage'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _MoreTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounts',
                  subtitle: 'Balances and where you keep money',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _MoreTile(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Organize income and expenses',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Insights'),
          const SizedBox(height: 8),
          Card(
            child: _MoreTile(
              icon: Icons.insights_outlined,
              title: 'Reports',
              subtitle: 'Spending trends and category breakdowns',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Data and privacy'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _MoreTile(
                  icon: Icons.backup_outlined,
                  title: 'Backup and restore',
                  subtitle: 'JSON backups and CSV export',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BackupScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                const _MoreTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Privacy',
                  subtitle: 'Balance visibility and app lock',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: WaveColors.muted,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 0.8,
    ),
  );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: WaveColors.primaryContainer,
      foregroundColor: WaveColors.primaryStrong,
      child: Icon(icon),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

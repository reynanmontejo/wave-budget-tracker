import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/wave_theme.dart';
import '../../core/theme/wave_page_route.dart';
import '../../data/providers.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/appearance_screen.dart';
import '../settings/privacy_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motionEnabled =
        ref.watch(appearanceProvider).gentleMotion &&
        !MediaQuery.disableAnimationsOf(context);
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
                    WavePageRoute<void>(
                      motionEnabled: motionEnabled,
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
                    WavePageRoute<void>(
                      motionEnabled: motionEnabled,
                      builder: (_) => const CategoriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Personalize'),
          const SizedBox(height: 8),
          Card(
            child: _MoreTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Theme and gentle motion',
              onTap: () => Navigator.push(
                context,
                WavePageRoute<void>(
                  motionEnabled: motionEnabled,
                  builder: (_) => const AppearanceScreen(),
                ),
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
                    WavePageRoute<void>(
                      motionEnabled: motionEnabled,
                      builder: (_) => const BackupScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _MoreTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Privacy',
                  subtitle: 'Balance visibility and app lock',
                  onTap: () => Navigator.push(
                    context,
                    WavePageRoute<void>(
                      motionEnabled: motionEnabled,
                      builder: (_) => const PrivacyScreen(),
                    ),
                  ),
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

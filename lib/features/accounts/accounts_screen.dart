import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_page_route.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import 'account_actions.dart';
import 'account_card.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

enum _AccountView { all, wallets, archived }

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  _AccountView _view = _AccountView.all;

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(allAccountBalancesProvider);
    final balanceVisible = ref.watch(balancesVisibleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(balancesVisibleProvider.notifier).toggle(),
            tooltip: balanceVisible ? 'Hide balances' : 'Show balances',
            icon: Icon(
              balanceVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAccountForm(
          context,
          ref,
          initialType: _view == _AccountView.wallets ? 'E-wallet' : null,
        ),
        icon: const Icon(Icons.add),
        label: Text(
          _view == _AccountView.wallets ? 'Add e-wallet' : 'Add account',
        ),
      ),
      body: balances.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _AccountLoadError(
          onRetry: () => ref.invalidate(allAccountBalancesProvider),
        ),
        data: (items) {
          final active = items
              .where((item) => item.account.archivedAt == null)
              .toList();
          final archived = items
              .where((item) => item.account.archivedAt != null)
              .toList();
          final wallets = active
              .where((item) => item.account.typeName == 'E-wallet')
              .toList();
          final visibleItems = switch (_view) {
            _AccountView.all => active,
            _AccountView.wallets => wallets,
            _AccountView.archived => archived,
          };
          final total = active
              .where((item) => item.account.includeInNetWorth)
              .fold<int>(0, (sum, item) => sum + item.balanceMinor);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allAccountBalancesProvider);
              ref.invalidate(accountBalancesProvider);
              await ref.read(allAccountBalancesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _TotalBalanceCard(
                  totalMinor: total,
                  accountCount: active.length,
                  balanceVisible: balanceVisible,
                ),
                const SizedBox(height: 18),
                SegmentedButton<_AccountView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _AccountView.all,
                      label: Text('Active (${active.length})'),
                      icon: const Icon(Icons.wallet_outlined),
                    ),
                    ButtonSegment(
                      value: _AccountView.wallets,
                      label: Text('E-wallets (${wallets.length})'),
                      icon: const Icon(Icons.phone_android_rounded),
                    ),
                    ButtonSegment(
                      value: _AccountView.archived,
                      label: Text('Archived (${archived.length})'),
                      icon: const Icon(Icons.archive_outlined),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
                const SizedBox(height: 18),
                if (visibleItems.isEmpty)
                  _EmptyAccounts(view: _view)
                else
                  for (var index = 0; index < visibleItems.length; index++) ...[
                    _ManagedAccountCard(
                      summary: visibleItems[index],
                      balanceVisible: balanceVisible,
                    ),
                    if (index != visibleItems.length - 1)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ManagedAccountCard extends ConsumerWidget {
  const _ManagedAccountCard({
    required this.summary,
    required this.balanceVisible,
  });

  final AccountBalanceSummary summary;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = summary.account;
    final archived = account.archivedAt != null;
    final usage = ref.watch(accountUsageProvider(account.id)).valueOrNull;
    final actions = <AccountCardAction>[
      if (!archived) AccountCardAction.edit,
      if (!archived && account.typeName == 'E-wallet')
        AccountCardAction.reconcile,
      if (archived) AccountCardAction.restore else AccountCardAction.archive,
      if (usage?.canDeletePermanently ?? false) AccountCardAction.delete,
    ];
    return WaveAccountCard(
      summary: summary,
      balanceVisible: balanceVisible,
      actions: actions,
      onTap: () => _openDetails(context, ref, account.id),
      onAction: (action) => _handleAction(context, ref, action),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    AccountCardAction action,
  ) async {
    switch (action) {
      case AccountCardAction.edit:
        await openAccountForm(context, ref, initial: summary);
        return;
      case AccountCardAction.reconcile:
        await openReconcileAccount(context, ref, summary);
        return;
      case AccountCardAction.archive:
        await archiveAccountAction(context, ref, summary);
        return;
      case AccountCardAction.restore:
        await restoreAccountAction(context, ref, summary);
        return;
      case AccountCardAction.delete:
        await deleteAccountAction(context, ref, summary);
        return;
    }
  }
}

void _openDetails(BuildContext context, WidgetRef ref, String accountId) {
  final motionEnabled =
      ref.read(appearanceProvider).gentleMotion &&
      !MediaQuery.disableAnimationsOf(context);
  Navigator.push(
    context,
    WavePageRoute<void>(
      motionEnabled: motionEnabled,
      builder: (_) => AccountDetailScreen(accountId: accountId),
    ),
  );
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({
    required this.totalMinor,
    required this.accountCount,
    required this.balanceVisible,
  });

  final int totalMinor;
  final int accountCount;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [WaveColors.primaryStrong, WaveColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            balanceVisible ? Money(totalMinor).format() : '••••••',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$accountCount active ${accountCount == 1 ? 'account' : 'accounts'}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.view});
  final _AccountView view;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(
          view == _AccountView.archived
              ? Icons.archive_outlined
              : view == _AccountView.wallets
              ? Icons.phone_android_rounded
              : Icons.wallet_outlined,
          size: 44,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          switch (view) {
            _AccountView.archived => 'No archived accounts',
            _AccountView.wallets => 'No e-wallets yet',
            _AccountView.all => 'No active accounts',
          },
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(switch (view) {
          _AccountView.archived =>
            'Accounts you archive will remain available here.',
          _AccountView.wallets =>
            'Add a manually tracked wallet and enter its current value.',
          _AccountView.all => 'Add an account to start tracking a balance.',
        }, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _AccountLoadError extends StatelessWidget {
  const _AccountLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text('Unable to load accounts.'),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

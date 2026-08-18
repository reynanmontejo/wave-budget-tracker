import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../transactions/add_transaction_sheet.dart';
import 'account_actions.dart';
import 'account_card.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(allAccountBalancesProvider);
    final visible = ref.watch(balancesVisibleProvider);
    return balances.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('Unable to load this account.')),
      ),
      data: (items) {
        final summary = items
            .where((item) => item.account.id == accountId)
            .firstOrNull;
        if (summary == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account')),
            body: const Center(child: Text('This account no longer exists.')),
          );
        }
        return _AccountDetailBody(summary: summary, balanceVisible: visible);
      },
    );
  }
}

class _AccountDetailBody extends ConsumerWidget {
  const _AccountDetailBody({
    required this.summary,
    required this.balanceVisible,
  });

  final AccountBalanceSummary summary;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = summary.account;
    final archived = account.archivedAt != null;
    final activity = ref.watch(accountActivityProvider(account.id));
    final usage = ref.watch(accountUsageProvider(account.id)).valueOrNull;
    final actions = <AccountCardAction>[
      if (!archived) AccountCardAction.edit,
      if (!archived && account.typeName == 'E-wallet')
        AccountCardAction.reconcile,
      if (archived) AccountCardAction.restore else AccountCardAction.archive,
      if (usage?.canDeletePermanently ?? false) AccountCardAction.delete,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
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
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateAccountData(ref, accountId: account.id);
          await ref.read(allAccountBalancesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            if (archived) ...[
              const _ArchivedBanner(),
              const SizedBox(height: 12),
            ],
            WaveAccountCard(
              summary: summary,
              balanceVisible: balanceVisible,
              actions: actions,
              onTap: () {},
              onAction: (action) => _handleAction(context, ref, action),
            ),
            const SizedBox(height: 14),
            _AccountMetadata(summary: summary),
            if (!archived) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openTransfer(context),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Transfer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => account.typeName == 'E-wallet'
                          ? openReconcileAccount(context, ref, summary)
                          : openAccountForm(context, ref, initial: summary),
                      icon: Icon(
                        account.typeName == 'E-wallet'
                            ? Icons.sync_alt_rounded
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        account.typeName == 'E-wallet' ? 'Reconcile' : 'Edit',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            activity.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Unable to load account activity.'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const _EmptyActivity()
                  : Column(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          _AccountActivityTile(
                            entry: items[index],
                            accountId: account.id,
                            balanceVisible: balanceVisible,
                          ),
                          if (index != items.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
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
        final deleted = await deleteAccountAction(context, ref, summary);
        if (deleted && context.mounted) Navigator.pop(context);
        return;
    }
  }

  Future<void> _openTransfer(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            const AddTransactionSheet(initialMode: EntryMode.transfer),
      );
}

class _AccountMetadata extends StatelessWidget {
  const _AccountMetadata({required this.summary});
  final AccountBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          children: [
            _MetadataItem(label: 'Type', value: account.typeName),
            if (account.typeName == 'E-wallet')
              _MetadataItem(
                label: 'Provider',
                value: account.walletProviderName ?? 'Manual wallet',
              ),
            if (account.typeName == 'E-wallet' &&
                account.walletIdentifierSuffix != null)
              _MetadataItem(
                label: 'Identifier',
                value: '••${account.walletIdentifierSuffix}',
              ),
            if (account.typeName == 'E-wallet')
              _MetadataItem(
                label: 'Last reconciled',
                value: account.walletLastReconciledAt == null
                    ? 'Not yet'
                    : DateFormat.yMMMd().add_jm().format(
                        account.walletLastReconciledAt!,
                      ),
              ),
            _MetadataItem(label: 'Currency', value: account.currencyCode),
            _MetadataItem(
              label: 'Opening balance',
              value: Money(
                account.openingBalanceMinor,
                currencyCode: account.currencyCode,
              ).format(),
            ),
            _MetadataItem(
              label: 'Opened',
              value: DateFormat.yMMMd().format(account.openingBalanceDate),
            ),
            _MetadataItem(
              label: 'Total balance',
              value: account.includeInNetWorth ? 'Included' : 'Excluded',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _AccountActivityTile extends StatelessWidget {
  const _AccountActivityTile({
    required this.entry,
    required this.accountId,
    required this.balanceVisible,
  });

  final ActivityEntry entry;
  final String accountId;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context) {
    final adjustment = entry.kind.startsWith('adjustment_');
    final incoming =
        entry.kind == 'income' ||
        entry.kind == 'adjustment_in' ||
        (entry.kind == 'transfer' && entry.destinationAccountId == accountId);
    final color = adjustment
        ? WaveColors.primary
        : entry.kind == 'transfer'
        ? WaveColors.primary
        : incoming
        ? WaveColors.income
        : WaveColors.expense;
    final icon = adjustment
        ? Icons.sync_alt_rounded
        : entry.kind == 'transfer'
        ? Icons.swap_horiz_rounded
        : incoming
        ? Icons.add_rounded
        : Icons.remove_rounded;
    final counterpart = adjustment
        ? 'Manual balance correction'
        : entry.kind == 'transfer'
        ? incoming
              ? 'From ${entry.accountName}'
              : 'To ${entry.destinationName}'
        : entry.accountName;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(
          entry.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$counterpart • ${DateFormat.MMMd().add_jm().format(entry.occurredAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          balanceVisible
              ? '${incoming ? '+' : '-'}${Money(entry.amountMinor).format()}'
              : '••••',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.archive_outlined),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Archived accounts preserve history but cannot receive new activity.',
          ),
        ),
      ],
    ),
  );
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined),
          SizedBox(width: 12),
          Expanded(child: Text('No activity has been recorded here yet.')),
        ],
      ),
    ),
  );
}

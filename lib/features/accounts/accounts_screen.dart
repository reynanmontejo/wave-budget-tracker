import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccount(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: balances.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load accounts.')),
        data: (items) {
          final total = items.fold<int>(
            0,
            (sum, item) => sum + item.balanceMinor,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: WaveColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Money(total).format(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (final item in items) ...[
                _AccountCard(
                  summary: item,
                  onEdit: () => _showEditAccount(context, ref, item),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddAccount(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = 'Cash';
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Account name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items:
                    const ['Cash', 'Bank', 'E-wallet', 'Savings', 'Investment']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => type = value ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening balance',
                  prefixText: '₱ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = Money.parseMajorUnits(
                  balance.text.trim().isEmpty ? '0' : balance.text,
                );
                if (amount == null) {
                  _showDialogError(
                    dialogContext,
                    'Enter a valid opening balance.',
                  );
                  return;
                }
                try {
                  await ref
                      .read(managementRepositoryProvider)
                      .createAccount(
                        name: name.text,
                        typeName: type,
                        openingBalanceMinor: amount,
                      );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    _showDialogError(
                      dialogContext,
                      error is ArgumentError
                          ? error.message?.toString() ??
                                'Check the account details.'
                          : 'Wave could not add this account. Please try again.',
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    name.dispose();
    balance.dispose();
    if (created ?? false) ref.invalidate(accountBalancesProvider);
  }

  Future<void> _showEditAccount(
    BuildContext context,
    WidgetRef ref,
    AccountBalanceSummary summary,
  ) async {
    final name = TextEditingController(text: summary.account.name);
    final balance = TextEditingController(
      text: (summary.account.openingBalanceMinor / 100).toStringAsFixed(2),
    );
    var type = summary.account.typeName;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Account name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items:
                    const ['Cash', 'Bank', 'E-wallet', 'Savings', 'Investment']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => type = value ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening balance',
                  prefixText: '₱ ',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Changing the opening balance updates the account’s current balance while preserving all transactions.',
                style: TextStyle(color: WaveColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = Money.parseMajorUnits(balance.text);
                if (amount == null) {
                  _showDialogError(
                    dialogContext,
                    'Enter a valid opening balance.',
                  );
                  return;
                }
                try {
                  await ref
                      .read(managementRepositoryProvider)
                      .updateAccount(
                        id: summary.account.id,
                        name: name.text,
                        typeName: type,
                        openingBalanceMinor: amount,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    _showDialogError(
                      dialogContext,
                      error is ArgumentError
                          ? error.message?.toString() ??
                                'Check the account details.'
                          : 'Wave could not update this account. Please try again.',
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    name.dispose();
    balance.dispose();
    if (updated ?? false) {
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(accountsProvider);
    }
  }

  void _showDialogError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.summary, required this.onEdit});
  final AccountBalanceSummary summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: WaveColors.primaryContainer,
          foregroundColor: WaveColors.primaryStrong,
          child: Icon(Icons.account_balance_wallet_outlined),
        ),
        title: Text(
          summary.account.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(summary.account.typeName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Money(summary.balanceMinor).format(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  onEdit();
                  return;
                }
                if (value != 'archive') {
                  return;
                }
                try {
                  await ref
                      .read(managementRepositoryProvider)
                      .archiveAccount(summary.account.id);
                  ref.invalidate(accountBalancesProvider);
                } on StateError catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

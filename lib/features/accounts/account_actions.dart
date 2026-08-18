import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_page_route.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import 'account_form_screen.dart';
import 'account_reconcile_screen.dart';

void invalidateAccountData(WidgetRef ref, {String? accountId}) {
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(allAccountBalancesProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(totalsProvider);
  ref.invalidate(dashboardMetricsProvider);
  ref.invalidate(cashFlowInsightProvider);
  ref.invalidate(recentActivityProvider);
  ref.invalidate(activityEntriesProvider);
  if (accountId != null) {
    ref.invalidate(accountUsageProvider(accountId));
    ref.invalidate(accountActivityProvider(accountId));
  }
}

Future<bool> openAccountForm(
  BuildContext context,
  WidgetRef ref, {
  AccountBalanceSummary? initial,
  String? initialType,
}) async {
  final motionEnabled =
      ref.read(appearanceProvider).gentleMotion &&
      !MediaQuery.disableAnimationsOf(context);
  final changed = await Navigator.push<bool>(
    context,
    WavePageRoute<bool>(
      motionEnabled: motionEnabled,
      builder: (_) =>
          AccountFormScreen(initial: initial, initialType: initialType),
    ),
  );
  if (changed ?? false) {
    invalidateAccountData(ref, accountId: initial?.account.id);
    return true;
  }
  return false;
}

Future<bool> openReconcileAccount(
  BuildContext context,
  WidgetRef ref,
  AccountBalanceSummary summary,
) async {
  final motionEnabled =
      ref.read(appearanceProvider).gentleMotion &&
      !MediaQuery.disableAnimationsOf(context);
  final result = await Navigator.push<BalanceReconcileResult>(
    context,
    WavePageRoute<BalanceReconcileResult>(
      motionEnabled: motionEnabled,
      builder: (_) => AccountReconcileScreen(summary: summary),
    ),
  );
  if (result == null || !context.mounted) return false;
  invalidateAccountData(ref, accountId: summary.account.id);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result.adjustmentId == null
              ? 'Wallet value already matched'
              : 'Wallet value updated',
        ),
        action: result.adjustmentId == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await ref
                        .read(managementRepositoryProvider)
                        .reverseBalanceAdjustment(result.adjustmentId!);
                    invalidateAccountData(ref, accountId: summary.account.id);
                  } catch (error) {
                    if (context.mounted) _snack(context, _accountError(error));
                  }
                },
              ),
      ),
    );
  return true;
}

Future<bool> archiveAccountAction(
  BuildContext context,
  WidgetRef ref,
  AccountBalanceSummary summary,
) async {
  try {
    final usage = await ref.read(
      accountUsageProvider(summary.account.id).future,
    );
    if (!context.mounted) return false;
    if (usage.activeSchedules > 0) {
      await _messageDialog(
        context,
        title: 'Account is used by a plan',
        message:
            'Pause or reassign ${usage.activeSchedules} active planned ${usage.activeSchedules == 1 ? 'transaction' : 'transactions'} before archiving ${summary.account.name}.',
      );
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${summary.account.name}?'),
        content: Text(
          'The account will no longer be available for new entries. Its ${usage.transactions + usage.transfers} historical ${usage.transactions + usage.transfers == 1 ? 'record' : 'records'} will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return false;
    await ref
        .read(managementRepositoryProvider)
        .archiveAccount(summary.account.id);
    invalidateAccountData(ref, accountId: summary.account.id);
    if (context.mounted) _snack(context, '${summary.account.name} archived');
    return true;
  } catch (error) {
    if (context.mounted) _snack(context, _accountError(error));
    return false;
  }
}

Future<bool> restoreAccountAction(
  BuildContext context,
  WidgetRef ref,
  AccountBalanceSummary summary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Restore ${summary.account.name}?'),
      content: const Text(
        'The account will become available for new income, expenses, transfers, and plans.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Restore'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false)) return false;
  try {
    await ref
        .read(managementRepositoryProvider)
        .restoreAccount(summary.account.id);
    invalidateAccountData(ref, accountId: summary.account.id);
    if (context.mounted) _snack(context, '${summary.account.name} restored');
    return true;
  } catch (error) {
    if (context.mounted) _snack(context, _accountError(error));
    return false;
  }
}

Future<bool> deleteAccountAction(
  BuildContext context,
  WidgetRef ref,
  AccountBalanceSummary summary,
) async {
  try {
    final usage = await ref.read(
      accountUsageProvider(summary.account.id).future,
    );
    if (!context.mounted) return false;
    if (!usage.canDeletePermanently) {
      await _messageDialog(
        context,
        title: 'This account cannot be deleted',
        message: usage.hasHistory
            ? 'It is linked to financial history or planning data. Archive it instead so reports and balances remain correct.'
            : 'Its calculated balance is ${Money(usage.balanceMinor, currencyCode: summary.account.currencyCode).format()}. Bring the balance to zero or archive it instead.',
      );
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${summary.account.name} permanently?'),
        content: const Text(
          'This unused account will be removed from Wave. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return false;
    await ref
        .read(managementRepositoryProvider)
        .deleteUnusedAccount(summary.account.id);
    invalidateAccountData(ref, accountId: summary.account.id);
    if (context.mounted) _snack(context, '${summary.account.name} deleted');
    return true;
  } catch (error) {
    if (context.mounted) _snack(context, _accountError(error));
    return false;
  }
}

Future<void> _messageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Got it'),
      ),
    ],
  ),
);

String _accountError(Object error) => switch (error) {
  ArgumentError(:final message) =>
    message?.toString() ?? 'Check the account details.',
  StateError(:final message) => message,
  _ => 'Wave could not update this account. Please try again.',
};

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

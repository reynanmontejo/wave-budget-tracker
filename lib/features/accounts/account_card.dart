import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../data/database/app_database.dart';
import '../../data/wallet_providers.dart';

enum AccountCardAction { edit, reconcile, archive, restore, delete }

IconData accountIconFor(String key) => switch (key) {
  'account_balance' => Icons.account_balance_rounded,
  'payments' => Icons.payments_outlined,
  'savings' => Icons.savings_outlined,
  'phone' => Icons.phone_android_rounded,
  'trending_up' => Icons.trending_up_rounded,
  _ => Icons.account_balance_wallet_outlined,
};

class WaveAccountCard extends StatelessWidget {
  const WaveAccountCard({
    required this.summary,
    required this.balanceVisible,
    required this.onTap,
    this.compact = false,
    this.actions = const [],
    this.onAction,
    super.key,
  });

  final AccountBalanceSummary summary;
  final bool balanceVisible;
  final VoidCallback onTap;
  final bool compact;
  final List<AccountCardAction> actions;
  final ValueChanged<AccountCardAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    final archived = account.archivedAt != null;
    final wallet = account.typeName == 'E-wallet';
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(account.colorValue);
    final background = archived
        ? Color.lerp(scheme.surface, scheme.onSurface, .12)!
        : Color.lerp(scheme.surface, accent, compact ? .72 : .55)!;
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF132033);
    final secondary = foreground.withValues(alpha: .76);
    final balance = balanceVisible
        ? Money(
            summary.balanceMinor,
            currencyCode: account.currencyCode,
          ).format()
        : '••••••';

    final content = Semantics(
      button: true,
      label:
          '${account.name}, ${account.typeName}, ${account.currencyCode}, balance ${balanceVisible ? Money(summary.balanceMinor, currencyCode: account.currencyCode).format() : 'hidden'}${archived ? ', archived' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 15 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: wallet
                        ? Center(
                            child: Text(
                              walletProviderMonogram(
                                account.walletProviderName,
                              ),
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          )
                        : Icon(
                            accountIconFor(account.iconKey),
                            color: foreground,
                            size: 21,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 15 : 17,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: PopupMenuButton<AccountCardAction>(
                        tooltip: 'Account actions',
                        padding: EdgeInsets.zero,
                        color: scheme.surface,
                        iconColor: foreground,
                        onSelected: onAction,
                        itemBuilder: (_) => [
                          for (final action in actions)
                            PopupMenuItem(
                              value: action,
                              child: Row(
                                children: [
                                  Icon(_actionIcon(action), size: 20),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      _actionLabel(action),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 15 : 20),
              Text(
                wallet
                    ? '${account.walletProviderName ?? 'E-wallet'}${account.walletIdentifierSuffix == null ? '' : ' ••${account.walletIdentifierSuffix}'} • ${account.currencyCode}'
                    : '${account.typeName} • ${account.currencyCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  balance,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 22 : 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              if (!account.includeInNetWorth) ...[
                const SizedBox(height: 5),
                Text(
                  'Excluded from total',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (wallet && account.includeInNetWorth) ...[
                const SizedBox(height: 5),
                Text(
                  account.walletLastReconciledAt == null
                      ? 'Manual balance'
                      : 'Manual • ${DateFormat.MMMd().format(account.walletLastReconciledAt!)}',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: compact ? 220 : null,
        constraints: BoxConstraints(minHeight: compact ? 142 : 158),
        decoration: BoxDecoration(
          border: Border.all(color: foreground.withValues(alpha: .08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: content,
      ),
    );
  }

  static String _actionLabel(AccountCardAction action) => switch (action) {
    AccountCardAction.edit => 'Edit',
    AccountCardAction.reconcile => 'Reconcile value',
    AccountCardAction.archive => 'Archive',
    AccountCardAction.restore => 'Restore',
    AccountCardAction.delete => 'Delete permanently',
  };

  static IconData _actionIcon(AccountCardAction action) => switch (action) {
    AccountCardAction.edit => Icons.edit_outlined,
    AccountCardAction.reconcile => Icons.sync_alt_rounded,
    AccountCardAction.archive => Icons.archive_outlined,
    AccountCardAction.restore => Icons.unarchive_outlined,
    AccountCardAction.delete => Icons.delete_forever_outlined,
  };
}

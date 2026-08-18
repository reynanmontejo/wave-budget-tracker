import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/widgets/confirm_add_dialog.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';

final class BalanceReconcileResult {
  const BalanceReconcileResult({required this.adjustmentId});

  final String? adjustmentId;
}

class AccountReconcileScreen extends ConsumerStatefulWidget {
  const AccountReconcileScreen({required this.summary, super.key});

  final AccountBalanceSummary summary;

  @override
  ConsumerState<AccountReconcileScreen> createState() =>
      _AccountReconcileScreenState();
}

class _AccountReconcileScreenState
    extends ConsumerState<AccountReconcileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _observed;
  final _note = TextEditingController();
  int? _observedMinor;
  bool _saving = false;

  Account get account => widget.summary.account;
  int? get difference => _observedMinor == null
      ? null
      : _observedMinor! - widget.summary.balanceMinor;

  @override
  void initState() {
    super.initState();
    _observed = TextEditingController(
      text: (widget.summary.balanceMinor / 100).toStringAsFixed(2),
    );
    _observedMinor = widget.summary.balanceMinor;
  }

  @override
  void dispose() {
    _observed.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = account.currencyCode;
    return Scaffold(
      appBar: AppBar(title: const Text('Reconcile value')),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Text(
              account.walletProviderName ?? account.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Compare Wave with the value currently shown in your wallet app.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('Wave calculated'),
                trailing: Text(
                  Money(
                    widget.summary.balanceMinor,
                    currencyCode: currency,
                  ).format(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observed,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Value shown in wallet',
                prefixText: '₱ ',
              ),
              onChanged: (value) =>
                  setState(() => _observedMinor = Money.parseMajorUnits(value)),
              validator: (value) {
                final amount = Money.parseMajorUnits(value ?? '');
                if (amount == null) return 'Enter a valid wallet value.';
                if (amount < 0) return 'Wallet value cannot be negative.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: difference == null
                  ? const SizedBox.shrink()
                  : _DifferenceCard(
                      key: ValueKey(difference),
                      differenceMinor: difference!,
                      currencyCode: currency,
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Why the wallet value differs',
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This changes only the wallet balance. It will not count as income, expense, or budget spending.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: const Text('Review adjustment'),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final observed = Money.parseMajorUnits(_observed.text)!;
    final delta = observed - widget.summary.balanceMinor;
    final confirmed = await confirmAdd(
      context,
      title: 'Update wallet value?',
      details: [
        (
          'Calculated',
          Money(
            widget.summary.balanceMinor,
            currencyCode: account.currencyCode,
          ).format(),
        ),
        (
          'Entered',
          Money(observed, currencyCode: account.currencyCode).format(),
        ),
        (
          'Adjustment',
          '${delta > 0 ? '+' : ''}${Money(delta, currencyCode: account.currencyCode).format()}',
        ),
        ('Reports', 'Excluded from income and expenses'),
      ],
      confirmLabel: 'Confirm update',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(managementRepositoryProvider)
          .reconcileAccountBalance(
            accountId: account.id,
            observedBalanceMinor: observed,
            note: _note.text,
          );
      if (mounted) {
        Navigator.pop(context, BalanceReconcileResult(adjustmentId: id));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (error) {
            ArgumentError(:final message) =>
              message?.toString() ?? 'Check the wallet value.',
            StateError(:final message) => message,
            _ => 'Wave could not reconcile this wallet. Please try again.',
          }),
        ),
      );
    }
  }
}

class _DifferenceCard extends StatelessWidget {
  const _DifferenceCard({
    required this.differenceMinor,
    required this.currencyCode,
    super.key,
  });

  final int differenceMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final unchanged = differenceMinor == 0;
    final positive = differenceMinor > 0;
    final color = unchanged
        ? Theme.of(context).colorScheme.primary
        : positive
        ? const Color(0xFF3F8F70)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            unchanged ? Icons.check_circle_outline : Icons.sync_alt,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unchanged ? 'Values already match' : 'Balance adjustment',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!unchanged)
                  Text(
                    '${positive ? '+' : ''}${Money(differenceMinor, currencyCode: currencyCode).format()}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
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

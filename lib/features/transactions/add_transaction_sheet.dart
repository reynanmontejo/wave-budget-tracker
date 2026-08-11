import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/ledger_repository.dart';
import '../../data/providers.dart';

enum _EntryMode { expense, income, transfer }

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  _EntryMode _mode = _EntryMode.expense;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.parseMajorUnits(_amountController.text);
    if (amount == null || amount == 0 || _accountId == null) {
      _showError('Enter a valid amount and account.');
      return;
    }
    if (_mode != _EntryMode.transfer && _categoryId == null) {
      _showError('Choose a category.');
      return;
    }
    if (_mode == _EntryMode.transfer && _toAccountId == null) {
      _showError('Choose a destination account.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(ledgerRepositoryProvider);
      if (_mode == _EntryMode.transfer) {
        await repository.createTransfer(
          amountMinor: amount,
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          occurredAt: DateTime.now(),
          note: _noteController.text,
        );
      } else {
        await repository.createEntry(
          type: _mode == _EntryMode.income
              ? LedgerEntryType.income
              : LedgerEntryType.expense,
          amountMinor: amount,
          accountId: _accountId!,
          categoryId: _categoryId!,
          occurredAt: DateTime.now(),
          note: _noteController.text,
        );
      }
      ref.invalidate(totalsProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(expenseReportProvider);
      ref.invalidate(homeBudgetProgressProvider);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'Check the entry and try again.');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _changeMode(_EntryMode mode) {
    setState(() {
      _mode = mode;
      _categoryId = null;
    });
  }

  void _swapAccounts() {
    setState(() {
      final previousFrom = _accountId;
      _accountId = _toAccountId;
      _toAccountId = previousFrom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(
      _mode == _EntryMode.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );
    final categories = categoryState.valueOrNull ?? const <Category>[];
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    _categoryId ??= categories.firstOrNull?.id;
    _accountId ??= accounts.firstOrNull?.id;
    if (_mode == _EntryMode.transfer) {
      _toAccountId ??= accounts
          .where((item) => item.id != _accountId)
          .firstOrNull
          ?.id;
    }

    return Material(
      color: WaveColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Add entry',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<_EntryMode>(
                segments: const [
                  ButtonSegment(
                    value: _EntryMode.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: _EntryMode.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment(
                    value: _EntryMode.transfer,
                    label: Text('Transfer'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) => _changeMode(value.first),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  prefixText: '₱ ',
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 20),
              if (_mode != _EntryMode.transfer) ...[
                Text(
                  'Category',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in categories)
                      ChoiceChip(
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        onSelected: (_) =>
                            setState(() => _categoryId = category.id),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: _mode == _EntryMode.transfer
                      ? 'From account'
                      : 'Account',
                ),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _accountId = value;
                  if (_toAccountId == value) _toAccountId = null;
                }),
              ),
              if (_mode == _EntryMode.transfer) ...[
                IconButton(
                  onPressed: _swapAccounts,
                  tooltip: 'Swap accounts',
                  icon: const Icon(
                    Icons.swap_vert_rounded,
                    color: WaveColors.primary,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: [
                    for (final account in accounts.where(
                      (item) => item.id != _accountId,
                    ))
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _toAccountId = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Transfers move money between your accounts and do not affect income or expense totals.',
                  style: TextStyle(color: WaveColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Save ${_mode.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

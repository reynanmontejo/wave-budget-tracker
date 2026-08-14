import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/ledger_repository.dart';
import '../../data/providers.dart';

enum EntryMode { expense, income, transfer }

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.initialMode = EntryMode.expense});

  final EntryMode initialMode;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late EntryMode _mode;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  bool _saving = false;
  bool _showDetails = false;
  DateTime _occurredAt = DateTime.now();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool _validateQuickEntry() {
    final amount = Money.parseMajorUnits(_amountController.text);
    if (amount == null || amount == 0 || _accountId == null) {
      _showError('Enter a valid amount and account.');
      return false;
    }
    if (_mode != EntryMode.transfer && _categoryId == null) {
      _showError('Choose a category.');
      return false;
    }
    if (_mode == EntryMode.transfer && _toAccountId == null) {
      _showError('Choose a destination account.');
      return false;
    }
    if (_mode == EntryMode.transfer && _toAccountId == _accountId) {
      _showError('Choose two different accounts.');
      return false;
    }
    return true;
  }

  void _continueToDetails() {
    if (!_validateQuickEntry()) return;
    FocusScope.of(context).unfocus();
    setState(() => _showDetails = true);
  }

  Future<void> _save() async {
    if (!_validateQuickEntry()) return;
    final amount = Money.parseMajorUnits(_amountController.text)!;
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final repository = ref.read(ledgerRepositoryProvider);
      late final String activityId;
      late final String activityKind;
      if (_mode == EntryMode.transfer) {
        activityId = await repository.createTransfer(
          amountMinor: amount,
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          occurredAt: _occurredAt,
          note: _noteController.text,
        );
        activityKind = 'transfer';
      } else {
        activityId = await repository.createEntry(
          type: _mode == EntryMode.income
              ? LedgerEntryType.income
              : LedgerEntryType.expense,
          amountMinor: amount,
          accountId: _accountId!,
          categoryId: _categoryId!,
          occurredAt: _occurredAt,
          note: _noteController.text,
        );
        activityKind = _mode.name;
      }
      _invalidateLedgerData(container);
      if (mounted) {
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${_capitalized(activityKind)} added'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await repository.deleteActivity(activityId, activityKind);
                    _invalidateLedgerData(container);
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Unable to undo that entry.'),
                      ),
                    );
                  }
                },
              ),
            ),
          );
      }
    } catch (error) {
      _showError(
        error is ArgumentError
            ? error.message?.toString() ?? 'Check the entry and try again.'
            : 'Wave could not save this entry. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  void _invalidateLedgerData(ProviderContainer container) {
    container.invalidate(totalsProvider);
    container.invalidate(accountBalancesProvider);
    container.invalidate(expenseReportProvider);
    container.invalidate(homeBudgetProgressProvider);
    container.invalidate(transactionEntriesProvider);
    container.invalidate(activityEntriesProvider);
    container.invalidate(dashboardMetricsProvider);
  }

  void _changeMode(EntryMode mode) {
    setState(() {
      _mode = mode;
      _categoryId = null;
      _showDetails = false;
      _errorMessage = null;
    });
  }

  void _swapAccounts() {
    setState(() {
      final previousFrom = _accountId;
      _accountId = _toAccountId;
      _toAccountId = previousFrom;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(
      _mode == EntryMode.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );
    final accountState = ref.watch(accountsProvider);
    final categories = categoryState.valueOrNull ?? const <Category>[];
    final accounts = accountState.valueOrNull ?? const <Account>[];
    _categoryId ??= categories.firstOrNull?.id;
    _accountId ??= accounts.firstOrNull?.id;
    if (_mode == EntryMode.transfer) {
      _toAccountId ??= accounts
          .where((item) => item.id != _accountId)
          .firstOrNull
          ?.id;
    }

    final blocked =
        categoryState.isLoading ||
        accountState.isLoading ||
        categoryState.hasError ||
        accountState.hasError ||
        accounts.isEmpty ||
        (_mode != EntryMode.transfer && categories.isEmpty) ||
        (_mode == EntryMode.transfer && accounts.length < 2);
    String accountName(String? id) =>
        accounts.where((item) => item.id == id).firstOrNull?.name ??
        'Choose account';
    final categoryName = categories
        .where((item) => item.id == _categoryId)
        .firstOrNull
        ?.name;
    final amount = Money.parseMajorUnits(_amountController.text);
    final modeName = _mode.name;
    final motionEnabled =
        ref.watch(appearanceProvider.select((value) => value.gentleMotion)) &&
        !MediaQuery.disableAnimationsOf(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: AnimatedSwitcher(
            duration: motionEnabled
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => motionEnabled
                ? FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  )
                : child,
            child: Column(
              key: ValueKey(_showDetails),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_showDetails)
                      IconButton(
                        onPressed: () => setState(() => _showDetails = false),
                        tooltip: 'Back to quick entry',
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Text(
                        _showDetails
                            ? '${_capitalized(modeName)} details'
                            : 'Add transaction',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  _showDetails
                      ? 'Step 2 of 2 · Review before saving'
                      : 'Step 1 of 2 · Quick entry',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WaveColors.primaryStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  _EntryNotice(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                    isError: true,
                  ),
                  const SizedBox(height: 14),
                ],
                if (!_showDetails)
                  _buildQuickEntry(
                    context,
                    categories: categories,
                    accounts: accounts,
                    categoryState: categoryState,
                    accountState: accountState,
                    blocked: blocked,
                  )
                else
                  _buildDetails(
                    context,
                    amount: amount,
                    categoryName: categoryName,
                    accountName: accountName,
                    modeName: modeName,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickEntry(
    BuildContext context, {
    required List<Category> categories,
    required List<Account> accounts,
    required AsyncValue<List<Category>> categoryState,
    required AsyncValue<List<Account>> accountState,
    required bool blocked,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<EntryMode>(
        segments: const [
          ButtonSegment(value: EntryMode.expense, label: Text('Expense')),
          ButtonSegment(value: EntryMode.income, label: Text('Income')),
          ButtonSegment(value: EntryMode.transfer, label: Text('Transfer')),
        ],
        selected: {_mode},
        showSelectedIcon: false,
        onSelectionChanged: (value) => _changeMode(value.first),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _amountController,
        onChanged: (_) {
          if (_errorMessage != null) setState(() => _errorMessage = null);
        },
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          prefixText: '₱ ',
          hintText: '0.00',
          helperText: 'Amount',
        ),
      ),
      const SizedBox(height: 16),
      if (categoryState.hasError || accountState.hasError) ...[
        const _EntryNotice(
          icon: Icons.error_outline_rounded,
          message:
              'Wave could not load your accounts or categories. Close this form and try again.',
          isError: true,
        ),
        const SizedBox(height: 16),
      ] else if (categoryState.isLoading || accountState.isLoading) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
      ] else if (accounts.isEmpty) ...[
        const _EntryNotice(
          icon: Icons.account_balance_wallet_outlined,
          message: 'Add an account before recording an entry.',
        ),
        const SizedBox(height: 16),
      ] else if (_mode != EntryMode.transfer && categories.isEmpty) ...[
        const _EntryNotice(
          icon: Icons.category_outlined,
          message: 'Add a matching category before recording an entry.',
        ),
        const SizedBox(height: 16),
      ],
      if (_mode != EntryMode.transfer) ...[
        Text(
          'Category',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              ChoiceChip(
                avatar: Icon(_categoryIcon(category.iconKey), size: 18),
                label: Text(category.name),
                selected: _categoryId == category.id,
                onSelected: (_) => setState(() {
                  _categoryId = category.id;
                  _errorMessage = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      DropdownButtonFormField<String>(
        initialValue: _accountId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _mode == EntryMode.transfer ? 'From account' : 'Account',
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        items: [
          for (final account in accounts)
            DropdownMenuItem(value: account.id, child: Text(account.name)),
        ],
        onChanged: (value) => setState(() {
          _accountId = value;
          if (_toAccountId == value) _toAccountId = null;
          _errorMessage = null;
        }),
      ),
      if (_mode == EntryMode.transfer) ...[
        IconButton(
          onPressed: _swapAccounts,
          tooltip: 'Swap accounts',
          icon: const Icon(Icons.swap_vert_rounded, color: WaveColors.primary),
        ),
        DropdownButtonFormField<String>(
          initialValue: _toAccountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'To account',
            prefixIcon: Icon(Icons.account_balance_wallet_rounded),
          ),
          items: [
            for (final account in accounts.where(
              (item) => item.id != _accountId,
            ))
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() {
            _toAccountId = value;
            _errorMessage = null;
          }),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: blocked ? null : _continueToDetails,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Continue'),
      ),
    ],
  );

  Widget _buildDetails(
    BuildContext context, {
    required int? amount,
    required String? categoryName,
    required String Function(String?) accountName,
    required String modeName,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: WaveColors.primaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              Money(amount ?? 0).format(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: WaveColors.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            if (_mode != EntryMode.transfer)
              _ReviewRow(
                icon: Icons.category_outlined,
                label: 'Category',
                value: categoryName ?? 'Choose category',
              ),
            _ReviewRow(
              icon: Icons.account_balance_wallet_outlined,
              label: _mode == EntryMode.transfer ? 'From' : 'Account',
              value: accountName(_accountId),
            ),
            if (_mode == EntryMode.transfer)
              _ReviewRow(
                icon: Icons.arrow_forward_rounded,
                label: 'To',
                value: accountName(_toAccountId),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Date'),
          subtitle: Text(
            MaterialLocalizations.of(context).formatMediumDate(_occurredAt),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _pickDate,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _noteController,
        maxLength: 120,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Note (optional)',
          hintText: 'Add a short description',
          prefixIcon: Icon(Icons.edit_note_rounded),
        ),
      ),
      if (_mode == EntryMode.transfer)
        const Text(
          'Transfers move money between your accounts and do not affect income or expense totals.',
          style: TextStyle(color: WaveColors.muted, fontSize: 12),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        icon: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_saving ? 'Saving…' : 'Confirm $modeName'),
      ),
      TextButton(
        onPressed: _saving ? null : () => setState(() => _showDetails = false),
        child: const Text('Edit quick details'),
      ),
    ],
  );

  String _capitalized(String value) =>
      '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

  IconData _categoryIcon(String key) => switch (key) {
    'food' => Icons.restaurant_rounded,
    'transport' => Icons.directions_car_rounded,
    'salary' => Icons.payments_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'bills' => Icons.receipt_long_rounded,
    _ => Icons.category_rounded,
  };
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: WaveColors.primaryStrong),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EntryNotice extends StatelessWidget {
  const _EntryNotice({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : WaveColors.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: isError
              ? Theme.of(context).colorScheme.onErrorContainer
              : WaveColors.primaryStrong,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

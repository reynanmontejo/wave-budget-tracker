import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/ledger_repository.dart';
import '../../data/providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(activityEntriesProvider);
    final hasFilters =
        ref.watch(activityTypeFilterProvider) != null ||
        ref.watch(activityAccountFilterProvider) != null ||
        ref.watch(activityCategoryFilterProvider) != null;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Badge(
                  isLabelVisible: hasFilters,
                  child: IconButton(
                    onPressed: () => _showFilters(context, ref),
                    tooltip: 'Filter transactions',
                    icon: const Icon(Icons.filter_list_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(child: _PeriodSelector()),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _chooseCustomRange(context, ref),
                  tooltip: 'Custom date range',
                  icon: const Icon(Icons.date_range_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Unable to load activity: $error')),
              data: (items) => items.isEmpty
                  ? const _EmptyLedger()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _ActivityTile(entry: items[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseCustomRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(selectedPeriodProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.startInclusive,
        end: current.endExclusive.subtract(const Duration(days: 1)),
      ),
    );
    if (range == null) return;
    ref.read(selectedCustomPeriodProvider.notifier).state =
        ExpensePeriod.custom(range.start, range.end);
    ref.read(selectedPeriodKindProvider.notifier).state =
        ExpensePeriodKind.custom;
  }

  Future<void> _showFilters(BuildContext context, WidgetRef ref) async {
    final accounts =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    final categories =
        ref.read(allCategoriesProvider).valueOrNull ?? const <Category>[];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: ref.read(activityTypeFilterProvider),
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All types')),
                DropdownMenuItem(value: 'expense', child: Text('Expenses')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfers')),
              ],
              onChanged: (value) =>
                  ref.read(activityTypeFilterProvider.notifier).state = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: ref.read(activityAccountFilterProvider),
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All accounts'),
                ),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) =>
                  ref.read(activityAccountFilterProvider.notifier).state =
                      value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: ref.read(activityCategoryFilterProvider),
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All categories'),
                ),
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) =>
                  ref.read(activityCategoryFilterProvider.notifier).state =
                      value,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(activityTypeFilterProvider.notifier).state = null;
                    ref.read(activityAccountFilterProvider.notifier).state =
                        null;
                    ref.read(activityCategoryFilterProvider.notifier).state =
                        null;
                    Navigator.pop(context);
                  },
                  child: const Text('Clear all'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodKindProvider);
    final visible = selected == ExpensePeriodKind.custom
        ? ExpensePeriodKind.custom
        : selected;
    return SegmentedButton<ExpensePeriodKind>(
      segments: [
        const ButtonSegment(value: ExpensePeriodKind.day, label: Text('Day')),
        const ButtonSegment(value: ExpensePeriodKind.week, label: Text('Week')),
        const ButtonSegment(
          value: ExpensePeriodKind.month,
          label: Text('Month'),
        ),
        if (selected == ExpensePeriodKind.custom)
          const ButtonSegment(
            value: ExpensePeriodKind.custom,
            label: Text('Custom'),
          )
        else
          const ButtonSegment(
            value: ExpensePeriodKind.year,
            label: Text('Year'),
          ),
      ],
      selected: {visible},
      showSelectedIcon: false,
      onSelectionChanged: (value) =>
          ref.read(selectedPeriodKindProvider.notifier).state = value.first,
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = entry.kind == 'income'
        ? WaveColors.income
        : entry.kind == 'transfer'
        ? WaveColors.primary
        : WaveColors.expense;
    final icon = entry.kind == 'income'
        ? Icons.add_rounded
        : entry.kind == 'transfer'
        ? Icons.swap_horiz_rounded
        : Icons.remove_rounded;
    final accountText = entry.kind == 'transfer'
        ? '${entry.accountName} → ${entry.destinationName}'
        : entry.accountName;
    return Dismissible(
      key: ValueKey('${entry.kind}-${entry.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${entry.kind}?'),
          content: const Text('Balances and reports will update immediately.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref
            .read(ledgerRepositoryProvider)
            .deleteActivity(entry.id, entry.kind);
        _invalidateLedger(ref);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: WaveColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        child: ListTile(
          onTap: entry.kind == 'transfer'
              ? null
              : () => _editEntry(context, ref),
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
            '$accountText • ${DateFormat.MMMd().add_jm().format(entry.occurredAt)}',
          ),
          trailing: Text(
            '${entry.kind == 'income'
                ? '+'
                : entry.kind == 'expense'
                ? '-'
                : ''}${Money(entry.amountMinor).format()}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Future<void> _editEntry(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController(
      text: (entry.amountMinor / 100).toStringAsFixed(2),
    );
    final note = TextEditingController(text: entry.note ?? '');
    final categories = entry.kind == 'income'
        ? ref.read(incomeCategoriesProvider).valueOrNull ?? const <Category>[]
        : ref.read(expenseCategoriesProvider).valueOrNull ?? const <Category>[];
    final accounts =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    var categoryId = entry.categoryId;
    var accountId = entry.accountId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${entry.kind}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => accountId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final minor = Money.parseMajorUnits(amount.text);
                if (minor == null ||
                    minor == 0 ||
                    categoryId == null ||
                    accountId == null) {
                  return;
                }
                await ref
                    .read(ledgerRepositoryProvider)
                    .updateEntry(
                      id: entry.id,
                      type: entry.kind == 'income'
                          ? LedgerEntryType.income
                          : LedgerEntryType.expense,
                      amountMinor: minor,
                      accountId: accountId!,
                      categoryId: categoryId!,
                      occurredAt: entry.occurredAt,
                      note: note.text,
                    );
                _invalidateLedger(ref);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
  }
}

void _invalidateLedger(WidgetRef ref) {
  ref.invalidate(totalsProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(expenseReportProvider);
  ref.invalidate(homeBudgetProgressProvider);
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: WaveColors.primary,
            size: 52,
          ),
          SizedBox(height: 16),
          Text(
            'No activity in this period',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'Try another period or clear the active filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WaveColors.muted),
          ),
        ],
      ),
    ),
  );
}

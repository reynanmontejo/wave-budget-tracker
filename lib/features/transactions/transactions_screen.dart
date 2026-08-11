import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/period/expense_period.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(transactionEntriesProvider);
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
                IconButton(
                  onPressed: () {},
                  tooltip: 'Filter transactions',
                  icon: const Icon(Icons.filter_list_rounded),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _PeriodSelector(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const _EmptyLedger(
                title: 'Unable to load transactions',
                message: 'Your data was not changed. Try again.',
              ),
              data: (items) => items.isEmpty
                  ? const _EmptyLedger(
                      title: 'No transactions in this period',
                      message: 'Tap Add to record an expense or income.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _TransactionTile(entry: items[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPeriodKindProvider);
    return SegmentedButton<ExpensePeriodKind>(
      segments: const [
        ButtonSegment(value: ExpensePeriodKind.day, label: Text('Today')),
        ButtonSegment(value: ExpensePeriodKind.week, label: Text('Week')),
        ButtonSegment(value: ExpensePeriodKind.month, label: Text('Month')),
        ButtonSegment(value: ExpensePeriodKind.year, label: Text('Year')),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (value) =>
          ref.read(selectedPeriodKindProvider.notifier).state = value.first,
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.entry});
  final TransactionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = entry.transaction;
    final isIncome = transaction.type == 'income';
    final color = isIncome ? WaveColors.income : WaveColors.expense;
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'The account balance and reports will update immediately.',
          ),
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
        await ref.read(ledgerRepositoryProvider).deleteEntry(transaction.id);
        ref.invalidate(totalsProvider);
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(expenseReportProvider);
        ref.invalidate(homeBudgetProgressProvider);
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
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(isIncome ? Icons.add_rounded : Icons.remove_rounded),
          ),
          title: Text(
            entry.categoryName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${entry.accountName} • ${DateFormat.MMMd().add_jm().format(transaction.occurredAt)}',
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${Money(transaction.amountMinor).format()}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: WaveColors.primary,
            size: 52,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WaveColors.muted),
          ),
        ],
      ),
    ),
  );
}

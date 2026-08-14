import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../core/widgets/confirm_add_dialog.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final progress = ref.watch(budgetProgressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            onPressed: () => _showBudgetDialog(context, ref),
            tooltip: 'Add budget',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(ref, month, -1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    DateFormat.yMMMM().format(month),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(ref, month, 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: progress.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Unable to load budgets.')),
              data: (items) => items.isEmpty
                  ? _EmptyBudgets(onAdd: () => _showBudgetDialog(context, ref))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        _Summary(items: items),
                        const SizedBox(height: 14),
                        for (final item in items) ...[
                          _BudgetCard(
                            progress: item,
                            onEdit: () =>
                                _showBudgetDialog(context, ref, existing: item),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(selectedBudgetMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
    );
  }

  Future<void> _showBudgetDialog(
    BuildContext context,
    WidgetRef ref, {
    BudgetProgress? existing,
  }) async {
    final categories =
        ref.read(expenseCategoriesProvider).valueOrNull ?? const <Category>[];
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an expense category before creating a budget.'),
        ),
      );
      return;
    }
    var categoryId = existing?.budget.categoryId ?? categories.first.id;
    var saving = false;
    final limit = TextEditingController(
      text: existing == null
          ? ''
          : (existing.budget.limitMinor / 100).toStringAsFixed(2),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Create monthly budget'
                : 'Update monthly budget',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Expense category',
                ),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: existing == null
                    ? (value) =>
                          setState(() => categoryId = value ?? categoryId)
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limit,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit',
                  prefixText: '₱ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = Money.parseMajorUnits(limit.text);
                      if (amount == null || amount == 0) {
                        _showDialogMessage(
                          dialogContext,
                          'Enter a budget greater than zero.',
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final categoryName = categories
                            .where((item) => item.id == categoryId)
                            .firstOrNull
                            ?.name;
                        final confirmed = await confirmAdd(
                          dialogContext,
                          title: 'Confirm monthly budget',
                          details: [
                            ('Category', categoryName ?? 'Selected category'),
                            ('Limit', Money(amount).format()),
                          ],
                        );
                        if (!confirmed || !dialogContext.mounted) return;
                        await ref
                            .read(budgetRepositoryProvider)
                            .setMonthlyBudget(
                              categoryId: categoryId,
                              month: ref.read(selectedBudgetMonthProvider),
                              limitMinor: amount,
                            );
                        ref.invalidate(budgetProgressProvider);
                        ref.invalidate(homeBudgetProgressProvider);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          _showDialogMessage(
                            dialogContext,
                            error is ArgumentError
                                ? error.message?.toString() ??
                                      'Check the budget details.'
                                : 'Wave could not save this budget. Please try again.',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(existing == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    limit.dispose();
  }

  void _showDialogMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});
  final List<BudgetProgress> items;
  @override
  Widget build(BuildContext context) {
    final planned = items.fold<int>(
      0,
      (sum, item) => sum + item.budget.limitMinor,
    );
    final spent = items.fold<int>(0, (sum, item) => sum + item.spentMinor);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryValue(
                label: 'Planned',
                value: Money(planned).format(),
              ),
            ),
            const SizedBox(height: 44, child: VerticalDivider()),
            Expanded(
              child: _SummaryValue(
                label: 'Spent',
                value: Money(spent).format(),
              ),
            ),
            const SizedBox(height: 44, child: VerticalDivider()),
            Expanded(
              child: _SummaryValue(
                label: 'Remaining',
                value: Money(planned - spent).format(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(color: WaveColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.progress, required this.onEdit});
  final BudgetProgress progress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    final (label, color) = fraction >= 1
        ? ('Over budget', WaveColors.expense)
        : fraction >= .75
        ? ('Near limit', WaveColors.warning)
        : ('On track', WaveColors.income);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(
                      progress.categoryColorValue,
                    ).withValues(alpha: .12),
                    foregroundColor: Color(progress.categoryColorValue),
                    child: const Icon(Icons.label_outline_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress.categoryName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${Money(progress.spentMinor).format()} / ${Money(progress.budget.limitMinor).format()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: color.withValues(alpha: .12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: const TextStyle(
                      color: WaveColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pie_chart_outline_rounded,
            size: 56,
            color: WaveColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No budgets this month',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Set limits for the categories that matter.',
            style: TextStyle(color: WaveColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Create budget'),
          ),
        ],
      ),
    ),
  );
}

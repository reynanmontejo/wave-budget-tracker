import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../data/savings_repository.dart';
import '../../core/widgets/confirm_add_dialog.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoalForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load savings goals.')),
        data: (items) => items.isEmpty
            ? const _EmptyGoals()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _GoalCard(items[index]),
              ),
      ),
    );
  }

  void _openGoalForm(BuildContext context, [SavingsGoal? goal]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GoalForm(goal: goal),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_outlined, size: 56, color: WaveColors.savings),
          SizedBox(height: 14),
          Text(
            'Start a savings goal',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Track intentional allocations without changing your account balance.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard(this.progress);
  final SavingsGoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = progress.goal;
    final completed = goal.status == SavingsGoalStatus.completed.name;
    return Card(
      child: InkWell(
        onTap: () => _showHistory(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(
                      goal.colorValue,
                    ).withValues(alpha: .14),
                    foregroundColor: Color(goal.colorValue),
                    child: const Icon(Icons.flag_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      final repo = ref.read(savingsRepositoryProvider);
                      if (value == 'edit') {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => _GoalForm(goal: goal),
                        );
                      }
                      if (value == 'complete') {
                        await repo.setStatus(
                          goal.id,
                          SavingsGoalStatus.completed,
                        );
                      }
                      if (value == 'reopen') {
                        await repo.setStatus(goal.id, SavingsGoalStatus.active);
                      }
                      if (value == 'archive') {
                        await repo.setStatus(
                          goal.id,
                          SavingsGoalStatus.archived,
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit goal'),
                      ),
                      PopupMenuItem(
                        value: completed ? 'reopen' : 'complete',
                        child: Text(completed ? 'Reopen' : 'Mark complete'),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: progress.fraction.clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: Color(goal.colorValue),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Money(progress.savedMinor).format()} of ${Money(goal.targetMinor).format()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${(progress.fraction * 100).clamp(0, 999).round()}%'),
                ],
              ),
              if (goal.targetDate != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Target ${DateFormat.yMMMd().format(goal.targetDate!)}',
                  style: const TextStyle(fontSize: 12, color: WaveColors.muted),
                ),
              ],
              if (!completed) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _addContribution(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add contribution'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addContribution(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to ${progress.goal.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₱ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, Money.parseMajorUnits(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result <= 0) return;
    if (!context.mounted) return;
    final confirmed = await confirmAdd(
      context,
      title: 'Confirm contribution',
      details: [
        ('Goal', progress.goal.name),
        ('Amount', Money(result).format()),
      ],
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(savingsRepositoryProvider)
        .addContribution(
          goalId: progress.goal.id,
          amountMinor: result,
          occurredAt: DateTime.now(),
        );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => _ContributionHistory(goal: progress.goal),
    );
  }
}

class _ContributionHistory extends ConsumerWidget {
  const _ContributionHistory({required this.goal});
  final SavingsGoal goal;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<List<SavingsContribution>>(
        stream: ref.read(savingsRepositoryProvider).watchContributions(goal.id),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <SavingsContribution>[];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${goal.name} history',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No contributions yet.'))
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            final item = items[index];
                            final reversed = item.reversedAt != null;
                            return ListTile(
                              leading: Icon(
                                reversed
                                    ? Icons.undo_rounded
                                    : Icons.add_circle_outline,
                                color: reversed
                                    ? WaveColors.muted
                                    : WaveColors.savings,
                              ),
                              title: Text(
                                Money(item.amountMinor).format(),
                                style: TextStyle(
                                  decoration: reversed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat.yMMMd().format(item.occurredAt),
                              ),
                              trailing: reversed
                                  ? const Text('Reversed')
                                  : TextButton(
                                      onPressed: () => ref
                                          .read(savingsRepositoryProvider)
                                          .reverseContribution(item.id),
                                      child: const Text('Reverse'),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.goal});
  final SavingsGoal? goal;
  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final TextEditingController name = TextEditingController(
    text: widget.goal?.name,
  );
  late final TextEditingController target = TextEditingController(
    text: widget.goal == null
        ? ''
        : (widget.goal!.targetMinor / 100).toStringAsFixed(2),
  );
  DateTime? targetDate;
  String? accountId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    targetDate = widget.goal?.targetDate;
    accountId = widget.goal?.linkedAccountId;
  }

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = Money.parseMajorUnits(target.text);
    if (amount == null || amount <= 0 || name.text.trim().isEmpty) return;
    if (widget.goal == null) {
      final confirmed = await confirmAdd(
        context,
        title: 'Confirm savings goal',
        details: [
          ('Goal', name.text.trim()),
          ('Target', Money(amount).format()),
          if (targetDate != null)
            ('Target date', DateFormat.yMMMd().format(targetDate!)),
        ],
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => saving = true);
    final repo = ref.read(savingsRepositoryProvider);
    try {
      if (widget.goal == null) {
        await repo.createGoal(
          name: name.text,
          targetMinor: amount,
          targetDate: targetDate,
          linkedAccountId: accountId,
        );
      } else {
        await repo.updateGoal(
          id: widget.goal!.id,
          name: name.text,
          targetMinor: amount,
          targetDate: targetDate,
          linkedAccountId: accountId,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal == null ? 'New savings goal' : 'Edit savings goal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₱ ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: accountId,
              decoration: const InputDecoration(
                labelText: 'Linked account (optional)',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No linked account'),
                ),
                for (final item in accounts)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => accountId = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Target date (optional)'),
              subtitle: Text(
                targetDate == null
                    ? 'No date'
                    : DateFormat.yMMMd().format(targetDate!),
              ),
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate:
                      targetDate ??
                      DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (value != null) setState(() => targetDate = value);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving…' : 'Save goal'),
            ),
          ],
        ),
      ),
    );
  }
}

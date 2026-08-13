import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money.dart';
import '../../core/theme/wave_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/schedule_repository.dart';
import '../../data/providers.dart';
import '../../core/widgets/confirm_add_dialog.dart';

class PlannedScreen extends ConsumerWidget {
  const PlannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(scheduledTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _ScheduleForm(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan activity'),
      ),
      body: schedules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load upcoming activity.')),
        data: (items) => items.isEmpty
            ? const _EmptyPlanned()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ScheduleCard(items[index]),
              ),
      ),
    );
  }
}

class _EmptyPlanned extends StatelessWidget {
  const _EmptyPlanned();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_rounded, size: 54, color: WaveColors.primary),
          SizedBox(height: 14),
          Text(
            'Nothing planned yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Add future income or expenses without changing your current balance.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard(this.item);
  final ScheduledTransaction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = item.nextDueAt.isBefore(DateTime.now());
    final paused = item.status == ScheduleStatus.paused.name;
    final color = item.type == 'income'
        ? WaveColors.income
        : WaveColors.expense;
    Future<void> act(Future<void> Function(ScheduleRepository) action) async {
      try {
        await action(ref.read(scheduleRepositoryProvider));
        ref.invalidate(scheduleForecastProvider);
        ref.invalidate(totalsProvider);
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(dashboardMetricsProvider);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is ArgumentError
                    ? error.message.toString()
                    : error.toString(),
              ),
            ),
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  foregroundColor: color,
                  child: Icon(
                    item.type == 'income'
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.note ??
                            (item.type == 'income'
                                ? 'Upcoming income'
                                : 'Future expense'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        paused
                            ? 'Paused'
                            : overdue
                            ? 'Overdue · ${DateFormat.MMMd().format(item.nextDueAt)}'
                            : 'Due ${DateFormat.MMMd().format(item.nextDueAt)} · ${item.recurrence}',
                        style: TextStyle(
                          color: overdue && !paused ? WaveColors.expense : null,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money(item.amountMinor).format(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => _ScheduleForm(schedule: item),
                      );
                    }
                    if (value == 'post') act((repo) => repo.post(item.id));
                    if (value == 'skip') act((repo) => repo.skip(item.id));
                    if (value == 'pause') {
                      act((repo) => repo.setPaused(item.id, !paused));
                    }
                    if (value == 'reschedule') {
                      showDatePicker(
                        context: context,
                        initialDate: item.nextDueAt.isBefore(DateTime.now())
                            ? DateTime.now()
                            : item.nextDueAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      ).then((date) {
                        if (date != null) {
                          act((repo) => repo.reschedule(item.id, date));
                        }
                      });
                    }
                    if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete planned activity?'),
                          content: Text(
                            'Delete ${item.note ?? (item.type == 'income' ? 'this upcoming income' : 'this planned expense')} and cancel its future reminders?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await act((repo) => repo.delete(item.id));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit schedule'),
                    ),
                    if (!paused)
                      const PopupMenuItem(
                        value: 'post',
                        child: Text('Mark paid / received'),
                      ),
                    if (!paused && item.recurrence != 'none')
                      const PopupMenuItem(
                        value: 'skip',
                        child: Text('Skip occurrence'),
                      ),
                    PopupMenuItem(
                      value: 'pause',
                      child: Text(paused ? 'Resume' : 'Pause'),
                    ),
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Text('Reschedule'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({this.schedule});
  final ScheduledTransaction? schedule;
  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  late final TextEditingController amount;
  late final TextEditingController note;
  late final TextEditingController interval;
  late String type;
  String? accountId;
  String? categoryId;
  late DateTime dueAt;
  late ScheduleRecurrence recurrence;
  DateTime? endAt;
  bool autoPost = false;
  bool reminderEnabled = false;
  int reminderOffsetMinutes = 1440;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    amount = TextEditingController(
      text: schedule == null
          ? ''
          : (schedule.amountMinor / 100).toStringAsFixed(2),
    );
    note = TextEditingController(text: schedule?.note);
    interval = TextEditingController(
      text: (schedule?.recurrenceInterval ?? 1).toString(),
    );
    type = schedule?.type ?? 'expense';
    accountId = schedule?.accountId;
    categoryId = schedule?.categoryId;
    dueAt = schedule?.nextDueAt ?? DateTime.now().add(const Duration(days: 1));
    recurrence = schedule == null
        ? ScheduleRecurrence.none
        : ScheduleRecurrence.values.byName(schedule.recurrence);
    endAt = schedule?.endAt;
    autoPost = schedule?.autoPost ?? false;
    reminderEnabled = schedule?.reminderEnabled ?? false;
    reminderOffsetMinutes = schedule?.reminderOffsetMinutes ?? 1440;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    interval.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final minor = Money.parseMajorUnits(amount.text);
    final repeatEvery = int.tryParse(interval.text) ?? 0;
    if (minor == null ||
        minor <= 0 ||
        accountId == null ||
        categoryId == null ||
        (recurrence != ScheduleRecurrence.none && repeatEvery <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an amount, account, category, and positive repeat interval.',
          ),
        ),
      );
      return;
    }
    if (reminderEnabled) {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow notifications in device settings to enable reminders.',
              ),
            ),
          );
        }
        return;
      }
    }
    if (widget.schedule == null) {
      if (!mounted) return;
      final confirmed = await confirmAdd(
        context,
        title: 'Confirm planned activity',
        details: [
          ('Type', type == 'income' ? 'Upcoming income' : 'Future expense'),
          ('Amount', Money(minor).format()),
          ('Due', DateFormat.yMMMd().format(dueAt)),
          ('Repeat', recurrence.name),
        ],
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => saving = true);
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      if (widget.schedule == null) {
        await repository.create(
          type: type,
          amountMinor: minor,
          accountId: accountId!,
          categoryId: categoryId!,
          nextDueAt: dueAt,
          recurrence: recurrence,
          recurrenceInterval: recurrence == ScheduleRecurrence.none
              ? 1
              : repeatEvery,
          endAt: endAt,
          note: note.text,
          autoPost: autoPost,
          reminderEnabled: reminderEnabled,
          reminderOffsetMinutes: reminderEnabled ? reminderOffsetMinutes : null,
        );
      } else {
        await repository.update(
          id: widget.schedule!.id,
          type: type,
          amountMinor: minor,
          accountId: accountId!,
          categoryId: categoryId!,
          nextDueAt: dueAt,
          recurrence: recurrence,
          recurrenceInterval: recurrence == ScheduleRecurrence.none
              ? 1
              : repeatEvery,
          endAt: endAt,
          note: note.text,
          autoPost: autoPost,
          reminderEnabled: reminderEnabled,
          reminderOffsetMinutes: reminderEnabled ? reminderOffsetMinutes : null,
        );
      }
      ref.invalidate(scheduleForecastProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final categories =
        ref
            .watch(
              type == 'income'
                  ? incomeCategoriesProvider
                  : expenseCategoriesProvider,
            )
            .valueOrNull ??
        const <Category>[];
    accountId ??= accounts.firstOrNull?.id;
    if (!categories.any((item) => item.id == categoryId)) {
      categoryId = categories.firstOrNull?.id;
    }
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
              widget.schedule == null
                  ? 'Plan future activity'
                  : 'Edit planned activity',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() {
                type = value.first;
                categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
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
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final item in accounts)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => accountId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$type'),
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final item in categories)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => categoryId = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Due date'),
              subtitle: Text(DateFormat.yMMMd().format(dueAt)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: dueAt,
                  firstDate: widget.schedule == null
                      ? DateTime.now()
                      : DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => dueAt = date);
              },
            ),
            DropdownButtonFormField<ScheduleRecurrence>(
              initialValue: recurrence,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: [
                for (final item in ScheduleRecurrence.values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      item == ScheduleRecurrence.custom
                          ? 'Custom (days)'
                          : item.name,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => recurrence = value ?? ScheduleRecurrence.none),
            ),
            if (recurrence != ScheduleRecurrence.none) ...[
              const SizedBox(height: 12),
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Repeat every',
                  suffixText: switch (recurrence) {
                    ScheduleRecurrence.daily ||
                    ScheduleRecurrence.custom => 'day(s)',
                    ScheduleRecurrence.weekly => 'week(s)',
                    ScheduleRecurrence.monthly => 'month(s)',
                    ScheduleRecurrence.yearly => 'year(s)',
                    ScheduleRecurrence.none => null,
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('End date (optional)'),
                subtitle: Text(
                  endAt == null
                      ? 'No end date'
                      : DateFormat.yMMMd().format(endAt!),
                ),
                trailing: endAt == null
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => endAt = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: endAt ?? dueAt,
                    firstDate: dueAt,
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => endAt = date);
                },
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: autoPost,
              onChanged: (value) => setState(() => autoPost = value),
              title: const Text('Post automatically'),
              subtitle: const Text(
                'Creates the transaction when Wave next opens after it is due.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reminderEnabled,
              onChanged: (value) => setState(() => reminderEnabled = value),
              title: const Text('Reminder'),
              subtitle: const Text(
                'Show a device notification before this activity is due.',
              ),
            ),
            if (reminderEnabled)
              DropdownButtonFormField<int>(
                initialValue: reminderOffsetMinutes,
                decoration: const InputDecoration(labelText: 'Remind me'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('When due')),
                  const DropdownMenuItem(
                    value: 60,
                    child: Text('1 hour before'),
                  ),
                  const DropdownMenuItem(
                    value: 1440,
                    child: Text('1 day before'),
                  ),
                  const DropdownMenuItem(
                    value: 10080,
                    child: Text('1 week before'),
                  ),
                  if (!const {
                    0,
                    60,
                    1440,
                    10080,
                  }.contains(reminderOffsetMinutes))
                    DropdownMenuItem(
                      value: reminderOffsetMinutes,
                      child: Text('$reminderOffsetMinutes minutes before'),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => reminderOffsetMinutes = value ?? 1440),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving…' : 'Save planned activity'),
            ),
          ],
        ),
      ),
    );
  }
}

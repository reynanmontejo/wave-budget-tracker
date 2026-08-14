import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';
import 'schedule_notification_service.dart';

enum ScheduleRecurrence { none, daily, weekly, monthly, yearly, custom }

enum ScheduleStatus { active, paused, completed }

final class AutoPostReport {
  const AutoPostReport({required this.posted, required this.failures});
  final int posted;
  final List<String> failures;
}

final class ScheduleForecast {
  const ScheduleForecast({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.items,
    required this.occurrences,
  });

  final int incomeMinor;
  final int expenseMinor;
  final List<ScheduledTransaction> items;
  final List<ScheduleForecastOccurrence> occurrences;
  int get netMinor => incomeMinor - expenseMinor;
}

final class ScheduleForecastOccurrence {
  const ScheduleForecastOccurrence({
    required this.schedule,
    required this.dueAt,
  });
  final ScheduledTransaction schedule;
  final DateTime dueAt;
}

final class ScheduleRepository {
  ScheduleRepository(
    this.database, {
    ScheduleNotificationGateway? notifications,
  }) : _uuid = const Uuid(),
       _notifications =
           notifications ?? const NoopScheduleNotificationGateway();

  final AppDatabase database;
  final Uuid _uuid;
  final ScheduleNotificationGateway _notifications;

  Stream<List<ScheduledTransaction>> watchActive() =>
      (database.select(database.scheduledTransactions)
            ..where(
              (row) => row.status.isNotValue(ScheduleStatus.completed.name),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.nextDueAt)]))
          .watch();

  Future<void> syncAllNotifications() async {
    final schedules = await database
        .select(database.scheduledTransactions)
        .get();
    for (final schedule in schedules) {
      try {
        await _notifications.sync(schedule);
      } catch (_) {
        // One platform alarm must not prevent remaining reminders from syncing.
      }
    }
  }

  Future<void> cancelAllNotifications() => _notifications.cancelAll();

  Future<bool> showTestNotification() async {
    if (!await _notifications.requestPermission()) return false;
    await _notifications.showTestNotification();
    return true;
  }

  Future<bool> scheduleBackupReminder(bool enabled) async {
    if (enabled && !await _notifications.requestPermission()) return false;
    await _notifications.scheduleBackupReminder(enabled);
    return true;
  }

  Future<String> create({
    required String type,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime nextDueAt,
    ScheduleRecurrence recurrence = ScheduleRecurrence.none,
    int recurrenceInterval = 1,
    DateTime? endAt,
    String? note,
    bool autoPost = false,
    bool reminderEnabled = false,
    int? reminderOffsetMinutes,
  }) async {
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Schedule type must be income or expense.');
    }
    if (amountMinor <= 0 || recurrenceInterval <= 0) {
      throw ArgumentError('Amount and recurrence interval must be positive.');
    }
    if (endAt != null && endAt.isBefore(nextDueAt)) {
      throw ArgumentError('End date cannot be before the first due date.');
    }
    await _validateReferences(type, accountId, categoryId);
    final id = _uuid.v4();
    await database
        .into(database.scheduledTransactions)
        .insert(
          ScheduledTransactionsCompanion.insert(
            id: id,
            type: type,
            amountMinor: amountMinor,
            accountId: accountId,
            categoryId: categoryId,
            nextDueAt: nextDueAt,
            recurrence: Value(recurrence.name),
            recurrenceInterval: Value(recurrenceInterval),
            recurrenceAnchorDay: Value(nextDueAt.day),
            endAt: Value(endAt),
            note: Value(_cleanNote(note)),
            autoPost: Value(autoPost),
            reminderEnabled: Value(reminderEnabled),
            reminderOffsetMinutes: Value(reminderOffsetMinutes),
          ),
        );
    await _syncSafely(id);
    return id;
  }

  Future<void> update({
    required String id,
    required String type,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime nextDueAt,
    required ScheduleRecurrence recurrence,
    required int recurrenceInterval,
    DateTime? endAt,
    String? note,
    bool autoPost = false,
    bool reminderEnabled = false,
    int? reminderOffsetMinutes,
  }) async {
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Schedule type must be income or expense.');
    }
    if (amountMinor <= 0 || recurrenceInterval <= 0) {
      throw ArgumentError('Amount and recurrence interval must be positive.');
    }
    if (endAt != null && endAt.isBefore(nextDueAt)) {
      throw ArgumentError('End date cannot be before the next due date.');
    }
    final current = await _get(id);
    if (current.status == ScheduleStatus.completed.name) {
      throw StateError('A completed schedule cannot be edited.');
    }
    await _validateReferences(type, accountId, categoryId);
    final changed =
        await (database.update(
          database.scheduledTransactions,
        )..where((row) => row.id.equals(id))).write(
          ScheduledTransactionsCompanion(
            type: Value(type),
            amountMinor: Value(amountMinor),
            accountId: Value(accountId),
            categoryId: Value(categoryId),
            nextDueAt: Value(nextDueAt),
            recurrence: Value(recurrence.name),
            recurrenceInterval: Value(recurrenceInterval),
            recurrenceAnchorDay: Value(nextDueAt.day),
            endAt: Value(endAt),
            note: Value(_cleanNote(note)),
            autoPost: Value(autoPost),
            reminderEnabled: Value(reminderEnabled),
            reminderOffsetMinutes: Value(
              reminderEnabled ? reminderOffsetMinutes : null,
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed != 1) throw ArgumentError('Schedule not found.');
    await _syncSafely(id);
  }

  Future<int> processDueAutoPosts({
    DateTime? now,
    int safetyLimit = 1000,
  }) async => (await processDueAutoPostsDetailed(
    now: now,
    safetyLimit: safetyLimit,
  )).posted;

  Future<AutoPostReport> processDueAutoPostsDetailed({
    DateTime? now,
    int safetyLimit = 1000,
  }) async {
    final cutoff = now ?? DateTime.now();
    var posted = 0;
    var handled = 0;
    final failures = <String>[];
    while (handled < safetyLimit) {
      final due =
          await (database.select(database.scheduledTransactions)
                ..where(
                  (row) =>
                      row.status.equals(ScheduleStatus.active.name) &
                      row.autoPost.equals(true) &
                      row.nextDueAt.isSmallerOrEqualValue(cutoff),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.nextDueAt)])
                ..limit(1))
              .getSingleOrNull();
      if (due == null) break;
      handled++;
      try {
        await post(due.id, postedAt: due.nextDueAt);
        posted++;
      } on ArgumentError catch (error) {
        failures.add('${due.note ?? due.type}: ${error.message}');
        await _disableInvalidAutoPost(due.id);
      } on StateError catch (error) {
        failures.add('${due.note ?? due.type}: ${error.message}');
        await _disableInvalidAutoPost(due.id);
      } catch (error) {
        failures.add('${due.note ?? due.type}: $error');
        // Keep auto-post enabled so a transient platform/database error can be
        // retried on the next launch or resume without blocking initialization.
        break;
      }
    }
    return AutoPostReport(posted: posted, failures: failures);
  }

  Future<void> _disableInvalidAutoPost(String scheduleId) =>
      (database.update(
        database.scheduledTransactions,
      )..where((row) => row.id.equals(scheduleId))).write(
        ScheduledTransactionsCompanion(
          autoPost: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<String> post(String scheduleId, {DateTime? postedAt}) async {
    final ledgerId = await database.transaction(() async {
      final schedule = await _get(scheduleId);
      if (schedule.status != ScheduleStatus.active.name) {
        throw StateError('Only active schedules can be posted.');
      }
      await _validateReferences(
        schedule.type,
        schedule.accountId,
        schedule.categoryId,
      );
      final alreadyPosted =
          await (database.select(database.scheduledOccurrences)..where(
                (row) =>
                    row.scheduleId.equals(schedule.id) &
                    row.dueAt.equals(schedule.nextDueAt),
              ))
              .getSingleOrNull();
      if (alreadyPosted != null) {
        throw StateError('This occurrence was already handled.');
      }

      final ledgerId = _uuid.v4();
      final effectiveDate = postedAt ?? DateTime.now();
      await database
          .into(database.ledgerTransactions)
          .insert(
            LedgerTransactionsCompanion.insert(
              id: ledgerId,
              accountId: schedule.accountId,
              categoryId: schedule.categoryId,
              type: schedule.type,
              amountMinor: schedule.amountMinor,
              occurredAt: effectiveDate,
              note: Value(_postedNote(schedule.note)),
            ),
          );
      await _recordOccurrence(schedule, 'posted', ledgerId: ledgerId);
      await _advance(schedule, lastPostedAt: effectiveDate);
      return ledgerId;
    });
    await _syncSafely(scheduleId);
    return ledgerId;
  }

  Future<void> skip(String scheduleId) async {
    await database.transaction(() async {
      final schedule = await _get(scheduleId);
      if (schedule.status != ScheduleStatus.active.name) {
        throw StateError('Only active schedules can be skipped.');
      }
      await _recordOccurrence(schedule, 'skipped');
      await _advance(schedule);
    });
    await _syncSafely(scheduleId);
  }

  Future<void> reschedule(String scheduleId, DateTime dueAt) =>
      database.transaction(() async {
        final schedule = await _get(scheduleId);
        if (schedule.status == ScheduleStatus.completed.name) {
          throw StateError('A completed schedule cannot be rescheduled.');
        }
        await _recordOccurrence(schedule, 'rescheduled');
        await (database.update(
          database.scheduledTransactions,
        )..where((row) => row.id.equals(scheduleId))).write(
          ScheduledTransactionsCompanion(
            nextDueAt: Value(dueAt),
            recurrenceAnchorDay: Value(dueAt.day),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _syncSafely(scheduleId);
      });

  Future<void> setPaused(String scheduleId, bool paused) async {
    final schedule = await _get(scheduleId);
    if (schedule.status == ScheduleStatus.completed.name) {
      throw StateError('A completed schedule cannot be changed.');
    }
    await (database.update(
      database.scheduledTransactions,
    )..where((row) => row.id.equals(scheduleId))).write(
      ScheduledTransactionsCompanion(
        status: Value(
          paused ? ScheduleStatus.paused.name : ScheduleStatus.active.name,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _syncSafely(scheduleId);
  }

  Future<void> delete(String scheduleId) async {
    final changed = await (database.delete(
      database.scheduledTransactions,
    )..where((row) => row.id.equals(scheduleId))).go();
    if (changed != 1) throw ArgumentError('Schedule not found.');
    await _cancelSafely(scheduleId);
  }

  Future<ScheduleForecast> forecast(DateTime start, DateTime end) async {
    final rows =
        await (database.select(database.scheduledTransactions)..where(
              (row) =>
                  row.status.equals(ScheduleStatus.active.name) &
                  row.nextDueAt.isSmallerThanValue(end),
            ))
            .get();
    var income = 0;
    var expense = 0;
    final occurrences = <ScheduleForecastOccurrence>[];
    for (final row in rows) {
      var due = _fastForward(row, start);
      while (due.isBefore(end)) {
        if (row.endAt != null && due.isAfter(row.endAt!)) break;
        if (!due.isBefore(start)) {
          occurrences.add(
            ScheduleForecastOccurrence(schedule: row, dueAt: due),
          );
          if (row.type == 'income') {
            income += row.amountMinor;
          } else {
            expense += row.amountMinor;
          }
        }
        final next = _nextDue(
          due,
          ScheduleRecurrence.values.byName(row.recurrence),
          row.recurrenceInterval,
          row.recurrenceAnchorDay ?? due.day,
        );
        if (next == null || (row.endAt != null && next.isAfter(row.endAt!))) {
          break;
        }
        due = next;
      }
    }
    return ScheduleForecast(
      incomeMinor: income,
      expenseMinor: expense,
      items: rows,
      occurrences: occurrences..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
    );
  }

  static DateTime _fastForward(ScheduledTransaction row, DateTime start) {
    final current = row.nextDueAt;
    if (!current.isBefore(start)) return current;
    final recurrence = ScheduleRecurrence.values.byName(row.recurrence);
    final interval = row.recurrenceInterval;
    final anchor = row.recurrenceAnchorDay ?? current.day;
    switch (recurrence) {
      case ScheduleRecurrence.none:
        return current;
      case ScheduleRecurrence.daily:
      case ScheduleRecurrence.custom:
        final steps = start.difference(current).inDays ~/ interval;
        var result = current.add(Duration(days: steps * interval));
        if (result.isBefore(start)) {
          result = result.add(Duration(days: interval));
        }
        return result;
      case ScheduleRecurrence.weekly:
        final days = interval * 7;
        final steps = start.difference(current).inDays ~/ days;
        var result = current.add(Duration(days: steps * days));
        if (result.isBefore(start)) result = result.add(Duration(days: days));
        return result;
      case ScheduleRecurrence.monthly:
        final months =
            (start.year - current.year) * 12 + start.month - current.month;
        final steps = math.max(0, months ~/ interval);
        var result = _monthDate(current, steps * interval, anchor);
        if (result.isBefore(start)) {
          result = _monthDate(result, interval, anchor);
        }
        return result;
      case ScheduleRecurrence.yearly:
        final steps = math.max(0, (start.year - current.year) ~/ interval);
        var result = _yearDate(current, steps * interval, anchor);
        if (result.isBefore(start)) {
          result = _yearDate(result, interval, anchor);
        }
        return result;
    }
  }

  Future<void> _validateReferences(
    String type,
    String accountId,
    String categoryId,
  ) async {
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final category = await (database.select(
      database.categories,
    )..where((row) => row.id.equals(categoryId))).getSingleOrNull();
    if (account == null || account.archivedAt != null) {
      throw ArgumentError('Choose an active account.');
    }
    if (category == null ||
        category.archivedAt != null ||
        category.type != type) {
      throw ArgumentError('Choose a matching active category.');
    }
  }

  Future<ScheduledTransaction> _get(String id) async {
    final item = await (database.select(
      database.scheduledTransactions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null) throw ArgumentError('Schedule not found.');
    return item;
  }

  Future<void> _syncSafely(String id) async {
    try {
      await _notifications.sync(await _get(id));
    } catch (_) {
      // Notification delivery must never roll back or block financial data.
    }
  }

  Future<void> _cancelSafely(String id) async {
    try {
      await _notifications.cancel(id);
    } catch (_) {
      // A stale OS notification is preferable to losing a database mutation.
    }
  }

  Future<void> _recordOccurrence(
    ScheduledTransaction schedule,
    String state, {
    String? ledgerId,
  }) => database
      .into(database.scheduledOccurrences)
      .insert(
        ScheduledOccurrencesCompanion.insert(
          id: _uuid.v4(),
          scheduleId: schedule.id,
          dueAt: schedule.nextDueAt,
          state: state,
          ledgerTransactionId: Value(ledgerId),
        ),
      );

  Future<void> _advance(
    ScheduledTransaction schedule, {
    DateTime? lastPostedAt,
  }) async {
    final recurrence = ScheduleRecurrence.values.byName(schedule.recurrence);
    final next = _nextDue(
      schedule.nextDueAt,
      recurrence,
      schedule.recurrenceInterval,
      schedule.recurrenceAnchorDay ?? schedule.nextDueAt.day,
    );
    final completed =
        next == null ||
        (schedule.endAt != null && next.isAfter(schedule.endAt!));
    await (database.update(
      database.scheduledTransactions,
    )..where((row) => row.id.equals(schedule.id))).write(
      ScheduledTransactionsCompanion(
        nextDueAt: next == null ? const Value.absent() : Value(next),
        status: Value(
          completed
              ? ScheduleStatus.completed.name
              : ScheduleStatus.active.name,
        ),
        lastPostedAt: lastPostedAt == null
            ? const Value.absent()
            : Value(lastPostedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static DateTime? _nextDue(
    DateTime current,
    ScheduleRecurrence recurrence,
    int interval,
    int anchorDay,
  ) => switch (recurrence) {
    ScheduleRecurrence.none => null,
    ScheduleRecurrence.daily ||
    ScheduleRecurrence.custom => current.add(Duration(days: interval)),
    ScheduleRecurrence.weekly => current.add(Duration(days: 7 * interval)),
    ScheduleRecurrence.monthly => _monthDate(current, interval, anchorDay),
    ScheduleRecurrence.yearly => _yearDate(current, interval, anchorDay),
  };

  static DateTime _monthDate(DateTime current, int interval, int anchorDay) {
    final first = DateTime(
      current.year,
      current.month + interval,
      1,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(
      first.year,
      first.month,
      math.min(anchorDay, lastDay),
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  static DateTime _yearDate(DateTime current, int interval, int anchorDay) {
    final year = current.year + interval;
    final lastDay = DateTime(year, current.month + 1, 0).day;
    return DateTime(
      year,
      current.month,
      math.min(anchorDay, lastDay),
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  static String? _cleanNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _postedNote(String? note) =>
      note == null ? 'Posted from planned activity' : '$note (planned)';
}

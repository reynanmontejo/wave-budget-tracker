import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'database/app_database.dart';

abstract interface class ScheduleNotificationGateway {
  Future<bool> requestPermission();
  Future<void> sync(ScheduledTransaction schedule);
  Future<void> cancel(String scheduleId);
  Future<void> cancelAll();
  Future<void> showTestNotification();
  Future<void> scheduleBackupReminder(bool enabled);
}

final class NoopScheduleNotificationGateway
    implements ScheduleNotificationGateway {
  const NoopScheduleNotificationGateway();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(ScheduledTransaction schedule) async {}

  @override
  Future<void> cancel(String scheduleId) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> showTestNotification() async {}

  @override
  Future<void> scheduleBackupReminder(bool enabled) async {}
}

final class DeviceScheduleNotificationService
    implements ScheduleNotificationGateway {
  DeviceScheduleNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'wave_planned_activity';
  static const _channelName = 'Planned activity';
  static const _channelDescription =
      'Reminders for upcoming expenses and expected income.';
  static const _backupReminderId = 0x57415645;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final current = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(current.identifier));
    } catch (_) {
      // timezone defaults to UTC if the device zone cannot be resolved.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  @override
  Future<void> sync(ScheduledTransaction schedule) async {
    await initialize();
    final id = notificationId(schedule.id);
    await _plugin.cancel(id: id);
    if (!schedule.reminderEnabled || schedule.status != 'active') return;

    final offset = Duration(minutes: schedule.reminderOffsetMinutes ?? 0);
    var fireAt = schedule.nextDueAt.subtract(offset);
    final now = DateTime.now();
    if (!fireAt.isAfter(now)) {
      fireAt = now.add(const Duration(seconds: 2));
    }
    final kind = schedule.type == 'income' ? 'income' : 'expense';
    await _plugin.zonedSchedule(
      id: id,
      title: schedule.type == 'income'
          ? 'Upcoming income reminder'
          : 'Upcoming expense reminder',
      body: schedule.note == null
          ? 'Your planned $kind is coming up.'
          : '${schedule.note} is coming up.',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'schedule:${schedule.id}',
    );
  }

  @override
  Future<void> cancel(String scheduleId) async {
    await initialize();
    await _plugin.cancel(id: notificationId(scheduleId));
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      id: 0x57415644,
      title: 'Wave reminders are working',
      body: 'You will receive reminders for planned activity you enable.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> scheduleBackupReminder(bool enabled) async {
    await initialize();
    await _plugin.cancel(id: _backupReminderId);
    if (!enabled) return;
    final fireAt = tz.TZDateTime.now(tz.local).add(const Duration(days: 7));
    await _plugin.zonedSchedule(
      id: _backupReminderId,
      title: 'Time to back up Wave',
      body: 'Create and store a recent backup outside your phone.',
      scheduledDate: fireAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'backup-reminder',
    );
  }

  static int notificationId(String scheduleId) {
    var hash = 0x811C9DC5;
    for (final unit in scheduleId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}

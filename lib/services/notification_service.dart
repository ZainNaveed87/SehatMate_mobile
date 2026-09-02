import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/demo_data.dart';
import '../localization/app_strings.dart';
import '../localization/language_controller.dart';

class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.permissionGranted,
    required this.exactAlarmGranted,
    required this.scheduledCount,
  });

  final bool permissionGranted;
  final bool exactAlarmGranted;
  final int scheduledCount;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (_) {
      // tz.local remains usable when the OS timezone identifier is unavailable.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  Future<NotificationScheduleResult> scheduleNextOccurrences({
    required String planId,
    required List<DemoTask> tasks,
  }) async {
    if (kIsWeb) {
      return const NotificationScheduleResult(permissionGranted: false, exactAlarmGranted: false, scheduledCount: 0);
    }
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notificationsAllowed = await android?.requestNotificationsPermission() ?? true;
    if (!notificationsAllowed) {
      return const NotificationScheduleResult(permissionGranted: false, exactAlarmGranted: false, scheduledCount: 0);
    }
    final exactAlarmAllowed = await android?.requestExactAlarmsPermission() ?? true;
    if (!exactAlarmAllowed) {
      return const NotificationScheduleResult(permissionGranted: true, exactAlarmGranted: false, scheduledCount: 0);
    }

    var scheduled = 0;
    final language = LanguageController.instance.language;
    for (final task in tasks.where((item) => item.status == TaskStatus.ready)) {
      final time = _parseClockTime(task.time);
      if (time == null) continue;
      final occurrence = _nextOccurrence(task.day, time.$1, time.$2);
      if (occurrence == null) continue;
      await _plugin.zonedSchedule(
        id: _notificationId(planId, task.id),
        title: task.kind == TaskKind.medicine
            ? AppStrings.get('notification_medicine_reminder_title', language)
            : AppStrings.get('notification_care_plan_reminder_title', language),
        body: '${task.title} · ${_formatClock(time.$1, time.$2)}',
        scheduledDate: occurrence,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'sehatmate_care_reminders',
            AppStrings.get('notification_care_reminders_channel', language),
            channelDescription: AppStrings.get(
              'notification_care_reminders_channel_description',
              language,
            ),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'care-plan:$planId;task:${task.id}',
      );
      scheduled++;
    }
    return NotificationScheduleResult(permissionGranted: true, exactAlarmGranted: true, scheduledCount: scheduled);
  }

  Future<void> cancelPlan(String planId) async {
    if (kIsWeb) return;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith('care-plan:$planId;') == true) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  (int, int)? _parseClockTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return (hour, minute);
  }

  tz.TZDateTime? _nextOccurrence(String rawDate, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final date = DateTime.tryParse(rawDate);
    var next = date == null
        ? tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        : tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
    if (!next.isAfter(now) && date == null) next = next.add(const Duration(days: 1));
    if (!next.isAfter(now)) return null;
    return next;
  }

  int _notificationId(String planId, String taskId) =>
      Object.hash(planId, taskId) & 0x7fffffff;

  String _formatClock(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

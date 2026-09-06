import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_routes.dart';
import 'auth_service.dart';
import 'care_plan_service.dart';
import 'document_service.dart';
import 'family_care_service.dart';
import 'notification_service.dart';
import 'progress_service.dart';

typedef TaskOccurrenceLoader =
    Future<CareTaskAppDayData> Function({DateTime? date});
typedef ProgressSummaryLoader = Future<ProgressSummary> Function({int days});
typedef DocumentListLoader = Future<List<CareDocument>> Function();
typedef FamilyHomeLoader = Future<FamilyHomeData> Function();
typedef NotificationPermissionLoader =
    Future<NotificationPermissionSnapshot> Function();

class NotificationCenterException implements Exception {
  const NotificationCenterException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.titleKey,
    required this.messageKey,
    required this.createdAt,
    this.values = const {},
    this.route,
    this.read = false,
  });

  final String id;
  final String type;
  final String titleKey;
  final String messageKey;
  final Map<String, Object?> values;
  final DateTime createdAt;
  final String? route;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      titleKey: titleKey,
      messageKey: messageKey,
      values: values,
      createdAt: createdAt,
      route: route,
      read: read ?? this.read,
    );
  }
}

abstract interface class NotificationCenterClient {
  Future<List<AppNotification>> loadNotifications();
  Future<void> markRead(String id);
  Future<void> markAllRead(Iterable<String> ids);
}

abstract interface class NotificationReadStore {
  Future<Set<String>> readIds(String key);
  Future<void> writeIds(String key, Set<String> ids);
}

class SharedPreferencesNotificationReadStore implements NotificationReadStore {
  const SharedPreferencesNotificationReadStore();

  @override
  Future<Set<String>> readIds(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(key);
    if (rawList != null) return rawList.toSet();

    final rawJson = prefs.getString(key);
    if (rawJson == null || rawJson.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toSet();
      }
    } catch (_) {
      return <String>{};
    }
    return <String>{};
  }

  @override
  Future<void> writeIds(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setStringList(key, ids.toList()..sort());
    if (!saved) {
      throw const NotificationCenterException(
        'Notification read state could not be saved.',
      );
    }
  }
}

class NotificationCenterService implements NotificationCenterClient {
  NotificationCenterService({
    TaskOccurrenceLoader? taskLoader,
    ProgressSummaryLoader? progressLoader,
    DocumentListLoader? documentLoader,
    FamilyHomeLoader? familyLoader,
    NotificationPermissionLoader? permissionLoader,
    NotificationReadStore? readStore,
    String? Function()? userIdProvider,
    DateTime Function()? nowProvider,
  }) : _taskLoader =
           taskLoader ?? CarePlanService.instance.fetchAllTaskOccurrences,
       _progressLoader =
           progressLoader ?? ProgressService.instance.fetchSummary,
       _documentLoader =
           documentLoader ?? DocumentService.instance.listDocuments,
       _familyLoader = familyLoader ?? FamilyCareService.instance.fetchHome,
       _permissionLoader =
           permissionLoader ?? NotificationService.instance.permissionStatus,
       _readStore = readStore ?? const SharedPreferencesNotificationReadStore(),
       _userIdProvider =
           userIdProvider ?? (() => AuthSession.instance.user?.id),
       _nowProvider = nowProvider ?? DateTime.now;

  static final NotificationCenterService instance = NotificationCenterService();

  static const _readKeyPrefix = 'sehatmate_notification_center_read_ids_v1';

  final TaskOccurrenceLoader _taskLoader;
  final ProgressSummaryLoader _progressLoader;
  final DocumentListLoader _documentLoader;
  final FamilyHomeLoader _familyLoader;
  final NotificationPermissionLoader _permissionLoader;
  final NotificationReadStore _readStore;
  final String? Function() _userIdProvider;
  final DateTime Function() _nowProvider;

  @override
  Future<List<AppNotification>> loadNotifications() async {
    final readIds = await _readStore.readIds(_readKey);
    final now = _nowProvider();

    try {
      final taskDay = await _taskLoader(date: null);
      final progress = await _progressLoader(days: 7);
      final documents = await _documentLoader();
      final family = await _familyLoader();
      final notifications = <AppNotification>[
        ..._taskNotifications(taskDay, now),
        ..._progressNotifications(progress, now),
        ..._documentNotifications(documents, now),
        ..._familyNotifications(family, now),
      ];

      final permissions = await _permissionSnapshot();
      if (permissions.notificationsDisabled) {
        notifications.add(_permissionNotification(now));
      }

      notifications.sort((a, b) {
        final compared = b.createdAt.compareTo(a.createdAt);
        return compared == 0 ? a.id.compareTo(b.id) : compared;
      });

      return notifications.take(50).map((notification) {
        return notification.copyWith(read: readIds.contains(notification.id));
      }).toList();
    } catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> markRead(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    final ids = await _readStore.readIds(_readKey);
    ids.add(cleanId);
    await _readStore.writeIds(_readKey, ids);
  }

  @override
  Future<void> markAllRead(Iterable<String> ids) async {
    final current = await _readStore.readIds(_readKey);
    current.addAll(ids.map((id) => id.trim()).where((id) => id.isNotEmpty));
    await _readStore.writeIds(_readKey, current);
  }

  String get _readKey {
    final userId = _userIdProvider()?.trim();
    return '$_readKeyPrefix:${userId == null || userId.isEmpty ? 'local' : userId}';
  }

  Future<NotificationPermissionSnapshot> _permissionSnapshot() async {
    try {
      return await _permissionLoader();
    } catch (_) {
      return const NotificationPermissionSnapshot(
        supported: false,
        notificationsEnabled: true,
        exactAlarmEnabled: true,
      );
    }
  }

  List<AppNotification> _taskNotifications(
    CareTaskAppDayData taskDay,
    DateTime now,
  ) {
    return taskDay.occurrences
        .map((occurrence) => _taskNotification(occurrence, now))
        .whereType<AppNotification>()
        .toList();
  }

  AppNotification? _taskNotification(
    CareTaskOccurrence occurrence,
    DateTime now,
  ) {
    if (occurrence.completed || occurrence.skipped) return null;

    final dueAt = _dueAt(occurrence) ?? now;
    final taskValues = {
      'task': occurrence.title,
      'time': _displayTime(occurrence.scheduledTime),
    };
    final route = occurrence.carePlanId.isEmpty
        ? AppRoutes.calendar
        : AppRoutes.carePlan(occurrence.carePlanId);

    if (occurrence.missed) {
      return AppNotification(
        id: 'task-missed:${occurrence.id}',
        type: 'task_missed',
        titleKey: 'notification_center_task_missed_title',
        messageKey: 'notification_center_task_missed_message',
        values: taskValues,
        createdAt: dueAt,
        route: route,
      );
    }

    if (occurrence.pending && _isOverdue(occurrence, now)) {
      return AppNotification(
        id: 'task-overdue:${occurrence.id}',
        type: 'task_overdue',
        titleKey: 'notification_center_task_overdue_title',
        messageKey: 'notification_center_task_overdue_message',
        values: taskValues,
        createdAt: dueAt,
        route: route,
      );
    }

    if (occurrence.pending) {
      return AppNotification(
        id: 'task-due:${occurrence.id}',
        type: 'task_due',
        titleKey: 'notification_center_task_due_title',
        messageKey: 'notification_center_task_due_message',
        values: taskValues,
        createdAt: dueAt,
        route: route,
      );
    }

    return null;
  }

  List<AppNotification> _progressNotifications(
    ProgressSummary summary,
    DateTime now,
  ) {
    final openCount = summary.gaps.open + summary.gaps.inProgress;
    if (summary.activePlanCount == 0 || openCount <= 0) {
      return const [];
    }

    return [
      AppNotification(
        id: 'care-gaps:${summary.date}:$openCount',
        type: 'care_gap',
        titleKey: 'notification_center_care_gap_title',
        messageKey: 'notification_center_care_gap_message',
        values: {'count': openCount},
        createdAt: now,
        route: AppRoutes.careGaps,
      ),
    ];
  }

  List<AppNotification> _documentNotifications(
    List<CareDocument> documents,
    DateTime now,
  ) {
    final notifications = <AppNotification>[];
    for (final document in documents) {
      final createdAt = document.createdAt ?? now;
      if (document.processingStatus == 'failed') {
        notifications.add(
          AppNotification(
            id: 'document-failed:${document.id}',
            type: 'document_failed',
            titleKey: 'notification_center_document_failed_title',
            messageKey: 'notification_center_document_failed_message',
            values: {'document': document.originalName},
            createdAt: createdAt,
            route: AppRoutes.documents,
          ),
        );
      } else if (document.processingStatus == 'processed' &&
          document.hasVerifiedInstructions) {
        notifications.add(
          AppNotification(
            id: 'document-ready:${document.id}:${document.verifiedInstructionCount}',
            type: 'document_ready',
            titleKey: 'notification_center_document_ready_title',
            messageKey: 'notification_center_document_ready_message',
            values: {
              'document': document.originalName,
              'count': document.verifiedInstructionCount,
            },
            createdAt: createdAt,
            route: AppRoutes.documents,
          ),
        );
      }
    }
    return notifications;
  }

  List<AppNotification> _familyNotifications(
    FamilyHomeData family,
    DateTime now,
  ) {
    return family.pendingInvitations
        .map(
          (invitation) => AppNotification(
            id: 'family-invitation:${invitation.id}',
            type: 'family_invitation',
            titleKey: 'notification_center_family_invitation_title',
            messageKey: 'notification_center_family_invitation_message',
            createdAt: invitation.createdAt ?? now,
            route: AppRoutes.family,
          ),
        )
        .toList();
  }

  AppNotification _permissionNotification(DateTime now) {
    return AppNotification(
      id: 'system-notifications-disabled',
      type: 'permission',
      titleKey: 'notification_center_permission_title',
      messageKey: 'notification_center_permission_message',
      createdAt: now,
      route: AppRoutes.settings,
    );
  }

  DateTime? _dueAt(CareTaskOccurrence occurrence) {
    final date = DateTime.tryParse(occurrence.occurrenceDate);
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(occurrence.scheduledTime);
    if (date == null || match == null) return date;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return date;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isOverdue(CareTaskOccurrence occurrence, DateTime now) {
    final dueAt = _dueAt(occurrence);
    if (dueAt == null) return false;
    return dueAt.add(const Duration(minutes: 45)).isBefore(now);
  }

  String _displayTime(String scheduledTime) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(scheduledTime);
    if (match == null) return scheduledTime.isEmpty ? 'today' : scheduledTime;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return scheduledTime;
    }
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  NotificationCenterException _mapException(Object error) {
    if (error is NotificationCenterException) return error;
    if (error is CarePlanException) {
      return NotificationCenterException(
        error.message,
        retryable: error.retryable,
      );
    }
    if (error is ProgressException) {
      return NotificationCenterException(
        error.message,
        retryable: error.retryable,
      );
    }
    if (error is DocumentException) {
      return NotificationCenterException(
        error.message,
        retryable: error.retryable,
      );
    }
    if (error is FamilyCareException) {
      return NotificationCenterException(error.message);
    }
    if (error is AuthException) {
      return NotificationCenterException(error.message);
    }
    return const NotificationCenterException(
      'Notifications could not be loaded. Please try again.',
    );
  }
}

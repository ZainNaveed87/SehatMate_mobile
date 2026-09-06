import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:sehatmate_ai/services/document_service.dart';
import 'package:sehatmate_ai/services/family_care_service.dart';
import 'package:sehatmate_ai/services/notification_center_service.dart';
import 'package:sehatmate_ai/services/notification_service.dart';
import 'package:sehatmate_ai/services/progress_service.dart';

void main() {
  test(
    'does not fabricate notifications when real sources are empty',
    () async {
      final service = _service();

      final notifications = await service.loadNotifications();

      expect(notifications, isEmpty);
      expect(
        notifications.any((item) => item.titleKey.contains('demo')),
        isFalse,
      );
    },
  );

  test(
    'builds task notifications only from real task occurrence state',
    () async {
      final now = DateTime(2026, 9, 6, 12);
      final service = _service(
        now: now,
        tasks: [
          _task(id: 'due', time: '13:00', status: 'pending'),
          _task(id: 'overdue', time: '08:00', status: 'pending'),
          _task(id: 'missed', time: '07:00', status: 'missed'),
          _task(id: 'completed', time: '09:00', status: 'completed'),
        ],
      );

      final notifications = await service.loadNotifications();

      expect(notifications.map((item) => item.type), [
        'task_due',
        'task_overdue',
        'task_missed',
      ]);
      expect(
        notifications.any((item) => item.id.contains('completed')),
        isFalse,
      );
      expect(
        notifications.singleWhere((item) => item.type == 'task_due').route,
        '/care-plan/plan-1',
      );
    },
  );

  test('read state is local and independent from task completion', () async {
    final store = _MemoryNotificationReadStore();
    final service = _service(
      store: store,
      tasks: [_task(id: 'due', time: '13:00', status: 'pending')],
    );

    await service.markRead('task-due:due');
    final notifications = await service.loadNotifications();

    expect(notifications.single.read, isTrue);
    expect(notifications.single.type, 'task_due');
    expect(service.lastTaskDay!.occurrences.single.status, 'pending');
  });

  test(
    'builds notifications from gaps, documents, family and permissions',
    () async {
      final service = _service(
        progress: _progress(openGaps: 2, inProgressGaps: 1),
        documents: [
          _document(id: 'ready', status: 'processed', verified: 3),
          _document(id: 'failed', status: 'failed'),
        ],
        family: FamilyHomeData(
          relationships: const [],
          pendingInvitations: [
            FamilyInvitation(
              id: 'invite-1',
              relationshipLabel: 'Daughter',
              status: 'pending',
              inviter: null,
              caregiver: null,
              careRecipient: null,
              requestedScopes: const {},
              createdAt: DateTime(2026, 9, 5, 8),
            ),
          ],
        ),
        permission: const NotificationPermissionSnapshot(
          supported: true,
          notificationsEnabled: false,
          exactAlarmEnabled: true,
        ),
      );

      final types = (await service.loadNotifications())
          .map((item) => item.type)
          .toSet();

      expect(
        types,
        containsAll([
          'care_gap',
          'document_ready',
          'document_failed',
          'family_invitation',
          'permission',
        ]),
      );
    },
  );

  test('maps retryable source errors for the screen', () async {
    final service = NotificationCenterService(
      taskLoader: ({date}) async {
        throw const CarePlanException('Network unavailable', retryable: true);
      },
      progressLoader: ({days = 7}) async => _progress(),
      documentLoader: () async => const [],
      familyLoader: () async =>
          const FamilyHomeData(relationships: [], pendingInvitations: []),
      permissionLoader: () async => const NotificationPermissionSnapshot(
        supported: true,
        notificationsEnabled: true,
        exactAlarmEnabled: true,
      ),
      readStore: _MemoryNotificationReadStore(),
      userIdProvider: () => 'user-1',
    );

    await expectLater(
      service.loadNotifications(),
      throwsA(
        isA<NotificationCenterException>()
            .having((error) => error.message, 'message', 'Network unavailable')
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });
}

_RecordingNotificationCenterService _service({
  DateTime? now,
  List<CareTaskOccurrence> tasks = const [],
  ProgressSummary? progress,
  List<CareDocument> documents = const [],
  FamilyHomeData family = const FamilyHomeData(
    relationships: [],
    pendingInvitations: [],
  ),
  NotificationPermissionSnapshot permission =
      const NotificationPermissionSnapshot(
        supported: true,
        notificationsEnabled: true,
        exactAlarmEnabled: true,
      ),
  _MemoryNotificationReadStore? store,
}) {
  final service = _RecordingNotificationCenterService(
    tasks: tasks,
    progress: progress ?? _progress(),
    documents: documents,
    family: family,
    permission: permission,
    store: store ?? _MemoryNotificationReadStore(),
    now: now ?? DateTime(2026, 9, 6, 9),
  );
  return service;
}

class _RecordingNotificationCenterService extends NotificationCenterService {
  _RecordingNotificationCenterService({
    required List<CareTaskOccurrence> tasks,
    required ProgressSummary progress,
    required List<CareDocument> documents,
    required FamilyHomeData family,
    required NotificationPermissionSnapshot permission,
    required _MemoryNotificationReadStore store,
    required DateTime now,
  }) : super(
         taskLoader: ({date}) async {
           final data = _taskDay(tasks);
           _lastTaskDay = data;
           return data;
         },
         progressLoader: ({days = 7}) async => progress,
         documentLoader: () async => documents,
         familyLoader: () async => family,
         permissionLoader: () async => permission,
         readStore: store,
         userIdProvider: () => 'user-1',
         nowProvider: () => now,
       );

  CareTaskAppDayData? get lastTaskDay => _lastTaskDay;
}

CareTaskAppDayData? _lastTaskDay;

class _MemoryNotificationReadStore implements NotificationReadStore {
  final idsByKey = <String, Set<String>>{};

  @override
  Future<Set<String>> readIds(String key) async {
    return Set<String>.of(idsByKey[key] ?? const {});
  }

  @override
  Future<void> writeIds(String key, Set<String> ids) async {
    idsByKey[key] = Set<String>.of(ids);
  }
}

CareTaskAppDayData _taskDay(List<CareTaskOccurrence> occurrences) {
  return CareTaskAppDayData(
    date: '2026-09-06',
    occurrences: occurrences,
    summary: CareTaskAppDaySummary(
      total: occurrences.length,
      completed: occurrences.where((item) => item.completed).length,
      skipped: occurrences.where((item) => item.skipped).length,
      missed: occurrences.where((item) => item.missed).length,
      pending: occurrences.where((item) => item.pending).length,
      activePlans: 1,
      openCareGaps: 0,
      careReadiness: 90,
    ),
  );
}

CareTaskOccurrence _task({
  required String id,
  required String time,
  required String status,
}) {
  return CareTaskOccurrence(
    id: id,
    carePlanId: 'plan-1',
    scheduleItemId: 'schedule-1',
    occurrenceDate: '2026-09-06',
    scheduledTime: time,
    title: 'Check blood pressure',
    taskKind: 'medicine',
    period: 'morning',
    recurrenceText: 'Daily',
    grounding: 'Verified cuff instruction.',
    status: status,
    completedAt: '',
    completedTime: '',
    outcomeSource: '',
    note: '',
    planTitle: 'Recovery',
  );
}

ProgressSummary _progress({int openGaps = 0, int inProgressGaps = 0}) {
  return ProgressSummary(
    date: '2026-09-06',
    windowDays: 7,
    activePlanCount: 1,
    primaryPlan: const ProgressPlan(id: 'plan-1', title: 'Recovery'),
    readiness: const ProgressScore(available: true, score: 91),
    tasks: const ProgressTasks(
      scheduled: 0,
      completed: 0,
      skipped: 0,
      missed: 0,
      pending: 0,
      completionRate: null,
    ),
    gaps: ProgressGaps(
      total: openGaps + inProgressGaps,
      open: openGaps,
      inProgress: inProgressGaps,
      resolved: 0,
    ),
    understanding: const ProgressUnderstanding(
      available: false,
      score: null,
      planId: null,
      planTitle: null,
    ),
    trend: const ProgressTrend(metric: 'task_completion_rate', points: []),
  );
}

CareDocument _document({
  required String id,
  required String status,
  int verified = 0,
}) {
  return CareDocument(
    id: id,
    carePlanId: 'plan-1',
    carePlanTitle: 'Recovery',
    documentType: 'prescription',
    originalName: '$id.pdf',
    mimeType: 'application/pdf',
    fileSizeBytes: 1024,
    pageCount: null,
    processingStatus: status,
    processingError: null,
    createdAt: DateTime(2026, 9, 6, 7),
    instructionCount: verified,
    verifiedInstructionCount: verified,
  );
}

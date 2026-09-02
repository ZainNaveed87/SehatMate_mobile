import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_data.dart';
import 'auth_service.dart';
import 'care_plan_service.dart';
import 'notification_service.dart';

class ReliableOutcomeResult {
  const ReliableOutcomeResult({
    required this.occurrence,
    required this.queued,
    this.conflictRecovered = false,
  });

  final CareTaskOccurrence occurrence;
  final bool queued;
  final bool conflictRecovered;
}

class CareReliabilityService extends ChangeNotifier {
  CareReliabilityService._();

  static final CareReliabilityService instance = CareReliabilityService._();

  static const _queueKey = 'sehatmate_task_outcome_queue_v1';
  static const _timezoneKey = 'sehatmate_last_timezone_v1';
  static const _notificationSyncKey = 'sehatmate_last_notification_sync_v1';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _started = false;
  bool _online = true;
  bool _syncing = false;
  int _pendingCount = 0;
  String _lastError = '';
  DateTime? _lastNotificationSync;

  bool get online => _online;
  bool get syncing => _syncing;
  int get pendingCount => _pendingCount;
  String get lastError => _lastError;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    _pendingCount = _readQueue(prefs).length;
    _lastNotificationSync =
        DateTime.tryParse(prefs.getString(_notificationSyncKey) ?? '');

    final current = await Connectivity().checkConnectivity();
    _online = _hasConnection(current);
    notifyListeners();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final nextOnline = _hasConnection(results);
      final changed = nextOnline != _online;
      _online = nextOnline;
      if (changed) notifyListeners();
      if (nextOnline) {
        unawaited(syncNow());
      }
    });

    if (_online && AuthSession.instance.isAuthenticated) {
      unawaited(syncNow());
    }
  }

  Future<void> stop() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _started = false;
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  Future<ReliableOutcomeResult> setOutcome(
    CareTaskOccurrence occurrence,
    String status, {
    String note = '',
  }) async {
    final operationKey = _newOperationKey(occurrence.id);

    try {
      final updated =
          await CarePlanService.instance.setTaskOccurrenceOutcome(
        occurrence.id,
        status: status,
        note: note,
        operationKey: operationKey,
        baseStatus: occurrence.status,
      );
      await CarePlanService.instance.applyOptimisticOutcomeToCaches(
        occurrence,
        updated,
      );
      await _removeQueuedForOccurrence(occurrence.id);
      return ReliableOutcomeResult(
        occurrence: updated,
        queued: false,
      );
    } on CarePlanException catch (error) {
      if (error.conflict) {
        final current = error.data?['occurrence'];
        if (current is Map<String, dynamic>) {
          final serverOccurrence =
              CarePlanService.instance.taskOccurrenceFromJson(current);
          await CarePlanService.instance.applyOptimisticOutcomeToCaches(
            occurrence,
            serverOccurrence,
          );
          await _removeQueuedForOccurrence(occurrence.id);
          return ReliableOutcomeResult(
            occurrence: serverOccurrence,
            queued: false,
            conflictRecovered: true,
          );
        }
        rethrow;
      }

      if (!error.retryable) rethrow;

      final optimistic = occurrence.copyWith(
        status: status,
        completedAt:
            status == 'completed' ? DateTime.now().toIso8601String() : '',
        completedTime:
            status == 'completed' ? _clockKey(DateTime.now()) : '',
        outcomeSource: 'offline_pending_sync',
        note: note,
      );

      await _queueOutcome(
        occurrence: occurrence,
        desired: optimistic,
        operationKey: operationKey,
        note: note,
      );
      await CarePlanService.instance.applyOptimisticOutcomeToCaches(
        occurrence,
        optimistic,
      );

      return ReliableOutcomeResult(
        occurrence: optimistic,
        queued: true,
      );
    }
  }

  Future<void> syncNow({bool forceNotifications = false}) async {
    if (_syncing ||
        !_online ||
        !AuthSession.instance.isAuthenticated ||
        AuthSession.instance.isGuest) {
      return;
    }

    _syncing = true;
    _lastError = '';
    notifyListeners();

    try {
      await _flushOutcomeQueue();
      await _reconcileTimezoneAndNotifications(
        force: forceNotifications,
      );
    } on CarePlanException catch (error) {
      _lastError = error.message;
      if (error.retryable) _online = false;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _syncing = false;
      final prefs = await SharedPreferences.getInstance();
      _pendingCount = _readQueue(prefs).length;
      notifyListeners();
    }
  }

  Future<void> onAppResumed() async {
    if (!_started) await start();
    final results = await Connectivity().checkConnectivity();
    _online = _hasConnection(results);
    notifyListeners();
    if (_online) {
      await syncNow();
    }
  }

  Future<void> _queueOutcome({
    required CareTaskOccurrence occurrence,
    required CareTaskOccurrence desired,
    required String operationKey,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);

    Map<String, dynamic>? previous;
    for (final item in queue) {
      if (item['occurrenceId']?.toString() == occurrence.id) {
        previous = item;
        break;
      }
    }

    final baseStatus =
        previous?['baseStatus']?.toString() ?? occurrence.status;

    queue.removeWhere(
      (item) => item['occurrenceId']?.toString() == occurrence.id,
    );

    if (desired.status == baseStatus) {
      await _saveQueue(prefs, queue);
      return;
    }

    queue.add({
      'operationKey': operationKey,
      'occurrenceId': occurrence.id,
      'status': desired.status,
      'note': note,
      'baseStatus': baseStatus,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
      'nextAttemptAt': '',
    });

    if (queue.length > 100) {
      queue.removeRange(0, queue.length - 100);
    }
    await _saveQueue(prefs, queue);
  }

  Future<void> _flushOutcomeQueue() async {
    final prefs = await SharedPreferences.getInstance();
    var queue = _readQueue(prefs);
    if (queue.isEmpty) {
      _pendingCount = 0;
      return;
    }

    final now = DateTime.now().toUtc();
    final remaining = <Map<String, dynamic>>[];

    for (final item in queue) {
      final nextAttemptAt =
          DateTime.tryParse(item['nextAttemptAt']?.toString() ?? '');
      if (nextAttemptAt != null && nextAttemptAt.isAfter(now)) {
        remaining.add(item);
        continue;
      }

      final occurrenceId = item['occurrenceId']?.toString() ?? '';
      final status = item['status']?.toString() ?? '';
      if (occurrenceId.isEmpty ||
          !const {'pending', 'completed', 'skipped'}.contains(status)) {
        continue;
      }

      try {
        await CarePlanService.instance.setTaskOccurrenceOutcome(
          occurrenceId,
          status: status,
          note: item['note']?.toString() ?? '',
          operationKey: item['operationKey']?.toString() ?? '',
          baseStatus: item['baseStatus']?.toString() ?? '',
        );
      } on CarePlanException catch (error) {
        if (error.conflict) {
          continue;
        }
        if (!error.retryable) {
          _lastError = error.message;
          continue;
        }

        final attempts = (item['attempts'] as num?)?.toInt() ?? 0;
        final nextAttempts = attempts + 1;
        final exponent = nextAttempts.clamp(0, 6).toInt();
        final delayMinutes = (1 << exponent).clamp(1, 60).toInt();
        remaining.add({
          ...item,
          'attempts': nextAttempts,
          'nextAttemptAt':
              now.add(Duration(minutes: delayMinutes)).toIso8601String(),
        });
        _lastError = error.message;
      }
    }

    queue = remaining;
    await _saveQueue(prefs, queue);
    _pendingCount = queue.length;
  }

  Future<void> _removeQueuedForOccurrence(String occurrenceId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs)
      ..removeWhere(
        (item) => item['occurrenceId']?.toString() == occurrenceId,
      );
    await _saveQueue(prefs, queue);
  }

  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveQueue(
    SharedPreferences prefs,
    List<Map<String, dynamic>> queue,
  ) async {
    await prefs.setString(_queueKey, jsonEncode(queue));
    _pendingCount = queue.length;
    notifyListeners();
  }

  Future<void> _reconcileTimezoneAndNotifications({
    required bool force,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final timezone = await FlutterTimezone.getLocalTimezone();
    final timezoneId = timezone.identifier;
    final previousTimezone = prefs.getString(_timezoneKey);
    final timezoneChanged =
        previousTimezone != null && previousTimezone != timezoneId;

    final now = DateTime.now();
    final recentlySynced = _lastNotificationSync != null &&
        now.difference(_lastNotificationSync!).inMinutes < 15;

    if (!force && !timezoneChanged && recentlySynced) {
      if (previousTimezone == null) {
        await prefs.setString(_timezoneKey, timezoneId);
      }
      return;
    }

    final plans = await CarePlanService.instance.fetchPlans();
    for (final plan in plans) {
      if (plan.status == PlanStatus.completed) {
        await NotificationService.instance.cancelPlan(plan.id);
        continue;
      }
      if (plan.status != PlanStatus.active) continue;

      final detail =
          await CarePlanService.instance.fetchPlanDetail(plan.id);

      await NotificationService.instance.cancelPlan(plan.id);
      await NotificationService.instance.scheduleNextOccurrences(
        planId: plan.id,
        tasks: detail.tasks,
      );
    }

    _lastNotificationSync = now;
    await prefs.setString(_timezoneKey, timezoneId);
    await prefs.setString(
      _notificationSyncKey,
      now.toIso8601String(),
    );
  }

  String _newOperationKey(String occurrenceId) =>
      'outcome:$occurrenceId:${DateTime.now().microsecondsSinceEpoch}';

  String _clockKey(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

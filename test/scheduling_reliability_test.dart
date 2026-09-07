import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/data/demo_data.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/care_plan_detail_screen.dart';
import 'package:sehatmate_ai/screens/task_outcome_screens.dart';
import 'package:sehatmate_ai/screens/simulation_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthSession.instance.logout();
  });

  test('savePlanDuration sends device local today', () async {
    late Map<String, dynamic> body;
    final service = CarePlanService(
      tokenProvider: () => 'session-token',
      now: () => DateTime(2026, 9, 7, 0, 15),
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/care-plans/10/duration');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'data': <String, dynamic>{}});
      }),
    );

    await service.savePlanDuration('10', mode: 'custom', endDate: '2026-09-07');

    expect(body, {
      'mode': 'custom',
      'endDate': '2026-09-07',
      'today': '2026-09-07',
    });
  });

  test(
    'saveMedicineRecurrence sends structured repeat pattern and local today',
    () async {
      late Map<String, dynamic> body;
      final service = CarePlanService(
        tokenProvider: () => 'session-token',
        now: () => DateTime(2026, 9, 7, 0, 15),
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/schedule-items/701/recurrence');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'data': <String, dynamic>{}});
        }),
      );

      await service.saveMedicineRecurrence(
        '701',
        mode: 'weekdays',
        weekdays: const [1, 3, 5],
      );

      expect(body, {
        'mode': 'weekdays',
        'weekdays': [1, 3, 5],
        'today': '2026-09-07',
      });
    },
  );

  test(
    'calendar occurrence fetch sends selected date and local today',
    () async {
      final service = CarePlanService(
        tokenProvider: () => 'session-token',
        now: () => DateTime(2026, 9, 7, 23, 55),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/task-occurrences');
          expect(request.url.queryParameters['date'], '2026-09-10');
          expect(request.url.queryParameters['today'], '2026-09-07');
          return _jsonResponse({
            'data': {
              'date': '2026-09-10',
              'occurrences': <Map<String, dynamic>>[],
              'summary': {
                'total': 0,
                'completed': 0,
                'skipped': 0,
                'missed': 0,
                'pending': 0,
                'activePlans': 0,
                'openCareGaps': 0,
                'careReadiness': 0,
              },
            },
          });
        }),
      );

      final day = await service.fetchAllTaskOccurrences(
        date: DateTime(2026, 9, 10),
      );

      expect(day.date, '2026-09-10');
    },
  );

  test('simulation calendar args use known finding or task date only', () {
    final direct = simulationCalendarArgsForFinding({
      'action': 'calendar',
      'date': '2026-09-12',
    }, const <DemoTask>[]);
    expect(direct?.initialDate, '2026-09-12');

    final fromTask = simulationCalendarArgsForFinding(
      {'action': 'calendar', 'taskId': 't1'},
      const [
        DemoTask(
          id: 't1',
          day: '2026-09-10',
          time: '10:00',
          title: 'Follow-up',
          note: '',
          kind: TaskKind.visit,
          status: TaskStatus.ready,
        ),
      ],
    );
    expect(fromTask?.initialDate, '2026-09-10');

    expect(
      simulationCalendarArgsForFinding({
        'action': 'calendar',
        'taskId': 'missing',
      }, const <DemoTask>[]),
      isNull,
    );
    expect(
      simulationCalendarArgsForFinding({
        'action': 'calendar',
        'date': '2026-09-10T00:00:00Z',
      }, const <DemoTask>[]),
      isNull,
    );
  });

  test('calendar route date parser rejects malformed initial dates', () {
    expect(
      calendarLocalDateKey(calendarInitialDateFrom('2026-09-07')!),
      '2026-09-07',
    );
    expect(calendarInitialDateFrom('2026-09-07T00:00:00Z'), isNull);
    expect(calendarInitialDateFrom('2026-09-31'), isNull);
    expect(
      calendarLocalDateKey(calendarInitialDateFrom(DateTime(2026, 9, 8, 18))!),
      '2026-09-08',
    );
  });

  testWidgets('calendar opens on initial date and falls back safely', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      initialDate: '2026-09-10',
      now: () => DateTime(2026, 9, 7, 9),
    );
    expect(
      find.byKey(const ValueKey('calendar_day_2026-09-10_selected')),
      findsOneWidget,
    );

    await _pumpCalendar(
      tester,
      initialDate: '2026-09-31',
      now: () => DateTime(2026, 9, 7, 9),
    );
    expect(
      find.byKey(const ValueKey('calendar_day_2026-09-07_selected')),
      findsOneWidget,
    );
  });

  testWidgets(
    'calendar rolls today forward on resume but preserves chosen dates',
    (tester) async {
      var now = DateTime(2026, 9, 7, 23, 58);
      await _pumpCalendar(tester, now: () => now);
      expect(
        find.byKey(const ValueKey('calendar_day_2026-09-07_selected')),
        findsOneWidget,
      );

      now = DateTime(2026, 9, 8, 0, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar_day_2026-09-08_selected')),
        findsOneWidget,
      );

      now = DateTime(2026, 9, 7, 23, 58);
      await _pumpCalendar(tester, initialDate: '2026-09-10', now: () => now);

      now = DateTime(2026, 9, 8, 0, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar_day_2026-09-10_selected')),
        findsOneWidget,
      );
    },
  );

  testWidgets('medicine course duration dialog cancel does not save', (
    tester,
  ) async {
    var patchCount = 0;
    await _pumpCarePlanDetail(
      tester,
      onRequest: (request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/care-plans/10') {
          return _jsonResponse(_carePlanDetailBody());
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/schedule-items/701/duration') {
          patchCount += 1;
          return _jsonResponse({'data': <String, dynamic>{}});
        }
        return http.Response('Not found', 404);
      },
    );

    final setDurationButton = find.text('Set duration');

    await tester.ensureVisible(setDurationButton);
    await tester.pumpAndSettle();

    await tester.tap(setDurationButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Set course duration'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(patchCount, 0);
    expect(find.text('Set duration'), findsOneWidget);
  });

  testWidgets('medicine repeat pattern dialog cancel does not save', (
    tester,
  ) async {
    var patchCount = 0;
    await _pumpCarePlanDetail(
      tester,
      onRequest: (request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/care-plans/10') {
          return _jsonResponse(_carePlanDetailBody());
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/schedule-items/701/recurrence') {
          patchCount += 1;
          return _jsonResponse({'data': <String, dynamic>{}});
        }
        return http.Response('Not found', 404);
      },
    );

    final setRepeatPatternButton = find.text('Set repeat pattern');

    await tester.ensureVisible(setRepeatPatternButton);
    await tester.pumpAndSettle();

    await tester.tap(setRepeatPatternButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Repeat pattern for'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(patchCount, 0);
    expect(find.text('Set repeat pattern'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  Object? initialDate,
  required DateTime Function() now,
}) async {
  await AuthSession.instance.startGuestSession();
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        home: TaskCalendarScreen(
          initialDate: initialDate,
          now: now,
          startReliability: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCarePlanDetail(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request request) onRequest,
}) async {
  final service = CarePlanService(
    tokenProvider: () => 'session-token',
    now: () => DateTime(2026, 9, 7, 9),
    client: MockClient(onRequest),
  );

  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        home: CarePlanDetailScreen(
          planId: '10',
          initialTab: 1,
          carePlanService: service,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _carePlanDetailBody() {
  return {
    'data': {
      'plan': {
        'id': '10',
        'title': 'Recovery Plan',
        'status': 'reality_check',
        'startDate': '2026-09-07',
        'readinessScore': 70,
        'understandingScore': 0,
        'durationMode': 'prescription',
        'suggestedEndDate': null,
        'plannedEndDate': null,
        'createdAt': '2026-09-07',
      },
      'verifiedInstructions': [
        {
          'id': '91',
          'category': 'medicine',
          'title': 'DemoMed',
          'instruction': 'Take DemoMed with breakfast.',
          'timing': 'Morning',
          'review_status': 'verified',
        },
      ],
      'tasks': [
        {
          'id': '701',
          'instruction_id': '91',
          'task_date': '2026-09-07',
          'schedule_date': '2026-09-07',
          'task_time': 'Morning',
          'schedule_time': null,
          'title': 'DemoMed',
          'note': 'Morning',
          'task_kind': 'medicine',
          'display_time': 'Morning',
          'recurrence_text': '',
          'recurrence_mode': null,
          'recurrence_weekdays_json': null,
          'recurrence_interval_days': null,
          'recurrence_month_days_json': null,
          'recurrence_source': null,
          'grounding': 'suggested',
          'time_locked': 0,
          'instruction_duration_days': null,
          'instruction_duration_source': null,
          'status': 'ready',
        },
      ],
      'gaps': <Map<String, dynamic>>[],
      'documents': <Map<String, dynamic>>[],
    },
  };
}

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

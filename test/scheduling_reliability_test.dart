import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/data/demo_data.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
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

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

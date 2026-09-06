import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/data/demo_data.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:sehatmate_ai/services/care_reliability_service.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:sehatmate_ai/services/simple_care_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Simple Care uses real injected task data without demo fallback',
    (tester) async {
      final service = _FakeSimpleCareClient(today: _today([_task()]));
      await _pumpSimpleCare(tester, service: service);

      expect(find.text('Check blood pressure'), findsWidgets);
      expect(find.textContaining('Real recovery plan'), findsWidgets);
      expect(find.text('Morning Medicine'), findsNothing);
      expect(find.text('Your care'), findsOneWidget);
      expect(find.text('Care Plans'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Teach-Back'), findsOneWidget);
      expect(find.text('Family Care'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Complete').first);
      await tester.pumpAndSettle();

      expect(service.outcomeCalls, ['task-1:completed']);
      expect(find.text('Completed'), findsWidgets);
    },
  );

  testWidgets('Simple Care shows truthful empty state', (tester) async {
    await _pumpSimpleCare(
      tester,
      service: _FakeSimpleCareClient(today: _today(const [])),
    );

    expect(find.text('No care tasks today'), findsOneWidget);
    expect(find.text('Morning Medicine'), findsNothing);
  });

  testWidgets('Simple Care shows loading, offline error and retry states', (
    tester,
  ) async {
    final service = _FakeSimpleCareClient.sequence([
      const CarePlanException('Network unavailable', retryable: true),
      _today([_task()]),
    ]);

    await _pumpSimpleCare(tester, service: service, settle: false);

    expect(find.text('Loading today’s care...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Today’s care could not load'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);

    await tester.tap(find.byKey(const Key('simple_care_retry_button')));
    await tester.pumpAndSettle();

    expect(find.text('Check blood pressure'), findsWidgets);
    expect(find.text('Network unavailable'), findsNothing);
  });

  testWidgets('Simple Care keeps missed and gap status visible', (
    tester,
  ) async {
    await _pumpSimpleCare(
      tester,
      service: _FakeSimpleCareClient(
        today: _today(
          [_task(id: 'missed-1', title: 'Follow up call', status: 'missed')],
          missed: 1,
          openCareGaps: 2,
          careReadiness: 61,
        ),
      ),
    );

    expect(find.text('Missed'), findsWidgets);
    expect(find.text('Important status'), findsOneWidget);
    expect(find.text('1 missed item'), findsOneWidget);
    expect(find.text('2 care gap needs review'), findsOneWidget);
    expect(find.text('Care readiness is 61%'), findsOneWidget);
    expect(find.text('Open care plan'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
  });

  testWidgets('Simple Care reflects the persistent mode indicator', (
    tester,
  ) async {
    final settings = SettingsService.forTesting(
      store: _MemorySettingsStore(value: true),
    );
    await settings.initialize();

    await _pumpSimpleCare(
      tester,
      service: _FakeSimpleCareClient(today: _today([_task()])),
      settings: settings,
    );

    expect(find.text('Mode on'), findsOneWidget);

    await settings.setSimpleCareMode(false);
    await tester.pumpAndSettle();

    expect(find.text('Mode off'), findsOneWidget);
  });
}

Future<void> _pumpSimpleCare(
  WidgetTester tester, {
  required SimpleCareClient service,
  SettingsService? settings,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        home: SimpleCareScreen(
          service: service,
          settingsService:
              settings ??
              SettingsService.forTesting(store: _MemorySettingsStore()),
        ),
      ),
    ),
  );
 if (!settle) return;

await tester.pump();
await tester.pumpAndSettle();
}

class _FakeSimpleCareClient implements SimpleCareClient {
  _FakeSimpleCareClient({
    required CareTaskAppDayData today,
    List<DemoPlan>? plans,
  }) : _responses = [today],
       _plans = plans ?? [_plan()];

  _FakeSimpleCareClient.sequence(
    List<Object> responses, {
    List<DemoPlan>? plans,
  }) : _responses = List<Object>.of(responses),
       _plans = plans ?? [_plan()];

  final List<Object> _responses;
  final List<DemoPlan> _plans;
  final outcomeCalls = <String>[];

  @override
  Future<CareTaskAppDayData> fetchTodayCare() async {
    final response = _responses.length > 1
        ? _responses.removeAt(0)
        : _responses.single;
    if (response is CareTaskAppDayData) return response;
    throw response;
  }

  @override
  Future<List<DemoPlan>> fetchCarePlans() async => _plans;

  @override
  Future<ReliableOutcomeResult> setOutcome(
    CareTaskOccurrence occurrence,
    String status,
  ) async {
    outcomeCalls.add('${occurrence.id}:$status');
    return ReliableOutcomeResult(
      occurrence: occurrence.copyWith(status: status),
      queued: false,
    );
  }
}

class _MemorySettingsStore implements SettingsPreferenceStore {
  _MemorySettingsStore({this.value});

  bool? value;

  @override
  Future<bool?> readBool(String key) async => value;

  @override
  Future<void> writeBool(String key, bool value) async {
    this.value = value;
  }
}

CareTaskAppDayData _today(
  List<CareTaskOccurrence> occurrences, {
  int missed = 0,
  int openCareGaps = 0,
  int careReadiness = 88,
}) {
  return CareTaskAppDayData(
    date: _todayDate(),
    occurrences: occurrences,
    summary: CareTaskAppDaySummary(
      total: occurrences.length,
      completed: occurrences.where((item) => item.completed).length,
      skipped: occurrences.where((item) => item.skipped).length,
      missed: missed,
      pending: occurrences.where((item) => item.pending).length,
      activePlans: 1,
      openCareGaps: openCareGaps,
      careReadiness: careReadiness,
    ),
  );
}

CareTaskOccurrence _task({
  String id = 'task-1',
  String title = 'Check blood pressure',
  String status = 'pending',
  String time = '23:59',
}) {
  return CareTaskOccurrence(
    id: id,
    carePlanId: 'plan-1',
    scheduleItemId: 'schedule-1',
    occurrenceDate: _todayDate(),
    scheduledTime: time,
    title: title,
    taskKind: 'medicine',
    period: 'morning',
    recurrenceText: 'Daily',
    grounding: 'Use the verified cuff instructions.',
    status: status,
    completedAt: '',
    completedTime: '',
    outcomeSource: '',
    note: '',
    planTitle: 'Real recovery plan',
  );
}

DemoPlan _plan() {
  return const DemoPlan(
    id: 'plan-1',
    title: 'Real recovery plan',
    status: PlanStatus.active,
    startDate: '2026-09-06',
    readiness: 88,
    nextTask: 'Check blood pressure',
    documents: ['doc-1'],
  );
}

String _todayDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

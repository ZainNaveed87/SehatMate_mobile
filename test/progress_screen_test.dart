import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/library_screens.dart';
import 'package:sehatmate_ai/services/progress_service.dart';

void main() {
  testWidgets('ProgressScreen renders real backend metrics and trend', (
    tester,
  ) async {
    await _pumpProgress(tester, service: _FakeProgressClient(_summary()));

    expect(find.text('Care Readiness'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Task completion trend'), findsOneWidget);
    expect(find.text('Transport'), findsNothing);
    expect(find.text('Care readiness trend'), findsNothing);
  });

  testWidgets('ProgressScreen shows no active care plan state', (tester) async {
    await _pumpProgress(
      tester,
      service: _FakeProgressClient(_summary(activePlanCount: 0)),
    );

    expect(find.text('No active care plan'), findsOneWidget);
  });

  testWidgets('ProgressScreen shows no task data state for null trend values', (
    tester,
  ) async {
    await _pumpProgress(
      tester,
      service: _FakeProgressClient(
        _summary(
          tasks: const ProgressTasks(
            scheduled: 0,
            completed: 0,
            skipped: 0,
            missed: 0,
            pending: 0,
            completionRate: null,
          ),
          trend: const ProgressTrend(
            metric: 'task_completion_rate',
            points: [
              ProgressTrendPoint(
                date: '2026-09-03',
                scheduled: 0,
                completed: 0,
                value: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('No task data yet'), findsOneWidget);
  });

  testWidgets('ProgressScreen shows retryable offline state', (tester) async {
    final service = _FakeProgressClient.sequence([
      const ProgressException('Network unavailable', retryable: true),
      _summary(),
    ]);

    await _pumpProgress(tester, service: service);

    expect(find.text('Progress could not load'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);
    final retryButton = find.byKey(const Key('progress_retry_button'));
    expect(retryButton, findsOneWidget);
    expect(service.fetches, 1);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(service.fetches, 2);
    expect(find.text('Care Readiness'), findsOneWidget);
    expect(find.text('Network unavailable'), findsNothing);
  });
}

Future<void> _pumpProgress(
  WidgetTester tester, {
  required ProgressClient service,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(home: ProgressScreen(service: service)),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FakeProgressClient implements ProgressClient {
  _FakeProgressClient(ProgressSummary summary) : _responses = [summary];
  _FakeProgressClient.sequence(List<Object> responses)
    : _responses = List<Object>.of(responses);

  final List<Object> _responses;
  var fetches = 0;

  @override
  Future<ProgressSummary> fetchSummary({int days = 7}) async {
    fetches += 1;
    final response = _responses.length >= fetches
        ? _responses[fetches - 1]
        : _responses.last;
    if (response is ProgressSummary) return response;
    throw response;
  }
}

ProgressSummary _summary({
  int activePlanCount = 1,
  ProgressTasks tasks = const ProgressTasks(
    scheduled: 5,
    completed: 2,
    skipped: 1,
    missed: 1,
    pending: 1,
    completionRate: 40,
  ),
  ProgressTrend trend = const ProgressTrend(
    metric: 'task_completion_rate',
    points: [
      ProgressTrendPoint(
        date: '2026-08-28',
        scheduled: 1,
        completed: 1,
        value: 100,
      ),
      ProgressTrendPoint(
        date: '2026-09-03',
        scheduled: 0,
        completed: 0,
        value: null,
      ),
    ],
  ),
}) {
  return ProgressSummary(
    date: '2026-09-03',
    windowDays: 7,
    activePlanCount: activePlanCount,
    primaryPlan: activePlanCount == 0
        ? null
        : const ProgressPlan(id: '3', title: 'Recovery'),
    readiness: activePlanCount == 0
        ? const ProgressScore(available: false, score: null)
        : const ProgressScore(available: true, score: 84),
    tasks: tasks,
    gaps: const ProgressGaps(total: 3, open: 2, inProgress: 1, resolved: 1),
    understanding: const ProgressUnderstanding(
      available: true,
      score: 90,
      planId: '3',
      planTitle: 'Recovery',
    ),
    trend: trend,
  );
}

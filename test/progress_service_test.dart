import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/services/progress_service.dart';

void main() {
  group('ProgressService', () {
    test('fetchSummary sends auth and parses real progress payload', () async {
      final service = ProgressService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/progress/summary');
          expect(request.url.queryParameters['days'], '7');
          expect(request.headers['Authorization'], 'Bearer session-token');
          expect(request.url.queryParameters.containsKey('userId'), isFalse);

          return _jsonResponse({'data': _summaryJson()});
        }),
      );

      final summary = await service.fetchSummary();

      expect(summary.activePlanCount, 1);
      expect(summary.primaryPlan?.title, 'Recovery');
      expect(summary.readiness.score, 84);
      expect(summary.tasks.completionRate, 40);
      expect(summary.gaps.inProgress, 1);
      expect(summary.understanding.score, 90);
      expect(summary.trend.points.last.value, isNull);
    });

    test('throws before HTTP when no auth token is available', () async {
      var called = false;
      final service = ProgressService(
        tokenProvider: () => null,
        client: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      );

      await expectLater(
        service.fetchSummary(),
        throwsA(isA<ProgressException>()),
      );
      expect(called, isFalse);
    });

    test('maps retryable backend errors', () async {
      final service = ProgressService(
        tokenProvider: () => 'session-token',
        client: MockClient(
          (_) async => _jsonResponse({
            'message': 'Progress temporarily unavailable.',
          }, statusCode: 503),
        ),
      );

      await expectLater(
        service.fetchSummary(),
        throwsA(
          isA<ProgressException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });
  });
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _summaryJson() => {
  'date': '2026-09-03',
  'windowDays': 7,
  'activePlanCount': 1,
  'primaryPlan': {'id': '3', 'title': 'Recovery'},
  'readiness': {'available': true, 'score': 84},
  'tasks': {
    'scheduled': 5,
    'completed': 2,
    'skipped': 1,
    'missed': 1,
    'pending': 1,
    'completionRate': 40,
  },
  'gaps': {'total': 3, 'open': 2, 'inProgress': 1, 'resolved': 1},
  'understanding': {
    'available': true,
    'score': 90,
    'planId': '3',
    'planTitle': 'Recovery',
  },
  'trend': {
    'metric': 'task_completion_rate',
    'points': [
      {'date': '2026-08-28', 'scheduled': 1, 'completed': 1, 'value': 100},
      {'date': '2026-09-03', 'scheduled': 0, 'completed': 0, 'value': null},
    ],
  },
};

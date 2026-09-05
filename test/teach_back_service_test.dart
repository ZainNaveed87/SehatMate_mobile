import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/services/teach_back_service.dart';

void main() {
  group('TeachBackService', () {
    test('fetchTargets sends auth and parses verified targets', () async {
      final service = TeachBackService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/teach-back/targets');
          expect(request.headers['Authorization'], 'Bearer session-token');

          return _jsonResponse({
            'data': {
              'targets': [_targetJson()],
            },
          });
        }),
      );

      final targets = await service.fetchTargets();

      expect(targets, hasLength(1));
      expect(targets.single.targetType, 'instruction');
      expect(targets.single.targetId, 'inst-1');
      expect(targets.single.title, 'Take tablet');
    });

    test(
      'fetchSession parses questions, assessments, and final result',
      () async {
        final service = TeachBackService(
          tokenProvider: () => 'session-token',
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(
              request.url.path,
              '/api/teach-back/session/instruction/inst-1',
            );

            return _jsonResponse({'data': _sessionJson()});
          }),
        );

        final session = await service.fetchSession(
          targetType: 'instruction',
          targetId: 'inst-1',
        );

        expect(session.canAssess, isTrue);
        expect(session.questions.single.id, 'what_to_do');
        expect(session.assessments.single.status, 'understood');
        expect(
          session.assessmentsByQuestionId['what_to_do']?.answerText,
          'One tablet',
        );
        expect(session.finalResult.completed, isFalse);
      },
    );

    test('assessAnswer omits client user identifiers from POST body', () async {
      final service = TeachBackService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/teach-back/assess');
          final body = jsonDecode(request.body) as Map<String, dynamic>;

          expect(body, {
            'targetType': 'instruction',
            'targetId': 'inst-1',
            'questionId': 'what_to_do',
            'answer': 'I will take one tablet after breakfast.',
          });
          expect(body.containsKey('userId'), isFalse);
          expect(body.containsKey('user_id'), isFalse);

          return _jsonResponse({
            'data': {
              'target': _targetJson(),
              'assessment': _assessmentJson(
                answerText: 'I will take one tablet after breakfast.',
              ),
              'finalResult': _finalResultJson(completed: true, score: 92),
            },
          });
        }),
      );

      final response = await service.assessAnswer(
        targetType: 'instruction',
        targetId: 'inst-1',
        questionId: 'what_to_do',
        answer: 'I will take one tablet after breakfast.',
      );

      expect(response.assessment.score, 92);
      expect(response.finalResult.completed, isTrue);
    });

    test('throws before HTTP when no auth token is available', () async {
      var called = false;
      final service = TeachBackService(
        tokenProvider: () => null,
        client: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      );

      await expectLater(
        service.fetchTargets(),
        throwsA(
          isA<TeachBackException>().having(
            (error) => error.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('maps retryable server errors with status code and message', () async {
      final service = TeachBackService(
        tokenProvider: () => 'session-token',
        client: MockClient(
          (_) async => _jsonResponse({
            'message': 'Too many Teach-Back attempts.',
          }, statusCode: 429),
        ),
      );

      await expectLater(
        service.fetchTargets(),
        throwsA(
          isA<TeachBackException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.message,
                'message',
                contains('Too many'),
              ),
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

Map<String, dynamic> _sessionJson() => {
  'target': _targetJson(),
  'canAssess': true,
  'planStatement': 'Take one tablet after breakfast.',
  'language': 'English',
  'questions': [
    {
      'id': 'what_to_do',
      'text': 'Tell me what you need to do.',
      'focus': 'action',
      'order': 1,
    },
  ],
  'assessments': [_assessmentJson()],
  'finalResult': _finalResultJson(),
};

Map<String, dynamic> _targetJson() => {
  'targetType': 'instruction',
  'targetId': 'inst-1',
  'carePlanId': 'plan-1',
  'carePlanTitle': 'Blood pressure plan',
  'title': 'Take tablet',
  'instruction': 'Take one tablet',
  'timing': 'After breakfast',
  'notes': 'Use water',
  'sourceUpdatedAt': '2026-09-05T08:00:00.000Z',
};

Map<String, dynamic> _assessmentJson({
  String answerText = 'One tablet',
  String status = 'understood',
  int score = 92,
}) => {
  'id': 'attempt-1',
  'questionId': 'what_to_do',
  'questionText': 'Tell me what you need to do.',
  'answerText': answerText,
  'status': status,
  'score': score,
  'matchedPoints': ['one tablet'],
  'missingPoints': const <String>[],
  'feedback': 'You understood this instruction.',
  'retryPrompt': '',
  'planStatement': 'Take one tablet after breakfast.',
};

Map<String, dynamic> _finalResultJson({
  bool completed = false,
  int score = 0,
}) => {
  'completed': completed,
  'score': score,
  'status': completed ? 'understood' : 'in_progress',
  'questionCount': 1,
  'answeredCount': completed ? 1 : 0,
  'understoodCount': completed ? 1 : 0,
  'needsReviewCount': 0,
  'weakQuestionIds': const <String>[],
};

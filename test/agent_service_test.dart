import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/services/agent_service.dart';

class _TokenProvider implements AgentAuthTokenProvider {
  const _TokenProvider(this.token);

  @override
  final String? token;
}

void main() {
  AgentService serviceFor(http.Response response) {
    return AgentService(
      tokenProvider: const _TokenProvider('test-token'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return response;
      }),
    );
  }

  http.Response jsonResponse(int statusCode, Map<String, dynamic> body) {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<AgentException> sendFailure(http.Response response) async {
    try {
      await serviceFor(response).send(const AgentRequest(message: 'Hello'));
      fail('Expected AgentException.');
    } on AgentException catch (error) {
      return error;
    }
  }

  test('raw backend message is not exposed', () async {
    final error = await sendFailure(
      jsonResponse(500, const {
        'success': false,
        'message': 'internal database failure: provider stack trace',
      }),
    );

    expect(error.code, AgentErrorCode.unavailable);
    expect(error.message, isNot(contains('internal database failure')));
    expect(
      error.message,
      'SehatMate AI is temporarily unavailable. Please try again.',
    );
  });

  test('401 maps safely', () async {
    final error = await sendFailure(
      jsonResponse(401, const {'message': 'token decode failed'}),
    );

    expect(error.code, AgentErrorCode.unauthenticated);
    expect(error.message, 'Please sign in to continue.');
  });

  test('403 maps safely', () async {
    final error = await sendFailure(
      jsonResponse(403, const {'message': 'policy details hidden'}),
    );

    expect(error.code, AgentErrorCode.forbidden);
    expect(
      error.message,
      'SehatMate AI is temporarily unavailable. Please try again.',
    );
  });

  test('429 maps safely', () async {
    final error = await sendFailure(
      jsonResponse(429, const {'message': 'provider quota exceeded'}),
    );

    expect(error.code, AgentErrorCode.rateLimited);
    expect(
      error.message,
      'SehatMate AI is busy right now. Please try again shortly.',
    );
  });

  test('AGENT_DISABLED maps safely', () async {
    final error = await sendFailure(
      jsonResponse(403, const {
        'code': 'AGENT_DISABLED',
        'message': 'disabled because internal flag x',
      }),
    );

    expect(error.code, AgentErrorCode.disabled);
    expect(
      error.message,
      'SehatMate AI is temporarily unavailable. Please try again.',
    );
  });

  test(
    'AGENT_SESSION_NOT_FOUND still classifies for controller retry',
    () async {
      final error = await sendFailure(
        jsonResponse(404, const {
          'code': 'AGENT_SESSION_NOT_FOUND',
          'message': 'session table miss',
        }),
      );

      expect(error.code, AgentErrorCode.sessionNotFound);
      expect(error.isSessionNotFound, isTrue);
      expect(
        error.message,
        'SehatMate AI is temporarily unavailable. Please try again.',
      );
    },
  );

  test('500 arbitrary internal message is not exposed', () async {
    final error = await sendFailure(
      jsonResponse(500, const {
        'data': {'message': 'internal database failure in read capability'},
      }),
    );

    expect(error.code, AgentErrorCode.unavailable);
    expect(error.message, isNot(contains('database')));
  });

  test('malformed JSON maps safely', () async {
    final error = await sendFailure(http.Response('not json', 200));

    expect(error.code, AgentErrorCode.malformed);
    expect(error.message, 'SehatMate AI returned an invalid response.');
  });
}

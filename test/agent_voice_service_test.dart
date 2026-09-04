import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/features/agent/services/agent_service.dart';
import 'package:sehatmate_ai/features/agent/services/agent_voice_service.dart';

class _TokenProvider implements AgentAuthTokenProvider {
  const _TokenProvider(this.token);

  @override
  final String? token;
}

Future<File> _tempAudioFile(List<int> bytes) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}sehatmate_voice_test_${DateTime.now().microsecondsSinceEpoch}.m4a',
  );
  await file.writeAsBytes(bytes);
  return file;
}

void main() {
  test(
    'transcription uploads raw audio once without authority fields',
    () async {
      final file = await _tempAudioFile([1, 2, 3, 4]);
      final requests = <http.Request>[];
      final service = AgentVoiceService(
        tokenProvider: const _TokenProvider('test-token'),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'transcript': 'Care plans kholo'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.transcribe(
        AgentVoiceRecording(
          path: file.path,
          duration: const Duration(seconds: 2),
        ),
      );

      expect(result.text, 'Care plans kholo');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/agent/voice/transcribe'));
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      expect(requests.single.headers['Content-Type'], 'audio/mp4');
      expect(requests.single.bodyBytes, [1, 2, 3, 4]);
      expect(utf8.decode(requests.single.bodyBytes), isNot(contains('userId')));
      expect(
        utf8.decode(requests.single.bodyBytes),
        isNot(contains('language')),
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('no-speech response does not produce a transcript', () async {
    final file = await _tempAudioFile([1, 2, 3, 4]);
    final service = AgentVoiceService(
      tokenProvider: const _TokenProvider('test-token'),
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'code': 'VOICE_NO_SPEECH',
            'message': 'No speech.',
          }),
          422,
        );
      }),
    );

    try {
      await service.transcribe(
        AgentVoiceRecording(
          path: file.path,
          duration: const Duration(seconds: 2),
        ),
      );
      fail('Expected AgentException.');
    } on AgentException catch (error) {
      expect(error.code, AgentErrorCode.noSpeech);
    }
  });

  test('missing auth token is rejected before upload', () async {
    var calls = 0;
    final service = AgentVoiceService(
      tokenProvider: const _TokenProvider(null),
      client: MockClient((_) async {
        calls += 1;
        return http.Response('{}', 200);
      }),
    );

    try {
      await service.transcribe(
        const AgentVoiceRecording(
          path: 'missing.m4a',
          duration: Duration(seconds: 1),
        ),
      );
      fail('Expected AgentException.');
    } on AgentException catch (error) {
      expect(error.code, AgentErrorCode.unauthenticated);
      expect(calls, 0);
    }
  });
}

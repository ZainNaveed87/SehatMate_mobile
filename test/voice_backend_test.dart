import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_backend.dart';

void main() {
  test('logout cleanup uses only the original room account token', () async {
    String? current = 'old-account';
    final requests = <http.Request>[];
    final api = HttpVoiceBackend(
      token: () => current,
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('{"success":true,"data":{"id":"voice-one"}}', 200);
      }),
    );
    await api.create('42');
    current = null;
    await api.end('voice-one');
    expect(requests.last.headers['Authorization'], 'Bearer old-account');
    await expectLater(api.get('voice-one'), throwsA(isA<VoiceFailure>()));
    expect(requests.length, 2);
  });
  test(
    'voice requests use bearer user auth and actual scoped API paths',
    () async {
      final requests = <http.Request>[];
      final api = HttpVoiceBackend(
        token: () => 'fictional-auth',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'voice-one', 'epoch': 1},
            }),
            200,
          );
        }),
      );
      await api.create('42');
      await api.token('voice-one');
      await api.transfer('voice-one', 1, 'device');
      await api.receipt('voice-one', 'turn-one');
      expect(requests.map((r) => r.url.path), [
        '/api/agent/voice-sessions',
        '/api/agent/voice-sessions/voice-one/token',
        '/api/agent/voice-sessions/voice-one/transport',
        '/api/agent/voice-sessions/voice-one/turns/turn-one',
      ]);
      expect(
        requests.every(
          (r) => r.headers['Authorization'] == 'Bearer fictional-auth',
        ),
        true,
      );
      expect(jsonDecode(requests.first.body), {'agentSessionId': '42'});
      expect(jsonDecode(requests[2].body), {'epoch': 1, 'mode': 'device'});
    },
  );
  test('unauthenticated requests never touch network', () async {
    var requests = 0;
    final api = HttpVoiceBackend(
      token: () => null,
      client: MockClient((r) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(api.create('42'), throwsA(isA<VoiceFailure>()));
    expect(requests, 0);
  });
  test(
    'provider error bodies are sanitized and POST is never automatically retried',
    () async {
      var requests = 0;
      final api = HttpVoiceBackend(
        token: () => 'fake',
        client: MockClient((r) async {
          requests++;
          return http.Response(
            '{"success":false,"code":"VOICE_TURN_BUSY","message":"sensitive provider details"}',
            409,
          );
        }),
      );
      await expectLater(
        api.submit('voice-one', {
          'epoch': 1,
          'turnId': 'turn-one',
          'message': 'synthetic',
        }),
        throwsA(
          isA<VoiceFailure>().having((e) => e.code, 'code', 'VOICE_TURN_BUSY'),
        ),
      );
      expect(requests, 1);
    },
  );
}

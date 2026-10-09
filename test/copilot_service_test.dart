import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_service.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/services/auth_service.dart';

class Client implements AgentClient {
  @override
  Future<AgentResponse> send(AgentRequest r) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'token',
      'sehatroute_auth_user':
          '{"id":"a","name":"User","email":"user@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void publish(CopilotRegistry r, String state) => r.publish(
    owner: 'page',
    screenId: 'home',
    route: 'home',
    stateKey: state,
    targets: const [CopilotTarget(id: 'main', kind: 'section', label: 'Home')],
    actions: const [],
  );
  test(
    'context posts serialize and obsolete completion cannot mark current generation synced',
    () async {
      final r = CopilotRegistry(accountId: 'a');
      publish(r, '1');
      final agent = AgentController(client: Client());
      await agent.bindSession('s');
      final posts = <Map<String, dynamic>>[];
      final first = Completer<http.Response>();
      final service = CopilotService(
        registry: r,
        agent: agent,
        client: MockClient((request) async {
          posts.add(jsonDecode(request.body));
          return posts.length == 1 ? first.future : http.Response('{}', 200);
        }),
      );
      final previousVersion = r.snapshot!.version;
      final old = service.ensureCurrent('s');
      await Future<void>.delayed(Duration.zero);
      publish(r, '2');
      final latest = service.ensureCurrent('s');
      await Future<void>.delayed(Duration.zero);
      expect(posts.length, 1);
      first.complete(http.Response('{}', 200));
      expect(await old, false);
      expect(await latest, true);
      expect(posts[0]['context']['ui']['version'], previousVersion);
      expect(posts[1]['context']['ui']['version'], r.snapshot!.version);
      service.dispose();
      agent.dispose();
      r.dispose();
    },
  );
  test(
    'unchanged context renews before server expiry and stops in background',
    () async {
      final r = CopilotRegistry(accountId: 'a');
      publish(r, '1');
      final agent = AgentController(client: Client());
      await agent.bindSession('s');
      var now = DateTime.utc(2026);
      var posts = 0;
      final service = CopilotService(
        registry: r,
        agent: agent,
        now: () => now,
        client: MockClient((request) async {
          posts++;
          return http.Response('{}', 200);
        }),
      );
      expect(await service.ensureCurrent('s'), true);
      expect(posts, 1);
      expect(await service.ensureCurrent('s'), true);
      expect(posts, 1);
      now = now.add(const Duration(minutes: 1));
      expect(await service.ensureCurrent('s'), true);
      expect(posts, 2);
      service.setForeground(false);
      expect(await service.ensureCurrent('s'), false);
      expect(posts, 2);
      service.dispose();
      agent.dispose();
      r.dispose();
    },
  );
}

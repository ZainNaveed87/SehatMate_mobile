import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_memory_review.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_service.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';

class _Client implements AgentClient {
  @override
  Future<AgentResponse> send(AgentRequest request) =>
      throw UnimplementedError();
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
  late LanguageController language;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    language = LanguageController.forTesting();
  });
  tearDown(() => language.dispose());
  Widget app({required Widget home, GlobalKey<NavigatorState>? navigatorKey}) =>
      LanguageScope(
        controller: language,
        child: MaterialApp(home: home, navigatorKey: navigatorKey),
      );

  testWidgets('memory review renders data envelope and forget reloads it', (
    tester,
  ) async {
    final registry = CopilotRegistry(accountId: 'a');
    final agent = AgentController(client: _Client());
    final methods = <String>[];
    var forgotten = false;
    final service = CopilotService(
      registry: registry,
      agent: agent,
      client: MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'DELETE') {
          expect(request.url.path.endsWith('/memory/17'), true);
          forgotten = true;
          return http.Response('{"success":true}', 200);
        }
        return http.Response(
          forgotten
              ? '{"success":true,"data":[]}'
              : '{"success":true,"data":[{"id":"17","kind":"USER_PREFERENCE","value":{"style":"brief"}}]}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      app(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(showCopilotMemoryReview(context, service));
              unawaited(showCopilotMemoryReview(context, service));
            },
            child: const Text('Review'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('style: brief'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(methods, ['GET', 'DELETE', 'GET']);
    expect(find.text('style: brief'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    service.dispose();
    agent.dispose();
    registry.dispose();
  });

  testWidgets('account invalidation removes only owned memory sheet', (
    tester,
  ) async {
    final registry = CopilotRegistry(accountId: 'a');
    final agent = AgentController(client: _Client());
    final pending = Completer<http.Response>();
    final service = CopilotService(
      registry: registry,
      agent: agent,
      client: MockClient((_) => pending.future),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      app(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCopilotMemoryReview(context, service),
            child: const Text('Review'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pump(const Duration(milliseconds: 350));
    unawaited(
      showDialog<void>(
        context: navigatorKey.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(content: Text('Unrelated dialog')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    registry.invalidate();
    pending.complete(
      http.Response(
        '{"success":true,"data":[{"id":"17","value":{"style":"private"}}]}',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unrelated dialog'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('style: private'), findsNothing);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    service.dispose();
    agent.dispose();
    registry.dispose();
  });

  testWidgets(
    'account invalidation closes pending memory proposal without save',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      final agent = AgentController(client: _Client());
      var requests = 0;
      final service = CopilotService(
        registry: registry,
        agent: agent,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"success":true}', 200);
        }),
      );
      await tester.pumpWidget(
        app(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmCopilotMemory(context, service, {
                'kind': 'USER_PREFERENCE',
                'key': 'explanation.style',
                'value': {'style': 'brief'},
              }, 'session'),
              child: const Text('Propose'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Propose'));
      await tester.pumpAndSettle();
      expect(find.text('style: brief'), findsOneWidget);
      registry.invalidate();
      await tester.pumpAndSettle();
      expect(find.text('style: brief'), findsNothing);
      expect(requests, 0);
      service.dispose();
      agent.dispose();
      registry.dispose();
    },
  );
}

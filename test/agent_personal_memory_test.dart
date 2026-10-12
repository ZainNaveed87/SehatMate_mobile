import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_service.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_memory_review.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/features/agent/widgets/agent_confirmation_card.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixtures;

const candidate =
    'Your name is Zane. Do you want me to save that in Agent Memory?';
Map<String, dynamic> packet({bool confirmed = false, bool cancelled = false}) =>
    {
      ...fixtures.result,
      'reply': confirmed
          ? "I've saved your name as Zane."
          : cancelled
          ? 'Memory save cancelled.'
          : candidate,
      'actionStatus': confirmed
          ? 'confirmed'
          : cancelled
          ? 'cancelled'
          : 'awaiting_confirmation',
      if (!confirmed && !cancelled)
        'confirmation': {
          'confirmationId': 'memory-confirm',
          'kind': 'personal_memory',
          'message': candidate,
        },
      if (confirmed)
        'memoryReceipt': {
          'operation': 'remember',
          'status': 'succeeded',
          'key': 'identity.name',
        },
    };

class Client implements AgentClient {
  final requests = <AgentRequest>[];
  bool saved = false;
  @override
  Future<AgentResponse> send(AgentRequest request) async {
    requests.add(request);
    final confirmed = request.confirmationDecision == 'confirm';
    saved |= confirmed;
    return AgentResponse.fromJson(
      packet(
        confirmed: confirmed,
        cancelled: request.confirmationDecision == 'cancel',
      ),
    );
  }
}

class Backend extends fixtures.Backend {
  final submissions = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> submit(String id, Map<String, dynamic> body) {
    submissions.add(body);
    replyResult = packet(confirmed: true);
    return super.submit(id, body);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'test-token',
      'sehatroute_auth_user':
          '{"id":"test","name":"User","email":"test@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'}),
  );
  test(
    'personal confirmation parses through the canonical response; unknown kinds still reject',
    () {
      expect(
        AgentResponse.fromJson(packet()).confirmation?.kind,
        'personal_memory',
      );
      expect(
        () => AgentResponse.fromJson({
          ...packet(),
          'confirmation': {
            'confirmationId': 'x',
            'kind': 'invented',
            'message': 'x',
          },
        }),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'typed Confirm and Cancel send only the same server confirmation ID',
    (tester) async {
      for (final decision in ['confirm', 'cancel']) {
        final client = Client();
        final controller = AgentController(client: client);
        await controller.sendText('my name is Zane, add it to memory');
        expect(client.saved, false);
        expect(
          controller.pendingConfirmation?.confirmationId,
          'memory-confirm',
        );
        final language = LanguageController.forTesting();
        await tester.pumpWidget(
          LanguageScope(
            controller: language,
            child: MaterialApp(
              home: Scaffold(
                body: AgentConfirmationCard(
                  messageId: 'memory',
                  confirmationId: 'memory-confirm',
                  kind: 'personal_memory',
                  message: candidate,
                  active: true,
                  loading: false,
                  onConfirm: controller.confirmPendingAction,
                  onCancel: controller.cancelPendingAction,
                ),
              ),
            ),
          ),
        );
        expect(find.text(candidate), findsOneWidget);
        await tester.tap(
          find.byKey(ValueKey('agent_${decision}_memory_memory-confirm')),
        );
        await tester.pumpAndSettle();
        expect(client.requests.last.toJson(), {
          'sessionId': '41',
          'confirmation': {
            'confirmationId': 'memory-confirm',
            'decision': decision,
          },
        });
        expect(client.saved, decision == 'confirm');
        expect(controller.pendingConfirmation, isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        language.dispose();
      }
    },
  );
  testWidgets(
    'live Worker memory reply is visible and Voice Confirm resolves the same operation',
    (tester) async {
      final agent = AgentController(client: Client()),
          backend = Backend(),
          transport = fixtures.Transport();
      final voice = VoiceCompanionController(
        backend: backend,
        transport: transport,
        agent: agent,
        authenticated: () => true,
      );
      final language = LanguageController.forTesting();
      await tester.runAsync(() => voice.start(AppLanguage.english));
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(home: VoiceCompanionSurface(controller: voice)),
        ),
      );
      transport.event(
        'transcript_final',
        1,
        turnId: 'memory-turn',
        payload: {'text': 'my name is Zane add it to memory'},
      );
      transport.event('processing', 2, turnId: 'memory-turn');
      transport.event(
        'agent_result',
        3,
        turnId: 'memory-turn',
        payload: {'result': packet()},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(agent.pendingConfirmation?.confirmationId, 'memory-confirm');
      expect(find.text(candidate), findsWidgets);
      expect(voice.reply, candidate);
      expect(agent.messages.last.text, candidate);
      await tester.runAsync(() => voice.confirm('memory-confirm', true));
      await tester.pump();
      expect(backend.submissions.single['confirmation'], {
        'confirmationId': 'memory-confirm',
        'decision': 'confirm',
      });
      expect(agent.pendingConfirmation, isNull);
      expect(agent.messages.last.text, voice.reply);
      await tester.pumpWidget(const SizedBox());
      await voice.end();
      voice.dispose();
      agent.dispose();
      language.dispose();
    },
  );
  testWidgets(
    'open empty Memory review refreshes from server after confirmed write and on reopen',
    (tester) async {
      final client = Client();
      final controller = AgentController(client: client);
      final registry = CopilotRegistry(accountId: 'test');
      final language = LanguageController.forTesting();
      var reads = 0;
      final service = CopilotService(
        registry: registry,
        agent: controller,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path.endsWith('/memory'), true);
          reads++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': client.saved
                  ? [
                      {
                        'id': '17',
                        'kind': 'CONFIRMED_FACT',
                        'value': {'name': 'Zane'},
                      },
                    ]
                  : [],
            }),
            200,
          );
        }),
      );
      await controller.sendText('my name is Zane, add it to memory');
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    unawaited(showCopilotMemoryReview(context, service)),
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('name: Zane'), findsNothing);
      expect(reads, 1);
      await tester.runAsync(() async {
        await controller.confirmPendingAction('memory-confirm');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(client.saved, true);
      expect(controller.memoryRevision, 1);
      expect(registry.valid, true);
      expect(AuthSession.instance.user?.id, 'test');
      expect(AuthSession.instance.isAuthenticated, true);
      expect(reads, 2);
      expect(find.text('name: Zane'), findsOneWidget);
      expect(reads, 2);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('name: Zane'), findsOneWidget);
      expect(reads, 3);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      controller.dispose();
      registry.dispose();
      language.dispose();
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_backend.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'voice_companion_controller_test.dart' as fixtures;

void main() {
  late AgentController agent;
  late VoiceCompanionController voice;
  late fixtures.Transport transport;
  late List<http.Request> requests;
  late List<Object> outcomes;
  late List<String> diagnostics;
  late DebugPrintCallback previousPrint;
  Completer<void>? freshGate;
  Completer<void>? freshEntered;
  String? freshError;
  late String freshId;
  const store = AgentSessionStore(accountId: 'startup');

  http.Response failure(String code) => http.Response(
    jsonEncode({'success': false, 'code': code, 'message': 'private-body'}),
    switch (code) {
      'AGENT_SESSION_NOT_FOUND' => 404,
      'VOICE_INVALID_REQUEST' => 422,
      'AGENT_DISABLED' => 403,
      _ => 503,
    },
  );

  List<String> createdWith() => requests
      .where((r) => r.url.path == '/api/agent/voice-sessions')
      .map((r) => jsonDecode(r.body)['agentSessionId'] as String)
      .toList();
  int sessionRequests() =>
      requests.where((r) => r.url.path == '/api/agent/session').length;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      store.storageKey: '22',
      AgentSessionStore.key: 'other-session',
      'unrelated-preference': 'keep',
    });
    requests = [];
    outcomes = [fixtures.binding()];
    diagnostics = [];
    freshGate = null;
    freshEntered = null;
    freshError = null;
    freshId = '41';
    previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) diagnostics.add(message);
    };
    agent = AgentController(client: fixtures.Client(), sessionStore: store);
    transport = fixtures.Transport();
    final backend = HttpVoiceBackend(
      token: () => 'test-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/agent/session') {
          expect(agent.sessionId, isNull);
          expect(await store.read(), isNull);
          freshEntered?.complete();
          await freshGate?.future;
          if (freshError != null) return failure(freshError!);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'sessionId': freshId},
            }),
            200,
          );
        }
        if (request.url.path == '/api/agent/voice-sessions') {
          final outcome = outcomes.removeAt(0);
          if (outcome is String) return failure(outcome);
          return http.Response(
            jsonEncode({'success': true, 'data': outcome}),
            200,
          );
        }
        return http.Response('{"success":true,"data":{}}', 200);
      }),
    );
    voice = VoiceCompanionController(
      backend: backend,
      transport: transport,
      agent: agent,
      authenticated: () => true,
      ensureAgentSession: backend.ensureAgentSession,
    );
  });
  tearDown(() async {
    await voice.end();
    voice.dispose();
    agent.dispose();
    debugPrint = previousPrint;
  });

  test(
    'valid cached Agent session creates voice once without recreation',
    () async {
      await voice.start(AppLanguage.english);
      expect(createdWith(), ['22']);
      expect(sessionRequests(), 0);
      expect(transport.connects, 1);
      expect(voice.state, 'listening');
      expect(diagnostics, [
        'VOICE_CLIENT_START:AGENT_SESSION_READY',
        'VOICE_CLIENT_START:CREATE_REQUEST',
        'VOICE_CLIENT_START:CREATE_SUCCESS',
      ]);
    },
  );

  test(
    'stale create clears only its reference, recreates and retries once',
    () async {
      outcomes = ['AGENT_SESSION_NOT_FOUND', fixtures.binding()];
      final states = <String>[];
      voice.addListener(() => states.add(voice.state));
      await voice.start(AppLanguage.english);
      expect(createdWith(), ['22', '41']);
      expect(sessionRequests(), 1);
      expect(agent.sessionId, '41');
      expect(await store.read(), '41');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AgentSessionStore.key), 'other-session');
      expect(prefs.getString('unrelated-preference'), 'keep');
      expect(agent.messages, isEmpty);
      expect(states, isNot(contains('recovering')));
      expect(voice.state, 'listening');
      expect(transport.connects, 1);
      expect(diagnostics, [
        'VOICE_CLIENT_START:AGENT_SESSION_READY',
        'VOICE_CLIENT_START:CREATE_REQUEST',
        'VOICE_CLIENT_START:STALE_AGENT_SESSION',
        'VOICE_CLIENT_START:AGENT_SESSION_RECREATED',
        'VOICE_CLIENT_START:CREATE_REQUEST',
        'VOICE_CLIENT_START:CREATE_SUCCESS',
      ]);
    },
  );

  test(
    'second stale rejection stops and never caches the rejected fresh session',
    () async {
      outcomes = ['AGENT_SESSION_NOT_FOUND', 'AGENT_SESSION_NOT_FOUND'];
      await voice.start(AppLanguage.english);
      expect(createdWith(), ['22', '41']);
      expect(sessionRequests(), 1);
      expect(agent.sessionId, isNull);
      expect(await store.read(), isNull);
      expect(voice.state, 'recovering');
      expect(transport.connects, 0);
      expect(diagnostics.last, 'VOICE_CLIENT_START:CREATE_FAILED');
    },
  );

  for (final code in [
    'VOICE_INVALID_REQUEST',
    'VOICE_UNAVAILABLE',
    'AGENT_DISABLED',
  ]) {
    test('$code does not recreate or retry a cached session', () async {
      outcomes = [code];
      await voice.start(AppLanguage.english);
      expect(createdWith(), ['22']);
      expect(sessionRequests(), 0);
      expect(await store.read(), '22');
      expect(voice.state, 'recovering');
      expect(transport.connects, 0);
      expect(diagnostics.last, 'VOICE_CLIENT_START:CREATE_FAILED');
      expect(diagnostics.join(), isNot(contains('private-body')));
    });
  }

  test('failed fresh session request leaves stale reference cleared', () async {
    outcomes = ['AGENT_SESSION_NOT_FOUND'];
    freshError = 'AGENT_DISABLED';
    await voice.start(AppLanguage.english);
    expect(createdWith(), ['22']);
    expect(sessionRequests(), 1);
    expect(await store.read(), isNull);
    expect(voice.state, 'recovering');
    expect(transport.connects, 0);
  });

  test('unrelated failure on retry stops after exactly two creates', () async {
    outcomes = ['AGENT_SESSION_NOT_FOUND', 'VOICE_UNAVAILABLE'];
    await voice.start(AppLanguage.english);
    expect(createdWith(), ['22', '41']);
    expect(sessionRequests(), 1);
    expect(await store.read(), '41');
    expect(voice.state, 'recovering');
    expect(transport.connects, 0);
  });

  test(
    'session recreation cannot reuse the rejected stale reference',
    () async {
      outcomes = ['AGENT_SESSION_NOT_FOUND'];
      freshId = '22';
      await voice.start(AppLanguage.english);
      expect(createdWith(), ['22']);
      expect(sessionRequests(), 1);
      expect(agent.sessionId, isNull);
      expect(await store.read(), isNull);
      expect(voice.state, 'recovering');
    },
  );

  test(
    'end during fresh session recovery prevents retry and connection',
    () async {
      outcomes = ['AGENT_SESSION_NOT_FOUND', fixtures.binding()];
      freshEntered = Completer<void>();
      freshGate = Completer<void>();
      final start = voice.start(AppLanguage.english);
      await freshEntered!.future.timeout(const Duration(seconds: 2));
      await voice.end();
      freshGate!.complete();
      await start;
      expect(createdWith(), ['22']);
      expect(await store.read(), isNull);
      expect(transport.connects, 0);
      expect(voice.state, 'idle');
    },
  );

  testWidgets('current Connecting title never paints an outgoing error title', (
    tester,
  ) async {
    debugPrint = previousPrint;
    final language = LanguageController.forTesting();
    addTearDown(language.dispose);
    voice.state = 'recovering';
    await tester.pumpWidget(
      LanguageScope(
        controller: language,
        child: MaterialApp(
          home: AnimatedBuilder(
            animation: voice,
            builder: (_, _) => VoiceCompanionSurface(controller: voice),
          ),
        ),
      ),
    );
    expect(find.text('Voice needs attention'), findsOneWidget);
    voice.state = 'connecting';
    voice.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Connecting...'), findsOneWidget);
    expect(find.text('Voice needs attention'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final recovered in [true, false]) {
    testWidgets(
      'retry stays Connecting until stale recovery ${recovered ? 'succeeds' : 'fails'}',
      (tester) async {
        debugPrint = previousPrint;
        outcomes = [
          'VOICE_UNAVAILABLE',
          'AGENT_SESSION_NOT_FOUND',
          recovered ? fixtures.binding() : 'VOICE_UNAVAILABLE',
        ];
        await tester.runAsync(() => voice.start(AppLanguage.english));
        final language = LanguageController.forTesting();
        addTearDown(language.dispose);
        await tester.pumpWidget(
          LanguageScope(
            controller: language,
            child: MaterialApp(
              home: AnimatedBuilder(
                animation: voice,
                builder: (_, _) => VoiceCompanionSurface(controller: voice),
              ),
            ),
          ),
        );
        expect(find.text('Voice needs attention'), findsOneWidget);
        freshEntered = Completer<void>();
        freshGate = Completer<void>();
        late Future<void> retry;
        await tester.runAsync(() async {
          retry = voice.start(AppLanguage.english);
        });
        for (var step = 0; step < 10 && !freshEntered!.isCompleted; step++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        expect(freshEntered!.isCompleted, isTrue);
        await tester.pump();
        expect(find.text('Connecting...'), findsOneWidget);
        expect(find.text('Voice needs attention'), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Connecting...'), findsOneWidget);
        expect(find.text('Voice needs attention'), findsNothing);
        expect(voice.state, 'connecting');
        freshGate!.complete();
        await tester.runAsync(() => retry);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(recovered ? 'Listening' : 'Voice needs attention'),
          findsOneWidget,
        );
        expect(find.text('Connecting...'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

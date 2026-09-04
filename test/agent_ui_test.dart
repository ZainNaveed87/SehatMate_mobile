import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/models/agent_speech.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/features/agent/services/agent_voice_service.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/services/agent_service.dart';

class _UiFakeClient implements AgentClient {
  _UiFakeClient(this.outcomes);

  final requests = <AgentRequest>[];
  final List<Object> outcomes;

  @override
  Future<AgentResponse> send(AgentRequest request) async {
    requests.add(request);

    if (outcomes.isEmpty) {
      throw StateError(
        'Unexpected Agent request #${requests.length}: ${request.toJson()}',
      );
    }

    final outcome = outcomes.removeAt(0);
    if (outcome is Completer<AgentResponse>) return outcome.future;
    return outcome as AgentResponse;
  }
}

class _FakeVoiceRecorder implements AgentVoiceRecorder {
  _FakeVoiceRecorder({this.permission = true, AgentVoiceRecording? recording})
    : recording =
          recording ??
          const AgentVoiceRecording(
            path: 'voice.m4a',
            duration: Duration(seconds: 1),
          );

  bool permission;
  AgentVoiceRecording? recording;
  Completer<AgentVoiceRecording?>? stopCompleter;
  int permissionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async {
    permissionCalls += 1;
    return permission;
  }

  @override
  Future<void> start() async {
    startCalls += 1;
  }

  @override
  Future<AgentVoiceRecording?> stop() {
    stopCalls += 1;
    return stopCompleter?.future ?? Future.value(recording);
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

class _FakeVoiceTranscriber implements AgentVoiceTranscriber {
  _FakeVoiceTranscriber(this.outcomes);

  final List<Object> outcomes;
  final recordings = <AgentVoiceRecording>[];

  @override
  Future<AgentVoiceTranscript> transcribe(AgentVoiceRecording recording) async {
    recordings.add(recording);
    final outcome = outcomes.removeAt(0);
    if (outcome is AgentException) throw outcome;
    if (outcome is Completer<AgentVoiceTranscript>) return outcome.future;
    return outcome as AgentVoiceTranscript;
  }
}

class _FakeVoicePlayer implements AgentVoicePlayer {
  final played = <AgentSpeech>[];
  int stops = 0;
  int disposes = 0;
  bool failPlayback = false;

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  Future<void> play(AgentSpeech speech) async {
    if (failPlayback) throw StateError('playback failed');
    played.add(speech);
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
  }
}

AgentResponse _response({
  String sessionId = 's-ui',
  String reply = 'Your next task is ready.',
  String language = 'en',
  String? confirmationId,
  String confirmationKind = 'task_outcome',
  String confirmationMessage = 'Mark "Morning medicine reminder" as completed.',
  String? actionStatus,
  Map<String, Object?>? navigation,
  Map<String, Object?>? speech,
}) {
  return AgentResponse.fromJson({
    'success': true,
    'sessionId': sessionId,
    'language': language,
    'reply': reply,
    'navigation': navigation,
    'speech': speech,
    'confirmation': confirmationId == null
        ? null
        : {
            'confirmationId': confirmationId,
            'kind': confirmationKind,
            'message': confirmationMessage,
          },
    'actionStatus': actionStatus,
    'referencedEntities': [],
  });
}

Future<AgentController> _pumpAgent(
  WidgetTester tester, {
  required _UiFakeClient client,
  AppLanguage language = AppLanguage.english,
  AgentVoiceRecorder? voiceRecorder,
  AgentVoiceTranscriber? voiceTranscriber,
  AgentVoicePlayer? voicePlayer,
}) async {
  final languageController = LanguageController.forTesting();
  await languageController.setLanguage(language, syncToServer: false);

  final controller = AgentController(client: client);

  // Make initialization deterministic before the screen starts interacting
  // with the controller.
  await controller.initialize();

  await tester.pumpWidget(
    LanguageScope(
      controller: languageController,
      child: MaterialApp(
        home: AgentScreen(
          controller: controller,
          voiceRecorder: voiceRecorder,
          voiceTranscriber: voiceTranscriber,
          voicePlayer: voicePlayer,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(controller.initialized, isTrue);

  return controller;
}

Future<void> _sendFromComposer(
  WidgetTester tester,
  AgentController controller,
  _UiFakeClient client,
  String text,
) async {
  final previousRequestCount = client.requests.length;

  expect(controller.initialized, isTrue);
  expect(controller.loading, isFalse);
  expect(controller.confirmationLoading, isFalse);

  final composer = find.byKey(const ValueKey('agent_composer'));
  expect(composer, findsOneWidget);

  await tester.enterText(composer, text);
  await tester.pump();

  final sendButton = find.byIcon(Icons.send_outlined);
  expect(sendButton, findsOneWidget);

  await tester.tap(sendButton);
  await tester.pump();

  // Wait deterministically for this exact normal Agent request to finish.
  for (var i = 0; i < 100; i++) {
    if (client.requests.length == previousRequestCount + 1 &&
        !controller.loading) {
      break;
    }

    await tester.pump(const Duration(milliseconds: 10));
  }

  expect(
    client.requests.length,
    previousRequestCount + 1,
    reason: 'Composer send should produce exactly one Agent request.',
  );

  expect(
    controller.loading,
    isFalse,
    reason: 'Agent response should finish before the test continues.',
  );

  await tester.pumpAndSettle();
}

FilledButton _confirmButton(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key)));

TextButton _cancelButton(WidgetTester tester, String key) =>
    tester.widget<TextButton>(find.byKey(ValueKey(key)));

void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'test-token',
      'sehatroute_auth_user':
          '{"id":"user-1","name":"Test User","email":"test@example.com"}',
    });

    await AuthSession.instance.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // baqi saare existing tests yahan same rahenge...

  testWidgets('mic button exists and permission is requested only when used', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecorder(permission: false);
    final client = _UiFakeClient([]);
    await _pumpAgent(
      tester,
      client: client,
      voiceRecorder: recorder,
      voiceTranscriber: _FakeVoiceTranscriber([]),
      voicePlayer: _FakeVoicePlayer(),
    );

    expect(find.byKey(const ValueKey('agent_mic_button')), findsOneWidget);
    expect(recorder.permissionCalls, 0);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();

    expect(recorder.permissionCalls, 1);
    expect(recorder.startCalls, 0);
    expect(find.byKey(const ValueKey('agent_composer')), findsOneWidget);
  });

  testWidgets('recording state is visible and stop uploads exactly once', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecorder();
    final stop = Completer<AgentVoiceRecording?>();
    recorder.stopCompleter = stop;
    final transcriber = _FakeVoiceTranscriber([
      const AgentVoiceTranscript(text: 'Aaj mera next task kya hai?'),
    ]);
    final client = _UiFakeClient([_response()]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceRecorder: recorder,
      voiceTranscriber: transcriber,
      voicePlayer: _FakeVoicePlayer(),
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    expect(find.text('Recording'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    expect(find.text('Transcribing'), findsOneWidget);
    expect(recorder.stopCalls, 1);

    stop.complete(recorder.recording);
    await tester.pumpAndSettle();

    expect(transcriber.recordings, hasLength(1));
    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'Aaj mera next task kya hai?');
    expect(client.requests.single.requestSpeech, isTrue);
    expect(controller.messages.first.text, 'Aaj mera next task kya hai?');
  });

  testWidgets('empty/no-speech transcript does not send Agent request', (
    tester,
  ) async {
    final recorder = _FakeVoiceRecorder();
    final transcriber = _FakeVoiceTranscriber([
      const AgentException('No speech', code: AgentErrorCode.noSpeech),
    ]);
    final client = _UiFakeClient([]);
    await _pumpAgent(
      tester,
      client: client,
      voiceRecorder: recorder,
      voiceTranscriber: transcriber,
      voicePlayer: _FakeVoicePlayer(),
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests, isEmpty);
    expect(find.text('No understandable speech was detected.'), findsOneWidget);
  });

  testWidgets('voice transcript receives normal Phase D confirmation UI', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'voice-confirm',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    await _pumpAgent(
      tester,
      client: client,
      voiceRecorder: _FakeVoiceRecorder(),
      voiceTranscriber: _FakeVoiceTranscriber([
        const AgentVoiceTranscript(text: 'Aaj wali exercise skip kar do'),
      ]),
      voicePlayer: _FakeVoicePlayer(),
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.toJson(), {
      'message': 'Aaj wali exercise skip kar do',
      'voice': {'requestSpeech': true},
    });

    expect(
      find.byKey(
        const ValueKey('agent_confirmation_card_agent_msg_2_voice-confirm'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('voice response speech plays without extra Agent request', (
    tester,
  ) async {
    final player = _FakeVoicePlayer();
    final client = _UiFakeClient([
      _response(
        speech: const {
          'audioBase64': 'bXAz',
          'contentType': 'audio/mpeg',
          'format': 'mp3',
          'model': 'fish-audio/s2.1-pro-free:free',
        },
      ),
    ]);
    await _pumpAgent(
      tester,
      client: client,
      voiceRecorder: _FakeVoiceRecorder(),
      voiceTranscriber: _FakeVoiceTranscriber([
        const AgentVoiceTranscript(text: 'haan'),
      ]),
      voicePlayer: player,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'haan');
    expect(player.played, hasLength(1));
  });

  testWidgets('current confirmation card binds controls to its id', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-a',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(
        confirmationId: 'confirm-b',
        confirmationMessage: 'Mark "Evening walk" as skipped.',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(actionStatus: 'confirmed'),
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'Prepare A');
    await _sendFromComposer(tester, controller, client, 'Prepare B');

    expect(
      _confirmButton(tester, 'agent_confirm_agent_msg_2_confirm-a').onPressed,
      isNull,
    );
    expect(
      _cancelButton(tester, 'agent_cancel_agent_msg_2_confirm-a').onPressed,
      isNull,
    );
    expect(
      _confirmButton(tester, 'agent_confirm_agent_msg_4_confirm-b').onPressed,
      isNotNull,
    );
    expect(
      _cancelButton(tester, 'agent_cancel_agent_msg_4_confirm-b').onPressed,
      isNotNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent_confirm_agent_msg_4_confirm-b')),
    );
    await tester.pumpAndSettle();

    expect(client.requests.last.toJson(), {
      'sessionId': 's-ui',
      'confirmation': {'confirmationId': 'confirm-b', 'decision': 'confirm'},
    });
  });

  testWidgets(
    'duplicate current confirmation cards expose only latest controls',
    (tester) async {
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-same',
          actionStatus: 'awaiting_confirmation',
        ),
        _response(
          confirmationId: 'confirm-same',
          actionStatus: 'awaiting_confirmation',
        ),
      ]);
      final controller = await _pumpAgent(tester, client: client);

      await _sendFromComposer(tester, controller, client, 'Prepare first');

      await _sendFromComposer(tester, controller, client, 'Prepare duplicate');

      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_2_confirm-same',
        ).onPressed,
        isNull,
      );
      expect(
        _cancelButton(
          tester,
          'agent_cancel_agent_msg_2_confirm-same',
        ).onPressed,
        isNull,
      );
      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_4_confirm-same',
        ).onPressed,
        isNotNull,
      );
      expect(
        _cancelButton(
          tester,
          'agent_cancel_agent_msg_4_confirm-same',
        ).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'confirmation loading disables controls and composer only in flight',
    (tester) async {
      final confirmationCompleter = Completer<AgentResponse>();
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-load',
          actionStatus: 'awaiting_confirmation',
        ),
        confirmationCompleter,
        _response(reply: 'Read reply after confirmation.'),
      ]);
      final controller = await _pumpAgent(tester, client: client);

      await _sendFromComposer(tester, controller, client, 'Prepare action');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('agent_confirm_agent_msg_2_confirm-load')),
      );
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isFalse,
      );
      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_2_confirm-load',
        ).onPressed,
        isNull,
      );
      expect(client.requests, hasLength(2));

      await controller.sendText('Blocked send');
      await tester.pump();

      expect(
        client.requests,
        hasLength(2),
        reason: 'Normal sends must be ignored while confirmation is in flight.',
      );

      confirmationCompleter.complete(_response(actionStatus: 'confirmed'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isTrue,
      );

      await _sendFromComposer(tester, controller, client, 'Normal read');
      expect(client.requests, hasLength(3));
      expect(client.requests.last.message, 'Normal read');
    },
  );

  testWidgets('schedule reminder review shows medical recheck copy in English', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-schedule-en',
        confirmationKind: 'schedule_time',
        confirmationMessage: 'Set reminder to 08:00.',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    final controller = await _pumpAgent(
      tester,
      client: client,
      language: AppLanguage.english,
    );

    await _sendFromComposer(tester, controller, client, 'Move reminder');

    expect(
      find.text(
        'Verified medical timing will be checked again on the server before this reminder is saved.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('schedule reminder review shows medical recheck copy in Urdu', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-schedule-ur',
        confirmationKind: 'schedule_time',
        confirmationMessage: 'Set reminder to 08:00.',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    final controller = await _pumpAgent(
      tester,
      client: client,
      language: AppLanguage.urdu,
    );

    await _sendFromComposer(tester, controller, client, 'Move reminder');

    expect(
      find.text(
        'یہ reminder محفوظ ہونے سے پہلے server verified medical timing دوبارہ check کرے گا۔',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'schedule reminder review shows medical recheck copy in Roman Urdu',
    (tester) async {
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-schedule-roman',
          confirmationKind: 'schedule_time',
          confirmationMessage: 'Set reminder to 08:00.',
          actionStatus: 'awaiting_confirmation',
        ),
      ]);

      final controller = await _pumpAgent(
        tester,
        client: client,
        language: AppLanguage.romanUrdu,
      );

      await _sendFromComposer(tester, controller, client, 'Move reminder');

      expect(
        find.text(
          'Yeh reminder save hone se pehle server verified medical timing dobara check karega.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('navigation open action still renders for authorized target', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        reply: 'I can open care plans.',
        navigation: {'target': 'care_plans', 'params': <String, String>{}},
      ),
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'Open care plans');

    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('sign-in unavailable state renders safely', (tester) async {
    await AuthSession.instance.logout();
    final client = _UiFakeClient([]);
    await _pumpAgent(tester, client: client);

    expect(find.text('Sign in to use SehatMate AI'), findsOneWidget);
  });
}

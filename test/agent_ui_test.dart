import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
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

class _FakeVoiceService implements AgentVoiceClient {
  _FakeVoiceService({
    this.available = true,
    List<Object>? transcripts,
    this.failTts = false,
  }) : transcripts = transcripts ?? <Object>[];

  bool available;
  bool failTts;
  final List<Object> transcripts;
  final spoken = <String>[];
  final spokenLanguages = <AppLanguage>[];
  VoidCallback? listeningComplete;
  Completer<AgentVoiceTranscript>? stopCompleter;
  int initializeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int stopSpeakingCalls = 0;
  int disposeCalls = 0;
  bool _isListening = false;

  @override
  bool get speechAvailable => available;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initializeSpeech(AppLanguage language) async {
    initializeCalls += 1;
    return available;
  }

  @override
  Future<void> startListening({
    required AppLanguage language,
    VoidCallback? onListeningComplete,
  }) async {
    startCalls += 1;
    _isListening = true;
    listeningComplete = onListeningComplete;
  }

  @override
  Future<AgentVoiceTranscript> stopListening() async {
    stopCalls += 1;
    _isListening = false;
    if (stopCompleter != null) return stopCompleter!.future;
    final outcome = transcripts.removeAt(0);
    if (outcome is AgentException) throw outcome;
    return outcome as AgentVoiceTranscript;
  }

  @override
  Future<void> cancelListening() async {
    cancelCalls += 1;
    _isListening = false;
  }

  @override
  Future<void> speak(String text, {required AppLanguage language}) async {
    if (failTts) throw StateError('TTS failed');
    spoken.add(text);
    spokenLanguages.add(language);
  }

  @override
  Future<void> stopSpeaking() async {
    stopSpeakingCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
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
  Map<String, Object?>? clarification,
}) {
  return AgentResponse.fromJson({
    'success': true,
    'sessionId': sessionId,
    'language': language,
    'reply': reply,
    'navigation': navigation,
    'speech': speech,
    'clarification': clarification,
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

Map<String, Object?> _clarificationJson({
  String clarificationId = 'clarify-ui',
}) {
  return {
    'clarificationId': clarificationId,
    'kind': 'entity_reference',
    'question': 'Which one do you mean?',
    'options': [
      {'choiceId': 'choice-a', 'label': 'QA Prescription Plan'},
      {'choiceId': 'choice-b', 'label': 'QA Discharge Plan'},
    ],
    'expiresAt': '2999-01-01T00:00:00.000Z',
  };
}

Future<AgentController> _pumpAgent(
  WidgetTester tester, {
  required _UiFakeClient client,
  AppLanguage language = AppLanguage.english,
  AgentVoiceClient? voiceService,
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
        home: AgentScreen(controller: controller, voiceService: voiceService),
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

OutlinedButton _choiceButton(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey(key)));

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

  testWidgets(
    'mic button exists and device speech initializes only when used',
    (tester) async {
      final voice = _FakeVoiceService(available: false);
      final client = _UiFakeClient([]);
      await _pumpAgent(tester, client: client, voiceService: voice);

      expect(find.byKey(const ValueKey('agent_mic_button')), findsOneWidget);
      expect(voice.initializeCalls, 0);

      await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
      await tester.pump();

      expect(voice.initializeCalls, 1);
      expect(voice.startCalls, 0);
      expect(find.byKey(const ValueKey('agent_composer')), findsOneWidget);
    },
  );

  testWidgets('recording state is visible and stop sends transcript once', (
    tester,
  ) async {
    final voice = _FakeVoiceService();
    final stop = Completer<AgentVoiceTranscript>();
    voice.stopCompleter = stop;
    final client = _UiFakeClient([_response()]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    expect(find.text('Recording'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    expect(find.text('Transcribing'), findsOneWidget);
    expect(voice.stopCalls, 1);

    stop.complete(
      const AgentVoiceTranscript(text: 'Aaj mera next task kya hai?'),
    );
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'Aaj mera next task kya hai?');
    expect(client.requests.single.requestSpeech, isFalse);
    expect(client.requests.single.toJson(), {
      'message': 'Aaj mera next task kya hai?',
    });
    expect(controller.messages.first.text, 'Aaj mera next task kya hai?');
  });

  testWidgets('empty/no-speech transcript does not send Agent request', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [
        const AgentException('No speech', code: AgentErrorCode.noSpeech),
      ],
    );
    final client = _UiFakeClient([]);
    await _pumpAgent(tester, client: client, voiceService: voice);

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
    final voice = _FakeVoiceService(
      transcripts: [
        const AgentVoiceTranscript(text: 'Aaj wali exercise skip kar do'),
      ],
    );
    final client = _UiFakeClient([
      _response(
        confirmationId: 'voice-confirm',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    await _pumpAgent(tester, client: client, voiceService: voice);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.toJson(), {
      'message': 'Aaj wali exercise skip kar do',
    });

    expect(
      find.byKey(
        const ValueKey('agent_confirmation_card_agent_msg_2_voice-confirm'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'clarification question and choices render and send one selection',
    (tester) async {
      final client = _UiFakeClient([
        _response(
          reply: 'Which one do you mean?',
          clarification: _clarificationJson(),
        ),
        _response(reply: 'Opening QA Prescription Plan.'),
      ]);
      final controller = await _pumpAgent(tester, client: client);

      await _sendFromComposer(tester, controller, client, 'us wala dikhao');

      expect(find.text('Which one do you mean?'), findsNWidgets(2));
      expect(find.text('QA Prescription Plan'), findsOneWidget);
      expect(find.text('QA Discharge Plan'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('agent_clarification_card_agent_msg_2_clarify-ui'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'agent_clarification_choice_agent_msg_2_clarify-ui_choice-a',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.requests.last.toJson(), {
        'sessionId': 's-ui',
        'message': 'us wala dikhao',
        'clarification': {
          'clarificationId': 'clarify-ui',
          'choiceId': 'choice-a',
        },
      });
      expect(controller.pendingClarification, isNull);
      expect(
        _choiceButton(
          tester,
          'agent_clarification_choice_agent_msg_2_clarify-ui_choice-a',
        ).onPressed,
        isNull,
      );
    },
  );

  testWidgets('clarification double tap cannot send twice', (tester) async {
    final selectionCompleter = Completer<AgentResponse>();
    final client = _UiFakeClient([
      _response(
        reply: 'Which one do you mean?',
        clarification: _clarificationJson(),
      ),
      selectionCompleter,
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'us wala dikhao');
    final choiceFinder = find.byKey(
      const ValueKey(
        'agent_clarification_choice_agent_msg_2_clarify-ui_choice-a',
      ),
    );

    await tester.tap(choiceFinder);
    await tester.tap(choiceFinder);
    await tester.pump();

    expect(controller.clarificationLoading, isTrue);
    expect(client.requests, hasLength(2));
    expect(
      _choiceButton(
        tester,
        'agent_clarification_choice_agent_msg_2_clarify-ui_choice-a',
      ).onPressed,
      isNull,
    );

    selectionCompleter.complete(_response(reply: 'Opening selected plan.'));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(2));
    expect(controller.clarificationLoading, isFalse);
  });

  testWidgets('normal composer remains usable and retires old clarification', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        reply: 'Which one do you mean?',
        clarification: _clarificationJson(),
      ),
      _response(reply: 'Here are your care plans.'),
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'us wala dikhao');
    expect(controller.pendingClarification?.clarificationId, 'clarify-ui');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
          .enabled,
      isTrue,
    );

    await _sendFromComposer(tester, controller, client, 'show all care plans');

    expect(controller.pendingClarification, isNull);
    expect(
      _choiceButton(
        tester,
        'agent_clarification_choice_agent_msg_2_clarify-ui_choice-a',
      ).onPressed,
      isNull,
    );
    expect(client.requests, hasLength(2));
  });

  testWidgets('voice ambiguity renders choices and does not auto-select', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'us wala dikhao')],
    );
    final client = _UiFakeClient([
      _response(
        reply: 'Aap kis wale ki baat kar rahe hain?',
        language: 'roman_ur',
        clarification: _clarificationJson(),
      ),
    ]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'us wala dikhao');
    expect(controller.pendingClarification?.clarificationId, 'clarify-ui');
    expect(find.text('QA Prescription Plan'), findsOneWidget);
    expect(voice.spoken, ['Aap kis wale ki baat kar rahe hain?']);
  });

  testWidgets('voice response speech follows Agent reply language', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'haan')],
    );

    final client = _UiFakeClient([
      _response(reply: 'Aapka next task tayyar hai.', language: 'roman_ur'),
    ]);

    await _pumpAgent(
      tester,
      client: client,
      language: AppLanguage.english,
      voiceService: voice,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'haan');
    expect(client.requests.single.requestSpeech, isFalse);

    expect(voice.spoken, ['Aapka next task tayyar hai.']);

    expect(voice.spokenLanguages, [AppLanguage.romanUrdu]);

    // App/UI language remains English even though
    // the Agent reply language is Roman Urdu.
    expect(find.text('SehatMate AI'), findsOneWidget);

    // Roman Urdu Agent reply is rendered normally.
    expect(find.text('Aapka next task tayyar hai.'), findsOneWidget);
  });

  testWidgets('spoken haan with pending confirmation uses backend flow', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'haan')],
    );
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-voice-yes',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(reply: 'Action confirmed.', actionStatus: 'confirmed'),
    ]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await _sendFromComposer(tester, controller, client, 'Prepare skip');
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.last.toJson(), {
      'sessionId': 's-ui',
      'message': 'haan',
    });
    expect(controller.pendingConfirmation, isNull);
  });

  testWidgets('spoken haan without pending confirmation stays normal text', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'haan')],
    );
    final client = _UiFakeClient([
      _response(reply: 'What should I help with?'),
    ]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.toJson(), {'message': 'haan'});
    expect(controller.pendingConfirmation, isNull);
  });

  testWidgets('cancel transcript is sent literally to existing Agent flow', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'nahi')],
    );
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-voice-no',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(reply: 'Action cancelled.', actionStatus: 'cancelled'),
    ]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await _sendFromComposer(tester, controller, client, 'Prepare skip');
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.last.toJson(), {
      'sessionId': 's-ui',
      'message': 'nahi',
    });
    expect(controller.pendingConfirmation, isNull);
  });

  testWidgets('voice navigation renders only from AgentResponse navigation', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: 'care plans kholo')],
    );
    final client = _UiFakeClient([
      _response(
        reply: 'I can open care plans.',
        navigation: {'target': 'care_plans', 'params': <String, String>{}},
      ),
    ]);
    await _pumpAgent(tester, client: client, voiceService: voice);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.message, 'care plans kholo');
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('arbitrary spoken route cannot create local navigation', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [const AgentVoiceTranscript(text: '/admin/delete')],
    );
    final client = _UiFakeClient([
      _response(
        reply: 'I cannot open that.',
        navigation: {'target': '/admin/delete', 'params': <String, String>{}},
      ),
    ]);
    await _pumpAgent(tester, client: client, voiceService: voice);

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests.single.toJson(), {'message': '/admin/delete'});
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('TTS failure leaves Agent action state unchanged', (
    tester,
  ) async {
    final voice = _FakeVoiceService(
      transcripts: [
        const AgentVoiceTranscript(text: 'aaj wali exercise skip kar do'),
      ],
      failTts: true,
    );
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-tts-failure',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);
    final controller = await _pumpAgent(
      tester,
      client: client,
      voiceService: voice,
    );

    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent_mic_button')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    expect(
      controller.pendingConfirmation?.confirmationId,
      'confirm-tts-failure',
    );
    expect(
      find.text('The answer is shown, but audio playback failed.'),
      findsOneWidget,
    );
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

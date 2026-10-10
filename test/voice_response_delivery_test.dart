import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_message.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixtures;
import 'agent_task_workflow_test.dart' as workflows;
import 'package:sehatmate_ai/features/agent/voice/voice_turn_trace.dart';

void main() {
  late AgentController agent;
  late VoiceCompanionController voice;
  late fixtures.Transport transport;
  late LanguageController language;
  Completer<void>? action;
  var actions = 0;
  var seq = 0;
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'test-token',
      'sehatroute_auth_user': '{"id":"test","name":"Test","email":"test@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({AgentSessionStore.key: '41'});
    seq = 0; actions = 0; action = null;
    agent = AgentController(client: fixtures.Client(), onCopilotResult: (_, _) async {
      actions++;
      await action?.future;
    });
    transport = fixtures.Transport();
    language = LanguageController.forTesting();
    voice = VoiceCompanionController(backend: fixtures.Backend(), transport: transport,
      agent: agent, authenticated: () => true);
  });
  tearDown(() async {
    if (action != null && !action!.isCompleted) action!.complete();
    await voice.end(); voice.dispose(); agent.dispose(); language.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.runAsync(() => voice.start(AppLanguage.english));
    await tester.pumpWidget(LanguageScope(controller: language, child: MaterialApp(
      home: AnimatedBuilder(animation: voice, builder: (_, _) => VoiceCompanionSurface(controller: voice)))));
  }
  Future<void> emit(WidgetTester tester, String kind, String turn, [Map<String, dynamic> payload = const {}]) async {
    transport.event(kind, ++seq, turnId: turn, payload: payload);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  Future<void> complete(WidgetTester tester, String turn, String reply, [Map<String, dynamic> fields = const {}]) async {
    await emit(tester, 'transcript_final', turn, {'text': 'spoken input'});
    await emit(tester, 'processing', turn);
    await emit(tester, 'agent_result', turn, {'result': {...fixtures.result, 'reply': reply, ...fields}});
  }

  testWidgets('normal result is visible before any TTS event and equals history', (tester) async {
    await mount(tester);
    await complete(tester, 'normal', 'Yes, I can hear you.');
    expect(voice.state, 'listening');
    expect(find.text('Yes, I can hear you.'), findsOneWidget);
    expect(agent.messages.last.text, voice.reply);
    expect(actions, 1);
  });
  testWidgets('text and state publish before awaited Copilot action completes', (tester) async {
    await mount(tester); action = Completer<void>();
    var results=0;
    voice.onResult=(_) => results++;
    await complete(tester, 'action', 'What name should I give the care plan?');
    expect(actions, 1);
    expect(voice.state, 'listening');
    expect(find.text('What name should I give the care plan?'), findsOneWidget);
    expect(find.text('Thinking...'), findsNothing);
    expect(results,0);
    await voice.mute();
    action!.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:20)));
    await tester.pump();
    expect(results,1);
    expect(voice.state,'muted');
    expect(transport.mic,isFalse);
    expect(agent.messages.last.text,voice.reply);
  });
  testWidgets('TTS failure retains assistant text in live surface', (tester) async {
    await mount(tester); await complete(tester, 'failed-audio', 'The saved authoritative answer.');
    await emit(tester, 'fallback_required', 'failed-audio', {'component':'tts','code':'FISH_RATE_LIMIT'});
    expect(find.text('The saved authoritative answer.'), findsOneWidget);
    expect(find.text('Voice needs attention'), findsOneWidget);
    expect(agent.messages.last.text, voice.reply);
  });
  testWidgets('question review cancellation next chat all remain visible after playback', (tester) async {
    await mount(tester);
    final replies = ['What name should I give the care plan?', 'Create a draft care plan named Test?',
      'Care plan creation cancelled.', 'Yes, I can hear you.'];
    for (var i=0;i<replies.length;i++) {
      final turn='case-$i';
      final fields = i==0
          ? <String,dynamic>{'taskWorkflow':{'workflowId':'workflow-1','kind':'create_care_plan','revision':1,
              'status':'collecting','fields':<String,dynamic>{},'awaitingField':'title'}}
          : i==1
          ? <String,dynamic>{'taskWorkflow':workflows.snapshot(title:'Test'), 'actionStatus':'awaiting_confirmation',
              'confirmation':{'confirmationId':'confirm-1','kind':'create_care_plan','message':replies[i]}}
          : i==2
          ? <String,dynamic>{'taskWorkflow':{'workflowId':'workflow-1','kind':'create_care_plan','revision':3,
              'status':'cancelled','fields':{'title':'Test'}},'actionStatus':'cancelled'}
          : <String,dynamic>{};
      await complete(tester, turn, replies[i], fields);
      if(i==1) expect(agent.pendingConfirmation?.kind,'create_care_plan');
      await emit(tester, 'speaking', turn, {'playbackId': 'play-$i'});
      await emit(tester, 'playback_complete', turn, {'playbackId': 'play-$i'});
      expect(find.text(replies[i]), findsOneWidget);
      expect(agent.messages.last.text, replies[i]);
      expect(transport.mic, isTrue);
    }
    expect(actions, 4);
    expect(agent.messages.where((m)=>m.author==AgentMessageAuthor.assistant).length, 4);
  });
  testWidgets('duplicate result is not duplicated and manual mute still wins', (tester) async {
    await mount(tester); await voice.mute();
    await complete(tester, 'dedup', 'Visible while muted.');
    await emit(tester, 'agent_result', 'dedup', {'result': {...fixtures.result, 'reply':'Visible while muted.'}});
    expect(actions, 1); expect(voice.state, 'muted'); expect(transport.mic, isFalse);
    expect(agent.messages.where((m)=>m.author==AgentMessageAuthor.assistant).length, 1);
    expect(find.text('Visible while muted.'), findsOneWidget);
  });
  testWidgets('new processing displays its transcript rather than an older reply', (tester) async {
    await mount(tester); await complete(tester, 'old', 'Old answer.');
    await emit(tester, 'transcript_final', 'new', {'text':'new input'});
    await emit(tester, 'processing', 'new');
    expect(find.text('Old answer.'), findsNothing);
    expect(find.text('new input'), findsOneWidget);
  });
  test('opaque correlation matches backend and Worker without including the turn', () {
    expect(voiceTurnCorrelation('hello'),'4f9f2cab');
  });
}

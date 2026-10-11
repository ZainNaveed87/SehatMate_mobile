import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_host.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_surface.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/care_plans_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixture;

class Decisions extends fixture.Backend {
  final bodies=<Map<String,dynamic>>[];
  Completer<Map<String,dynamic>>? pending;
  @override Future<Map<String,dynamic>> submit(String id,Map<String,dynamic> body) async {
    bodies.add(body);
    return pending?.future??super.submit(id,body);
  }
}
class TrackedTransport extends fixture.Transport {
  int disconnects=0;
  @override Future<void> disconnect() async {disconnects++;await super.disconnect();}
}
Future<void> drain() => Future<void>.delayed(const Duration(milliseconds:30));
void main() {
  late AgentController agent;
  late VoiceCompanionController voice;
  late Decisions backend;
  late TrackedTransport transport;
  late LanguageController language;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'sehatroute_auth_token':'test-token','sehatroute_auth_user':'{"id":"a","name":"User","email":"test@example.com"}'});
    await AuthSession.instance.initialize();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({AgentSessionStore.key:'41'});
    agent=AgentController(client:fixture.Client());backend=Decisions();transport=TrackedTransport();language=LanguageController.forTesting();
    voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
  });
  tearDown(() async {await voice.end();voice.dispose();agent.dispose();language.dispose();});
  Future<void> review() async {
    await voice.start(AppLanguage.english);
    transport.event('transcript_final',1,turnId:'title',payload:{'text':'naya pakistan'});
    transport.event('processing',2,turnId:'title');
    transport.event('agent_result',3,turnId:'title',payload:{'result':{
      ...fixture.result,'reply':'Create this draft?', 'actionStatus':'awaiting_confirmation',
      'confirmation':{'confirmationId':'review','kind':'create_care_plan','message':'Create this draft?'},
      'taskWorkflow':{'workflowId':'workflow','kind':'create_care_plan','revision':2,'status':'awaiting_confirmation','fields':{'title':'naya pakistan'},'confirmationId':'review','expiresAt':'2099-01-01T00:00:00Z'},
    }});
    await drain();
  }
  for(final decision in [true,false]) {
    test('guided ${decision?'confirm':'cancel'} uses one receipt contract without muting healthy input',() async {
      await review();backend.replyResult={...fixture.result,'actionStatus':decision?'confirmed':'cancelled'};
      final changes=List<bool>.of(transport.microphoneChanges);
      await voice.confirm('review',decision);
      expect(backend.bodies.single['confirmation'],{'confirmationId':'review','decision':decision?'confirm':'cancel'});
      expect(backend.bodies.single.containsKey('message'),false);
      expect(agent.pendingConfirmation,isNull);expect(transport.mic,true);expect(voice.muted,false);
      expect(transport.microphoneChanges.skip(changes.length),isNot(contains(false)));
      expect(transport.controls.where((v)=>v['type']=='mute'),isEmpty);
      expect(transport.disconnects,0);expect(voice.state,'listening');expect(voice.recoveryRequired,false);
      await voice.confirm('review',decision);expect(backend.bodies.length,1);
    });
  }
  test('simultaneous review clicks submit only once',() async {
    await review();backend.pending=Completer();
    final first=voice.confirm('review',true);await Future<void>.delayed(Duration.zero);
    await voice.confirm('review',true);expect(backend.bodies.length,1);
    backend.pending!.complete({'status':'completed','epoch':1,'turnId':backend.bodies.single['turnId'],'result':{...fixture.result,'actionStatus':'confirmed'}});
    await first;expect(agent.pendingConfirmation,isNull);
  });
  test('interrupting the confirmation prompt cannot end the pending decision processing state',() async {
    await review();transport.event('speaking',4,payload:{'playbackId':'prompt'});await drain();
    backend.pending=Completer();final deciding=voice.confirm('review',true);await Future<void>.delayed(Duration.zero);
    transport.event('interrupted',5);await drain();expect(voice.state,'processing');expect(transport.mic,true);
    backend.pending!.complete({'status':'completed','epoch':1,'turnId':backend.bodies.single['turnId'],'result':{...fixture.result,'actionStatus':'confirmed'}});
    await deciding;expect(voice.state,'listening');
  });
  test('Worker delivery of the button receipt cannot append a duplicate assistant turn',() async {
    await review();backend.replyResult={...fixture.result,'actionStatus':'confirmed'};
    await voice.confirm('review',true);final count=agent.messages.length;
    transport.event('agent_result',4,turnId:backend.bodies.single['turnId'],payload:{'result':backend.replyResult});await drain();
    expect(agent.messages.length,count);expect(agent.pendingConfirmation,isNull);expect(backend.bodies.length,1);
    expect(transport.controls.where((v)=>v['type']=='receipt_ready').single['turnId'],backend.bodies.single['turnId']);
  });
  test('confirmation while manually muted never resumes or speaks automatically',() async {
    await review();await voice.mute();backend.replyResult={...fixture.result,'actionStatus':'confirmed'};
    await voice.confirm('review',true);expect(voice.muted,true);expect(transport.mic,false);expect(voice.state,'muted');
  });
  test('old confirmation result cannot act on a newer listening session',() async {
    await review();backend.pending=Completer();
    final first=voice.confirm('review',true);await Future<void>.delayed(Duration.zero);
    await voice.end();await voice.start(AppLanguage.english);
    backend.receiptStatus='recovery_required';
    transport.event('processing',1,turnId:'new-current');await Future<void>.delayed(Duration.zero);
    backend.pending!.completeError(StateError('obsolete submission'));await first;
    expect(voice.state,'processing');expect(voice.recoveryRequired,false);expect(transport.mic,true);
    expect(backend.calls.where((v)=>v=='receipt'),isEmpty);
  });
  test('healthy pending confirmation has no attention transition',() async {
    final logs=<String>[];final previous=debugPrint;
    debugPrint=(String? message,{int? wrapWidth}){if(message!=null)logs.add(message);};
    try {await review();expect(logs.where((v)=>v.contains('VOICE_ATTENTION_REQUIRED')),isEmpty);expect(transport.mic,true);expect(voice.state,'awaiting_confirmation');}
    finally {debugPrint=previous;}
  });
  test('genuine Worker fallback records its first safe attention reason and retry recovers',() async {
    await review();final logs=<String>[];final previous=debugPrint;
    debugPrint=(String? message,{int? wrapWidth}){if(message!=null)logs.add(message);};
    try {
      transport.event('fallback_required',4,payload:{'component':'tts','code':'FISH_RATE_LIMIT'});await drain();
      final event=logs.map((s){try{return jsonDecode(s);}catch(_){return null;}}).whereType<Map>().firstWhere((v)=>v['event']=='VOICE_ATTENTION_REQUIRED');
      expect(event['code'],'FISH_RATE_LIMIT');expect(event['state'],'awaiting_confirmation');
      expect(voice.state,'recovering');expect(voice.muted,false);expect(transport.disconnects,0);
      await voice.resume();expect(voice.state,'listening');expect(transport.mic,true);
    } finally {debugPrint=previous;}
  });
  test('invalid result records an event failure without printing its private content',() async {
    await review();final logs=<String>[];final previous=debugPrint;
    debugPrint=(String? message,{int? wrapWidth}){if(message!=null)logs.add(message);};
    try {
      transport.event('agent_result',4,turnId:'bad',payload:{'result':{...fixture.result,'sessionId':'private-rejected'}});await drain();
      expect(logs.join(),contains('VOICE_EVENT_RECOVERY_REQUIRED'));expect(logs.join(),isNot(contains('private-rejected')));
      expect(voice.recoveryRequired,true);expect(voice.muted,false);expect(transport.mic,false);
    }finally{debugPrint=previous;}
  });
  testWidgets('guided form verifies final real value before allowing shared confirmation', (tester) async {
    await tester.runAsync(review);voice.minimizePresentation();
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:r),p=CopilotPresentation()..enterGuided(const GuidanceSummary('care_plan_new'));
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(builder:(context,child)=>Overlay.wrap(child:VoiceCompanionScope(controller:voice,child:CopilotHost(voice:voice,registry:r,executor:e,presentation:p,child:child!))),home:const NewCarePlanScreen())));
    await tester.pump();await tester.pump(const Duration(milliseconds:80));
    expect(find.byKey(const ValueKey('guided_pending_confirmation')),findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('guided_confirmation_confirm'))).onPressed,isNull);
    await tester.pump(const Duration(milliseconds:450));await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field'))).controller!.text,'naya pakistan');
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('guided_confirmation_confirm'))).onPressed,isNotNull);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('new_care_plan_continue_button'))).onPressed,isNull,
      reason:'The ordinary form submit must not create a second plan beside a pending Agent transaction.');
    expect(agent.pendingConfirmation!.confirmationId,agent.taskWorkflow!.confirmationId);
    expect(agent.messages.where((m)=>m.confirmation!=null).length,1);expect(transport.mic,true);expect(voice.state,'awaiting_confirmation');
    backend.replyResult={...fixture.result,'actionStatus':'confirmed'};
    await tester.tap(find.byKey(const ValueKey('guided_confirmation_confirm')));await tester.pumpAndSettle();
    expect(backend.bodies.single['confirmation'],{'confirmationId':'review','decision':'confirm'});
    expect(find.byKey(const ValueKey('guided_pending_confirmation')),findsNothing);expect(transport.disconnects,0);
    await tester.pumpWidget(const SizedBox());e.dispose();r.dispose();p.dispose();
  });
  testWidgets('voice surface exposes the same pending confirmation and cancellation', (tester) async {
    await tester.runAsync(review);
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(home:AnimatedBuilder(animation:voice,builder:(context,_)=>VoiceCompanionSurface(controller:voice)))));await tester.pump(const Duration(milliseconds:300));
    expect(find.byKey(const ValueKey('voice_pending_confirmation')),findsOneWidget);
    backend.replyResult={...fixture.result,'actionStatus':'cancelled'};
    await tester.ensureVisible(find.byKey(const ValueKey('voice_confirmation_cancel')));await tester.tap(find.byKey(const ValueKey('voice_confirmation_cancel')));await tester.pump(const Duration(milliseconds:300));
    expect(backend.bodies.single['confirmation'],{'confirmationId':'review','decision':'cancel'});expect(transport.mic,true);expect(voice.state,'listening');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('chat and guided form represent one authoritative pending object without adding a turn', (tester) async {
    await tester.runAsync(review);final pending=agent.pendingConfirmation;
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(home:VoiceCompanionScope(controller:voice,child:AgentScreen(controller:agent)))));await tester.pump(const Duration(milliseconds:300));
    expect(find.text('Create this draft?'),findsWidgets);expect(agent.pendingConfirmation,same(pending));expect(agent.messages.where((m)=>m.confirmation!=null).length,1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('editing a reviewed title disables Confirm without rewriting it', (tester) async {
    await tester.runAsync(review);
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(home:VoiceCompanionScope(controller:voice,child:const NewCarePlanScreen()))));
    await tester.pump();await tester.pump(const Duration(milliseconds:450));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new_care_plan_name_field')),'My own edit');await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('guided_confirmation_confirm'))).onPressed,isNull);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field'))).controller!.text,'My own edit');
    expect(agent.taskWorkflow!.title,'naya pakistan');expect(agent.pendingConfirmation!.confirmationId,'review');
    expect(transport.mic,true);expect(backend.bodies,isEmpty);await tester.pumpWidget(const SizedBox());
  });
  for (final selected in [AppLanguage.english,AppLanguage.romanUrdu,AppLanguage.urdu]) {
    testWidgets('guided confirmation controls fit a narrow form in $selected', (tester) async {
      tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(320,700);
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await language.setLanguage(selected,syncToServer:false);await tester.runAsync(review);
      await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(home:VoiceCompanionScope(controller:voice,child:const NewCarePlanScreen()))));
      await tester.pump();await tester.pump(const Duration(milliseconds:450));await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guided_pending_confirmation')),findsOneWidget);expect(tester.takeException(),isNull);
      expect(transport.mic,true);await tester.pumpWidget(const SizedBox());
    });
  }
}

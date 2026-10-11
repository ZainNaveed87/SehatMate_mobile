import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_host.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/care_plans_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixture;

AgentResponse titleReply(String title) => AgentResponse.fromJson({
  ...fixture.result, 'reply':'Create this draft?', 'actionStatus':'awaiting_confirmation',
  'confirmation':{'confirmationId':'review','kind':'create_care_plan','message':'Create this draft?'},
  'taskWorkflow':{'workflowId':'workflow','kind':'create_care_plan','revision':2,'status':'awaiting_confirmation','fields':{'title':title},'confirmationId':'review','expiresAt':'2099-01-01T00:00:00Z'},
});

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'sehatroute_auth_token':'test-token','sehatroute_auth_user':'{"id":"a","name":"User","email":"test@example.com"}'});
    await AuthSession.instance.initialize();
  });
  setUp(() => SharedPreferences.setMockInitialValues({AgentSessionStore.key:'41'}));
  for(final width in [320.0,360.0,375.0,400.0]) {
    testWidgets('guided voice controls fit care-plan screen at $width', (tester) async {
      tester.view.devicePixelRatio=1;tester.view.physicalSize=Size(width,800);
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final agent=AgentController(client:fixture.Client()),transport=fixture.Transport();
      final voice=VoiceCompanionController(backend:fixture.Backend(),transport:transport,agent:agent,authenticated:()=>true);
      await tester.runAsync(()=>voice.start(AppLanguage.english));
      final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused')),p=CopilotPresentation();
      r.walkthroughCommand=(_)async=>true;p.enterGuided(const GuidanceSummary('care_plan_new',targetId:'care_plan_new.name'));
      final locale=LanguageController.forTesting();
      await tester.pumpWidget(LanguageScope(controller:locale,child:MaterialApp(builder:(context,child)=>Overlay.wrap(child:VoiceCompanionScope(controller:voice,child:CopilotHost(voice:voice,registry:r,executor:e,presentation:p,child:child!))),home:const NewCarePlanScreen())));
      await tester.pumpAndSettle();expect(tester.takeException(),isNull);
      expect(voice.enabled,true);expect(voice.muted,false);expect(transport.mic,true);
      await tester.pumpWidget(const SizedBox());await tester.runAsync(voice.end);voice.dispose();agent.dispose();locale.dispose();e.dispose();r.dispose();p.dispose();
    });
    for(final language in AppLanguage.values) {
      testWidgets('New Care Plan fits $width in $language', (tester) async {
        tester.view.devicePixelRatio=1;tester.view.physicalSize=Size(width,800);
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final locale=LanguageController.forTesting();
        await locale.setLanguage(language,syncToServer:false);
        await tester.pumpWidget(LanguageScope(controller:locale,child:const MaterialApp(home:NewCarePlanScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(),isNull);
        expect(tester.getRect(find.byKey(const ValueKey('new_care_plan_name_field'))).right,lessThanOrEqualTo(width));
        await tester.pumpWidget(const SizedBox());locale.dispose();
      });
    }
  }
  testWidgets('name highlight bounds exclude helper and follow actual input after scroll', (tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(400,800);
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused'));
    final locale=LanguageController.forTesting();
    await tester.pumpWidget(LanguageScope(controller:locale,child:MaterialApp(home:CopilotScope(registry:r,executor:e,child:const NewCarePlanScreen()))));
    await tester.pumpAndSettle();
    final revealing=r.reveal('care_plan_new.name','highlight');await tester.pumpAndSettle();expect(await revealing,true);
    final field=find.byKey(const ValueKey('new_care_plan_name_field'));
    final input=find.descendant(of:field,matching:find.byType(InputDecorator));
    final highlight=find.byKey(const ValueKey('copilot_highlight_care_plan_new.name'));
    // The real control has no supporting subtext inside its measured anchor.
    expect(tester.widget<InputDecorator>(input).decoration.helperText,isNull);
    expect(tester.getRect(highlight),tester.getRect(field));
    final helper=find.text('Choose a unique name you will recognize later.').last;
    expect(tester.getRect(helper).top,greaterThanOrEqualTo(tester.getRect(highlight).bottom));
    await tester.drag(find.byType(SingleChildScrollView).first,const Offset(0,-80));await tester.pumpAndSettle();
    expect(tester.getRect(highlight),tester.getRect(field));expect(r.highlightedTarget,'care_plan_new.name');
    await tester.pumpWidget(const SizedBox());locale.dispose();e.dispose();r.dispose();
  });
  testWidgets('authoritative title types progressively, disables submit, then completes exactly', (tester) async {
    final agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:fixture.Backend(),transport:fixture.Transport(),agent:agent,authenticated:()=>true);
    final locale=LanguageController.forTesting();
    await tester.pumpWidget(LanguageScope(controller:locale,child:MaterialApp(home:VoiceCompanionScope(controller:voice,child:const NewCarePlanScreen()))));await tester.pumpAndSettle();
    await tester.runAsync(()=>agent.acceptVoiceResult(titleReply('naya pakistan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:100));
    final field=tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field')));
    expect(field.controller!.text,isNotEmpty);expect(field.controller!.text,isNot('naya pakistan'));
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('new_care_plan_continue_button'))).onPressed,isNull);
    await tester.pump(const Duration(milliseconds:450));await tester.pumpAndSettle();expect(field.controller!.text,'naya pakistan');expect(field.controller!.selection.baseOffset,13);
    await tester.pumpWidget(const SizedBox());voice.dispose();agent.dispose();locale.dispose();
  });
  testWidgets('app-owned connected voice survives navigation, highlight, fill, dialog and user edit', (tester) async {
    final backend=fixture.Backend(),transport=fixture.Transport(),agent=AgentController(client:fixture.Client());
    final voice=VoiceCompanionController(backend:backend,transport:transport,agent:agent,authenticated:()=>true);
    await tester.runAsync(()=>voice.start(AppLanguage.english));
    voice.minimizePresentation();final nav=GlobalKey<NavigatorState>();
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused')),p=CopilotPresentation(),locale=LanguageController.forTesting();
    await tester.pumpWidget(LanguageScope(controller:locale,child:MaterialApp(navigatorKey:nav,navigatorObservers:[CopilotNavigationObserver(r)],builder:(context,child)=>Overlay.wrap(child:VoiceCompanionScope(controller:voice,child:CopilotHost(voice:voice,registry:r,executor:e,presentation:p,child:child!))),home:const Scaffold(body:Text('Home')),routes:{AppRoutes.carePlanNew:(_)=>const NewCarePlanScreen()})));
    await tester.pumpAndSettle();nav.currentState!.pushReplacementNamed(AppRoutes.carePlanNew);await tester.pumpAndSettle();
    expect(VoiceCompanionScope.read(tester.element(find.byType(NewCarePlanScreen))),same(voice));
    final showing=r.reveal('care_plan_new.name','highlight');await tester.pumpAndSettle();expect(await showing,true);
    await tester.runAsync(()=>agent.acceptVoiceResult(titleReply('naya pakistan')));await tester.pump();await tester.pump(const Duration(milliseconds:80));
    expect(voice.enabled,true);expect(voice.muted,false);expect(transport.mic,true);
    await tester.enterText(find.byKey(const ValueKey('new_care_plan_name_field')),'My edit');await tester.pump(const Duration(seconds:1));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field'))).controller!.text,'My edit');
    await tester.runAsync(()=>agent.acceptVoiceResult(titleReply('New Agent title')));await tester.pump();await tester.pump(const Duration(seconds:1));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field'))).controller!.text,'My edit');
    final dialog=showDialog<void>(context:nav.currentState!.overlay!.context,builder:(_)=>const AlertDialog(title:Text('Review')));
    await tester.pumpAndSettle();expect(voice.enabled,true);expect(voice.muted,false);expect(transport.mic,true);
    nav.currentState!.pop();await tester.pumpAndSettle();await dialog;
    expect(transport.connects,1);expect(backend.calls,isNot(contains('end')));expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.runAsync(voice.end);voice.dispose();agent.dispose();locale.dispose();e.dispose();r.dispose();p.dispose();
  });
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_coordinator.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/care_plans_screen.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:sehatmate_ai/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_screen_adapter.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_walkthrough_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'voice_language_switch_test.dart' as languages;
import 'voice_companion_controller_test.dart' as fixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'sehatroute_auth_token':'token','sehatroute_auth_user':'{"id":"a","name":"User","email":"user@example.com"}'});
    await AuthSession.instance.initialize();
  });
  testWidgets('child highlight survives adapter refresh and remains the focused window', (tester) async {
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused'));
    Widget page(String revision)=>MaterialApp(home:CopilotScope(registry:r,executor:e,child:CopilotScreenAdapter(contextData:const AgentScreenContext(screenId:'settings'),title:'Settings',data:CopilotScreenData(stateKey:revision,targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:const [CopilotAction(id:'language.read',kind:'read_section',targetId:'settings.language')]),child:Builder(builder:(context)=>SingleChildScrollView(child:Column(children:[const SizedBox(height:900),copilotAnchor(context,'settings.language',const Text('Language')),const SizedBox(height:900)]))))));
    await tester.pumpWidget(page('one'));await tester.pumpAndSettle();
    final showing=r.reveal('settings.language','highlight');await tester.pumpAndSettle();expect(await showing,true);
    await tester.pumpWidget(page('two'));await tester.pumpAndSettle();
    expect(r.highlightedTarget,'settings.language');expect(r.snapshot!.focusedSectionId,'settings.language');
    await tester.pump(const Duration(seconds:6));expect(r.highlightedTarget,'settings.language');
    expect(r.catalog!.walkthroughOrder, isNot(contains('settings.main')));
    await tester.pumpWidget(const SizedBox());e.dispose();r.dispose();
  });
  testWidgets('reveal centers off-screen real target through nested scrollables', (tester) async {
    final r=CopilotRegistry(accountId:'a');
    r.publish(owner:'screen',screenId:'settings',route:'settings',stateKey:'one',targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:[]);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:Column(children:[const SizedBox(height:500),SizedBox(height:300,child:SingleChildScrollView(child:Column(children:[const SizedBox(height:700),CopilotAnchor(registry:r,targetId:'settings.language',child:const SizedBox(key:Key('target'),height:40,width:100)),const SizedBox(height:700)]))),const SizedBox(height:500)])))));
    final revealing=r.reveal('settings.language','highlight');await tester.pumpAndSettle();expect(await revealing,true);
    final center=tester.getCenter(find.byKey(const Key('target')));expect(center.dy,greaterThan(0));expect(center.dy,lessThan(600));expect(r.highlightedTarget,'settings.language');
    await tester.pumpWidget(const SizedBox());r.dispose();
  });
  testWidgets('unmounted target gives honest failure and never lights a parent', (tester) async {
    final r=CopilotRegistry(accountId:'a');r.publish(owner:'screen',screenId:'settings',route:'settings',stateKey:'one',targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:[]);
    await tester.pumpWidget(const MaterialApp(home:Text('No target')));expect(await r.reveal('settings.language','highlight'),false);expect(r.highlightedTarget,null);r.dispose();
  });
  testWidgets('account invalidation during visual preparation prevents reveal', (tester) async {
    final r=CopilotRegistry(accountId:'a');r.publish(owner:'screen',screenId:'settings',route:'settings',stateKey:'one',targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:[]);
    await tester.pumpWidget(MaterialApp(home:CopilotAnchor(registry:r,targetId:'settings.language',child:const Text('Language'))));
    r.beforeVisualAction=()async{r.invalidate();};expect(await r.reveal('settings.language','highlight'),false);await tester.pumpWidget(const SizedBox());r.dispose();
  });
  testWidgets('reveal is layout-neutral and respects reduced motion', (tester) async {
    final r=CopilotRegistry(accountId:'a');r.publish(owner:'screen',screenId:'settings',route:'settings',stateKey:'one',targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:[]);
    await tester.pumpWidget(MaterialApp(home:MediaQuery(data:const MediaQueryData(size:Size(800,600),disableAnimations:true),child:Center(child:CopilotAnchor(registry:r,targetId:'settings.language',child:const SizedBox(key:Key('content'),height:40,width:120))))));
    final before=tester.getRect(find.byKey(const Key('content')));expect(await r.reveal('settings.language','highlight'),true);await tester.pump();expect(tester.getRect(find.byKey(const Key('content'))),before);
    expect(tester.widget<AnimatedContainer>(find.byKey(const ValueKey('copilot_highlight_settings.language'))).duration,Duration.zero);
    await tester.pumpWidget(const SizedBox());r.dispose();
  });
  testWidgets('walkthrough child next previous repeat survives normal catalog refresh', (tester) async {
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused')),p=CopilotPresentation();final w=CopilotWalkthroughController(registry:r,presentation:p);r.walkthroughCommand=w.command;
    Widget page(String revision)=>MaterialApp(home:CopilotScope(registry:r,executor:e,child:CopilotScreenAdapter(contextData:const AgentScreenContext(screenId:'settings'),title:'Settings',data:CopilotScreenData(stateKey:revision,targets:const [CopilotTarget(id:'settings.language',kind:'control',label:'Language'),CopilotTarget(id:'settings.simple_care',kind:'control',label:'Simple care')]),child:Builder(builder:(context)=>Column(children:[copilotAnchor(context,'settings.language',const Text('Language')),copilotAnchor(context,'settings.simple_care',const Text('Simple care'))])))));
    await tester.pumpWidget(page('one'));await tester.pumpAndSettle();final start=w.start();await tester.pumpAndSettle();expect(await start,true);expect(r.highlightedTarget,'settings.language');
    await tester.pumpWidget(page('two'));await tester.pumpAndSettle();expect(w.state!.status,'active');expect(r.highlightedTarget,'settings.language');
    final next=w.next();await tester.pumpAndSettle();expect(await next,true);expect(r.highlightedTarget,'settings.simple_care');
    final previous=w.previous();await tester.pumpAndSettle();expect(await previous,true);expect(r.highlightedTarget,'settings.language');
    final repeat=w.repeat();await tester.pumpAndSettle();expect(await repeat,true);expect(r.highlightedTarget,'settings.language');w.stop();expect(r.highlightedTarget,null);
    await tester.pumpWidget(const SizedBox());w.dispose();p.dispose();e.dispose();r.dispose();
  });
  test('authoritative conversation response changes voice rendering without changing UI or reconnecting', () async {
    final h=await languages.harness();await h.voice.start(AppLanguage.english);h.backend.replyResult={...fixture.result,'language':'ur','conversationLanguage':'ur','reply':'اب اردو میں بات کریں گے۔'};
    await h.voice.submitManual('ab hum Urdu main baat karte hain');expect(h.voice.language,AppLanguage.urdu);expect(h.languages.language,AppLanguage.english);expect(h.backend.preferencesAtCreate,['English']);expect(h.backend.calls, isNot(contains('end')));
  });
  for(final selected in [AppLanguage.romanUrdu,AppLanguage.urdu]) {testWidgets('global confirmed app action persists Settings and does not claim success early: $selected',(tester)async{
    final h=await tester.runAsync(languages.harness);
    final r=CopilotRegistry(accountId:'a');late CopilotReceipt recorded;
    r.appLanguageCode=()=>h!.languages.language.agentLanguageCode;
    r.setAppLanguage=(code)async{await h!.languages.setLanguage(AppLanguageX.fromStorage(code),persistBeforeNotify:true);await WidgetsBinding.instance.endOfFrame;return h.languages.language.agentLanguageCode==code;};
    final e=CopilotExecutor(registry:r,confirm:(_)async=>true,receipt:(v)async{recorded=v;});
    await tester.pumpWidget(LanguageScope(controller:h!.languages,child:MaterialApp(home:CopilotScope(registry:r,executor:e,child:const AppShell(currentRoute:AppRoutes.dashboard,title:'Home',child:Text('Home'))))));await tester.pumpAndSettle();
    final action=r.snapshot!.actions.singleWhere((a)=>a.id=='app.language.${selected.agentLanguageCode}');expect(action.requiresConfirmation,true);
    final running=e.run(CopilotPlan(id:'issued',screenId:'home',version:r.snapshot!.version,operations:[CopilotOperation(actionId:action.id,targetId:action.targetId,riskTier:2)]));
    await tester.runAsync(()async{await Future<void>.delayed(const Duration(milliseconds:5));});await tester.pumpAndSettle();expect((await running).single.code,'succeeded');expect(recorded.confirmationRef,isNotNull);expect(h.sync.profile.preferredLanguage,selected.serverPreferredLanguage);
    final settings=SettingsService.forTesting();await tester.pumpWidget(LanguageScope(controller:h.languages,child:MaterialApp(home:SettingsScreen(settingsService:settings))));await tester.pumpAndSettle();
    expect(tester.widget<DropdownButtonFormField<AppLanguage>>(find.byKey(const Key('settings_language_dropdown'))).initialValue,selected);
    await tester.pumpWidget(const SizedBox());settings.dispose();e.dispose();r.dispose();
  });}
  testWidgets('real new-care-plan route mounts, title preview follows workflow and chat survives',(tester)async{
    final r=CopilotRegistry(accountId:'a'),e=CopilotExecutor(registry:CopilotRegistry(accountId:'unused'));
    final nav=GlobalKey<NavigatorState>(),observer=CopilotNavigationObserver(r);final coordinator=AgentNavigationCoordinator(navigatorKey:nav,observer:observer,registry:r);
    final agent=AgentController(client:fixture.Client());
    final sharedVoice=VoiceCompanionController(backend:fixture.Backend(),transport:fixture.Transport(),agent:agent,authenticated:()=>true);
    final language=LanguageController.forTesting();
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(navigatorKey:nav,navigatorObservers:[observer],builder:(context,child)=>CopilotScope(registry:r,executor:e,child:VoiceCompanionScope(controller:sharedVoice,child:child!)),home:const AppShell(currentRoute:AppRoutes.dashboard,title:'Home',child:Text('Home')),routes:{AppRoutes.carePlanNew:(_)=>const NewCarePlanScreen()})));await tester.pumpAndSettle();
    final opening=coordinator.navigate(const AgentNavigation(target:'care_plan_new',params:{}));await tester.pumpAndSettle();expect((await opening).succeeded,true);expect(find.byKey(const ValueKey('new_care_plan_name_field')),findsOneWidget);expect(r.hasRenderedTarget('care_plan_new.name'),true);
    final id='workflow',confirmation='confirm-title';
    final response=AgentResponse.fromJson({'success':true,'sessionId':'501','language':'en','reply':'Create this draft?','referencedEntities':[],'actionStatus':'awaiting_confirmation','confirmation':{'confirmationId':confirmation,'kind':'create_care_plan','message':'Create this draft?'},'taskWorkflow':{'workflowId':id,'kind':'create_care_plan','revision':2,'status':'awaiting_confirmation','fields':{'title':'naya pakistan'},'confirmationId':confirmation,'expiresAt':'2099-01-01T00:00:00Z'}});
    await tester.runAsync(()=>agent.acceptVoiceResult(response,transcript:'naya pakistan'));await tester.pumpAndSettle();expect(tester.widget<TextField>(find.byKey(const ValueKey('new_care_plan_name_field'))).controller!.text,'naya pakistan');expect(agent.messages.any((m)=>m.text=='naya pakistan'),true);expect(agent.taskWorkflow!.status,'awaiting_confirmation');
    await tester.pumpWidget(const SizedBox());sharedVoice.dispose();agent.dispose();language.dispose();e.dispose();r.dispose();
  });

  test('confirmed app language updates runtime without RTC reconnect or losing manual mute',()async{
    final h=await languages.harness();await h.voice.start(AppLanguage.english);
    expect(await h.voice.applyAppLanguage(AppLanguage.romanUrdu),true);expect(h.sync.profile.preferredLanguage,'Roman Urdu');expect(h.voice.language,AppLanguage.romanUrdu);expect(h.backend.preferencesAtCreate,['English']);expect(h.backend.calls,isNot(contains('end')));
    await h.voice.mute();expect(await h.voice.applyAppLanguage(AppLanguage.urdu),true);expect(h.voice.state,'muted');expect(h.backend.calls,isNot(contains('end')));
  });
  test('failed persisted app setting returns no success and keeps prior authoritative language',()async{
    final h=await languages.harness();h.sync.fail=true;
    await expectLater(h.voice.applyAppLanguage(AppLanguage.urdu),throwsStateError);expect(h.languages.language,AppLanguage.english);expect(h.sync.profile.preferredLanguage,'English');
  });

}

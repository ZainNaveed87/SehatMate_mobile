import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_host.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_walkthrough_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_coordinator.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/support_screens.dart';
import 'package:sehatmate_ai/screens/document_viewer_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/document_service.dart';
import 'package:sehatmate_ai/services/settings_service.dart';
import 'package:sehatmate_ai/widgets/app_shell.dart';
import 'voice_companion_controller_test.dart' as fixtures;

class IntegrationClient implements AgentClient {
  final responses=<AgentResponse>[];
  final requests=<AgentRequest>[];
  @override Future<AgentResponse> send(AgentRequest request)async {requests.add(request);return responses.removeAt(0);}
}
AgentResponse workflowResult(Map<String,dynamic> workflow,{String status='awaiting_confirmation'})=>AgentResponse.fromJson(jsonDecode(jsonEncode({
  'success':true,'sessionId':'501','language':'roman_ur','reply':'Care plan ka naam confirm karein.','referencedEntities':[], 'actionStatus':status,'taskWorkflow':workflow,
  if(status=='awaiting_confirmation')'confirmation':{'confirmationId':workflow['confirmationId'],'kind':'create_care_plan','message':'Care plan ka naam confirm karein.'},
  if(status=='confirmed')'navigation':{'target':'care_plan_upload','params':{'carePlanId':workflow['completedReceipt']['planId']}}
})));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'sehatroute_auth_token':'token','sehatroute_auth_user':'{"id":"a","name":"User","email":"user@example.com"}'});
    await AuthSession.instance.initialize();
  });
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  testWidgets('shared voice result resolves Settings, real walkthrough and same chat; account fence rejects work', (tester) async {
    final registry=CopilotRegistry(accountId:'a'), presentation=CopilotPresentation()..openChat();
    final executor=CopilotExecutor(registry:registry);
    final navigator=GlobalKey<NavigatorState>(), observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:navigator,observer:observer,registry:registry,beforeVisualAction:()async{presentation.enterGuided(const GuidanceSummary('settings'));await WidgetsBinding.instance.endOfFrame;});
    final walk=CopilotWalkthroughController(registry:registry,presentation:presentation);
    registry.walkthroughCommand=walk.command;
    registry.beforeVisualAction=()async{presentation.enterGuided(const GuidanceSummary('settings'));await WidgetsBinding.instance.endOfFrame;};
    final client=IntegrationClient();
    final agent=AgentController(client:client,onCopilotResult:(result,source)async{if(result.navigation!=null)await coordinator.navigate(result.navigation!);});
    final voice=VoiceCompanionController(backend:fixtures.Backend(),transport:fixtures.Transport(),agent:agent,authenticated:()=>true,delay:(_)async{});
    final language=LanguageController.forTesting(), settings=SettingsService.forTesting();
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(navigatorKey:navigator,navigatorObservers:[observer],builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:true),child:AgentNavigationScope(coordinator:coordinator,child:VoiceCompanionHost(controller:voice,unifiedPresentation:true,child:CopilotHost(voice:voice,registry:registry,executor:executor,presentation:presentation,child:child!)))),home:const AppShell(currentRoute:AppRoutes.dashboard,title:'Home',child:Text('Home')),routes:{AppRoutes.settings:(_)=>SettingsScreen(settingsService:settings),AppRoutes.carePlanUpload:(_)=>const AppShell(currentRoute:AppRoutes.carePlanUpload,title:'Upload',child:Text('Upload documents'))})));
    await tester.pumpAndSettle();
    expect(navigator.currentState,isNotNull);
    await tester.enterText(find.byKey(const ValueKey('agent_composer')),'Unsent question');
    final result=AgentResponse.fromJson({'success':true,'sessionId':'501','language':'roman_ur','reply':'Settings khol raha hoon.','actionStatus':'completed','referencedEntities':[],'navigation':{'target':'settings','params':<String,dynamic>{}}});
    expect(result.navigation,isNotNull);
    final received=agent.acceptVoiceResult(result,transcript:'اصل آواز');
    await tester.pumpAndSettle();await received;
    expect(registry.snapshot!.screenId,'settings');expect(presentation.mode,CopilotMode.guided);
    expect(observer.pages.where((p)=>p.settings.name==AppRoutes.settings),hasLength(1));
    client.responses.add(result);
    final repeated=agent.sendText('Settings khol do');await tester.pumpAndSettle();await repeated;
    expect(observer.pages.where((p)=>p.settings.name==AppRoutes.settings),hasLength(1));
    final start=walk.start();await tester.pumpAndSettle();expect(await start,true);
    final next=walk.next();await tester.pumpAndSettle();expect(await next,true);
    expect(registry.hasRenderedTarget(registry.highlightedTarget!),true);
    final previous=walk.previous();await tester.pumpAndSettle();expect(await previous,true);
    walk.openChat();await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('agent_composer'))).controller!.text,'Unsent question');
    expect(agent.messages.where((m)=>m.text=='اصل آواز'),hasLength(1));
    final resumed=walk.continueGuidance();await tester.pumpAndSettle();expect(await resumed,true);
    walk.stop();expect(registry.highlightedTarget,null);expect(presentation.mode,CopilotMode.collapsed);
    await agent.acceptVoiceResult(workflowResult({'workflowId':'workflow-1','kind':'create_care_plan','revision':1,'status':'collecting','fields':<String,dynamic>{},'awaitingField':'title'},status:'completed'));
    final draft={'workflowId':'workflow-1','kind':'create_care_plan','revision':2,'status':'awaiting_confirmation','fields':{'title':'Zain'},'confirmationId':'confirm-1','expiresAt':'2999-01-01T00:00:00.000Z'};
    client.responses.add(workflowResult(draft));await agent.sendText('Naam Zain');
    final corrected={...draft,'revision':3,'fields':{'title':'Ali'},'confirmationId':'confirm-2'};
    await agent.acceptVoiceResult(workflowResult(corrected));expect(agent.pendingConfirmation!.confirmationId,'confirm-2');expect(agent.taskWorkflow!.title,'Ali');
    final completed=workflowResult({...corrected,'status':'completed','completedReceipt':{'confirmationId':'confirm-2','planId':'17','title':'Ali'}},status:'confirmed');
    client.responses.add(completed);
    final confirmation=agent.confirmPendingAction('confirm-2');final duplicate=agent.confirmPendingAction('confirm-2');
    await tester.pumpAndSettle();await confirmation;await duplicate;
    expect(client.requests.where((r)=>r.confirmationId=='confirm-2'),hasLength(1));
    expect(registry.snapshot!.screenId,'care_plan_upload');expect(registry.snapshot!.entity!.id,'17');
    expect(observer.currentPage!.settings.arguments,isA<CarePlanUploadArgs>());
    final replay=agent.acceptVoiceResult(completed);await tester.pumpAndSettle();await replay;
    expect(observer.pages.where((p)=>p.settings.name==AppRoutes.carePlanUpload),hasLength(1));
    expect(client.requests.where((r)=>r.confirmationId=='confirm-2'),hasLength(1));
    coordinator.invalidate();registry.invalidate();executor.cancel();
    expect(walk.state,null);expect((await coordinator.navigate(result.navigation!)).outcome,NavigationOutcome.stale);
    await tester.pumpAndSettle();expect(find.byKey(const ValueKey('assistant_launcher')),findsNothing);
    await tester.pumpWidget(const SizedBox());await tester.pump(const Duration(milliseconds:600));walk.dispose();voice.dispose();agent.dispose();executor.dispose();registry.dispose();presentation.dispose();language.dispose();settings.dispose();
  });
  testWidgets('plain document viewer retains global Agent access and executes its actual zoom control', (tester) async {
    final registry=CopilotRegistry(accountId:'a'), presentation=CopilotPresentation();
    final executor=CopilotExecutor(registry:registry), agent=AgentController(client:fixtures.Client());
    final voice=VoiceCompanionController(backend:fixtures.Backend(),transport:fixtures.Transport(),agent:agent,authenticated:()=>true,delay:(_)async{});
    final language=LanguageController.forTesting();
    final file=DocumentFile(documentId:'17',originalName:'test.png',mimeType:'image/png',bytes:base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:true),child:VoiceCompanionHost(controller:voice,unifiedPresentation:true,child:CopilotHost(voice:voice,registry:registry,executor:executor,presentation:presentation,child:child!))),home:DocumentViewerScreen(file:file))));
    await tester.pumpAndSettle();expect(registry.snapshot!.screenId,'document_viewer');expect(find.byKey(const ValueKey('assistant_launcher')),findsOneWidget);
    expect(registry.hasRenderedTarget('document_viewer.zoom_in'),true);
    final before=registry.snapshot!.version;
    final action=registry.snapshot!.actions.firstWhere((a)=>a.id=='document_viewer.zoom_in.execute');
    expect(await action.execute!(),true);await tester.pumpAndSettle();expect(registry.snapshot!.version,isNot(before));
    await tester.tap(find.byKey(const ValueKey('assistant_launcher')));await tester.pumpAndSettle();expect(find.byKey(const ValueKey('agent_composer')),findsOneWidget);
    await tester.pumpWidget(const SizedBox());await tester.pump(const Duration(milliseconds:600));voice.dispose();agent.dispose();executor.dispose();registry.dispose();presentation.dispose();language.dispose();
  });
}

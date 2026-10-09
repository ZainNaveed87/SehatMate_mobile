import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_host.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_scope.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/widgets/app_shell.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'token',
      'sehatroute_auth_user':
          '{"id":"a","name":"User","email":"user@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('compact host adapts to a short landscape keyboard viewport', (tester) async {
    tester.view.physicalSize=const Size(640,320);tester.view.devicePixelRatio=1;tester.view.viewInsets=const FakeViewPadding(bottom:140);
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetViewInsets);
    final registry=CopilotRegistry(accountId:'a'),presentation=CopilotPresentation()..openChat();final executor=CopilotExecutor(registry:registry),agent=AgentController(client:fixtures.Client());
    final voice=VoiceCompanionController(backend:fixtures.Backend(),transport:fixtures.Transport(),agent:agent,authenticated:()=>true,delay:(_)async{});final language=LanguageController.forTesting();
    await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:true),child:VoiceCompanionHost(controller:voice,unifiedPresentation:true,child:CopilotHost(voice:voice,registry:registry,executor:executor,presentation:presentation,child:child!))),home:const Scaffold(body:Text('page')))));
    await tester.pumpAndSettle();expect(tester.takeException(),isNull);expect(tester.getRect(find.byKey(const ValueKey('agent_composer'))).bottom,lessThanOrEqualTo(180));
    await tester.pumpWidget(const SizedBox());voice.dispose();agent.dispose();executor.dispose();registry.dispose();presentation.dispose();language.dispose();
  });
  for(final selected in AppLanguage.values) {
    testWidgets('$selected compact host fits keyboard and enlarged text', (tester) async {
      tester.view.physicalSize=const Size(360,640);tester.view.devicePixelRatio=1;
      tester.view.viewInsets=const FakeViewPadding(bottom:240);
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetViewInsets);
      final registry=CopilotRegistry(accountId:'a'),presentation=CopilotPresentation()..openChat();
      final executor=CopilotExecutor(registry:registry),agent=AgentController(client:fixtures.Client());
      final voice=VoiceCompanionController(backend:fixtures.Backend(),transport:fixtures.Transport(),agent:agent,authenticated:()=>true,delay:(_)async{});
      final language=LanguageController.forTesting();await language.setLanguage(selected,syncToServer:false);
      await tester.pumpWidget(LanguageScope(controller:language,child:MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.6),disableAnimations:true),child:VoiceCompanionHost(controller:voice,unifiedPresentation:true,child:CopilotHost(voice:voice,registry:registry,executor:executor,presentation:presentation,child:child!))),home:const Scaffold(body:Text('page')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(tester.getRect(find.byKey(const ValueKey('agent_composer'))).bottom,lessThanOrEqualTo(400));
      await tester.enterText(find.byKey(const ValueKey('agent_composer')),'Unsent draft');
      presentation.minimizeChat();await tester.pumpAndSettle();
      presentation.openChat();await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('agent_composer'))).controller?.text,'Unsent draft');
      await tester.pumpWidget(const SizedBox());voice.dispose();agent.dispose();executor.dispose();registry.dispose();presentation.dispose();language.dispose();
    });
  }
  testWidgets(
    'launcher overlays two routes and preserves shared Agent history and minimized voice',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a'),
          presentation = CopilotPresentation();
      final executor = CopilotExecutor(registry: registry);
      final agent = AgentController(client: fixtures.Client());
      final voice = VoiceCompanionController(
        backend: fixtures.Backend(),
        transport: fixtures.Transport(),
        agent: agent,
        authenticated: () => true,
        delay: (_) async {},
      );
      final language = LanguageController.forTesting();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [CopilotNavigationObserver(registry)],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: VoiceCompanionHost(
                unifiedPresentation:true,
                controller: voice,
                child: CopilotHost(
                  voice: voice,
                  registry: registry,
                  executor: executor,
                  presentation: presentation,
                  child: child!,
                ),
              ),
            ),
            home: const AppShell(
              currentRoute: AppRoutes.dashboard,
              title: 'Home',
              child: Text('Home content'),
            ),
            routes: {
              AppRoutes.dashboard: (_) => const AppShell(
                currentRoute: AppRoutes.dashboard,
                title: 'Home',
                child: Text('Home content'),
              ),
              AppRoutes.progress: (_) => const AppShell(
                currentRoute: AppRoutes.progress,
                title: 'Progress',
                child: Text('Progress content'),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assistant_launcher')));
      await tester.pumpAndSettle();
      expect(presentation.visible, true);
      expect(registry.snapshot!.screenId, 'home');
      await agent.sendText('My question');
      await tester.pumpAndSettle();
      final count = agent.messages.length;
      await tester.tap(find.byTooltip('Minimize Agent'));
      await tester.pumpAndSettle();
      navigator.currentState!.pushNamed(AppRoutes.progress);
      await tester.pumpAndSettle();
      expect(registry.snapshot!.screenId, 'progress');
      await tester.tap(find.byKey(const ValueKey('assistant_launcher')));
      await tester.pumpAndSettle();
      expect(agent.messages.length, count);
      voice.state = 'muted';
      voice.presentationMinimized = true;
      presentation.minimizeChat();
      voice.notifyListeners();
      await tester.pump();
      expect(find.text('Progress content'), findsOneWidget);
      expect(find.byTooltip('Return to voice'), findsOneWidget);
      final current = registry.snapshot!;
      final navigation = current.actions.firstWhere(
        (a) => a.targetId == 'navigation.home',
      );
      final moving = executor.run(
        CopilotPlan(
          id: 'return',
          screenId: current.screenId,
          version: current.version,
          operations: [
            CopilotOperation(
              actionId: navigation.id,
              targetId: navigation.targetId,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect((await moving).single.ok, true);
      expect(presentation.visible, false);
      expect(registry.snapshot!.screenId, 'home');
      expect(agent.messages.length, count);
      registry.invalidate();
      executor.cancel();
      await tester.pump();
      expect(find.byTooltip('Minimize Agent'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      voice.dispose();
      agent.dispose();
      executor.dispose();
      registry.dispose();
      presentation.dispose();
      language.dispose();
    },
  );
}

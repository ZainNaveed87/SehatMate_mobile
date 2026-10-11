import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_host.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_companion_controller.dart';
import 'package:sehatmate_ai/features/agent/widgets/agent_header.dart';
import 'package:sehatmate_ai/features/agent/widgets/agent_confirmation_card.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'voice_companion_controller_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'sehatroute_auth_token':'test-token',
      'sehatroute_auth_user':'{"id":"a","name":"User","email":"test@example.com"}'});
    await AuthSession.instance.initialize();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for(final width in [320.0,360.0,375.0,400.0]) {
    for(final selected in AppLanguage.values) {
      testWidgets('Agent toolbar, sheet, confirmation and guidance fit $width / $selected', (tester) async {
        tester.view.physicalSize=Size(width,800);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final registry=CopilotRegistry(accountId:'a');
        final executor=CopilotExecutor(registry:registry), presentation=CopilotPresentation()..openChat();
        final agent=AgentController(client:fixtures.Client());
        final voice=VoiceCompanionController(backend:fixtures.Backend(),transport:fixtures.Transport(),agent:agent,authenticated:()=>true);
        final languages=LanguageController.forTesting();await languages.setLanguage(selected,syncToServer:false);
        registry.walkthroughCommand=(_)async=>true;
        await tester.pumpWidget(LanguageScope(controller:languages,child:MaterialApp(home:CopilotHost(
          voice:voice,registry:registry,executor:executor,presentation:presentation,onMemory:(){},
          child:Scaffold(body:SingleChildScrollView(child:Column(children:[
            const AgentHeader(title:'SehatMate Agent',subtitle:'Review the requested change before confirming.',showBack:false),
            AgentConfirmationCard(messageId:'m',confirmationId:'c',message:'Review the exact reminder time before saving.',kind:'schedule_time',active:true,loading:false,onConfirm:(_){},onCancel:(_){}),
          ]))),
        ))));
        await tester.pumpAndSettle();expect(tester.takeException(),isNull);
        presentation.enterGuided(const GuidanceSummary('settings'));await tester.pumpAndSettle();
        expect(tester.takeException(),isNull);
        final launcher=tester.getRect(find.byKey(const ValueKey('assistant_launcher')));
        expect(launcher.left,greaterThanOrEqualTo(0));expect(launcher.right,lessThanOrEqualTo(width));
        await tester.pumpWidget(const SizedBox());voice.dispose();agent.dispose();executor.dispose();registry.dispose();presentation.dispose();languages.dispose();
      });
    }
  }
}

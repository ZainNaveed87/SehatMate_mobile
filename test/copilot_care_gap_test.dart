import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_coordinator.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/care_gap_screens.dart';
import 'package:sehatmate_ai/screens/reality_check_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';

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
  testWidgets(
    'verified gap action opens its exact Reality Check question and highlights it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final questionResponse = Completer<void>();
      final service = CarePlanService(
        tokenProvider: () => 'token',
        client: MockClient((request) async {
          if (!request.url.path.endsWith('/care-gaps/17')) {
            await questionResponse.future;
          }
          final data = request.url.path.endsWith('/care-gaps/17')
              ? {
                  'gap': {
                    'id': '17',
                    'care_plan_id': '9',
                    'title': 'Morning schedule barrier',
                    'source_kind': 'reality_check',
                    'source_id': 'question_2',
                    'action_type': 'reality_check',
                    'action_label': 'Review Reality Check',
                    'lifecycle_status': 'open',
                    'blocking': true,
                  },
                }
              : {
                  'questions': [
                    {
                      'key': 'question_1',
                      'question': 'First unrelated question',
                      'options': ['Yes', 'No'],
                    },
                    {
                      'key': 'question_2',
                      'question': 'Can you follow this morning schedule?',
                      'options': ['Yes', 'Timing difficult'],
                    },
                  ],
                };
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      final registry = CopilotRegistry(accountId: 'a'),
          executor = CopilotExecutor(registry: registry);
      final language = LanguageController.forTesting();
      final navigator=GlobalKey<NavigatorState>();final observer=CopilotNavigationObserver(registry);final coordinator=AgentNavigationCoordinator(navigatorKey:navigator,observer:observer,registry:registry);
      FocusedRealityCheckArgs? receivedArgs;
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(navigatorKey:navigator,navigatorObservers:[observer],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: AgentNavigationScope(coordinator:coordinator,child:CopilotScope(
                registry: registry,
                executor: executor,
                child: child!,
              )),
            ),
            home: CareGapDetailScreen(gapId: '17', service: service),
            onGenerateRoute: (settings) {
              if (settings.name != AppRoutes.realityCheck) return null;
              final args = settings.arguments as FocusedRealityCheckArgs;
              receivedArgs=args;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => RealityCheckScreen(
                  planId: args.planId,
                  focusedQuestionKey: args.questionKey,
                  returnToPrevious: true,
                  service: service,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        registry.snapshot!.targets.any((t) => t.id == 'care_gaps.card.17'),
        true,
      );
      final snapshot = registry.snapshot!,
          action = snapshot.actions.firstWhere((a) => a.kind == 'open_entity');
      expect(action.execute, isNotNull);
      expect(navigator.currentState, isNotNull);
      expect(AgentNavigationScope.maybeOf(tester.element(find.byType(CareGapDetailScreen))), isNotNull);
      final future = executor.run(
        CopilotPlan(
          id: 'gap',
          screenId: snapshot.screenId,
          version: snapshot.version,
          operations: [
            CopilotOperation(actionId: action.id, targetId: action.targetId),
          ],
        ),
      );
      var navigationCompleted = false;
      future.then((_) => navigationCompleted = true);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(navigationCompleted, false, reason: navigationCompleted ? (await future).single.code : null);
      questionResponse.complete();
      await tester.pumpAndSettle();
      expect((await future).single.ok, true);
      expect(receivedArgs?.planId,'9');expect(receivedArgs?.questionKey,'question_2');
      expect(registry.snapshot!.screenId, 'reality_check');
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label == 'First unrelated question',
        ),
        false,
      );
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label == 'Can you follow this morning schedule?',
        ),
        true,
      );
      final highlight = registry.reveal(
        'reality_check.question.current',
        'highlight',
      );
      await tester.pumpAndSettle();
      expect(await highlight, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      executor.dispose();
      registry.dispose();
      language.dispose();
    },
  );
}

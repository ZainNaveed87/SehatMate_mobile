import 'package:flutter/material.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_conflict.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_handler.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';

void main() {
  test(
    'verified conflict response preserves bounded resolution choices and drops invented ones',
    () {
      final response = AgentResponse.fromJson({
        'success': true,
        'sessionId': 's',
        'language': 'en',
        'reply': 'Review your open gap.',
        'conflicts': [
          {
            'id': 'gap:17',
            'type': 'unresolved_care_gap',
            'severity': 'attention',
            'evidenceRefs': ['get_care_gaps:17'],
            'affectedTargets': ['care_gaps.card.17'],
            'explainableFacts': {'gapId': '17'},
            'allowedResolutions': ['open_care_gap', 'change_dose'],
            'requiresProfessionalReview': false,
          },
        ],
      });
      expect(response.conflicts.single.allowedResolutions, ['open_care_gap']);
      expect(response.conflicts.single.affectedTargets, ['care_gaps.card.17']);
      expect(response.conflicts.single.facts['gapId'], '17');
    },
  );
  testWidgets(
    'conflict navigation uses verified plan and never highlights unrelated current plan',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      registry.publish(
        owner: 'page',
        screenId: 'reality_check',
        route: 'reality_check',
        stateKey: '1',
        entity: const AgentEntityContext(type: 'care_plan', id: '99'),
        targets: const [
          CopilotTarget(
            id: 'reality_check.main',
            kind: 'section',
            label: 'Current plan',
          ),
        ],
        actions: const [],
      );
      final executor = CopilotExecutor(registry: registry);
      final language = LanguageController.forTesting();
      CareFlowArgs? destination;
      final conflict = CopilotConflict(
        id: 'reality:9',
        type: 'incomplete_reality_check',
        affectedTargets: ['reality_check.main'],
        allowedResolutions: ['open_reality_check'],
        facts: {'planId': '9'},
        professionalReview: false,
      );
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(
            builder: (context, child) => CopilotScope(
              registry: registry,
              executor: executor,
              child: child!,
            ),
            home: Scaffold(
              body: CopilotConflictCard(
                conflict: conflict,
                navigationHandler: const AgentNavigationHandler(),
              ),
            ),
            onGenerateRoute: (settings) {
              destination = settings.arguments as CareFlowArgs;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    const Scaffold(body: Text('Related Reality Check')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show affected section'), findsNothing);
      await tester.tap(find.text('Open Reality Check'));
      await tester.pumpAndSettle();
      expect(destination!.planId, '9');
      expect(find.text('Related Reality Check'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      executor.dispose();
      registry.dispose();
      language.dispose();
    },
  );
}

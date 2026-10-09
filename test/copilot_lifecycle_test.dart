import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_screen_adapter.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';
import 'package:sehatmate_ai/widgets/app_shell.dart';

void main() {
  test('route context keeps entity type and owner IDs precise', () {
    expect(agentContextForRoute(AppRoutes.carePlanNew)!.entity, isNull);
    expect(
      agentContextForRoute(AppRoutes.carePlanUpload)!.screenId,
      'care_plan_upload',
    );
    expect(agentContextForRoute(AppRoutes.carePlanReview)!.entity, isNull);
    expect(agentContextForRoute(AppRoutes.familyNew)!.entity, isNull);
    expect(agentContextForRoute('/family/12/plans/99')!.entity!.id, '12');
    expect(
      agentContextForRoute('/family/12/plans/99')!.screenId,
      'family_member_care_plans',
    );
    expect(agentContextForRoute('/care-plan/9')!.entity!.id, '9');
    expect(agentContextForRoute('/care-plan/not_a_real_plan'), isNull);
    expect(agentContextForRoute('/family/new/plans/99'), isNull);
  });
  test(
    'invalid and prohibited risk tiers never ask confirmation or execute',
    () async {
      final registry = CopilotRegistry(accountId: 'a');
      var calls = 0, confirmations = 0;
      registry.publish(
        owner: 'page',
        screenId: 'home',
        route: 'home',
        stateKey: '1',
        targets: const [
          CopilotTarget(id: 'target', kind: 'section', label: 'Target'),
        ],
        actions: [
          CopilotAction(
            id: 'action',
            kind: 'select_option',
            targetId: 'target',
            execute: () async {
              calls++;
              return true;
            },
          ),
        ],
      );
      final executor = CopilotExecutor(
        registry: registry,
        confirm: (_) async {
          confirmations++;
          return true;
        },
      );
      for (final risk in [-1, 3, 5]) {
        final result = await executor.run(
          CopilotPlan(
            id: 'risk$risk',
            screenId: 'home',
            version: registry.snapshot!.version,
            operations: [
              CopilotOperation(
                actionId: 'action',
                targetId: 'target',
                riskTier: risk,
              ),
            ],
          ),
        );
        expect(result.single.code, 'invalid_arguments');
      }
      expect(calls, 0);
      expect(confirmations, 0);
      executor.dispose();
      registry.dispose();
    },
  );
  testWidgets(
    'real page transitions clear unsupported context, dialogs preserve it, and stacked anchors recover',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      final executor = CopilotExecutor(registry: registry);
      final navigator = GlobalKey<NavigatorState>();
      Widget page(String label) => Scaffold(
        body: CopilotScreenAdapter(
          contextData: const AgentScreenContext(screenId: 'home'),
          title: label,
          child: Text(label),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [CopilotNavigationObserver(registry)],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: CopilotScope(
              registry: registry,
              executor: executor,
              child: child!,
            ),
          ),
          home: page('Original'),
        ),
      );
      await tester.pumpAndSettle();
      final original = registry.snapshot!.version;
      showDialog<void>(
        context: navigator.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(title: Text('Confirm')),
      );
      await tester.pumpAndSettle();
      expect(registry.snapshot!.version, original);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Unsupported')),
        ),
      );
      await tester.pumpAndSettle();
      expect(registry.snapshot, isNull);
      expect(await registry.reveal('home.main', 'highlight'), false);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(registry.snapshot!.screenId, 'home');
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page('Second')),
      );
      await tester.pumpAndSettle();
      expect(registry.snapshot!.targets.first.label, 'Second');
      expect(await registry.reveal('home.main', 'highlight'), true);
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(registry.snapshot!.targets.first.label, 'Original');
      expect(await registry.reveal('home.main', 'highlight'), true);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('copilot_highlight_home.main')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      executor.dispose();
      registry.dispose();
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/features/agent/navigation/semantic_route_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every advertised navigation target has a real closed destination', () {
    const registry = SemanticRouteRegistry();
    for (final target in AgentNavigation.supportedTargets) {
      final params = switch (target) {
        'care_plan_detail' || 'care_plan_upload' || 'care_plan_review' || 'reality_check' || 'simulation' || 'care_gaps' => {'carePlanId': '1'},
        'care_gap_detail' => {'careGapId': '1'},
        'family_member_detail' => {'relationshipId': '1'},
        'family_member_care_plans' => {'relationshipId': '1', 'carePlanId': '2'},
        _ => <String, String>{},
      };
      expect(registry.resolve(AgentNavigation(target: target, params: params)), isNotNull, reason: target);
    }
  });
  test('a disabled mounted control never executes a callback or reports success', () async {
    final registry = CopilotRegistry(accountId: 'a');
    var calls = 0;
    registry.publish(owner: 'page', screenId: 'settings', route: 'settings', stateKey: 'busy',
      targets: const [CopilotTarget(id: 'settings.control', kind: 'control', label: 'Busy', enabled: false)],
      actions: [CopilotAction(id: 'settings.control.open', kind: 'open_section', targetId: 'settings.control', execute: () async {calls++;return true;})]);
    final executor = CopilotExecutor(registry: registry);
    final receipts = await executor.run(CopilotPlan(id: 'plan', screenId: 'settings', version: registry.snapshot!.version,
      operations: const [CopilotOperation(actionId: 'settings.control.open', targetId: 'settings.control')]));
    expect(calls, 0);expect(receipts.single.code, 'action_unavailable');
    executor.dispose();registry.dispose();
  });
}

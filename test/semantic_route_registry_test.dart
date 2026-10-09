import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/features/agent/navigation/semantic_route_registry.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';

void main() {
  test('real aliases resolve and unknown pages cannot execute', () {
    const registry = SemanticRouteRegistry();
    for (final target in ['calendar','today']) {
      expect(registry.resolve(AgentNavigation(target: target))?.routeName, '/calendar');
    }
    expect(registry.resolve(const AgentNavigation(target:'family'))?.routeName,'/family');
    expect(registry.resolve(const AgentNavigation(target:'biometrics')),isNull);
    expect(registry.resolve(const AgentNavigation(target:'settings',params:{'url':'evil'})),isNull);
  });
  test('creation upload requires exact owned-plan destination arguments', () {
    const registry = SemanticRouteRegistry();
    expect(registry.resolve(const AgentNavigation(target:'care_plan_upload')),isNull);
    final destination=registry.resolve(const AgentNavigation(target:'care_plan_upload',params:{'carePlanId':'7'}));
    expect(destination?.routeName,'/care-plan/upload');
    expect((destination?.arguments as CarePlanUploadArgs).planId,'7');
    expect(registry.resolve(const AgentNavigation(target:'family_member_care_plans',params:{'relationshipId':'8','carePlanId':'7'}))?.routeName,'/family/8/plans/7');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/screens/simulation_screen.dart';

void main() {
  test('simulation navigation accepts only safe canonical actions', () {
    expect(canonicalSimulationNavigationAction('schedule'), 'review_schedule');
    expect(
      canonicalSimulationNavigationAction('review_schedule'),
      'review_schedule',
    );
    expect(
      canonicalSimulationNavigationAction('recheck_reality'),
      'reality_check',
    );
    expect(
      canonicalSimulationNavigationAction('keep_at_risk'),
      'reality_check',
    );
    expect(
      canonicalSimulationNavigationAction('review_verified_instruction'),
      'review_instruction',
    );
    expect(canonicalSimulationNavigationAction('documents'), 'documents');
    expect(canonicalSimulationNavigationAction('family_care'), 'family_care');
    expect(canonicalSimulationNavigationAction('calendar'), 'calendar');
    expect(canonicalSimulationNavigationAction('care_plan'), 'care_plan');
    expect(canonicalSimulationNavigationAction('no_change'), 'no_change');

    // Unknown AI/backend strings fail closed to the current care-plan workflow;
    // Flutter never executes an arbitrary route string.
    expect(
      canonicalSimulationNavigationAction('/some/generated/route'),
      'care_plan',
    );
  });
}

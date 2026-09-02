import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';

void main() {
  test('all supplied static routes remain registered', () {
    const routes = <String>{
      AppRoutes.landing,
      AppRoutes.auth,
      AppRoutes.onboarding,
      AppRoutes.dashboard,
      AppRoutes.carePlans,
      AppRoutes.carePlanNew,
      AppRoutes.carePlanUpload,
      AppRoutes.carePlanReview,
      AppRoutes.realityCheck,
      AppRoutes.simulation,
      AppRoutes.calendar,
      AppRoutes.careGaps,
      AppRoutes.doctorQuestions,
      AppRoutes.documents,
      AppRoutes.family,
      AppRoutes.familyNew,
      AppRoutes.notifications,
      AppRoutes.patientProfile,
      AppRoutes.progress,
      AppRoutes.settings,
      AppRoutes.simpleCare,
      AppRoutes.teachBack,
    };

    expect(routes, hasLength(22));
    expect(AppRoutes.carePlan('p1'), '/care-plan/p1');
    expect(AppRoutes.careGap('g1'), '/care-gaps/g1');
    expect(AppRoutes.caregiver('c1'), '/family/c1');
  });
}

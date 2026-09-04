import 'package:flutter/material.dart';

import '../features/agent/agent_entry.dart';
import '../features/agent/screens/agent_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/care_gap_screens.dart';
import '../screens/care_plan_detail_screen.dart';
import '../screens/care_plan_review_screen.dart';
import '../screens/care_plan_upload_screen.dart';
import '../screens/care_plans_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/family_screens.dart';
import '../screens/landing_screen.dart';
import '../screens/library_screens.dart';
import '../screens/onboarding_screen.dart';
import '../screens/reality_check_screen.dart';
import '../screens/routine_preferences_screen.dart';
import '../screens/simulation_screen.dart';
import '../screens/support_screens.dart';
import '../screens/task_outcome_screens.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../localization/language_scope.dart';
import 'app_routes.dart';
import 'app_theme.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    var name = settings.name ?? AppRoutes.landing;
    final session = AuthSession.instance;

    // An authenticated user must never fall back into Landing/Auth simply
    // because Android Back or a stale route tries to open a public screen.
    //
    // Explicit logout clears AuthSession before navigating to Landing, so
    // logout behavior remains unchanged.
    if (session.isAuthenticated && AppRoutes.publicRoutes.contains(name)) {
      name = session.needsOnboarding
          ? AppRoutes.onboarding
          : AppRoutes.dashboard;
    } else if (!AppRoutes.publicRoutes.contains(name) &&
        name != AppRoutes.onboarding &&
        !session.canAccessApp) {
      name = AppRoutes.auth;
    } else if (session.needsOnboarding &&
        name != AppRoutes.onboarding &&
        !AppRoutes.publicRoutes.contains(name)) {
      name = AppRoutes.onboarding;
    } else if (name == AppRoutes.onboarding &&
        (!session.isAuthenticated || !session.needsOnboarding)) {
      name = session.canAccessApp ? AppRoutes.dashboard : AppRoutes.auth;
    }

    final Widget page;

    if (name == AppRoutes.landing) {
      page = const LandingScreen();
    } else if (name == AppRoutes.auth) {
      page = const AuthScreen();
    } else if (name == AppRoutes.onboarding) {
      page = const OnboardingScreen();
    } else if (name == AppRoutes.dashboard) {
      page = const DashboardScreen();
    } else if (name == AppRoutes.carePlans) {
      page = const CarePlansScreen();
    } else if (name == AppRoutes.carePlanNew) {
      page = const NewCarePlanScreen();
    } else if (name == AppRoutes.carePlanUpload) {
      final arguments = settings.arguments;

      page = CarePlanUploadScreen(
        draft: arguments is CarePlanUploadArgs ? arguments : null,
      );
    } else if (name == AppRoutes.carePlanReview) {
      final arguments = settings.arguments;

      final args = arguments is CarePlanReviewArgs ? arguments : null;

      page = CarePlanReviewScreen(
        planId: args?.planId,
        guidedSetup: args?.guidedSetup ?? false,
        returnToPrevious: args?.returnToPrevious ?? false,
      );
    } else if (name == AppRoutes.realityCheck) {
      final arguments = settings.arguments;

      final flowArgs = arguments is CareFlowArgs ? arguments : null;

      final focusedArgs = arguments is FocusedRealityCheckArgs
          ? arguments
          : null;

      page = RealityCheckScreen(
        planId: focusedArgs?.planId ?? flowArgs?.planId,
        guidedSetup: flowArgs?.guidedSetup ?? false,
        returnToPrevious: focusedArgs != null
            ? true
            : flowArgs?.returnToPrevious ?? false,
        focusedQuestionKey: focusedArgs?.questionKey,
        reviewContextLabel: focusedArgs?.reviewContextLabel ?? '',
      );
    } else if (name == AppRoutes.simulation) {
      final arguments = settings.arguments;

      final args = arguments is CareFlowArgs ? arguments : null;

      page = SimulationScreen(
        planId: args?.planId,
        guidedSetup: args?.guidedSetup ?? false,
        returnToPrevious: args?.returnToPrevious ?? false,
      );
    } else if (name == AppRoutes.calendar) {
      page = const TaskCalendarScreen();
    } else if (name == AppRoutes.notifications) {
      page = const NotificationsScreen();
    } else if (name == AppRoutes.documents) {
      page = const DocumentsScreen();
    } else if (name == AppRoutes.progress) {
      page = const TaskProgressScreen();
    } else if (name == AppRoutes.family) {
      page = const FamilyScreen();
    } else if (name == AppRoutes.familyNew) {
      page = const AddCaregiverScreen();
    } else if (name == AppRoutes.careGaps) {
      final arguments = settings.arguments;

      final args = arguments is CareFlowArgs ? arguments : null;

      page = CareGapsScreen(
        planId: args?.planId,
        guidedSetup: args?.guidedSetup ?? false,
        returnToPrevious: args?.returnToPrevious ?? false,
      );
    } else if (name == AppRoutes.doctorQuestions) {
      page = const DoctorQuestionsScreen();
    } else if (name == AppRoutes.teachBack) {
      page = const TeachBackScreen();
    } else if (name == AppRoutes.simpleCare) {
      page = const SimpleCareScreen();
    } else if (name == AppRoutes.routinePreferences) {
      page = const RoutinePreferencesScreen();
    } else if (name == AppRoutes.settings) {
      page = const SettingsScreen();
    } else if (name == AppRoutes.patientProfile) {
      page = const PatientProfileScreen();
    } else if (name == AppRoutes.agent) {
      final arguments = settings.arguments;

      page = AgentScreen(args: arguments is AgentScreenArgs ? arguments : null);
    } else if (RegExp(r'^/care-plan/[^/]+$').hasMatch(name)) {
      final arguments = settings.arguments;

      final CarePlanDetailArgs args;

      if (arguments is CarePlanDetailArgs) {
        args = arguments;
      } else if (arguments is int) {
        // Backward compatibility for any older navigation call
        // that still sends only an initial tab index.
        args = CarePlanDetailArgs(initialTab: arguments);
      } else {
        args = const CarePlanDetailArgs();
      }

      page = CarePlanDetailScreen(
        planId: name.split('/').last,
        initialTab: args.initialTab,
        guidedSetup: args.guidedSetup,
        returnToPrevious: args.returnToPrevious,
      );
    } else if (RegExp(r'^/care-gaps/[^/]+$').hasMatch(name)) {
      page = CareGapDetailScreen(gapId: name.split('/').last);
    } else if (RegExp(r'^/family/[^/]+$').hasMatch(name)) {
      page = CaregiverDetailScreen(caregiverId: name.split('/').last);
    } else {
      page = const _NotFoundScreen();
    }

    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name, arguments: settings.arguments),
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);

        return FadeTransition(
          opacity: curve,
          child: AnimatedBuilder(
            animation: curve,
            child: child,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 6 * (1 - curve.value)),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('app_name'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '404',
                style: TextStyle(fontSize: 72, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('page_not_found'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('page_not_found_description'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.landing),
                child: Text(context.tr('go_home')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

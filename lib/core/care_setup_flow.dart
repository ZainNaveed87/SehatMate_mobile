import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/care_plan_service.dart';
import 'app_routes.dart';

class CareSetupFlow {
  const CareSetupFlow._();

  static Future<void> resume(BuildContext context, DemoPlan plan) async {
    final progress = await CarePlanService.instance.resolveSetupProgress(plan);
    if (!context.mounted) return;
    await openStep(context, plan.id, progress.step);
  }

  static Future<void> openStep(
    BuildContext context,
    String planId,
    CareSetupStep step, {
    bool replace = false,
    bool returnToPrevious = false,
  }) async {
    final routeAndArgs = switch (step) {
      CareSetupStep.upload => (
          AppRoutes.carePlanUpload,
          CarePlanUploadArgs(
            planId: planId,
            documentTypes: const [],
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.review => (
          AppRoutes.carePlanReview,
          CarePlanReviewArgs(
            planId: planId,
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.schedule => (
          AppRoutes.carePlan(planId),
          CarePlanDetailArgs(
            initialTab: 1,
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.realityCheck => (
          AppRoutes.realityCheck,
          CareFlowArgs(
            planId: planId,
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.simulation || CareSetupStep.activate => (
          AppRoutes.simulation,
          CareFlowArgs(
            planId: planId,
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.careGaps => (
          AppRoutes.careGaps,
          CareFlowArgs(
            planId: planId,
            guidedSetup: true,
            returnToPrevious: returnToPrevious,
          ),
        ),
      CareSetupStep.complete => (AppRoutes.carePlan(planId), null),
    };

    if (replace) {
      await Navigator.pushReplacementNamed(
        context,
        routeAndArgs.$1,
        arguments: routeAndArgs.$2,
      );
    } else {
      await Navigator.pushNamed(
        context,
        routeAndArgs.$1,
        arguments: routeAndArgs.$2,
      );
    }
  }

  static CareSetupStep? stepForNumber(int number) => switch (number) {
        1 => CareSetupStep.upload,
        2 => CareSetupStep.review,
        3 => CareSetupStep.schedule,
        4 => CareSetupStep.realityCheck,
        5 => CareSetupStep.simulation,
        6 => CareSetupStep.careGaps,
        7 => CareSetupStep.activate,
        _ => null,
      };
}

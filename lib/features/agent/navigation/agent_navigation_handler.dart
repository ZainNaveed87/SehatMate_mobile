import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../services/care_plan_service.dart';
import '../models/agent_navigation.dart';
import '../models/agent_validation.dart';

class AgentNavigationHandler {
  const AgentNavigationHandler();

  bool canNavigate(AgentNavigation navigation) => _routeFor(navigation) != null;

  Future<bool> navigate(
    BuildContext context,
    AgentNavigation navigation,
  ) async {
    final resolved = _routeFor(navigation);
    if (resolved == null) return false;

    await Navigator.pushNamed(
      context,
      resolved.route,
      arguments: resolved.arguments,
    );
    return true;
  }

  _ResolvedRoute? _routeFor(AgentNavigation navigation) {
    final params = navigation.params;
    final carePlanId = _firstParam(params, const [
      'carePlanId',
      'care_plan_id',
      'planId',
      'plan_id',
      'id',
    ]);
    final careGapId = _firstParam(params, const [
      'careGapId',
      'care_gap_id',
      'gapId',
      'gap_id',
      'id',
    ]);

    switch (navigation.target) {
      case 'home':
        return const _ResolvedRoute(AppRoutes.dashboard);
      case 'today':
        return const _ResolvedRoute(AppRoutes.calendar);
      case 'care_plans':
        return const _ResolvedRoute(AppRoutes.carePlans);
      case 'care_plan_detail':
        if (!_validId(carePlanId)) return null;
        return _ResolvedRoute(AppRoutes.carePlan(carePlanId!));
      case 'reality_check':
        return _careFlowRoute(AppRoutes.realityCheck, carePlanId);
      case 'simulation':
        return _careFlowRoute(AppRoutes.simulation, carePlanId);
      case 'care_gaps':
        return _careFlowRoute(AppRoutes.careGaps, carePlanId);
      case 'care_gap_detail':
        if (!_validId(careGapId)) return null;
        return _ResolvedRoute(AppRoutes.careGap(careGapId!));
      case 'routine_settings':
        return const _ResolvedRoute(AppRoutes.routinePreferences);
      case 'profile':
        return const _ResolvedRoute(AppRoutes.patientProfile);
      case 'documents':
        return const _ResolvedRoute(AppRoutes.documents);
      case 'notifications':
        return const _ResolvedRoute(AppRoutes.notifications);
      case 'settings':
        return const _ResolvedRoute(AppRoutes.settings);
    }

    return null;
  }

  _ResolvedRoute _careFlowRoute(String route, String? carePlanId) {
    if (!_validId(carePlanId)) return _ResolvedRoute(route);
    return _ResolvedRoute(route, CareFlowArgs(planId: carePlanId!));
  }

  String? _firstParam(Map<String, String> params, List<String> keys) {
    for (final key in keys) {
      final value = params[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _validId(String? value) {
    if (value == null) return false;
    return isSafeAgentIdentifier(value);
  }
}

class _ResolvedRoute {
  const _ResolvedRoute(this.route, [this.arguments]);

  final String route;
  final Object? arguments;
}

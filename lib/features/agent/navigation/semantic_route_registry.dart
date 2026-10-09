import '../../../services/document_service.dart';
import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../services/care_plan_service.dart';
import '../../../screens/reality_check_screen.dart';
import '../../../screens/task_outcome_screens.dart';
import '../models/agent_navigation.dart';
import '../models/agent_validation.dart';

class SemanticDestination {
  const SemanticDestination(this.id,this.routeName,this.screenId,[this.arguments]);
  final String id,routeName,screenId;
  final Object? arguments;
  String get identityKey => identityFor(RouteSettings(name:routeName,arguments:arguments));
  static String identityFor(RouteSettings settings) {
    final a=settings.arguments;
    final suffix = switch(a) {
      CareFlowArgs() => '${a.planId}:${a.guidedSetup}:${a.returnToPrevious}',
      CarePlanUploadArgs() => '${a.planId}:${a.guidedSetup}:${a.returnToPrevious}',
      CarePlanReviewArgs() => '${a.planId}:${a.guidedSetup}:${a.returnToPrevious}',
      CarePlanDetailArgs() => '${a.initialTab}:${a.guidedSetup}:${a.returnToPrevious}',
      DocumentFile() => a.documentId,
      FocusedRealityCheckArgs() => '${a.planId}:${a.questionKey}:${a.reviewContextLabel}',
      CalendarRouteArgs() => '${a.initialDate}',
      _ => a == null ? '' : a.toString(),
    };
    return '${settings.name}|$suffix';
  }
}

class SemanticRouteRegistry {
  const SemanticRouteRegistry();
  static const plain={
    'home':AppRoutes.dashboard,'today':AppRoutes.calendar,'calendar':AppRoutes.calendar,
    'care_plans':AppRoutes.carePlans,'care_plan_new':AppRoutes.carePlanNew,
    'family_care':AppRoutes.family,'family':AppRoutes.family,'family_member_new':AppRoutes.familyNew,
    'progress':AppRoutes.progress,'documents':AppRoutes.documents,'notifications':AppRoutes.notifications,
    'profile':AppRoutes.patientProfile,'settings':AppRoutes.settings,'routine_settings':AppRoutes.routinePreferences,
    'doctor_questions':AppRoutes.doctorQuestions,'simple_care':AppRoutes.simpleCare,'teach_back':AppRoutes.teachBack,
  };
  SemanticDestination? resolve(AgentNavigation navigation) {
    final p=navigation.params,t=navigation.target;
    if (plain.containsKey(t)) {
      if(p.isNotEmpty)return null;
      return SemanticDestination(t,plain[t]!, t=='calendar'?'today':t=='family'?'family_care':t);
    }
    final allowed = switch(t) {
      'care_plan_detail' || 'care_plan_upload' || 'care_plan_review' || 'reality_check' || 'simulation' || 'care_gaps' => {'carePlanId'},
      'care_gap_detail' => {'careGapId'},
      'family_member_detail' => {'relationshipId'},
      'family_member_care_plans' => {'relationshipId','carePlanId'},
      _ => <String>{},
    };
    if(allowed.isEmpty || p.keys.any((k)=>!allowed.contains(k)) || p.values.any((v)=>!isSafeAgentIdentifier(v)))return null;
    final plan=p['carePlanId'],relationship=p['relationshipId'],gap=p['careGapId'];
    return switch(t) {
      'care_plan_detail' when plan!=null => SemanticDestination(t,AppRoutes.carePlan(plan),t),
      'care_plan_upload' when plan!=null => SemanticDestination(t,AppRoutes.carePlanUpload,t,CarePlanUploadArgs(planId:plan,guidedSetup:true)),
      'care_plan_review' when plan!=null => SemanticDestination(t,AppRoutes.carePlanReview,t,CarePlanReviewArgs(planId:plan)),
      'care_gap_detail' when gap!=null => SemanticDestination(t,AppRoutes.careGap(gap),t),
      'family_member_detail' when relationship!=null => SemanticDestination(t,AppRoutes.caregiver(relationship),t),
      'family_member_care_plans' when relationship!=null && plan!=null => SemanticDestination(t,AppRoutes.familyPlan(relationship,plan),t),
      'reality_check' || 'simulation' || 'care_gaps' => SemanticDestination(t, t=='reality_check'?AppRoutes.realityCheck:t=='simulation'?AppRoutes.simulation:AppRoutes.careGaps,t,plan==null?null:CareFlowArgs(planId:plan)),
      _ => null,
    };
  }
  String? screenForRoute(String? route) {
    for(final e in plain.entries) {if(e.value==route)return e.key;}
    if(route==AppRoutes.carePlanUpload)return 'care_plan_upload';
    if(route==AppRoutes.carePlanReview)return 'care_plan_review';
    if(route==AppRoutes.realityCheck)return 'reality_check';
    if(route==AppRoutes.simulation)return 'simulation';
    if(route==AppRoutes.careGaps)return 'care_gaps';
    if(RegExp(r'^/family/[1-9][0-9]{0,19}/plans/[1-9][0-9]{0,19}$').hasMatch(route??''))return 'family_member_care_plans';
    if(RegExp(r'^/family/[1-9][0-9]{0,19}$').hasMatch(route??''))return 'family_member_detail';
    if(RegExp(r'^/care-plan/[1-9][0-9]{0,19}$').hasMatch(route??''))return 'care_plan_detail';
    if(RegExp(r'^/care-gaps/[1-9][0-9]{0,19}$').hasMatch(route??''))return 'care_gap_detail';
    if(route==AppRoutes.documentViewer)return 'document_viewer';
    return null;
  }
}

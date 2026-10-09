import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agent_navigation.dart';
import '../copilot/copilot.dart';
import '../copilot/copilot_navigation_observer.dart';
import 'semantic_route_registry.dart';
import '../../../services/care_plan_service.dart';
import '../../../screens/reality_check_screen.dart';
import '../copilot/copilot_diagnostics.dart';

enum NavigationOutcome {opened,alreadyActive,reused,rejected,stale,redirected,unavailable,timedOut,unsavedConflict}
class NavigationResult {
  const NavigationResult(this.outcome);
  final NavigationOutcome outcome;
  bool get succeeded => const {NavigationOutcome.opened,NavigationOutcome.alreadyActive,NavigationOutcome.reused}.contains(outcome);
}
class NavigationOrigin {
  const NavigationOrigin({required this.accountGeneration,this.screenVersion});
  final int accountGeneration;
  final String? screenVersion;
}
class AgentNavigationCoordinator {
  AgentNavigationCoordinator({required this.navigatorKey,required this.observer,required this.registry,this.beforeVisualAction,this.requireAdapter=true});
  final GlobalKey<NavigatorState> navigatorKey;
  final CopilotNavigationObserver observer;
  final CopilotRegistry registry;
  final Future<void> Function()? beforeVisualAction;
  final bool requireAdapter;
  final _inFlight=<String,Future<NavigationResult>>{};
  Future<void> _queue=Future.value();
  int _generation=0;
  bool _valid=true;
  bool get busy=>_inFlight.isNotEmpty;
  void invalidate(){_valid=false;_generation++;}
  Future<NavigationResult> navigate(AgentNavigation command,{NavigationOrigin? origin}) {
    final destination=const SemanticRouteRegistry().resolve(command);
    if(destination==null)return Future.value(const NavigationResult(NavigationOutcome.rejected));
    return navigateLocal(destination,origin:origin);
  }
  /// Typed app-owned actions may preserve focused arguments; raw model routes cannot enter here.
  Future<NavigationResult> navigateLocal(SemanticDestination destination,{NavigationOrigin? origin}) {
    if(const SemanticRouteRegistry().screenForRoute(destination.routeName)!=destination.screenId)return Future.value(const NavigationResult(NavigationOutcome.rejected));
    final existing=_inFlight[destination.identityKey];
    if(existing!=null)return existing;
    final generation=_generation;
    final future=_queue.then((_)=>_execute(destination,generation,origin));
    _inFlight[destination.identityKey]=future;
    _queue=future.then<void>((_){}).catchError((Object _){});
    return future.whenComplete(()=>_inFlight.remove(destination.identityKey));
  }
  Future<NavigationResult> _execute(SemanticDestination d,int generation,NavigationOrigin? origin) async {
    bool stale()=>!_valid||!registry.valid||generation!=_generation||
      (origin!=null&&(origin.accountGeneration!=registry.generation || origin.screenVersion!=null&&origin.screenVersion!=registry.snapshot?.version));
    if(stale())return const NavigationResult(NavigationOutcome.stale);
    await beforeVisualAction?.call();
    if(stale())return const NavigationResult(NavigationOutcome.stale);
    final navigator=navigatorKey.currentState;
    if(navigator==null)return const NavigationResult(NavigationOutcome.unavailable);
    final current=observer.currentPage;
    if(current!=null&&SemanticDestination.identityFor(current.settings)==d.identityKey) {
      return NavigationResult(await _ready(d,generation)?NavigationOutcome.alreadyActive:NavigationOutcome.unavailable);
    }
    final existing=observer.pages.where((r)=>SemanticDestination.identityFor(r.settings)==d.identityKey).firstOrNull;
    final forms={'/care-plan/new','/care-plan/upload','/care-plan/review','/patient-profile','/family/new'};
    if(existing!=null&&observer.pages.skipWhile((r)=>r!=existing).skip(1).any((r)=>forms.contains(r.settings.name))) {
      return const NavigationResult(NavigationOutcome.unsavedConflict);
    }
    try {
      if(existing!=null){navigator.popUntil((route)=>identical(route,existing));}
      else {unawaited(navigator.pushNamed(d.routeName,arguments:d.arguments));}
      await WidgetsBinding.instance.endOfFrame;
      if(!_valid||generation!=_generation||!registry.valid)return const NavigationResult(NavigationOutcome.stale);
      if(SemanticDestination.identityFor(observer.currentPage?.settings??const RouteSettings())!=d.identityKey) {
        return const NavigationResult(NavigationOutcome.redirected);
      }
      if(!await _ready(d,generation))return const NavigationResult(NavigationOutcome.timedOut);
      return NavigationResult(existing==null?NavigationOutcome.opened:NavigationOutcome.reused);
    } catch(_){return const NavigationResult(NavigationOutcome.unavailable);}
  }
  Future<bool> _ready(SemanticDestination d,int generation) async {
    if(!requireAdapter)return _valid&&generation==_generation;
    final result=Completer<bool>();
    void check(){
      if(result.isCompleted)return;
      if(!_valid||!registry.valid||generation!=_generation){result.complete(false);return;}
      final arguments=d.arguments;
      final planId=switch(arguments){CareFlowArgs()=>arguments.planId,CarePlanUploadArgs()=>arguments.planId,CarePlanReviewArgs()=>arguments.planId,FocusedRealityCheckArgs()=>arguments.planId,_=>RegExp(r'^/care-plan/([1-9][0-9]{0,19})$').firstMatch(d.routeName)?.group(1)};
      final snapshot=registry.snapshot;
      if(snapshot?.screenId==d.screenId && (arguments is! FocusedRealityCheckArgs||(registry.hasRenderedTarget('reality_check.question.current')&&registry.catalog?.revision.startsWith('${arguments.questionKey}:')==true)) && (planId==null||snapshot?.entity?.type=='care_plan'&&snapshot?.entity?.id==planId)&&snapshot!.targets.any((t)=>registry.hasRenderedTarget(t.id))&&SemanticDestination.identityFor(observer.currentPage?.settings??const RouteSettings())==d.identityKey) {
        CopilotDiagnostics.emit(CopilotDiagnostic.navigationResolved,registeredScreen:d.screenId,outcome:CopilotDiagnosticOutcome.succeeded);
        result.complete(true);
      }
    }
    registry.addListener(check);
    final timer=Timer(const Duration(seconds:4),()=>result.isCompleted?null:result.complete(false));
    check();
    try{return await result.future;}finally{timer.cancel();registry.removeListener(check);}
  }
}
class AgentNavigationScope extends InheritedWidget {
  const AgentNavigationScope({super.key,required this.coordinator,required super.child});
  final AgentNavigationCoordinator coordinator;
  static AgentNavigationCoordinator? maybeOf(BuildContext context)=>context.getInheritedWidgetOfExactType<AgentNavigationScope>()?.coordinator;
  @override bool updateShouldNotify(AgentNavigationScope old)=>old.coordinator!=coordinator;
}

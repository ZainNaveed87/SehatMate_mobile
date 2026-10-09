import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agent_navigation.dart';
import 'semantic_route_registry.dart';
import 'agent_navigation_coordinator.dart';

/// Compatibility facade; authenticated app callers share the root coordinator.
class AgentNavigationHandler {
  const AgentNavigationHandler({this.navigatorKey});
  final GlobalKey<NavigatorState>? navigatorKey;
  bool canNavigate(AgentNavigation navigation)=>const SemanticRouteRegistry().resolve(navigation)!=null;
  bool dispatch(BuildContext context,AgentNavigation navigation) {
    if(!canNavigate(navigation))return false;
    unawaited(navigate(context,navigation));
    return true; // dispatch acknowledgement only, never a resolved UI receipt
  }
  Future<bool> navigate(BuildContext context,AgentNavigation navigation) async {
    final shared=AgentNavigationScope.maybeOf(context);
    if(shared!=null)return (await shared.navigate(navigation)).succeeded;
    final destination=const SemanticRouteRegistry().resolve(navigation);
    if(destination==null)return false;
    final navigator=navigatorKey?.currentState??Navigator.of(context);
    if(ModalRoute.of(context)?.settings.name==destination.routeName)return true;
    unawaited(navigator.pushNamed(destination.routeName,arguments:destination.arguments));
    await WidgetsBinding.instance.endOfFrame;
    return context.mounted;
  }
}

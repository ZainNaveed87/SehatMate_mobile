import 'package:flutter/material.dart';
import 'copilot.dart';

/// Only PageRoute changes invalidate capabilities. Confirmation and memory
/// PopupRoutes keep the underlying generation until explicitly dismissed.
class CopilotNavigationObserver extends NavigatorObserver {
  CopilotNavigationObserver(this.registry);
  final CopilotRegistry registry;
  final List<PageRoute<dynamic>> pages=[];
  PageRoute<dynamic>? get currentPage=>pages.lastOrNull;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {pages.add(route);registry.navigationChanged();}
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {pages.remove(route);registry.navigationChanged();}
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute || oldRoute is PageRoute) {
      final index=oldRoute is PageRoute ? pages.indexOf(oldRoute) : -1;
      if(oldRoute is PageRoute)pages.remove(oldRoute);
      if(newRoute is PageRoute)pages.insert(index<0?pages.length:index,newRoute);
      registry.navigationChanged();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {pages.remove(route);registry.navigationChanged();}
  }
}

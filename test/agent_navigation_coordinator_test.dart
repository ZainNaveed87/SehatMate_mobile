import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_coordinator.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';

void main() {
  testWidgets('account change cancels both active and queued navigation before push', (tester) async {
    final key=GlobalKey<NavigatorState>(), registry=CopilotRegistry(accountId:'a'), barrier=Completer<void>();
    final observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:key,observer:observer,registry:registry,requireAdapter:false,beforeVisualAction:()=>barrier.future);
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[observer],home:const Text('home'),routes:{'/settings':(_)=>const Text('settings'),'/progress':(_)=>const Text('progress')}));
    final first=coordinator.navigate(const AgentNavigation(target:'settings'));
    final second=coordinator.navigate(const AgentNavigation(target:'progress'));
    await tester.pump();coordinator.invalidate();registry.invalidate();barrier.complete();await tester.pumpAndSettle();
    expect((await first).outcome,NavigationOutcome.stale);expect((await second).outcome,NavigationOutcome.stale);expect(observer.pages,hasLength(1));
    await tester.pumpWidget(const SizedBox());registry.dispose();
  });
  testWidgets('a route without its real adapter cannot receive a readiness success', (tester) async {
    final key=GlobalKey<NavigatorState>(), registry=CopilotRegistry(accountId:'a');
    final observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:key,observer:observer,registry:registry);
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[observer],home:const Text('home'),routes:{'/settings':(_)=>const Text('settings')}));
    final pending=coordinator.navigate(const AgentNavigation(target:'settings'));await tester.pumpAndSettle();await tester.pump(const Duration(seconds:5));
    expect((await pending).outcome,NavigationOutcome.timedOut);
    await tester.pumpWidget(const SizedBox());coordinator.invalidate();registry.dispose();
  });
  testWidgets('redirected destination never receives success', (tester) async {
    final key=GlobalKey<NavigatorState>(),registry=CopilotRegistry(accountId:'test');
    final observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:key,observer:observer,registry:registry,requireAdapter:false);
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[observer],home:const Text('home'),onGenerateRoute:(_)=>MaterialPageRoute<void>(settings:const RouteSettings(name:'/auth'),builder:(_)=>const Text('sign in'))));
    final result=coordinator.navigate(const AgentNavigation(target:'settings'));
    await tester.pumpAndSettle();
    expect((await result).outcome,NavigationOutcome.redirected);
    expect(coordinator.busy,isFalse);
    coordinator.invalidate();registry.dispose();
  });
  testWidgets('existing destination reused with correct Back and form guard', (tester) async {
    final key=GlobalKey<NavigatorState>(),registry=CopilotRegistry(accountId:'test');
    final observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:key,observer:observer,registry:registry,requireAdapter:false);
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[observer],home:const Text('home'),routes:{'/settings':(_)=>const Text('settings'),'/care-plans':(_)=>const Text('plans'),'/care-plan/new':(_)=>const Text('form')}));
    final first=coordinator.navigate(const AgentNavigation(target:'settings'));await tester.pumpAndSettle();await first;
    key.currentState!.pushNamed('/care-plan/new');await tester.pumpAndSettle();
    expect((await coordinator.navigate(const AgentNavigation(target:'settings'))).outcome,NavigationOutcome.unsavedConflict);
    key.currentState!.pop();await tester.pumpAndSettle();
    key.currentState!.pushNamed('/care-plans');await tester.pumpAndSettle();
    final reused=coordinator.navigate(const AgentNavigation(target:'settings'));await tester.pumpAndSettle();
    expect((await reused).outcome,NavigationOutcome.reused);
    expect(observer.pages,hasLength(2));
    key.currentState!.pop();await tester.pumpAndSettle();expect(find.text('home'),findsOneWidget);
    coordinator.invalidate();registry.dispose();
  });
  testWidgets('duplicate commands share one push and resolve before page pop', (tester) async {
    final key=GlobalKey<NavigatorState>();
    final registry=CopilotRegistry(accountId:'test');
    final observer=CopilotNavigationObserver(registry);
    final coordinator=AgentNavigationCoordinator(navigatorKey:key,observer:observer,registry:registry,requireAdapter:false);
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[observer],home:const Text('home'),routes:{'/settings':(_)=>const Text('settings')}));
    final first=coordinator.navigate(const AgentNavigation(target:'settings'));
    final second=coordinator.navigate(const AgentNavigation(target:'settings'));
    await tester.pumpAndSettle();
    expect((await first).succeeded,isTrue);
    expect((await second).succeeded,isTrue);
    expect(observer.pages.where((r)=>r.settings.name=='/settings'),hasLength(1));
    expect((await coordinator.navigate(const AgentNavigation(target:'settings'))).outcome,NavigationOutcome.alreadyActive);
    coordinator.invalidate();
    expect((await coordinator.navigate(const AgentNavigation(target:'home'))).succeeded,isFalse);
    registry.dispose();
  });
}

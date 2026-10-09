import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_navigation_observer.dart';

Widget app(
  CopilotRegistry registry,
  CopilotNavigationObserver observer,
  GlobalKey<NavigatorState> key,
) => Stack(
  alignment: Alignment.topLeft,
  children: [
    AnimatedBuilder(
      animation: registry,
      builder: (_, child) => const SizedBox(),
    ),
    MaterialApp(
      restorationScopeId: 'copilot-regression',
      navigatorKey: key,
      navigatorObservers: [observer],
      home: const Scaffold(body: Text('Home')),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('Next')),
      ),
    ),
  ],
);

void main() {
  testWidgets(
    'idle build scope mounting Navigator does not notify a previously built UI listener',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      final observer = CopilotNavigationObserver(registry);
      final key = GlobalKey<NavigatorState>();
      var mountNavigator = false;
      late StateSetter rebuild;
      final listener = AnimatedBuilder(
        animation: registry,
        builder: (_, child) => const SizedBox(),
      );
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Stack(
              alignment: Alignment.topLeft,
              children: [
                listener,
                if (mountNavigator)
                  MaterialApp(
                    navigatorKey: key,
                    navigatorObservers: [observer],
                    home: const Scaffold(body: Text('Home')),
                  ),
              ],
            );
          },
        ),
      );
      rebuild(() {
        mountNavigator = true;
      });
      // Bootstrap/restoration can flush builds while schedulerPhase is idle.
      tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(observer.currentPage?.settings.name, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      registry.dispose();
    },
  );
  testWidgets(
    'initial Navigator mount and restoration never notify an ancestor during build',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      final observer = CopilotNavigationObserver(registry);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(registry, observer, key));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(observer.currentPage?.settings.name, '/');
      key.currentState!.restorablePushNamed('/next');
      await tester.pumpAndSettle();
      final data = await tester.getRestorationData();
      await tester.restartAndRestore();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(observer.currentPage?.settings.name, '/next');
      await tester.restoreFrom(data);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.currentPage?.settings.name, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      registry.dispose();
    },
  );
  testWidgets('rapid route changes notify once with newest state', (
    tester,
  ) async {
    final registry = CopilotRegistry(accountId: 'a');
    var calls = 0;
    String? screen;
    registry.addListener(() {
      calls++;
      screen = registry.snapshot?.screenId;
    });
    await tester.pumpWidget(const SizedBox());
    registry.navigationChanged();
    registry.navigationChanged();
    registry.publish(
      owner: 'newest',
      screenId: 'settings',
      route: 'settings',
      stateKey: '1',
      targets: const [
        CopilotTarget(id: 'section', kind: 'section', label: 'Latest'),
      ],
      actions: const [],
    );
    expect(calls, 0);
    expect(registry.snapshot?.screenId, 'settings');
    await tester.pump();
    expect(calls, 1);
    expect(screen, 'settings');
    await tester.pump();
    expect(calls, 1);
    registry.dispose();
  });
  testWidgets('disposed registry cannot deliver a deferred notification', (
    tester,
  ) async {
    final registry = CopilotRegistry(accountId: 'a');
    var calls = 0;
    registry.addListener(() {
      calls++;
    });
    registry.navigationChanged();
    registry.dispose();
    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'account invalidation fences state immediately and coalesces pending delivery',
    (tester) async {
      final registry = CopilotRegistry(accountId: 'a');
      var calls = 0;
      registry.addListener(() {
        calls++;
        expect(registry.valid, false);
        expect(registry.snapshot, isNull);
      });
      registry.navigationChanged();
      registry.invalidate();
      expect(registry.valid, false);
      expect(calls, 0);
      await tester.pump();
      expect(calls, 1);
      registry.dispose();
    },
  );
}

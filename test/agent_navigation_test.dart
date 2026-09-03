import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/models/agent_navigation.dart';
import 'package:sehatmate_ai/features/agent/navigation/agent_navigation_handler.dart';

class _RecordingObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('valid plain target navigates', (tester) async {
    final observer = _RecordingObserver();
    const handler = AgentNavigationHandler();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        routes: {
          '/': (_) => Builder(
            builder: (context) => TextButton(
              onPressed: () => handler.navigate(
                context,
                const AgentNavigation(target: 'settings'),
              ),
              child: const Text('go'),
            ),
          ),
          '/settings': (_) => const Text('settings'),
        },
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(observer.pushed?.settings.name, '/settings');
  });

  testWidgets('valid care plan target uses existing route', (tester) async {
    final observer = _RecordingObserver();
    const handler = AgentNavigationHandler();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Text('route'),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => handler.navigate(
              context,
              const AgentNavigation(
                target: 'care_plan_detail',
                params: {'carePlanId': 'cp1'},
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(observer.pushed?.settings.name, '/care-plan/cp1');
  });

  testWidgets('valid care gap target uses existing route', (tester) async {
    final observer = _RecordingObserver();
    const handler = AgentNavigationHandler();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Text('route'),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => handler.navigate(
              context,
              const AgentNavigation(
                target: 'care_gap_detail',
                params: {'careGapId': 'gap1'},
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(observer.pushed?.settings.name, '/care-gaps/gap1');
  });

  test('unsupported target and malformed id are rejected safely', () {
    expect(
      () => AgentNavigation.fromJson(const {'target': 'unknown'}),
      throwsFormatException,
    );

    const handler = AgentNavigationHandler();
    expect(
      handler.canNavigate(
        const AgentNavigation(
          target: 'care_plan_detail',
          params: {'carePlanId': '../bad'},
        ),
      ),
      isFalse,
    );
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';

void main() {
  CopilotRegistry registry() => CopilotRegistry(accountId: 'a');
  void register(
    CopilotRegistry r, {
    Future<bool> Function()? execute,
    bool confirm = false,
  }) {
    r.publish(
      owner: 'screen',
      screenId: 'reality_check',
      route: 'reality_check',
      stateKey: 'q1',
      targets: const [
        CopilotTarget(id: 'question', kind: 'section', label: 'Question'),
      ],
      actions: [
        CopilotAction(
          id: 'select',
          kind: 'select_option',
          targetId: 'question',
          requiresConfirmation: confirm,
          execute: execute ?? () async => true,
        ),
      ],
    );
  }

  CopilotPlan plan(
    CopilotRegistry r, {
    String id = 'p',
    String action = 'select',
    String target = 'question',
  }) => CopilotPlan(
    id: id,
    screenId: 'reality_check',
    version: r.snapshot!.version,
    operations: [CopilotOperation(actionId: action, targetId: target)],
  );

  test(
    'unknown and stale operations never invoke a registered callback',
    () async {
      final r = registry();
      var calls = 0;
      register(
        r,
        execute: () async {
          calls++;
          return true;
        },
      );
      final executor = CopilotExecutor(registry: r);
      expect(
        (await executor.run(plan(r, action: 'invented'))).single.code,
        'action_unavailable',
      );
      expect(
        (await executor.run(
          plan(r, target: 'invented', id: 'other'),
        )).single.code,
        'target_not_found',
      );
      final stale = plan(r, id: 'stale');
      r.publish(
        owner: 'screen',
        screenId: 'reality_check',
        route: 'reality_check',
        stateKey: 'q2',
        targets: const [],
        actions: const [],
      );
      expect((await executor.run(stale)).single.code, 'stale_context');
      expect(calls, 0);
    },
  );
  test(
    'consequential callbacks require explicit confirmation and duplicate plans execute once',
    () async {
      final r = registry();
      var calls = 0;
      var confirmations = 0;
      register(
        r,
        confirm: true,
        execute: () async {
          calls++;
          return true;
        },
      );
      final executor = CopilotExecutor(
        registry: r,
        confirm: (_) async {
          confirmations++;
          return true;
        },
      );
      final p = plan(r);
      expect((await executor.run(p)).single.code, 'succeeded');
      expect((await executor.run(p)).single.code, 'duplicate');
      expect(calls, 1);
      expect(confirmations, 1);
    },
  );
  test(
    'screen changed while confirmation is open rejects the callback',
    () async {
      final r = registry();
      var calls = 0;
      register(
        r,
        confirm: true,
        execute: () async {
          calls++;
          return true;
        },
      );
      final ready = Completer<bool>();
      final executor = CopilotExecutor(
        registry: r,
        confirm: (_) => ready.future,
      );
      final running = executor.run(plan(r));
      r.clear(owner: 'screen');
      ready.complete(true);
      expect((await running).single.code, 'stale_context');
      expect(calls, 0);
    },
  );
  test(
    'account clearing cancels in-flight work and clears deduplication',
    () async {
      final r = registry();
      register(r, confirm: true);
      final ready = Completer<bool>();
      final executor = CopilotExecutor(
        registry: r,
        confirm: (_) => ready.future,
      );
      final running = executor.run(plan(r));
      r.invalidate();
      ready.complete(true);
      expect((await running).single.code, 'account_changed');
      expect(r.snapshot, isNull);
    },
  );
  test(
    'destination readiness cancels on account invalidation and cannot republish',
    () async {
      final r = registry();
      final waiting = r.waitForScreenTarget(
        screenId: 'reality_check',
        entityId: '9',
        targetId: 'question',
      );
      r.invalidate();
      expect(await waiting, false);
      register(r);
      expect(r.snapshot, isNull);
      r.dispose();
    },
  );
  test('destination readiness timeout leaves capabilities unchanged', () async {
    final r = registry();
    expect(
      await r.waitForScreenTarget(
        screenId: 'reality_check',
        entityId: '9',
        targetId: 'question',
        timeout: Duration.zero,
      ),
      false,
    );
    expect(r.snapshot, isNull);
    r.dispose();
  });
  testWidgets('destination readiness requires owned mounted target', (
    tester,
  ) async {
    final r = registry();
    await tester.pumpWidget(
      MaterialApp(
        home: CopilotAnchor(
          registry: r,
          targetId: 'question',
          child: const Text('Question'),
        ),
      ),
    );
    final waiting = r.waitForScreenTarget(
      screenId: 'reality_check',
      entityId: '9',
      targetId: 'question',
    );
    var complete = false;
    waiting.then((_) => complete = true);
    r.publish(
      owner: 'new',
      screenId: 'reality_check',
      route: 'reality_check',
      stateKey: 'wrong-plan',
      entity: const AgentEntityContext(type: 'care_plan', id: '99'),
      targets: const [
        CopilotTarget(id: 'question', kind: 'question', label: 'Question'),
      ],
      actions: const [],
    );
    await tester.pump();
    expect(complete, false);
    r.publish(
      owner: 'new',
      screenId: 'reality_check',
      route: 'reality_check',
      stateKey: 'right-plan',
      entity: const AgentEntityContext(type: 'care_plan', id: '9'),
      targets: const [
        CopilotTarget(id: 'question', kind: 'question', label: 'Question'),
      ],
      actions: const [],
    );
    expect(await waiting, true);
    await tester.pumpWidget(const SizedBox());
    r.dispose();
  });
  test('closed argument schema rejects model arguments', () async {
    final r = registry();
    register(r);
    final p = CopilotPlan(
      id: 'bad',
      screenId: 'reality_check',
      version: r.snapshot!.version,
      operations: const [
        CopilotOperation(
          actionId: 'select',
          targetId: 'question',
          args: {'method': 'delete'},
        ),
      ],
    );
    expect(
      (await CopilotExecutor(registry: r).run(p)).single.code,
      'invalid_arguments',
    );
  });
  testWidgets(
    'anchors highlight in RTL with reduced motion and unregister safely',
    (tester) async {
      final r = registry();
      register(r);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(1.7),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: CopilotAnchor(
                registry: r,
                targetId: 'question',
                child: const Text('Question'),
              ),
            ),
          ),
        ),
      );
      expect(await r.reveal('question', 'highlight'), true);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('copilot_highlight_question')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(await r.reveal('question', 'highlight'), false);
      r.dispose();
    },
  );
  testWidgets('highlight scrolls an offscreen semantic anchor into view', (
    tester,
  ) async {
    final r = registry();
    register(r);
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 1200),
                CopilotAnchor(
                  registry: r,
                  targetId: 'question',
                  child: const Text('Question'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final showing = r.reveal('question', 'highlight');
    await tester.pumpAndSettle();
    expect(await showing, true);
    expect(scroll.offset, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    r.dispose();
    scroll.dispose();
  });
}

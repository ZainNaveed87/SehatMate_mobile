import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/services/agent_service.dart';
import 'package:sehatmate_ai/features/agent/services/agent_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAgentClient implements AgentClient {
  final requests = <AgentRequest>[];
  final List<Object> outcomes;

  _FakeAgentClient(this.outcomes);

  @override
  Future<AgentResponse> send(AgentRequest request) async {
    requests.add(request);
    final outcome = outcomes.removeAt(0);
    if (outcome is Completer<AgentResponse>) return outcome.future;
    if (outcome is AgentException) throw outcome;
    return outcome as AgentResponse;
  }
}

class _DelayedSessionStore extends AgentSessionStore {
  _DelayedSessionStore(this.value);

  final String? value;
  final completer = Completer<void>();
  int readCount = 0;
  String? saved;
  bool cleared = false;

  @override
  Future<String?> read() async {
    readCount += 1;
    await completer.future;
    return value;
  }

  @override
  Future<void> save(String sessionId) async {
    saved = sessionId;
  }

  @override
  Future<void> clear() async {
    cleared = true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AgentResponse response(String sessionId, String reply) {
    return AgentResponse.fromJson({
      'success': true,
      'sessionId': sessionId,
      'language': 'en',
      'reply': reply,
      'navigation': null,
      'referencedEntities': [],
    });
  }

  AgentResponse confirmationResponse(
    String sessionId, {
    String actionStatus = 'awaiting_confirmation',
    String? confirmationId = 'confirm-1',
    String kind = 'task_outcome',
    String message = 'Mark "Morning medicine reminder" as completed.',
  }) {
    return AgentResponse.fromJson({
      'success': true,
      'sessionId': sessionId,
      'language': 'en',
      'reply': 'I prepared this change for your review.',
      'navigation': null,
      'confirmation': confirmationId == null
          ? null
          : {
              'confirmationId': confirmationId,
              'kind': kind,
              'message': message,
            },
      'actionStatus': actionStatus,
      'referencedEntities': [],
    });
  }

  test('session id is saved and reused next turn', () async {
    final client = _FakeAgentClient([
      response('session-a', 'Hello'),
      response('session-a', 'Again'),
    ]);
    final store = const AgentSessionStore();
    final controller = AgentController(client: client, sessionStore: store);

    await controller.initialize();
    await controller.sendText('Hi');
    await controller.sendText('Next');

    expect(await store.read(), 'session-a');
    expect(client.requests.first.sessionId, isNull);
    expect(client.requests.last.sessionId, 'session-a');
  });

  test('session-not-found clears and retries once', () async {
    SharedPreferences.setMockInitialValues({
      AgentSessionStore.key: 'stale-session',
    });
    final client = _FakeAgentClient([
      const AgentException(
        'Session not found',
        code: AgentErrorCode.sessionNotFound,
      ),
      response('fresh-session', 'Fresh reply'),
    ]);
    final store = const AgentSessionStore();
    final controller = AgentController(client: client, sessionStore: store);

    await controller.initialize();
    await controller.sendText('Continue');

    expect(client.requests, hasLength(2));
    expect(client.requests.first.sessionId, 'stale-session');
    expect(client.requests.last.sessionId, isNull);
    expect(await store.read(), 'fresh-session');
    expect(controller.messages.last.text, 'Fresh reply');
  });

  test(
    'controller exposes loading, failure, duplicate prevention, and retry',
    () async {
      final client = _FakeAgentClient([
        const AgentException(
          'SehatMate AI is temporarily unavailable. Please try again.',
          code: AgentErrorCode.network,
          retryable: true,
        ),
        response('session-b', 'Recovered'),
      ]);
      final controller = AgentController(client: client);

      await controller.initialize();
      await controller.sendText('Next task?');
      await controller.sendText('   ');

      expect(controller.loading, isFalse);
      expect(controller.error?.code, AgentErrorCode.network);
      expect(controller.messages.last.failed, isTrue);
      expect(client.requests, hasLength(1));

      await controller.retryLast();

      expect(client.requests, hasLength(2));
      expect(controller.messages.last.text, 'Recovered');
      expect(controller.messages.last.failed, isFalse);
    },
  );

  test('send waits for delayed session initialization', () async {
    final client = _FakeAgentClient([response('next-session', 'Reply')]);
    final store = _DelayedSessionStore('persisted-session');
    final controller = AgentController(client: client, sessionStore: store);

    final initializeFuture = controller.initialize();
    final sendFuture = controller.sendText('Hello');

    expect(controller.initializing, isTrue);
    expect(client.requests, isEmpty);

    store.completer.complete();
    await initializeFuture;
    await sendFuture;

    expect(client.requests, hasLength(1));
    expect(client.requests.single.sessionId, 'persisted-session');
    expect(store.saved, 'next-session');
  });

  test('initialize is idempotent and does not duplicate reads', () async {
    final store = _DelayedSessionStore('persisted-session');
    final controller = AgentController(
      client: _FakeAgentClient([]),
      sessionStore: store,
    );

    final first = controller.initialize();
    final second = controller.initialize();

    expect(store.readCount, 1);

    store.completer.complete();
    await Future.wait([first, second]);

    expect(controller.initialized, isTrue);
    expect(controller.initializing, isFalse);
    expect(store.readCount, 1);
    expect(controller.sessionId, 'persisted-session');
  });

  test('duplicate send is still prevented while initializing', () async {
    final client = _FakeAgentClient([response('session-c', 'Only once')]);
    final store = _DelayedSessionStore('persisted-session');
    final controller = AgentController(client: client, sessionStore: store);

    final first = controller.sendText('Hello');
    final second = controller.sendText('Hello again');

    store.completer.complete();
    await Future.wait([first, second]);

    expect(client.requests, hasLength(1));
    expect(client.requests.single.message, 'Hello');
  });

  test(
    'controller tracks pending action state from structured response',
    () async {
      final client = _FakeAgentClient([confirmationResponse('session-d')]);
      final controller = AgentController(client: client);

      await controller.initialize();
      await controller.sendText('Mark next task done');

      expect(controller.pendingConfirmation?.confirmationId, 'confirm-1');
      expect(controller.messages.last.confirmation?.kind, 'task_outcome');
    },
  );

  test(
    'successful confirmation sends only confirmation payload and clears state',
    () async {
      final client = _FakeAgentClient([
        confirmationResponse('session-e'),
        confirmationResponse(
          'session-e',
          actionStatus: 'confirmed',
          confirmationId: null,
        ),
      ]);
      final controller = AgentController(client: client);

      await controller.initialize();
      await controller.sendText('Mark next task done');
      await controller.confirmPendingAction('confirm-1');

      expect(client.requests.last.toJson(), {
        'sessionId': 'session-e',
        'confirmation': {'confirmationId': 'confirm-1', 'decision': 'confirm'},
      });
      expect(controller.pendingConfirmation, isNull);
      expect(controller.messages.last.actionStatus, 'confirmed');
    },
  );

  test('cancellation sends cancel decision and clears state', () async {
    final client = _FakeAgentClient([
      confirmationResponse('session-f'),
      confirmationResponse(
        'session-f',
        actionStatus: 'cancelled',
        confirmationId: null,
      ),
    ]);
    final controller = AgentController(client: client);

    await controller.initialize();
    await controller.sendText('Skip next task');
    await controller.cancelPendingAction('confirm-1');

    expect(client.requests.last.toJson()['confirmation'], {
      'confirmationId': 'confirm-1',
      'decision': 'cancel',
    });
    expect(controller.pendingConfirmation, isNull);
  });

  test('failed confirmation preserves pending state for retry', () async {
    final client = _FakeAgentClient([
      confirmationResponse('session-g'),
      const AgentException('Network failed', code: AgentErrorCode.network),
    ]);
    final controller = AgentController(client: client);

    await controller.initialize();
    await controller.sendText('Mark next task done');
    await controller.confirmPendingAction('confirm-1');

    expect(controller.pendingConfirmation?.confirmationId, 'confirm-1');
    expect(controller.messages.last.failed, isTrue);
  });

  test(
    'stale confirmation id cannot confirm or cancel newer pending action',
    () async {
      final client = _FakeAgentClient([
        confirmationResponse('session-i', confirmationId: 'confirm-a'),
        confirmationResponse(
          'session-i',
          confirmationId: 'confirm-b',
          message: 'Mark "Evening walk" as skipped.',
        ),
        confirmationResponse(
          'session-i',
          actionStatus: 'confirmed',
          confirmationId: null,
        ),
      ]);
      final controller = AgentController(client: client);

      await controller.initialize();
      await controller.sendText('Prepare A');
      await controller.sendText('Prepare B');

      expect(controller.pendingConfirmation?.confirmationId, 'confirm-b');
      await controller.confirmPendingAction('confirm-a');
      await controller.cancelPendingAction('confirm-a');

      expect(client.requests, hasLength(2));
      expect(controller.pendingConfirmation?.confirmationId, 'confirm-b');

      await controller.confirmPendingAction('confirm-b');

      expect(client.requests.last.toJson()['confirmation'], {
        'confirmationId': 'confirm-b',
        'decision': 'confirm',
      });
      expect(controller.pendingConfirmation, isNull);
    },
  );

  test(
    'normal sends and retries are blocked only while confirmation is in flight',
    () async {
      final completer = Completer<AgentResponse>();
      final client = _FakeAgentClient([
        confirmationResponse('session-j', confirmationId: 'confirm-a'),
        const AgentException(
          'Normal request failed',
          code: AgentErrorCode.network,
        ),
        completer,
      ]);
      final controller = AgentController(client: client);

      await controller.initialize();
      await controller.sendText('Prepare A');
      await controller.sendText('Safe normal read while pending');
      expect(controller.lastFailedText, 'Safe normal read while pending');

      final confirm = controller.confirmPendingAction('confirm-a');
      expect(controller.confirmationLoading, isTrue);
      await controller.sendText('Blocked while confirmation in flight');
      await controller.retryLast();

      expect(client.requests, hasLength(3));

      completer.complete(
        confirmationResponse(
          'session-j',
          actionStatus: 'confirmed',
          confirmationId: null,
        ),
      );
      await confirm;

      expect(controller.confirmationLoading, isFalse);
      expect(client.requests, hasLength(3));
    },
  );

  test('confirmation double tap is ignored while loading', () async {
    final completer = Completer<AgentResponse>();
    final client = _FakeAgentClient([
      confirmationResponse('session-h'),
      completer,
    ]);
    final controller = AgentController(client: client);

    await controller.initialize();
    await controller.sendText('Mark next task done');
    final first = controller.confirmPendingAction('confirm-1');
    final second = controller.confirmPendingAction('confirm-1');

    expect(controller.confirmationLoading, isTrue);
    expect(client.requests, hasLength(2));

    completer.complete(
      confirmationResponse(
        'session-h',
        actionStatus: 'confirmed',
        confirmationId: null,
      ),
    );
    await Future.wait([first, second]);

    expect(client.requests, hasLength(2));
  });
}

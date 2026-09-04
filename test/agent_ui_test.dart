import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/localization/app_language.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UiFakeClient implements AgentClient {
  _UiFakeClient(this.outcomes);

  final requests = <AgentRequest>[];
  final List<Object> outcomes;

  @override
  Future<AgentResponse> send(AgentRequest request) async {
    requests.add(request);

    if (outcomes.isEmpty) {
      throw StateError(
        'Unexpected Agent request #${requests.length}: ${request.toJson()}',
      );
    }

    final outcome = outcomes.removeAt(0);
    if (outcome is Completer<AgentResponse>) return outcome.future;
    return outcome as AgentResponse;
  }
}

AgentResponse _response({
  String sessionId = 's-ui',
  String reply = 'Your next task is ready.',
  String language = 'en',
  String? confirmationId,
  String confirmationKind = 'task_outcome',
  String confirmationMessage = 'Mark "Morning medicine reminder" as completed.',
  String? actionStatus,
  Map<String, Object?>? navigation,
}) {
  return AgentResponse.fromJson({
    'success': true,
    'sessionId': sessionId,
    'language': language,
    'reply': reply,
    'navigation': navigation,
    'confirmation': confirmationId == null
        ? null
        : {
            'confirmationId': confirmationId,
            'kind': confirmationKind,
            'message': confirmationMessage,
          },
    'actionStatus': actionStatus,
    'referencedEntities': [],
  });
}

Future<AgentController> _pumpAgent(
  WidgetTester tester, {
  required _UiFakeClient client,
  AppLanguage language = AppLanguage.english,
}) async {
  final languageController = LanguageController.forTesting();
  await languageController.setLanguage(language, syncToServer: false);

  final controller = AgentController(client: client);

  // Make initialization deterministic before the screen starts interacting
  // with the controller.
  await controller.initialize();

  await tester.pumpWidget(
    LanguageScope(
      controller: languageController,
      child: MaterialApp(home: AgentScreen(controller: controller)),
    ),
  );

  await tester.pumpAndSettle();

  expect(controller.initialized, isTrue);

  return controller;
}

Future<void> _sendFromComposer(
  WidgetTester tester,
  AgentController controller,
  _UiFakeClient client,
  String text,
) async {
  final previousRequestCount = client.requests.length;

  expect(controller.initialized, isTrue);
  expect(controller.loading, isFalse);
  expect(controller.confirmationLoading, isFalse);

  final composer = find.byKey(const ValueKey('agent_composer'));
  expect(composer, findsOneWidget);

  await tester.enterText(composer, text);
  await tester.pump();

  final sendButton = find.byIcon(Icons.send_outlined);
  expect(sendButton, findsOneWidget);

  await tester.tap(sendButton);
  await tester.pump();

  // Wait deterministically for this exact normal Agent request to finish.
  for (var i = 0; i < 100; i++) {
    if (client.requests.length == previousRequestCount + 1 &&
        !controller.loading) {
      break;
    }

    await tester.pump(const Duration(milliseconds: 10));
  }

  expect(
    client.requests.length,
    previousRequestCount + 1,
    reason: 'Composer send should produce exactly one Agent request.',
  );

  expect(
    controller.loading,
    isFalse,
    reason: 'Agent response should finish before the test continues.',
  );

  await tester.pumpAndSettle();
}

FilledButton _confirmButton(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key)));

TextButton _cancelButton(WidgetTester tester, String key) =>
    tester.widget<TextButton>(find.byKey(ValueKey(key)));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'test-token',
      'sehatroute_auth_user':
          '{"id":"user-1","name":"Test User","email":"test@example.com"}',
    });
    await AuthSession.instance.initialize();
  });

  testWidgets('current confirmation card binds controls to its id', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-a',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(
        confirmationId: 'confirm-b',
        confirmationMessage: 'Mark "Evening walk" as skipped.',
        actionStatus: 'awaiting_confirmation',
      ),
      _response(actionStatus: 'confirmed'),
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'Prepare A');
    await _sendFromComposer(tester, controller, client, 'Prepare B');

    expect(
      _confirmButton(tester, 'agent_confirm_agent_msg_2_confirm-a').onPressed,
      isNull,
    );
    expect(
      _cancelButton(tester, 'agent_cancel_agent_msg_2_confirm-a').onPressed,
      isNull,
    );
    expect(
      _confirmButton(tester, 'agent_confirm_agent_msg_4_confirm-b').onPressed,
      isNotNull,
    );
    expect(
      _cancelButton(tester, 'agent_cancel_agent_msg_4_confirm-b').onPressed,
      isNotNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('agent_confirm_agent_msg_4_confirm-b')),
    );
    await tester.pumpAndSettle();

    expect(client.requests.last.toJson(), {
      'sessionId': 's-ui',
      'confirmation': {'confirmationId': 'confirm-b', 'decision': 'confirm'},
    });
  });

  testWidgets(
    'duplicate current confirmation cards expose only latest controls',
    (tester) async {
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-same',
          actionStatus: 'awaiting_confirmation',
        ),
        _response(
          confirmationId: 'confirm-same',
          actionStatus: 'awaiting_confirmation',
        ),
      ]);
      final controller = await _pumpAgent(tester, client: client);

      await _sendFromComposer(tester, controller, client, 'Prepare first');

      await _sendFromComposer(tester, controller, client, 'Prepare duplicate');

      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_2_confirm-same',
        ).onPressed,
        isNull,
      );
      expect(
        _cancelButton(
          tester,
          'agent_cancel_agent_msg_2_confirm-same',
        ).onPressed,
        isNull,
      );
      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_4_confirm-same',
        ).onPressed,
        isNotNull,
      );
      expect(
        _cancelButton(
          tester,
          'agent_cancel_agent_msg_4_confirm-same',
        ).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'confirmation loading disables controls and composer only in flight',
    (tester) async {
      final confirmationCompleter = Completer<AgentResponse>();
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-load',
          actionStatus: 'awaiting_confirmation',
        ),
        confirmationCompleter,
        _response(reply: 'Read reply after confirmation.'),
      ]);
      final controller = await _pumpAgent(tester, client: client);

      await _sendFromComposer(tester, controller, client, 'Prepare action');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('agent_confirm_agent_msg_2_confirm-load')),
      );
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isFalse,
      );
      expect(
        _confirmButton(
          tester,
          'agent_confirm_agent_msg_2_confirm-load',
        ).onPressed,
        isNull,
      );
      expect(client.requests, hasLength(2));

      await controller.sendText('Blocked send');
      await tester.pump();

      expect(
        client.requests,
        hasLength(2),
        reason: 'Normal sends must be ignored while confirmation is in flight.',
      );

      confirmationCompleter.complete(_response(actionStatus: 'confirmed'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent_composer')))
            .enabled,
        isTrue,
      );

      await _sendFromComposer(tester, controller, client, 'Normal read');
      expect(client.requests, hasLength(3));
      expect(client.requests.last.message, 'Normal read');
    },
  );

  testWidgets('schedule reminder review shows medical recheck copy in English', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-schedule-en',
        confirmationKind: 'schedule_time',
        confirmationMessage: 'Set reminder to 08:00.',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    final controller = await _pumpAgent(
      tester,
      client: client,
      language: AppLanguage.english,
    );

    await _sendFromComposer(tester, controller, client, 'Move reminder');

    expect(
      find.text(
        'Verified medical timing will be checked again on the server before this reminder is saved.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('schedule reminder review shows medical recheck copy in Urdu', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        confirmationId: 'confirm-schedule-ur',
        confirmationKind: 'schedule_time',
        confirmationMessage: 'Set reminder to 08:00.',
        actionStatus: 'awaiting_confirmation',
      ),
    ]);

    final controller = await _pumpAgent(
      tester,
      client: client,
      language: AppLanguage.urdu,
    );

    await _sendFromComposer(tester, controller, client, 'Move reminder');

    expect(
      find.text(
        'یہ reminder محفوظ ہونے سے پہلے server verified medical timing دوبارہ check کرے گا۔',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'schedule reminder review shows medical recheck copy in Roman Urdu',
    (tester) async {
      final client = _UiFakeClient([
        _response(
          confirmationId: 'confirm-schedule-roman',
          confirmationKind: 'schedule_time',
          confirmationMessage: 'Set reminder to 08:00.',
          actionStatus: 'awaiting_confirmation',
        ),
      ]);

      final controller = await _pumpAgent(
        tester,
        client: client,
        language: AppLanguage.romanUrdu,
      );

      await _sendFromComposer(tester, controller, client, 'Move reminder');

      expect(
        find.text(
          'Yeh reminder save hone se pehle server verified medical timing dobara check karega.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('navigation open action still renders for authorized target', (
    tester,
  ) async {
    final client = _UiFakeClient([
      _response(
        reply: 'I can open care plans.',
        navigation: {'target': 'care_plans', 'params': <String, String>{}},
      ),
    ]);
    final controller = await _pumpAgent(tester, client: client);

    await _sendFromComposer(tester, controller, client, 'Open care plans');

    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('sign-in unavailable state renders safely', (tester) async {
    await AuthSession.instance.logout();
    final client = _UiFakeClient([]);
    await _pumpAgent(tester, client: client);

    expect(find.text('Sign in to use SehatMate AI'), findsOneWidget);
  });
}

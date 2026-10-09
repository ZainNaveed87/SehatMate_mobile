import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';

class Client implements AgentClient {
  AgentRequest? request;
  final AgentResponse response;
  Client(this.response);
  @override
  Future<AgentResponse> send(AgentRequest r) async {
    request = r;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('only executed step and navigation kinds request fresh narration', () {
    for (final kind in [
      'next',
      'previous',
      'open_entity',
      'navigate_to_registered_route',
    ]) {
      expect(copilotShouldContinueAfter(kind), true, reason: kind);
    }
    for (final kind in [
      null,
      'select_option',
      'highlight',
      'focus',
      'scroll_to',
      'read_current_screen',
      'invented',
    ]) {
      expect(copilotShouldContinueAfter(kind), false, reason: '$kind');
    }
  });
  Map<String, dynamic> json() => {
    'success': true,
    'sessionId': 's',
    'language': 'en',
    'reply': 'Let me show you.',
    'uiPlan': {
      'id': 'p',
      'screenId': 'home',
      'version': 'v1',
      'operations': [
        {
          'actionId': 'show',
          'targetId': 'home.main',
          'args': {},
          'riskTier': 0,
        },
      ],
    },
  };
  test('optional UI plan is parsed and malformed directive is discarded', () {
    expect(
      AgentResponse.fromJson(json()).uiPlan?.operations.single.actionId,
      'show',
    );
    expect(
      AgentResponse.fromJson({
        ...json(),
        'uiPlan': {'id': 'bad'},
      }).uiPlan,
      isNull,
    );
  });
  test(
    'typing and voice results dispatch through one shared callback',
    () async {
      final response = AgentResponse.fromJson(json());
      final client = Client(response);
      final received = <String>[];
      final controller = AgentController(
        client: client,
        contextProvider: () => const AgentScreenContext(
          screenId: 'home',
          ui: {'version': 'current'},
        ),
        onCopilotResult: (r, source) async {
          received.add(source);
        },
      );
      await controller.sendText('show me');
      expect(client.request!.toJson()['context']['ui']['version'], 'current');
      await controller.acceptVoiceResult(response, transcript: 'show me');
      expect(received, ['text', 'voice']);
      expect(controller.messages.length, 4);
      controller.dispose();
    },
  );
  test(
    'continuation adds assistant guidance without inventing a user turn',
    () async {
      final response = AgentResponse.fromJson(json());
      final controller = AgentController(client: Client(response));
      await controller.bindSession('s');
      await controller.acceptCopilotContinuation(response, source: 'voice');
      expect(controller.messages.length, 1);
      expect(controller.messages.single.text, 'Let me show you.');
      expect(controller.messages.single.author.name, 'assistant');
      controller.dispose();
    },
  );
}

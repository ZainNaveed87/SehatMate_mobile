import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/screens/agent_screen.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UiFakeClient implements AgentClient {
  @override
  Future<AgentResponse> send(AgentRequest request) async {
    return AgentResponse.fromJson(const {
      'success': true,
      'sessionId': 's-ui',
      'language': 'en',
      'reply': 'Your next task is ready.',
      'navigation': null,
      'referencedEntities': [],
    });
  }
}

void main() {
  testWidgets('sign-in unavailable state renders safely', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.initialize();

    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController.instance,
        child: MaterialApp(
          home: AgentScreen(
            controller: AgentController(client: _UiFakeClient()),
          ),
        ),
      ),
    );

    expect(find.text('Sign in to use SehatMate AI'), findsOneWidget);
  });
}

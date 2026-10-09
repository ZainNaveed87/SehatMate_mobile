import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/reality_check_screen.dart';
import 'package:sehatmate_ai/services/auth_service.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
import 'package:sehatmate_ai/widgets/ui.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'sehatroute_auth_token': 'token',
      'sehatroute_auth_user':
          '{"id":"a","name":"User","email":"user@example.com"}',
    });
    await AuthSession.instance.initialize();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'actual Reality Check choices save, advance, back, correct and resume',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final service = CarePlanService(
        tokenProvider: () => 'token',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            writes.add(jsonDecode(request.body));
            return http.Response('{"success":true,"data":{}}', 200);
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'questions': [
                  {
                    'key': 'availability',
                    'category': 'routine',
                    'question': 'Can you follow your current schedule?',
                    'options': ['Yes reliably', 'Timing difficult'],
                  },
                  {
                    'key': 'support',
                    'category': 'support',
                    'question': 'Is support available?',
                    'options': ['Yes', 'No'],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      final registry = CopilotRegistry(accountId: 'a');
      var confirmations = 0;
      final executor = CopilotExecutor(
        registry: registry,
        confirm: (_) async {
          confirmations++;
          return true;
        },
      );
      final language = LanguageController.forTesting();
      Future<void> pump() => tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: CopilotScope(
              registry: registry,
              executor: executor,
              child: RealityCheckScreen(planId: '9', service: service),
            ),
          ),
        ),
      );
      Future<List<CopilotReceipt>> run(String kind, {String? label}) async {
        final snapshot = registry.snapshot!;
        final action = snapshot.actions.firstWhere(
          (a) =>
              a.kind == kind &&
              (label == null ||
                  snapshot.targets.any(
                    (t) => t.id == a.targetId && t.label == label,
                  )),
        );
        final future = executor.run(
          CopilotPlan(
            id: '${snapshot.version}:$kind:$label',
            screenId: snapshot.screenId,
            version: snapshot.version,
            operations: [
              CopilotOperation(actionId: action.id, targetId: action.targetId),
            ],
          ),
        );
        await tester.pumpAndSettle();
        return future;
      }

      await pump();
      await tester.pumpAndSettle();
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label.contains('Can you follow'),
        ),
        true,
      );
      expect(
        (await run('select_option', label: 'Timing difficult')).single.ok,
        true,
      );
      expect(writes.last['answers'][0]['answer'], 'Timing difficult');
      expect(
        tester
            .widgetList<OptionCard>(find.byType(OptionCard))
            .where((w) => w.selected)
            .single
            .label,
        'Timing difficult',
      );
      await run('next');
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label.contains('Is support available'),
        ),
        true,
      );
      await run('previous');
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label.contains('Can you follow'),
        ),
        true,
      );
      await run('select_option', label: 'Yes reliably');
      expect(writes.last['answers'][0]['answer'], 'Yes reliably');
      await run('next');
      expect(confirmations, 5);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pump();
      await tester.pumpAndSettle();
      expect(
        registry.snapshot!.targets.any(
          (t) => t.label.contains('Is support available'),
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      registry.dispose();
      executor.dispose();
      language.dispose();
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_workflow_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'bookmarks persist only current step and isolate accounts and entities',
    () async {
      final a = CopilotWorkflowStore(accountId: 'a');
      await a.save('reality_check', 'plan1', 'question2');
      expect(
        await CopilotWorkflowStore(
          accountId: 'a',
        ).read('reality_check', 'plan1'),
        'question2',
      );
      expect(
        await CopilotWorkflowStore(
          accountId: 'b',
        ).read('reality_check', 'plan1'),
        isNull,
      );
      expect(await a.read('reality_check', 'plan2'), isNull);
      await a.clear('reality_check', 'plan1');
      expect(await a.read('reality_check', 'plan1'), isNull);
    },
  );
}

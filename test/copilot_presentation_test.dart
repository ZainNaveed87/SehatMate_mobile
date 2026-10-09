import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
void main() {
  test('four presentation modes preserve one state owner and do not reopen guidance',(){
    final p=CopilotPresentation();
    expect(p.mode,CopilotMode.collapsed);
    p.openChat();expect(p.mode,CopilotMode.compact);expect(p.visible,isTrue);
    p.expandChat();expect(p.mode,CopilotMode.expanded);
    p.openChat();expect(p.mode,CopilotMode.compact);
    p.enterGuided(const GuidanceSummary('settings'));expect(p.mode,CopilotMode.guided);expect(p.visible,isFalse);
    p.finishGuidance();expect(p.mode,CopilotMode.collapsed);
    p.openChat();expect(p.visible,isTrue);
    p.minimizeChat();expect(p.mode,CopilotMode.collapsed);
    p.dispose();
  });
}

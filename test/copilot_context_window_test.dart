import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_screen_catalog.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_context_window.dart';

void main() {
  test('focused complete option group fits a deterministic bounded window', () {
    final targets = List.generate(30, (i) => CopilotTarget(id:'control.$i',kind:i<4?'option':'control',label:'اردو '*35,sectionId:i<4?'question':'other.$i'));
    final definition=CopilotScreenDefinition(screenId:'reality_check',routeId:'reality_check',revision:'1',targets:targets,actions:targets.map((t)=>CopilotAction(id:'${t.id}.read',kind:'read_section',targetId:t.id)).toList(),walkthroughOrder:targets.map((t)=>t.id).toList());
    final window=buildContextWindow(definition,focusedTargetId:'control.1');
    expect(window.targets.take(4).map((t)=>t.id),containsAll(['control.0','control.1','control.2','control.3']));
    final snapshot=CopilotSnapshot(screenId:'reality_check',route:'reality_check',version:'ui_${'a'*80}',targets:window.targets,actions:window.actions,focusedSectionId:'control.1');
    expect(utf8.encode(jsonEncode(snapshot.context.toJson())).length,lessThanOrEqualTo(4096));
    expect(window.targets.length,lessThanOrEqualTo(20));
    expect(window.actions.length,lessThanOrEqualTo(20));
    expect(buildContextWindow(definition,focusedTargetId:'control.1').targets.map((t)=>t.id),window.targets.map((t)=>t.id));
  });
  test('an oversized required option group fails rather than publishing partial choices', () {
    final d=CopilotScreenDefinition(screenId:'reality_check',routeId:'reality_check',revision:'1',targets:List.generate(21,(i)=>CopilotTarget(id:'option.$i',kind:'option',label:'Choice',sectionId:'question')),actions:const [],walkthroughOrder:const []);
    expect(()=>buildContextWindow(d,focusedTargetId:'option.0'),throwsFormatException);
  });
}

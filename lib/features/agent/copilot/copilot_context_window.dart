import 'dart:convert';
import 'copilot.dart';
import 'copilot_screen_catalog.dart';

class CopilotContextWindow {
  const CopilotContextWindow(this.targets,this.actions);
  final List<CopilotTarget> targets;
  final List<CopilotAction> actions;
}

CopilotContextWindow buildContextWindow(CopilotScreenDefinition definition,{String? focusedTargetId}) {
  final visible=definition.targets.where((t)=>t.visible!=false).toList();
  final focus=visible.where((t)=>t.id==focusedTargetId).firstOrNull;
  final targets=<CopilotTarget>[]; final actions=<CopilotAction>[];
  bool add(List<CopilotTarget> group,{bool required=false}) {
    final fresh=group.where((t)=>!targets.any((x)=>x.id==t.id)).toList();
    final next=[...targets,...fresh];
    final nextActions=[...actions,...definition.actions.where((a)=>fresh.any((t)=>t.id==a.targetId&&t.enabled!=false))];
    final bytes=utf8.encode(jsonEncode({'targets':next.map((t)=>t.toJson()).toList(),'actions':nextActions.map((a)=>a.toJson()).toList()})).length;
    if(next.length>20||nextActions.length>20||bytes>3350) {
      if(required) throw const FormatException('Required capability group exceeds context budget');
      return false;
    }
    targets.addAll(fresh); actions..clear()..addAll(nextActions);return true;
  }
  if(focus!=null) {
    final group=focus.sectionId==null?[focus]:visible.where((t)=>t.sectionId==focus.sectionId).toList();
    add(group,required:true);
  }
  // A question's choices are atomic even when focus is its question heading.
  final options=visible.where((t)=>t.kind=='option').toList();
  if(options.isNotEmpty)add(options,required:true);
  for(final id in definition.keyActions) {
    final action=definition.actions.where((a)=>a.id==id).firstOrNull;
    if(action!=null)add(visible.where((t)=>t.id==action.targetId).toList());
  }
  for(final t in visible){add([t]);}
  return CopilotContextWindow(List.unmodifiable(targets),List.unmodifiable(actions));
}

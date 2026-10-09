import '../copilot.dart';
import '../copilot_screen_adapter.dart';

CopilotScreenData carePlansCopilotData({required String stateKey,required Map<String,String> controls,required Future<bool> Function(int) selectTab,required bool loading}) => CopilotScreenData(stateKey:stateKey,targets:[
  for(final entry in controls.entries)CopilotTarget(id:'care_plans.${entry.key}',kind:'control',label:entry.value,help:entry.value,enabled:!loading),
],actions:[
  for(final entry in controls.entries)CopilotAction(id:'care_plans.${entry.key}.read',kind:'read_section',targetId:'care_plans.${entry.key}'),
  for(final tab in const ['active','draft','completed'].indexed)CopilotAction(id:'care_plans.tab.${tab.$2}.open',kind:'open_section',targetId:'care_plans.tab.${tab.$2}',execute:()=>selectTab(tab.$1)),
]);

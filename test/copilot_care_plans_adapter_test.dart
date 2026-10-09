import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/adapters/care_plans_copilot_adapter.dart';
void main(){test('actual care plan tabs delegate to the registered callback',()async{
  int selected=-1;final d=carePlansCopilotData(stateKey:'1',loading:false,controls:const {'tab.active':'Active','tab.draft':'Draft','tab.completed':'Completed','create':'Create'},selectTab:(i)async{selected=i;return true;});
  expect(await d.actions.firstWhere((a)=>a.id=='care_plans.tab.draft.open').execute!(),true);expect(selected,1);expect(d.targets.length,4);
});}

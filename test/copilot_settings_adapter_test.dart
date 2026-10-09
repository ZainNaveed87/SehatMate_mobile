import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/adapters/settings_copilot_adapter.dart';
void main(){test('real settings explicit mutations require confirmation and return failure honestly',()async{
  final d=settingsCopilotData(language:'roman_ur',simpleCare:false,busy:false,labels:const {'language':'Language','simple_care':'Simple Care','sign_out':'Sign out','open_simple_care':'Open Simple Care'},setLanguage:(_)async=>false,setSimpleCare:(_)async=>false,signOut:()async=>false);
  expect(d.targets.any((t)=>t.id=='settings.open_simple_care'),false);
  final writes=d.actions.where((a)=>a.execute!=null).toList();expect(writes.length,6);expect(writes.every((a)=>a.requiresConfirmation),true);
  for(final a in writes){expect(await a.execute!(),false);}
  expect(d.targets.any((t)=>t.id.contains('theme')),false);
});}

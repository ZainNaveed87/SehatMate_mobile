import '../copilot.dart';
import '../copilot_screen_adapter.dart';

CopilotScreenData settingsCopilotData({required String language,required bool simpleCare,required bool busy,required Map<String,String> labels,required Future<bool> Function(String) setLanguage,required Future<bool> Function(bool) setSimpleCare,required Future<bool> Function() signOut}) {
  final targets=<CopilotTarget>[
    for(final entry in labels.entries)
      if(entry.key!='open_simple_care'||simpleCare)
        CopilotTarget(id:'settings.${entry.key}',kind:'control',label:entry.value,help:entry.value,value:entry.key=='language'?language:entry.key=='simple_care'?simpleCare:null,enabled:!busy),
  ];
  return CopilotScreenData(stateKey:'$language:$simpleCare:$busy',targets:targets,actions:[
    for(final t in targets)CopilotAction(id:'${t.id}.read',kind:'read_section',targetId:t.id),
    if(!busy)...[
      for(final code in const ['en','ur','roman_ur'])CopilotAction(id:'settings.language.$code',kind:'set_language',targetId:'settings.language',requiresConfirmation:true,execute:()=>setLanguage(code)),
      for(final enabled in const [false,true])CopilotAction(id:'settings.simple_care.${enabled?'on':'off'}',kind:'set_simple_care',targetId:'settings.simple_care',requiresConfirmation:true,execute:()=>setSimpleCare(enabled)),
      CopilotAction(id:'settings.sign_out.execute',kind:'sign_out',targetId:'settings.sign_out',requiresConfirmation:true,execute:signOut),
    ],
  ]);
}

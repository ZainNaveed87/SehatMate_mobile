import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_screen_catalog.dart';
import 'package:sehatmate_ai/features/agent/copilot/copilot_walkthrough_controller.dart';
void main(){TestWidgetsFlutterBinding.ensureInitialized();
 test('account invalidation rejects a delayed walkthrough reveal without reopening guidance',() async {
  final r=CopilotRegistry(accountId:'old');final p=CopilotPresentation();final reveal=Completer<bool>();
  r.catalog=const CopilotScreenDefinition(screenId:'settings',routeId:'settings',revision:'one',targets:[CopilotTarget(id:'settings.language',kind:'control',label:'Language')],actions:[],walkthroughOrder:['settings.language']);
  final w=CopilotWalkthroughController(registry:r,presentation:p,reveal:(_)=>reveal.future);
  final running=w.start();r.invalidate();p.minimizeChat();reveal.complete(true);
  expect(await running,false);expect(w.state,null);expect(r.snapshot,null);expect(p.mode,CopilotMode.collapsed);
  w.dispose();r.dispose();p.dispose();
 });
 test('walkthrough advances only after reveal, repeats and never saves a questionnaire',()async{
  final r=CopilotRegistry(accountId:'test');final p=CopilotPresentation();bool succeeds=true;final seen=<String>[];
  r.catalog=const CopilotScreenDefinition(screenId:'settings',routeId:'settings',revision:'one',targets:[CopilotTarget(id:'settings.language',kind:'control',label:'Language'),CopilotTarget(id:'settings.simple_care',kind:'control',label:'Simple Care')],actions:[],walkthroughOrder:['settings.language','settings.simple_care']);
  final w=CopilotWalkthroughController(registry:r,presentation:p,reveal:(id)async{seen.add(id);return succeeds;});
  expect(await w.start(),true);expect(w.state!.currentIndex,0);expect(p.mode,CopilotMode.guided);
  succeeds=false;expect(await w.next(),false);expect(w.state!.currentIndex,0);
  succeeds=true;expect(await w.next(),true);expect(w.state!.currentIndex,1);expect(await w.repeat(),true);
  expect(await w.previous(),true);expect(w.state!.currentIndex,0);
  w.openChat();expect(p.mode,CopilotMode.compact);expect(await w.continueGuidance(),true);
  w.stop();expect(w.state,null);expect(p.mode,CopilotMode.collapsed);w.dispose();r.dispose();p.dispose();
});}

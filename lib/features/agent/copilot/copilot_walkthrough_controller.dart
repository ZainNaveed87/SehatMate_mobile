import 'package:flutter/foundation.dart';
import 'copilot.dart';
import 'copilot_context_window.dart';

class WalkthroughState {
  const WalkthroughState({required this.workflowId,required this.screenId,required this.catalogRevision,required this.orderedTargetIds,required this.currentIndex,required this.status,required this.startedAt});
  final String workflowId,screenId,catalogRevision,status;
  final List<String> orderedTargetIds;
  final int currentIndex;
  final DateTime startedAt;
  WalkthroughState at(int index,String status)=>WalkthroughState(workflowId:workflowId,screenId:screenId,catalogRevision:catalogRevision,orderedTargetIds:orderedTargetIds,currentIndex:index,status:status,startedAt:startedAt);
}

/// App-owned read-only progression. Never calls questionnaire Next/Previous.
class CopilotWalkthroughController extends ChangeNotifier {
  CopilotWalkthroughController({required this.registry,required this.presentation,this.reveal}){registry.addListener(_changed);}
  final CopilotRegistry registry;
  final CopilotPresentation presentation;
  final Future<bool> Function(String)? reveal;
  WalkthroughState? state;
  bool _busy=false,_disposed=false;
  int _generation=0;
  void _changed(){
    final s=state;
    if(!registry.valid){stop();return;}
    if(s!=null&&(registry.catalog?.screenId!=s.screenId||registry.catalog?.revision!=s.catalogRevision)) {
      _generation++;state=s.at(s.currentIndex,'paused');registry.clearHighlight();
    }
  }
  Future<bool> start()async{
    final d=registry.catalog;if(!registry.valid||d==null||d.walkthroughOrder.isEmpty||_busy)return false;
    state=WalkthroughState(workflowId:'walk_${DateTime.now().microsecondsSinceEpoch}',screenId:d.screenId,catalogRevision:d.revision,orderedTargetIds:List.unmodifiable(d.walkthroughOrder),currentIndex:0,status:'active',startedAt:DateTime.now());
    return _show(0);
  }
  Future<bool> _show(int index)async{
    final s=state, d=registry.catalog;
    if(_disposed||_busy||s==null||d==null||!registry.valid||s.screenId!=d.screenId||s.catalogRevision!=d.revision||index<0||index>=s.orderedTargetIds.length)return false;
    final id=s.orderedTargetIds[index];
    if(!d.targets.any((t)=>t.id==id&&t.visible!=false))return false;
    _busy=true;final generation=_generation;
    presentation.enterGuided(GuidanceSummary(s.screenId,targetId:id));
    try{
      final window=buildContextWindow(d,focusedTargetId:id);
      registry.publishCatalogWindow(window,focusedTargetId:id);
      final ok=await(reveal?.call(id)??registry.reveal(id,'highlight',sticky:true));
      if(!ok||_disposed||!registry.valid||generation!=_generation)return false;
      state=s.at(index,'active');notifyListeners();return true;
    }on FormatException{return false;}finally{_busy=false;}
  }
  Future<bool> next()async{
    final s=state;if(s==null||s.status!='active')return false;
    if(s.currentIndex+1==s.orderedTargetIds.length){state=s.at(s.currentIndex,'completed');registry.clearHighlight();presentation.finishGuidance();notifyListeners();return true;}
    return _show(s.currentIndex+1);
  }
  Future<bool> previous()=>state==null?Future.value(false):_show(state!.currentIndex-1);
  Future<bool> repeat()=>state==null?Future.value(false):_show(state!.currentIndex);
  void openChat(){if(state!=null)state=state!.at(state!.currentIndex,'paused');presentation.openChat();}
  Future<bool> continueGuidance()=>repeat();
  void stop(){_generation++;state=null;registry.clearHighlight();if(registry.valid)presentation.finishGuidance();if(!_disposed)notifyListeners();}
  Future<bool> command(String kind)async{switch(kind){case 'walkthrough_start':return start();case 'walkthrough_next':return next();case 'walkthrough_previous':return previous();case 'walkthrough_repeat':return repeat();case 'walkthrough_continue':return continueGuidance();case 'walkthrough_stop':stop();return true;case 'walkthrough_open_chat':openChat();return true;default:return false;}}
  @override void dispose(){_disposed=true;_generation++;registry.removeListener(_changed);registry.clearHighlight();super.dispose();}
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../localization/language_scope.dart';
import '../../../services/auth_service.dart';
import '../navigation/agent_navigation_handler.dart';
import '../screens/agent_screen.dart';
import '../widgets/agent_language_selector.dart';
import '../voice/voice_companion_controller.dart';
import 'copilot.dart';
import 'copilot_strings.dart';

class CopilotHost extends StatefulWidget {
  const CopilotHost({super.key,required this.voice,required this.registry,required this.executor,
    required this.presentation,required this.child,this.enabled=true,this.onMemory,
    this.navigationHandler=const AgentNavigationHandler()});
  final VoiceCompanionController voice;
  final CopilotRegistry registry;
  final CopilotExecutor executor;
  final CopilotPresentation presentation;
  final Widget child;
  final bool enabled;
  final VoidCallback? onMemory;
  final AgentNavigationHandler navigationHandler;
  @override State<CopilotHost> createState()=>_CopilotHostState();
}
class _CopilotHostState extends State<CopilotHost> {
  final _sheet=DraggableScrollableController();
  double _minimumExtent=.35;
  @override void initState(){super.initState();widget.presentation.addListener(_extentChanged);}
  @override void didUpdateWidget(CopilotHost old){super.didUpdateWidget(old);if(old.presentation!=widget.presentation){old.presentation.removeListener(_extentChanged);widget.presentation.addListener(_extentChanged);}}
  void _extentChanged(){if(_sheet.isAttached && widget.presentation.visible){_sheet.jumpTo(widget.presentation.sheetExtent.clamp(_minimumExtent,.96));}}
  @override void dispose(){widget.presentation.removeListener(_extentChanged);_sheet.dispose();super.dispose();}
  Future<void> _voice() async {
    FocusScope.of(context).unfocus();
    widget.voice.expandPresentation();
    if(widget.voice.voiceSessionId==null)await widget.voice.start(context.appLanguage);
  }
  @override Widget build(BuildContext context)=>CopilotScope(
    registry:widget.registry,executor:widget.executor,presentation:widget.presentation,
    child:AnimatedBuilder(animation:Listenable.merge([widget.presentation,widget.executor,widget.voice,widget.registry]),builder:(context,_){
      final p=widget.presentation,v=widget.voice;
      final enabled=widget.enabled&&widget.registry.valid&&AuthSession.instance.isAuthenticated;
      final padding=MediaQuery.paddingOf(context),keyboard=MediaQuery.viewInsetsOf(context).bottom;
      final availableHeight=MediaQuery.sizeOf(context).height-keyboard-padding.vertical-16;
      _minimumExtent=(150*MediaQuery.textScalerOf(context).scale(1)/availableHeight.clamp(1,double.infinity)).clamp(.35,.96);
      final bottomBar=widget.registry.snapshot?.screenId=='document_viewer'?0.0:72.0;
      return Stack(fit:StackFit.expand,children:[
        widget.child,
        if(enabled) Positioned.fill(top:padding.top+8,bottom:keyboard+padding.bottom+8,
          child:Offstage(offstage:!p.visible,child:ExcludeFocus(excluding:!p.visible,
            child:IgnorePointer(ignoring:!p.visible,child:DraggableScrollableSheet(
              controller:_sheet,initialChildSize:.45.clamp(_minimumExtent,.96),minChildSize:_minimumExtent,maxChildSize:.96,
              builder:(context,scroll)=>Align(alignment:Alignment.bottomCenter,child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:600),child:Material(elevation:12,
                borderRadius:BorderRadius.circular(22),clipBehavior:Clip.antiAlias,
                child:Column(children:[
                  Semantics(label:copilotText(context,'expand'),child:Container(margin:const EdgeInsets.only(top:8),width:36,height:4,decoration:BoxDecoration(color:Colors.black26,borderRadius:BorderRadius.circular(4)))),
                  Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[
                    const Icon(Icons.auto_awesome,size:18,color:Color(0xFF0F766E)),const SizedBox(width:6),
                    Expanded(child:Text(context.tr('agent_title'),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700))),
                    Flexible(flex:2,child:AgentLanguageSelector(compact:true,waitForLanguageChange:()=>v.languageChangeComplete)),
                    if(widget.onMemory!=null)IconButton(tooltip:copilotText(context,'memory_review'),onPressed:p.memoryReviewBusy?null:widget.onMemory,icon:const Icon(Icons.memory_outlined,size:20)),
                    IconButton(tooltip:copilotText(context,'expand'),onPressed:p.expandChat,icon:const Icon(Icons.open_in_full,size:18)),
                    IconButton(tooltip:copilotText(context,'minimize'),onPressed:(){FocusScope.of(context).unfocus();p.minimizeChat();},icon:const Icon(Icons.keyboard_arrow_down)),
                  ])),
                  Expanded(child:AgentScreen(key:const ValueKey('persistent_agent_chat'),embedded:true,controller:v.agent,scrollController:scroll,onRealtimeVoice:()=>unawaited(_voice()),navigationHandler:widget.navigationHandler)),
                ])),
              )),
            )))),
        ),
        if(enabled&&!p.visible&&!p.memoryReviewBusy)PositionedDirectional(end:12,bottom:padding.bottom+bottomBar+12,
          child:Material(elevation:5,color:const Color(0xFFEFFAF7),borderRadius:BorderRadius.circular(30),
            child:ConstrainedBox(constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width-24),child:Row(mainAxisSize:MainAxisSize.min,children:[
              Flexible(child:TextButton.icon(key:const ValueKey('assistant_launcher'),onPressed:p.openChat,
                icon:const Icon(Icons.auto_awesome,size:18),label:Text(p.mode==CopilotMode.guided?copilotText(context,'guided'):context.tr('agent_title'),maxLines:1,overflow:TextOverflow.ellipsis))),
              if(p.mode==CopilotMode.guided&&widget.registry.walkthroughCommand!=null)...[
                IconButton(tooltip:copilotText(context,'walkthrough_previous'),onPressed:()=>widget.registry.walkthroughCommand!('walkthrough_previous'),icon:const Icon(Icons.chevron_left)),
                IconButton(tooltip:copilotText(context,'walkthrough_next'),onPressed:()=>widget.registry.walkthroughCommand!('walkthrough_next'),icon:const Icon(Icons.chevron_right)),
                IconButton(tooltip:copilotText(context,'stop'),onPressed:()=>widget.registry.walkthroughCommand!('walkthrough_stop'),icon:const Icon(Icons.close)),
              ],
              IconButton(tooltip:copilotText(context,'return_voice'),onPressed:()=>unawaited(_voice()),icon:const Icon(Icons.mic_outlined)),
              if(v.voiceSessionId!=null)IconButton(tooltip:copilotText(context,v.muted?'unmute':'mute'),onPressed:v.muted?v.resume:v.mute,icon:Icon(v.muted?Icons.mic_off_outlined:Icons.pause)),
              if(v.voiceSessionId!=null)IconButton(tooltip:context.tr('agent_voice_end'),onPressed:v.end,icon:const Icon(Icons.stop_circle_outlined)),
            ]))),
        ),
      ]);
    }),
  );
}

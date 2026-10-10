import 'package:flutter/material.dart';
import '../models/agent_context.dart';
import '../models/agent_navigation.dart';
import '../navigation/agent_navigation_handler.dart';
import '../voice/voice_companion_scope.dart';
import 'copilot.dart';
import 'copilot_screen_catalog.dart';
import 'copilot_context_window.dart';

class CopilotScreenData {
  const CopilotScreenData({
    required this.stateKey,
    this.entity,
    this.focusedSectionId,
    this.targets = const [],
    this.actions = const [],
  });
  final String stateKey;
  final AgentEntityContext? entity;
  final String? focusedSectionId;
  final List<CopilotTarget> targets;
  final List<CopilotAction> actions;
}

/// Shared adapter for authenticated shell surfaces. Screen-specific adapters
/// supply only semantic state and callbacks, keeping the planner/executor generic.
class CopilotScreenAdapter extends StatefulWidget {
  const CopilotScreenAdapter({
    super.key,
    required this.contextData,
    required this.title,
    required this.child,
    this.data,
  });
  final AgentScreenContext? contextData;
  final String title;
  final CopilotScreenData? data;
  final Widget child;
  @override
  State<CopilotScreenAdapter> createState() => _CopilotScreenAdapterState();
}

class _CopilotScreenAdapterState extends State<CopilotScreenAdapter> {
  CopilotRegistry? _registry;
  int _revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(CopilotScreenAdapter old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  void _registryCleared() {
    if (mounted && _registry?.valid == true && _registry?.snapshot == null) {
      _schedule();
    }
  }

  void _schedule() {
    final r = CopilotScope.maybeOf(context)?.registry;
    if (_registry != r) {
      _registry?.removeListener(_registryCleared);
      _registry?.clear(owner: this);
      _registry = r;
      r?.addListener(_registryCleared);
    }
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _revision ||
          (ModalRoute.of(context)?.isCurrent == false && r?.owns(this) != true)) {
        return;
      }
      final c = widget.contextData;
      if (r == null || c == null) return;
      final data = widget.data;
      final mainId = '${c.screenId}.main';
      final targets = <CopilotTarget>[
        CopilotTarget(id: mainId, kind: 'section', label: widget.title),
        if (r.setAppLanguage != null && c.screenId != 'settings')
          CopilotTarget(id:'app.language',kind:'control',label:'App language',value:r.appLanguageCode?.call()),
        ...?data?.targets,
        ...r.renderedDescriptions.where((t)=>!t.id.startsWith('navigation.')&&data?.targets.any((x)=>x.id==t.id)!=true),
      ];
      final actions = <CopilotAction>[
        CopilotAction(
          id: '$mainId.read',
          kind: 'read_current_screen',
          targetId: mainId,
        ),
        CopilotAction(
          id: '$mainId.highlight',
          kind: 'highlight',
          targetId: mainId,
        ),
        CopilotAction(id: '$mainId.focus', kind: 'focus', targetId: mainId),
        CopilotAction(
          id: '$mainId.scroll',
          kind: 'scroll_to',
          targetId: mainId,
        ),
        if (r.setAppLanguage != null && c.screenId != 'settings')
          for (final code in const ['en','ur','roman_ur'])
            CopilotAction(id:'app.language.$code',kind:'set_language',targetId:'app.language',requiresConfirmation:true,execute:()=>r.setAppLanguage!(code)),
        ...?data?.actions,
        for(final t in r.renderedDescriptions.where((t)=>data?.targets.any((x)=>x.id==t.id)!=true))CopilotAction(id:'${t.id}.read',kind:'read_section',targetId:t.id),
        ...r.renderedActions,
      ];
      if(r.walkthroughCommand!=null) {
        for(final kind in const ['walkthrough_start','walkthrough_next','walkthrough_previous','walkthrough_repeat','walkthrough_stop','walkthrough_open_chat','walkthrough_continue']) {
          actions.add(CopilotAction(id:'$mainId.$kind',kind:kind,targetId:mainId,execute:()=>r.walkthroughCommand!(kind)));
        }
      }
      // Each navigation operation closes over this registered semantic route.
      for (final route in targets.length>1 ? <String>[] : const [
        'home',
        'today',
        'care_plans',
        'care_gaps',
        'progress',
        'profile',
        'settings',
      ]) {
        if (route == c.screenId || actions.length >= 20 || targets.length >= 20) {
          continue;
        }
        final target = 'navigation.$route';
        targets.add(
          CopilotTarget(
            id: target,
            kind: 'navigation',
            label: 'Open ${route.replaceAll('_', ' ')}',
          ),
        );
        final params = route == 'care_gaps' && data?.entity?.type == 'care_plan'
            ? {'carePlanId': data!.entity!.id}
            : <String, String>{};
        actions.add(
          CopilotAction(
            id: '$target.open',
            kind: 'navigate_to_registered_route',
            targetId: target,
            execute: () async {
              if (!mounted || ModalRoute.of(context)?.isCurrent == false) {
                return false;
              }
              VoiceCompanionScope.read(context)?.minimizePresentation();
              CopilotScope.maybeOf(context)?.presentation?.enterGuided(GuidanceSummary(c.screenId));
              final dispatched = await const AgentNavigationHandler().navigate(
                context,
                AgentNavigation(target: route, params: params),
              );
              await WidgetsBinding.instance.endOfFrame;
              return dispatched;
            },
          ),
        );
      }
      final definition=CopilotScreenDefinition(screenId:c.screenId,routeId:c.screenId,revision:data?.stateKey??widget.title,targets:targets,actions:actions,walkthroughOrder:targets.where((t)=>t.kind!='option'&&t.kind!='navigation'&&t.id!='app.language'&&(targets.length==1||t.id!=mainId)).map((t)=>t.id).toList(),keyActions:const ['app.language.en']);
      try {
        final focused=r.owns(this)&&definition.targets.any((t)=>t.id==r.highlightedTarget)?r.highlightedTarget:data?.focusedSectionId;
        final window=buildContextWindow(definition,focusedTargetId:focused);
        r.catalog=definition;
        r.publish(owner:this,screenId:c.screenId,route:c.screenId,stateKey:'${definition.revision}:${data?.entity?.id??c.entity?.id??''}:${r.appLanguageCode?.call()??''}',entity:data?.entity??c.entity,focusedSectionId:window.targets.any((t)=>t.id==focused)?focused:window.targets.any((t)=>t.id==mainId)?mainId:null,targets:window.targets,actions:window.actions);
      } on FormatException {
        r.catalog=null;
        r.clear(owner:this);
        // No partial choices or successful capabilities when the atomic group cannot fit.
      }

    });
  }

  @override
  void dispose() {
    _revision++;
    _registry?.removeListener(_registryCleared);
    _registry?.clear(owner: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contextData, r = _registry;
    return r == null || c == null
        ? widget.child
        : CopilotAnchor(
            registry: r,
            targetId: '${c.screenId}.main',
            child: widget.child,
          );
  }
}

Widget copilotAnchor(BuildContext context, String targetId, Widget child) {
  final registry = CopilotScope.maybeOf(context)?.registry;
  return registry == null
      ? child
      : CopilotAnchor(registry: registry, targetId: targetId, child: child);
}

/// Metadata belongs to the actual mounted control/section, never a model callback.
Widget copilotSection(BuildContext context,String id,String label,Widget child,{Future<bool> Function()? execute,String kind='open_section',bool requiresConfirmation=false}) {
 final registry=CopilotScope.maybeOf(context)?.registry;
 if(registry==null)return child;
 return CopilotAnchor(registry:registry,targetId:id,descriptor:CopilotTarget(id:id,kind:execute==null?'section':'control',label:label,help:label),action:execute==null?null:CopilotAction(id:'$id.execute',kind:kind,targetId:id,execute:execute,requiresConfirmation:requiresConfirmation),child:child);
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/agent_context.dart';
import 'copilot_screen_catalog.dart';
import 'copilot_context_window.dart';
import 'copilot_diagnostics.dart';

const copilotActionKinds = {
  'read_current_screen',
  'read_section',
  'read_selection',
  'highlight',
  'focus',
  'scroll_to',
  'open_section',
  'expand',
  'collapse',
  'select_option',
  'next',
  'previous',
  'navigate_to_registered_route',
  'open_entity',
  'set_language',
  'set_simple_care',
  'sign_out',
  'walkthrough_start','walkthrough_next','walkthrough_previous','walkthrough_repeat','walkthrough_stop','walkthrough_open_chat','walkthrough_continue',
};

/// Only an actual step or navigation warrants fresh automatic narration.
bool copilotShouldContinueAfter(String? executedKind) => const {
  'next',
  'previous',
  'open_entity',
  'navigate_to_registered_route',
  'walkthrough_start','walkthrough_next','walkthrough_previous','walkthrough_continue',
}.contains(executedKind);

class CopilotTarget {
  const CopilotTarget({
    required this.id,
    required this.kind,
    required this.label,
    this.selected,
    this.sectionId,
    this.help,
    this.value,
    this.visible,
    this.enabled,
  });
  final String id, kind, label;
  final bool? selected;
  final String? sectionId,help;
  final Object? value;
  final bool? visible,enabled;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    if (selected != null) 'selected': selected,
    if(sectionId!=null)'sectionId':sectionId,
    if(help!=null)'help':help,
    if(value!=null)'value':value,
    if(visible!=null)'visible':visible,
    if(enabled!=null)'enabled':enabled,
  };
}

/// A callback is closed over actual screen state; model arguments never choose
/// methods, routes, question keys, option values, or backend payloads.
class CopilotAction {
  const CopilotAction({
    required this.id,
    required this.kind,
    required this.targetId,
    this.requiresConfirmation = false,
    this.execute,
  });
  final String id, kind, targetId;
  final bool requiresConfirmation;
  final Future<bool> Function()? execute;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'targetId': targetId,
  };
}

class CopilotSnapshot {
  CopilotSnapshot({
    required this.screenId,
    required this.route,
    required this.version,
    required this.targets,
    required this.actions,
    this.entity,
    this.focusedSectionId,
  });
  final String screenId, route, version;
  final String? focusedSectionId;
  final AgentEntityContext? entity;
  final List<CopilotTarget> targets;
  final List<CopilotAction> actions;
  Map<String, dynamic> toJson() => {
    'screenId': screenId,
    'route': route,
    'version': version,
    if (focusedSectionId != null) 'focusedSectionId': focusedSectionId,
    'entities': [if (entity != null) entity!.toJson()],
    'targets': targets.map((t) => t.toJson()).toList(),
    'actions': actions.map((a) => a.toJson()).toList(),
  };
  AgentScreenContext get context =>
      AgentScreenContext(screenId: screenId, entity: entity, ui: toJson());
}

class CopilotOperation {
  const CopilotOperation({
    required this.actionId,
    required this.targetId,
    this.args = const {},
    this.riskTier = 0,
  });
  final String actionId, targetId;
  final Map<String, dynamic> args;
  final int riskTier;
  factory CopilotOperation.fromJson(Map<String, dynamic> j) {
    if (j['actionId'] is! String ||
        j['targetId'] is! String ||
        j['args'] is! Map) {
      throw const FormatException('Invalid UI operation');
    }
    return CopilotOperation(
      actionId: j['actionId'],
      targetId: j['targetId'],
      args: Map<String, dynamic>.from(j['args']),
      riskTier: j['riskTier'] is int ? j['riskTier'] : 0,
    );
  }
}

class CopilotPlan {
  const CopilotPlan({
    required this.id,
    required this.screenId,
    required this.version,
    required this.operations,
    this.continuationDepth = 0,
  });
  final String id, screenId, version;
  final List<CopilotOperation> operations;
  final int continuationDepth;
  bool guidanceOnly(CopilotSnapshot? snapshot) =>
      continuationDepth <= 4 &&
      operations.every(
        (op) =>
            snapshot?.actions.any(
              (action) =>
                  action.id == op.actionId &&
                  action.targetId == op.targetId &&
                  const {
                    'read_current_screen',
                    'read_section',
                    'read_selection',
                    'highlight',
                    'focus',
                    'scroll_to',
                  }.contains(action.kind),
            ) ==
            true,
      );
  factory CopilotPlan.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['screenId'] is! String ||
        value['version'] is! String ||
        value['operations'] is! List ||
        (value['operations'] as List).isEmpty ||
        (value['operations'] as List).length > 4 ||
        (value['id'] as String).isEmpty ||
        (value['version'] as String).isEmpty) {
      throw const FormatException('Invalid UI plan');
    }
    return CopilotPlan(
      id: value['id'],
      screenId: value['screenId'],
      version: value['version'],
      continuationDepth: value['continuationDepth'] is int
          ? value['continuationDepth']
          : 0,
      operations: (value['operations'] as List)
          .map(
            (v) =>
                CopilotOperation.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
    );
  }
}

class CopilotReceipt {
  const CopilotReceipt({
    required this.planId,
    required this.actionId,
    required this.targetId,
    required this.code,
    required this.before,
    required this.after,
    required this.source,
    this.confirmationRef,
  });
  final String planId, actionId, targetId, code, before, after, source;
  final String? confirmationRef;
  bool get ok => code == 'succeeded' || code == 'duplicate';
  Map<String, dynamic> toJson(String sessionId) => {
    'sessionId': sessionId,
    'planId': planId,
    'actionId': actionId,
    'targetId': targetId,
    'resultCode': code,
    'workflowId': planId,
    if (confirmationRef != null) 'confirmationRef': confirmationRef,
    'status': code == 'succeeded'
        ? 'succeeded'
        : code == 'cancelled'
        ? 'cancelled'
        : 'rejected',
    'source': source,
    'screenVersionBefore': before,
    'screenVersionAfter': after,
  };
}

class CopilotRegistry extends ChangeNotifier {
  CopilotRegistry({required this.accountId});
  final String accountId;
  final String _mountEpoch = DateTime.now().microsecondsSinceEpoch
      .toString()
      .padLeft(20, '0');
  final String _nonce = List.generate(
    8,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  CopilotSnapshot? snapshot;
  CopilotScreenDefinition? catalog;
  Future<bool> Function(String)? walkthroughCommand;
  Future<void> Function()? beforeVisualAction;
  void publishCatalogWindow(CopilotContextWindow window,{required String focusedTargetId}) {
    final d=catalog,owner=_owner;if(d==null||owner==null)return;
    publish(owner:owner,screenId:d.screenId,route:d.routeId,stateKey:'${d.revision}:focused:$focusedTargetId',entity:snapshot?.entity,focusedSectionId:focusedTargetId,targets:window.targets,actions:window.actions);
  }
  void clearHighlight(){if(highlightedTarget==null)return;highlightedTarget=null;_highlightTimer?.cancel();_notify();}
  Object? _owner;
  String? _stateKey;
  int _sequence = 0, generation = 0;
  bool _disposed = false, valid = true;
  String? highlightedTarget;
  Timer? _highlightTimer;
  final _anchors = <String, List<_CopilotAnchorState>>{};
  List<CopilotTarget> get renderedDescriptions => [
    for(final id in _anchors.keys)
      if(_activeAnchor(id)?.widget.descriptor!=null)_activeAnchor(id)!.widget.descriptor!,
  ];
  List<CopilotAction> get renderedActions => [
    for(final id in _anchors.keys)
      if(_activeAnchor(id)?.widget.action!=null)_activeAnchor(id)!.widget.action!,
  ];
  bool hasRenderedTarget(String id)=>_activeAnchor(id)!=null;

  void publish({
    required Object owner,
    required String screenId,
    required String route,
    required String stateKey,
    required List<CopilotTarget> targets,
    required List<CopilotAction> actions,
    AgentEntityContext? entity,
    String? focusedSectionId,
  }) {
    if (!valid || _disposed) return;
    if (!AgentScreenContext.supportedScreenIds.contains(screenId) ||
        !AgentScreenContext.supportedScreenIds.contains(route) ||
        targets.length > 20 ||
        actions.length > 20 ||
        targets.map((t) => t.id).toSet().length != targets.length ||
        actions.map((a) => a.id).toSet().length != actions.length ||
        actions.any(
          (a) =>
              !copilotActionKinds.contains(a.kind) ||
              !targets.any((t) => t.id == a.targetId),
        )) {
      throw const FormatException('Invalid screen capabilities');
    }
    final same =
        identical(_owner, owner) &&
        _stateKey == stateKey &&
        snapshot?.screenId == screenId;
    final next = CopilotSnapshot(
      screenId: screenId,
      route: route,
      version: same
          ? snapshot!.version
          : 'ui_${_mountEpoch}_${(++_sequence).toString().padLeft(8, '0')}_$_nonce',
      entity: entity,
      focusedSectionId: focusedSectionId,
      targets: List.unmodifiable(targets),
      actions: List.unmodifiable(actions),
    );
    if (utf8.encode(jsonEncode(next.context.toJson())).length > 4096) {
      throw const FormatException('UI context too large');
    }
    _owner = owner;
    _stateKey = stateKey;
    snapshot = next;
    if (!same) {
      highlightedTarget = null;
      CopilotDiagnostics.emit(CopilotDiagnostic.contextReady,registeredScreen:screenId);
      if (kDebugMode) debugPrint('AGENT_UI:CONTEXT_ACCEPTED');
      _notify();
    }
  }

  void navigationChanged() {
    catalog = null;
    snapshot = null;
    _owner = null;
    _stateKey = null;
    highlightedTarget = null;
    _highlightTimer?.cancel();
    _notify();
  }

  void _registerAnchor(String id, _CopilotAnchorState anchor) {
    final anchors = _anchors.putIfAbsent(id, () => []);
    if (!anchors.contains(anchor)) anchors.add(anchor);
  }

  void _unregisterAnchor(String id, _CopilotAnchorState anchor) {
    final anchors = _anchors[id];
    anchors?.remove(anchor);
    if (anchors?.isEmpty == true) _anchors.remove(id);
  }

  _CopilotAnchorState? _activeAnchor(String id) {
    final anchors = _anchors[id];
    if (anchors == null) return null;
    for (final anchor in anchors.reversed) {
      if (anchor.mounted && ModalRoute.of(anchor.context)?.isCurrent != false) {
        return anchor;
      }
    }
    return null;
  }

  bool owns(Object owner) => identical(_owner, owner);
  void clear({required Object owner}) {
    if (!identical(_owner, owner)) return;
    snapshot = null;
    _owner = null;
    _stateKey = null;
    highlightedTarget = null;
    _notify();
  }

  void invalidate() {
    catalog = null;
    valid = false;
    generation++;
    snapshot = null;
    highlightedTarget = null;
    _highlightTimer?.cancel();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    if(WidgetsBinding.instance.schedulerPhase==SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_){if(!_disposed)notifyListeners();});
    } else {notifyListeners();}
  }

  /// Wait for the destination's real semantic target, never for a fixed delay.
  /// This does not publish capabilities or advance a screen version.
  Future<bool> waitForScreenTarget({
    required String screenId,
    required String entityId,
    required String targetId,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!valid || _disposed) return false;
    final startedGeneration = generation;
    final result = Completer<bool>();
    void check() {
      if (result.isCompleted) return;
      if (!valid || _disposed || generation != startedGeneration) {
        result.complete(false);
        return;
      }
      final current = snapshot;
      if (current?.screenId == screenId &&
          current?.entity?.type == 'care_plan' &&
          current?.entity?.id == entityId &&
          current!.targets.any((target) => target.id == targetId) &&
          _activeAnchor(targetId) != null) {
        result.complete(true);
      }
    }

    addListener(check);
    final timer = Timer(timeout, () {
      if (!result.isCompleted) result.complete(false);
    });
    check();
    try {
      return await result.future;
    } finally {
      timer.cancel();
      if (!_disposed) removeListener(check);
    }
  }

  Future<bool> reveal(String id, String kind,{bool sticky=false}) async {
    await beforeVisualAction?.call();
    final anchor = _activeAnchor(id);
    if (!valid ||
        anchor == null ||
        !anchor.mounted ||
        snapshot?.targets.any((t) => t.id == id&&t.visible!=false) != true) {
      return false;
    }
    final version = snapshot?.version;
    final reduced =
        MediaQuery.maybeOf(anchor.context)?.disableAnimations ?? false;
    await Scrollable.ensureVisible(
      anchor.context,
      alignment: .35,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
    );
    if (!valid ||
        !anchor.mounted ||
        snapshot?.version != version ||
        _activeAnchor(id) != anchor) {
      return false;
    }
    if (kind == 'focus') anchor.focusNode.requestFocus();
    if (kind != 'scroll_to') {
      highlightedTarget = id;
      if (kDebugMode) debugPrint('AGENT_UI:TARGET_HIGHLIGHTED');
      _highlightTimer?.cancel();
      _notify();
      if(!sticky){_highlightTimer = Timer(const Duration(seconds: 5), () {
        highlightedTarget = null;
        _notify();
      });}
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    valid = false;
    _highlightTimer?.cancel();
    _anchors.clear();
    super.dispose();
  }
}

/// Bounded, account-scoped orchestration. A state-changing operation ends this
/// plan: the next step must be planned from newly published UI state.
class CopilotExecutor extends ChangeNotifier {
  CopilotExecutor({required this.registry, this.confirm, this.receipt});
  final CopilotRegistry registry;
  final Future<bool> Function(CopilotAction)? confirm;
  final Future<void> Function(CopilotReceipt)? receipt;
  final _seen = <String>{};
  bool paused = false, running = false;
  int get cancellationGeneration => _cancelGeneration;
  int _cancelGeneration = 0;
  String? status;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelGeneration++;
    super.dispose();
  }

  void pause() {
    paused = true;
    _cancelGeneration++;
    status = 'workflow_paused';
    if (kDebugMode) debugPrint('AGENT_WORKFLOW:PAUSED');
    notifyListeners();
  }

  void resume() {
    paused = false;
    status = null;
    notifyListeners();
  }

  void cancel() {
    _cancelGeneration++;
    paused = true;
    status = 'cancelled';
    notifyListeners();
  }

  void contextUnavailable() {
    status = 'context_unavailable';
    notifyListeners();
  }

  Future<List<CopilotReceipt>> run(
    CopilotPlan plan, {
    String source = 'text',
  }) async {
    final output = <CopilotReceipt>[];
    if (plan.operations.isEmpty || plan.operations.length > 4) return output;
    final generation = registry.generation, cancellation = _cancelGeneration;
    final wasRunning = running;
    if (!wasRunning) {
      running = true;
      if (kDebugMode) debugPrint('AGENT_WORKFLOW:STARTED');
      notifyListeners();
    }
    try {
      for (final op in plan.operations) {
        final before = registry.snapshot?.version ?? plan.version;
        String? code, confirmationRef;
        final key = '${plan.id}:${op.actionId}:${op.targetId}';
        String? fence() {
          if (!registry.valid || generation != registry.generation) {
            return 'account_changed';
          }
          if (paused || cancellation != _cancelGeneration) {
            return 'workflow_paused';
          }
          if (registry.snapshot?.screenId != plan.screenId ||
              registry.snapshot?.version != plan.version) {
            return 'stale_context';
          }
          return null;
        }

        code = wasRunning ? 'workflow_busy' : fence();
        CopilotAction? action;
        if (code == null && _seen.contains(key)) code = 'duplicate';
        if (code == null &&
            (op.args.isNotEmpty || op.riskTier < 0 || op.riskTier > 2)) {
          code = 'invalid_arguments';
        }
        final screen = registry.snapshot;
        if (code == null && !screen!.targets.any((t) => t.id == op.targetId)) {
          code = 'target_not_found';
        }
        if (code == null) {
          for (final a in screen!.actions) {
            if (a.id == op.actionId && a.targetId == op.targetId) action = a;
          }
          if (action == null) code = 'action_unavailable';
        }
        if (code == null &&
            (action!.requiresConfirmation || op.riskTier >= 2)) {
          final accepted = await (confirm?.call(action) ?? Future.value(false));
          code = fence();
          if (code == null && !accepted) code = 'cancelled';
          if (code == null && accepted) {
            confirmationRef =
                'ui_confirm_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
          }
        }
        if (code == null) {
          _seen.add(key);
          if (_seen.length > 128) _seen.remove(_seen.first);
          try {
            bool ok;
            if ({'highlight', 'focus', 'scroll_to'}.contains(action!.kind)) {
              ok = await registry.reveal(op.targetId, action.kind);
            } else if (action.kind.startsWith('read_')) {
              ok = await registry.reveal(op.targetId,'highlight');
            } else {
              ok = await (action.execute?.call() ?? Future.value(false));
            }
            code = !registry.valid || generation != registry.generation
                ? 'account_changed'
                : cancellation != _cancelGeneration
                ? 'workflow_paused'
                : ok
                ? 'succeeded'
                : 'action_failed';
          } catch (_) {
            code = 'action_failed';
          }
        }
        final result = CopilotReceipt(
          planId: plan.id,
          actionId: op.actionId,
          targetId: op.targetId,
          code: code,
          before: before,
          after: registry.snapshot?.version ?? before,
          source: source,
          confirmationRef: confirmationRef,
        );
        output.add(result);
        status = code;
        if (kDebugMode) {
          if (code == 'succeeded') debugPrint('AGENT_UI:ACTION_EXECUTED');
          if (code == 'stale_context') debugPrint('AGENT_UI:STALE_CONTEXT');
        }
        // Receipt network failure never causes an uncertain callback to replay.
        if (code != 'duplicate') {
          try {
            await receipt?.call(result);
          } catch (_) {}
        }
        if (!result.ok || registry.snapshot?.version != plan.version) break;
      }
    } finally {
      if (!wasRunning) running = false;
      if (kDebugMode) debugPrint('AGENT_WORKFLOW:COMPLETED');
      notifyListeners();
    }
    return output;
  }
}

class CopilotScope extends InheritedWidget {
  const CopilotScope({
    super.key,
    required this.registry,
    required this.executor,
    this.presentation,
    required super.child,
  });
  final CopilotRegistry registry;
  final CopilotExecutor executor;
  final CopilotPresentation? presentation;
  static CopilotScope? maybeOf(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<CopilotScope>();
  @override
  bool updateShouldNotify(CopilotScope old) => old.registry != registry;
}

class CopilotAnchor extends StatefulWidget {
  const CopilotAnchor({
    super.key,
    required this.registry,
    required this.targetId,
    required this.child,
    this.descriptor,
    this.action,
  });
  final CopilotRegistry registry;
  final String targetId;
  final Widget child;
  final CopilotTarget? descriptor;
  final CopilotAction? action;
  @override
  State<CopilotAnchor> createState() => _CopilotAnchorState();
}

class _CopilotAnchorState extends State<CopilotAnchor> {
  final focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.registry._registerAnchor(widget.targetId, this);
  }

  @override
  void didUpdateWidget(CopilotAnchor old) {
    super.didUpdateWidget(old);
    if (old.registry != widget.registry || old.targetId != widget.targetId) {
      old.registry._unregisterAnchor(old.targetId, this);
      widget.registry._registerAnchor(widget.targetId, this);
    }
  }

  @override
  void dispose() {
    widget.registry._unregisterAnchor(widget.targetId, this);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.registry,
    builder: (context, _) {
      final highlighted = widget.registry.highlightedTarget == widget.targetId;
      return Focus(
        focusNode: focusNode,
        child: AnimatedContainer(
          key: highlighted
              ? ValueKey('copilot_highlight_${widget.targetId}')
              : null,
          duration: MediaQuery.maybeOf(context)?.disableAnimations == true
              ? Duration.zero
              : const Duration(milliseconds: 180),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: highlighted
                ? Border.all(color: const Color(0xFF0D9488), width: 3)
                : null,
          ),
          child: widget.child,
        ),
      );
    },
  );
}

enum CopilotMode {collapsed,compact,expanded,guided}
class GuidanceSummary {
  const GuidanceSummary(this.screenId,{this.targetId});
  final String screenId;
  final String? targetId;
}
class CopilotPresentation extends ChangeNotifier {
  CopilotMode mode=CopilotMode.collapsed;
  GuidanceSummary? guidance;
  bool memoryReviewBusy=false;
  double sheetExtent=.45;
  bool get visible=>mode==CopilotMode.compact||mode==CopilotMode.expanded;
  void open()=>openChat();
  void close()=>minimizeChat();
  void openChat(){mode=CopilotMode.compact;sheetExtent=.45;notifyListeners();}
  void expandChat(){mode=CopilotMode.expanded;sheetExtent=.96;notifyListeners();}
  void minimizeChat(){mode=CopilotMode.collapsed;notifyListeners();}
  void enterGuided(GuidanceSummary summary){guidance=summary;mode=CopilotMode.guided;notifyListeners();}
  void finishGuidance(){guidance=null;mode=CopilotMode.collapsed;notifyListeners();}
  void setMemoryReviewBusy(bool value){memoryReviewBusy=value;notifyListeners();}
}

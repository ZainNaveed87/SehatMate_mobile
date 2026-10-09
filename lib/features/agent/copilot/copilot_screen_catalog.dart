import 'copilot.dart';

/// Complete local catalog; only a bounded window crosses the Agent boundary.
class CopilotScreenDefinition {
  const CopilotScreenDefinition({required this.screenId,required this.routeId,required this.revision,required this.targets,required this.actions,required this.walkthroughOrder,this.keyActions=const []});
  final String screenId,routeId,revision;
  final List<CopilotTarget> targets;
  final List<CopilotAction> actions;
  final List<String> walkthroughOrder,keyActions;
}

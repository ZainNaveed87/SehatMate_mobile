import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import 'models/agent_context.dart';
import 'copilot/copilot.dart';
import 'voice/voice_companion_scope.dart';

class AgentScreenArgs {
  const AgentScreenArgs({this.context});

  final AgentScreenContext? context;
}

Future<void> openAgent(
  BuildContext context, {
  AgentScreenContext? screenContext,
}) {
  final copilot = CopilotScope.maybeOf(context);
  if (copilot?.presentation != null) {
    VoiceCompanionScope.read(context)?.minimizePresentation();
    copilot!.presentation!.open();
    return Future<void>.value();
  }
  return Navigator.pushNamed(
    context,
    AppRoutes.agent,
    arguments: AgentScreenArgs(context: screenContext),
  );
}

/// Legacy named route enters the existing root conversation instead of creating one.
class AgentCompatibilityEntry extends StatefulWidget {
 const AgentCompatibilityEntry({super.key});
 @override State<AgentCompatibilityEntry> createState()=>_AgentCompatibilityEntryState();
}
class _AgentCompatibilityEntryState extends State<AgentCompatibilityEntry> {
 bool opened=false;
 @override void didChangeDependencies(){super.didChangeDependencies();if(opened)return;opened=true;WidgetsBinding.instance.addPostFrameCallback((_){if(!mounted)return;final presentation=CopilotScope.maybeOf(context)?.presentation;if(presentation==null)return;Navigator.of(context).pop();presentation.openChat();});}
 @override Widget build(BuildContext context)=>const SizedBox.shrink();
}

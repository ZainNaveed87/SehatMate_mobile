import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import 'models/agent_context.dart';

class AgentScreenArgs {
  const AgentScreenArgs({this.context});

  final AgentScreenContext? context;
}

Future<void> openAgent(
  BuildContext context, {
  AgentScreenContext? screenContext,
}) {
  return Navigator.pushNamed(
    context,
    AppRoutes.agent,
    arguments: AgentScreenArgs(context: screenContext),
  );
}

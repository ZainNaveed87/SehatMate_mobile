import 'package:flutter/foundation.dart';
import '../models/agent_context.dart';
enum CopilotDiagnostic {contextReady,visualStarted,navigationResolved,workflowChanged,languageReady}
enum CopilotDiagnosticOutcome {succeeded,rejected,stale,paused}
abstract final class CopilotDiagnostics {
  static void emit(CopilotDiagnostic code,{String? registeredScreen,CopilotDiagnosticOutcome? outcome,String? language}) {
    if(!kDebugMode)return;
    final screen=AgentScreenContext.supportedScreenIds.contains(registeredScreen)?registeredScreen:null;
    final canonical=const {'en','ur','roman_ur'}.contains(language)?language:null;
    debugPrint('AGENT_PHASE21:${code.name}${screen==null?'':':$screen'}${outcome==null?'':':${outcome.name}'}${canonical==null?'':':$canonical'}');
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';

enum VoiceTurnStage { uiEventReceived, uiTextReady, uiRendered }

String voiceTurnCorrelation(String turn) {
  var value = 2166136261;
  for (final byte in utf8.encode(turn)) {
    value = ((value ^ byte) * 16777619) & 0xffffffff;
  }
  return value.toRadixString(16).padLeft(8, '0');
}

void traceVoiceTurn(VoiceTurnStage stage, String turn) {
  if (!kDebugMode || turn.isEmpty || turn.length > 80) return;
  const names = {
    VoiceTurnStage.uiEventReceived: 'VOICE_TURN_UI_EVENT_RECEIVED',
    VoiceTurnStage.uiTextReady: 'VOICE_TURN_UI_TEXT_READY',
    VoiceTurnStage.uiRendered: 'VOICE_TURN_UI_RENDERED',
  };
  debugPrint(jsonEncode({'stage': names[stage], 'correlation': voiceTurnCorrelation(turn)}));
}

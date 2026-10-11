import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/voice/voice_lifecycle_trace.dart';

void main() {
  test('lifecycle diagnostics discard unregistered routes, actions and state values', () {
    final logs=<String>[];final previous=debugPrint;
    debugPrint=(String? message,{int? wrapWidth}){if(message!=null)logs.add(message);};
    try {
      traceVoiceLifecycle(VoiceLifecycleEvent.routeChanged,VoiceLifecycleReason.navigation,
        generation:3,state:'private-patient',screen:'room-private',action:'token-private',disconnectCause:'provider-private');
      final value=jsonDecode(logs.single) as Map<String,dynamic>;
      expect(value['generation'],3);expect(value['route'],'unknown');expect(value['action'],'other');expect(value['state'],'unknown');expect(value['cause'],'unknown');
      expect(logs.single, isNot(contains('private')));
      traceVoiceLifecycle(VoiceLifecycleEvent.micTrackState,VoiceLifecycleReason.microphoneObserved,micEnabled:false,manualMuted:false);
      final mic=jsonDecode(logs.last) as Map<String,dynamic>;
      expect(mic['micEnabled'],false);expect(mic['manualMuted'],false);
    } finally {debugPrint=previous;}
  });
  test('attention diagnostics retain fixed reason codes and discard private codes', () {
    final logs=<String>[];final previous=debugPrint;
    debugPrint=(String? message,{int? wrapWidth}){if(message!=null)logs.add(message);};
    try {
      traceVoiceLifecycle(VoiceLifecycleEvent.attentionRequired,VoiceLifecycleReason.eventRecovery,
        attentionCode:'FISH_RATE_LIMIT',state:'awaiting_confirmation',generation:2);
      final known=jsonDecode(logs.last) as Map<String,dynamic>;
      expect(known['event'],'VOICE_ATTENTION_REQUIRED');expect(known['code'],'FISH_RATE_LIMIT');
      traceVoiceLifecycle(VoiceLifecycleEvent.attentionRequired,VoiceLifecycleReason.eventRecovery,
        attentionCode:'private-room-token',failureCode:'private-provider-body');
      final unknown=jsonDecode(logs.last) as Map<String,dynamic>;
      expect(unknown['code'],'VOICE_ATTENTION_OTHER');expect(unknown['failure'],'VOICE_EVENT_FAILED');
      expect(logs.last,isNot(contains('private')));
    }finally{debugPrint=previous;}
  });
}

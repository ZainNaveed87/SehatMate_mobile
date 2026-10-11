import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/agent_context.dart';

enum VoiceLifecycleEvent {
  sessionState, micTrackState, manualMuteChanged, autoGateChanged, routeChanged,
  actionStarted, actionCompleted, disconnectRequested, disconnectStarted,
  disconnectCompleted, controllerDisposed,
}
enum VoiceLifecycleReason {
  start, userMute, userResume, userEnd, userStop, languageChange, eventRecovery,
  actionFailed, microphoneRequest, microphoneObserved, processing, playback,
  reconnecting, reconnected, reconnectTimeout, transportLost, startupFailed,
  staleStartup, staleResume, transfer, workerRecovery, workerTerminal, expiry,
  background, lifecycle, dispose, accountChanged, navigation, action,
  transportClose,
}

/// Closed codes only. No account, token, transcript, room or backend session IDs.
void traceVoiceLifecycle(VoiceLifecycleEvent event, VoiceLifecycleReason reason,
    {int? generation, String? state, bool? manualMuted, bool? micEnabled,
    bool? gated, String? screen, String? action, String? disconnectCause}) {
  if (!kDebugMode && !const bool.fromEnvironment('VOICE_LIFECYCLE_DIAGNOSTICS')) return;
  const events = <VoiceLifecycleEvent,String>{
    VoiceLifecycleEvent.sessionState:'VOICE_SESSION_STATE',
    VoiceLifecycleEvent.micTrackState:'VOICE_MIC_TRACK_STATE',
    VoiceLifecycleEvent.manualMuteChanged:'VOICE_MANUAL_MUTE_CHANGED',
    VoiceLifecycleEvent.autoGateChanged:'VOICE_AUTO_GATE_CHANGED',
    VoiceLifecycleEvent.routeChanged:'VOICE_ROUTE_CHANGED',
    VoiceLifecycleEvent.actionStarted:'VOICE_ACTION_STARTED',
    VoiceLifecycleEvent.actionCompleted:'VOICE_ACTION_COMPLETED',
    VoiceLifecycleEvent.disconnectRequested:'VOICE_DISCONNECT_REQUESTED',
    VoiceLifecycleEvent.disconnectStarted:'VOICE_DISCONNECT_STARTED',
    VoiceLifecycleEvent.disconnectCompleted:'VOICE_DISCONNECT_COMPLETED',
    VoiceLifecycleEvent.controllerDisposed:'VOICE_CONTROLLER_DISPOSED',
  };
  const states={'idle','manual','connecting','listening','muted','processing','speaking','recovering','disconnected','awaiting_confirmation','awaiting_clarification','resumed','inactive','hidden','paused','detached'};
  const causes={'unknown','clientInitiated','duplicateIdentity','serverShutdown','participantRemoved','roomDeleted','stateMismatch','joinFailure','disconnected','signalingConnectionFailure','reconnectAttemptsExceeded','connectionTimeout','mediaFailure','migration','roomClosed','agentError','signalClose','userUnavailable','userRejected','sipTrunkFailure'};
  const actions={'highlight','focus','scroll_to','fill_text','read_section','read_current_screen','open_section','open_entity','navigate_to_registered_route','set_language','confirmation'};
  debugPrint(jsonEncode({
    'event':events[event], 'reason':reason.name,
    if(generation!=null)'generation':generation,
    if(state!=null)'state':states.contains(state)?state:'unknown',
    if(manualMuted!=null)'manualMuted':manualMuted,
    if(micEnabled!=null)'micEnabled':micEnabled,
    if(gated!=null)'gated':gated,
    if(screen!=null)'route':AgentScreenContext.supportedScreenIds.contains(screen)?screen:'unknown',
    if(action!=null)'action':actions.contains(action)?action:'other',
    if(disconnectCause!=null)'cause':causes.contains(disconnectCause)?disconnectCause:'unknown',
  }));
}

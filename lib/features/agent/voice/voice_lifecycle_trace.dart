import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/agent_context.dart';

enum VoiceLifecycleEvent {
  sessionState, micTrackState, manualMuteChanged, autoGateChanged, routeChanged,
  actionStarted, actionCompleted, disconnectRequested, disconnectStarted,
  disconnectCompleted, controllerDisposed, attentionRequired,
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
    bool? gated, String? screen, String? action, String? disconnectCause,
    String? attentionCode, String? failureCode, bool? connected}) {
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
    VoiceLifecycleEvent.attentionRequired:'VOICE_ATTENTION_REQUIRED',
  };
  const states={'idle','manual','connecting','listening','muted','processing','speaking','recovering','disconnected','awaiting_confirmation','awaiting_clarification','resumed','inactive','hidden','paused','detached'};
  const causes={'unknown','clientInitiated','duplicateIdentity','serverShutdown','participantRemoved','roomDeleted','stateMismatch','joinFailure','disconnected','signalingConnectionFailure','reconnectAttemptsExceeded','connectionTimeout','mediaFailure','migration','roomClosed','agentError','signalClose','userUnavailable','userRejected','sipTrunkFailure'};
  const actions={'highlight','focus','scroll_to','fill_text','read_section','read_current_screen','open_section','open_entity','navigate_to_registered_route','set_language','confirmation'};
  // Closed internal codes only; never print arbitrary Worker/server values.
  const attentionCodes={
    'VOICE_CONNECTION_RECOVERY_REQUIRED','VOICE_TURN_DELAYED','VOICE_CLEANUP_PENDING',
    'VOICE_LANGUAGE_SYNC_FAILED','VOICE_CONTROL_UNAVAILABLE','VOICE_RESUME_FAILED',
    'VOICE_EVENT_RECOVERY_REQUIRED','VOICE_FALLBACK_REQUIRED','VOICE_RECOVERING',
    'VOICE_RECOVERY_REQUIRED','VOICE_STALE','VOICE_RECEIPT_EXPIRED','VOICE_TURN_UNCERTAIN',
    'VOICE_SESSION_EXPIRED','VOICE_SESSION_INVALID','VOICE_AUTHENTICATION_REQUIRED',
    'VOICE_WORKER_UNAVAILABLE','VOICE_START_FAILED','VOICE_RECONNECT_AUTHORIZATION_FAILED',
    'VOICE_CONNECTION_FAILED','VOICE_HANDOFF_UNAVAILABLE',
    'VOICE_INVALID_ROOM_TOKEN','VOICE_PARTICIPANT_MISMATCH','VOICE_NOT_CONNECTED',
    'LIVEKIT_RECONNECTING','LIVEKIT_DISCONNECTED','LIVEKIT_CONNECT_FAILED',
    'DEVICE_STT_UNAVAILABLE','DEVICE_STT_NO_FINAL_TRANSCRIPT','DEVICE_TTS_UNAVAILABLE',
    'DEVICE_TTS_REQUIRED','VOICE_PLAYBACK_FAILED','FISH_RATE_LIMIT','FISH_QUOTA',
    'FISH_REQUEST_LIMIT','FISH_DISABLED','FISH_UNAVAILABLE','FISH_INVALID_AUDIO',
    'FISH_AUDIO_LIMIT','FISH_TEXT_LIMIT','FISH_TEXT_SEGMENT_LIMIT','FISH_MODEL_REJECTED',
    'DEEPGRAM_UNAVAILABLE','DEEPGRAM_RATE_LIMIT','STT_UNAVAILABLE','TRANSCRIPT_LIMIT',
    'WORKER_TURN_UNCERTAIN','VOICE_UI_ACTION_FAILED','VOICE_UI_STATE_UNKNOWN',
  };
  const failureCodes={'VOICE_AGENT_SESSION_MISMATCH','VOICE_RESULT_INVALID','VOICE_EVENT_FAILED'};
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
    if(attentionCode!=null)'code':attentionCodes.contains(attentionCode)?attentionCode:'VOICE_ATTENTION_OTHER',
    if(failureCode!=null)'failure':failureCodes.contains(failureCode)?failureCode:'VOICE_EVENT_FAILED',
    if(connected!=null)'connected':connected,
  }));
}

import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;
import 'package:flutter/foundation.dart';
import '../controllers/agent_controller.dart';
import '../models/agent_response.dart';
import '../models/agent_transcript_presentation.dart';
import '../services/agent_voice_service.dart';
import '../../../localization/app_language.dart';
import '../../../localization/language_controller.dart';
import 'voice_backend.dart';
import 'voice_transport.dart';
import 'voice_turn_trace.dart';
import 'voice_lifecycle_trace.dart';

/// Application owned voice coordination. Audio, actions and transport ownership
/// are fenced independently; uncertain actions are read by receipt, never replayed.
class VoiceCompanionController extends ChangeNotifier {
  VoiceCompanionController({
    required this.backend,
    required this.transport,
    required this.agent,
    required this.authenticated,
    this.device,
    LanguageController? languagePreferences,
    Future<String> Function()? ensureAgentSession,
    Future<void> Function(Duration)? delay,
    Duration processingTimeout = const Duration(seconds: 135),
  }) : _ensureAgentSession = ensureAgentSession,
       _languagePreferences = languagePreferences,
       _processingTimeout = processingTimeout,
       _delay = delay ?? Future<void>.delayed {
    _events = transport.events.listen(_enqueue);
    _connections = transport.connections.listen((state) {
      final generation = _generation;
      unawaited(
        _connection(state).catchError((Object _) {
          if (_current(generation) && enabled) {
            _recover('VOICE_CONNECTION_RECOVERY_REQUIRED');
          }
        }),
      );
    });
    language = _languagePreferences?.language ?? language;
    _languagePreferences?.addListener(_selectedLanguageChanged);
  }
  final VoiceBackend backend;
  final VoiceTransport transport;
  final AgentController agent;
  final bool Function() authenticated;
  final AgentVoiceClient? device;
  final LanguageController? _languagePreferences;
  final Future<String> Function()? _ensureAgentSession;
  final Future<void> Function(Duration) _delay;
  final Duration _processingTimeout;
  late final StreamSubscription<VoicePacket> _events;
  late final StreamSubscription<VoiceConnection> _connections;
  Map<String, dynamic>? _binding;
  String? _workerIdentity, _inflight, _playbackId;
  String? _replyTurn, _renderedReplyTurn;
  final _transcripts = <String, String>{};
  String? _finalTranscriptTurn, _romanFinalTranscript;
  bool _finalPresentationComplete = false;
  String get visibleFinalTranscript => transcriptForDisplay(finalTranscript, language,
      rendering: _romanFinalTranscript, complete: _finalPresentationComplete);
  String get visibleInterimTranscript => transcriptForDisplay(interimTranscript, language, interim: true);
  final _completed = <String>{};
  final _devicePlaybacks = <String>{};
  int _speechGeneration = 0;
  AppLanguage _replyLanguage = AppLanguage.english;
  int _generation = 0, _eventSeq = 0, _controlSeq = 0;
  bool _disposed = false,
      _manualMuted = false,
      _desiredListening = false,
      _busy = false,
      _connected = false,
      _deviceFinishing = false;
  Future<void> _eventQueue = Future<void>.value();
  Future<void> _languageQueue = Future<void>.value();
  Completer<void>? _startupDone;
  Future<void>? _ending;
  int _languageRevision = 0;
  bool _languageRebindPending = false,
      _languageRebindListening = false,
      _languageRebindResume = false,
      _languageRebindManual = false;
  Future<void> get languageChangeComplete => _languageQueue;
  Timer? _expiry, _reconnectTimeout, _processingWatchdog;
  AppLanguage language = AppLanguage.english;
  bool enabled = false, foreground = true, recoveryRequired = false;
  bool deviceSpeechEnabled = false, deviceTtsEnabled = false;
  String state = 'idle',
      interimTranscript = '',
      finalTranscript = '',
      reply = '',
      recoveryCode = '';
  void Function(AgentResponse)? onResult;
  bool presentationMinimized = false;
  void minimizePresentation() {
    presentationMinimized = true;
    notifyListeners();
  }

  void expandPresentation() {
    presentationMinimized = false;
    notifyListeners();
  }

  Map<String, dynamic>? _pendingDeviceTts;
  String? get voiceSessionId => _binding?['id'] as String?;
  int? get epoch => _binding?['epoch'] as int?;
  String? get transportOwner => _binding?['transportOwner'] as String?;
  bool get muted => _manualMuted;
  int get sessionGeneration => _generation;
  bool get canResolveConfirmation => _binding != null && !_busy &&
      _inflight == null && !recoveryRequired && authenticated();
  bool get automaticInputGated => enabled && !_manualMuted && !_micRequested;
  bool _micRequested = false;
  void _trace(VoiceLifecycleEvent event, VoiceLifecycleReason reason) =>
      traceVoiceLifecycle(event, reason, generation:_generation, state:state,
          manualMuted:_manualMuted, micEnabled:_micRequested);
  Future<void> _microphone(bool enabled, VoiceLifecycleReason reason) async {
    final generation=_generation;
    _micRequested=enabled;
    _trace(VoiceLifecycleEvent.micTrackState,reason);
    traceVoiceLifecycle(VoiceLifecycleEvent.autoGateChanged,reason,
        generation:generation,gated:automaticInputGated,manualMuted:_manualMuted);
    await transport.microphone(enabled);
  }
  Future<void> _disconnect(VoiceLifecycleReason reason) async {
    _trace(VoiceLifecycleEvent.disconnectStarted,reason);
    await transport.disconnect();
    _trace(VoiceLifecycleEvent.disconnectCompleted,reason);
  }
  bool get activeForeground =>
      enabled && foreground && authenticated() && _binding != null;
  bool get eligibleCheckIn =>
      activeForeground &&
      !recoveryRequired &&
      !_busy &&
      _inflight == null &&
      state == 'listening';
  bool get hasDeviceTtsOffer => _pendingDeviceTts != null;
  bool get speechBudgetExhausted => recoveryCode == 'FISH_REQUEST_LIMIT';
  bool get speechUnavailable =>
      hasDeviceTtsOffer ||
      recoveryCode.startsWith('FISH_') ||
      recoveryCode == 'VOICE_PLAYBACK_FAILED' ||
      recoveryCode == 'DEVICE_TTS_UNAVAILABLE';
  bool _current(int generation) =>
      !_disposed && generation == _generation && authenticated() && foreground;
  void reportReplyRendered() {
    final turn = _replyTurn;
    if (_disposed || !enabled || turn == null || _renderedReplyTurn == turn) return;
    _renderedReplyTurn = turn;
    traceVoiceTurn(VoiceTurnStage.uiRendered, turn);
  }
  @override
  void notifyListeners() {
    if (!_disposed) {
      _trace(VoiceLifecycleEvent.sessionState,VoiceLifecycleReason.lifecycle);
      super.notifyListeners();
    }
  }

  void _recover(String code, {String? failureCode,
      VoiceLifecycleReason reason = VoiceLifecycleReason.lifecycle}) {
    if (state != 'recovering' || recoveryCode != code) {
      traceVoiceLifecycle(VoiceLifecycleEvent.attentionRequired,
          reason, generation: _generation, state: state,
          manualMuted: _manualMuted, micEnabled: _micRequested,
          attentionCode: code, failureCode: failureCode, connected: _connected);
    }
    recoveryCode = code;
    state = 'recovering';
    notifyListeners();
  }

  void _startStage(String stage) {
    if (kDebugMode) debugPrint('VOICE_CLIENT_START:$stage');
  }

  void _watchProcessing(String turn, int generation) {
    _processingWatchdog?.cancel();
    _processingWatchdog = Timer(_processingTimeout, () {
      if (!_current(generation) ||
          !enabled ||
          _inflight != turn ||
          state != 'processing') {
        return;
      }
      _recover('VOICE_TURN_DELAYED');
      // Read the same receipt only. Never resubmit an uncertain business action.
      unawaited(reconcile());
    });
  }

  bool _validBinding(Map<String, dynamic> value) =>
      value['id'] is String &&
      RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value['id']) &&
      value['epoch'] is int &&
      value['epoch'] > 0 &&
      value['status'] == 'active' &&
      DateTime.tryParse(
            value['expiresAt']?.toString() ?? '',
          )?.isAfter(DateTime.now()) ==
          true;
  void _bind(Map<String, dynamic> value) {
    if (!_validBinding(value)) {
      throw const VoiceFailure('VOICE_SESSION_EXPIRED');
    }
    if (_binding?['epoch'] != value['epoch']) {
      _eventSeq = 0;
      _controlSeq = 0;
      _workerIdentity = null;
    }
    _binding = value;
    _workerIdentity = value['workerIdentity'] as String?;
    _expiry?.cancel();
    final generation=_generation, bindingId=value['id'], bindingEpoch=value['epoch'];
    _expiry = Timer(
      DateTime.parse(value['expiresAt']).difference(DateTime.now()),
      () {
        if(_current(generation)&&voiceSessionId==bindingId&&epoch==bindingEpoch) {
          unawaited(end(reason:VoiceLifecycleReason.expiry));
        }
      },
    );
  }

  bool _appLanguageAction = false;
  /// Confirmed app setting uses the existing persistence and Worker resume claim.
  /// It keeps the RTC room, mute intent and transport generation intact.
  Future<bool> applyAppLanguage(AppLanguage selected) async {
    if (_disposed || !authenticated() || _languagePreferences == null || _appLanguageAction) return false;
    final generation=_generation;
    _appLanguageAction=true;
    try {
      await _languagePreferences.setLanguage(selected,persistBeforeNotify:true);
      if (!_current(generation)) return false;
      language=selected;
      _replyLanguage=selected;
      if (enabled && _connected && transportOwner=='worker' && _desiredListening && !recoveryRequired) {
        await _control('interrupt');
        if (!_current(generation)) return false;
        await _control('resume');
      }
      if (!_current(generation)) return false;
      notifyListeners();
      return _languagePreferences.language==selected;
    } finally {_appLanguageAction=false;}
  }

  void _selectedLanguageChanged() {
    if (_disposed) return;
    final selected = _languagePreferences!.language;
    if (_appLanguageAction) {language=selected;notifyListeners();return;}
    if (selected == language && !_languageRebindPending) return;
    if (!_languageRebindPending) {
      _languageRebindListening = _desiredListening;
      _languageRebindResume = enabled && state != 'manual';
      _languageRebindManual = state == 'manual';
    }
    final cleanup = enabled || _binding != null || _languageRebindPending;
    language = selected;
    if (!cleanup) {
      notifyListeners();
      return;
    }
    _languageRebindPending = true;
    final revision = ++_languageRevision;
    ++_generation;
    ++_speechGeneration;
    // Stop old-locale input immediately; cleanup/start are serialized below.
    unawaited(_microphone(false, VoiceLifecycleReason.languageChange).catchError((Object _) {}));
    final previousStartup = _startupDone?.future;
    final change = _languageQueue
        .then((_) async {
          await previousStartup;
          if (_disposed || revision != _languageRevision) return;
          await _endSession();
          if (_disposed ||
              revision != _languageRevision ||
              !foreground ||
              !authenticated()) {
            return;
          }
          if (!_languageRebindResume) {
            state = _languageRebindManual ? 'manual' : 'idle';
            notifyListeners();
            return;
          }
          if (recoveryCode == 'VOICE_CLEANUP_PENDING') {
            _recover('VOICE_CLEANUP_PENDING');
            return;
          }
          await _start(selected, initiallyListening: _languageRebindListening);
          if (!_disposed &&
              revision == _languageRevision &&
              enabled &&
              _binding != null) {
            if (kDebugMode) debugPrint('VOICE_LANGUAGE:SESSION_REBOUND');
          }
        })
        .catchError((Object _) {
          if (!_disposed && revision == _languageRevision) {
            _recover('VOICE_LANGUAGE_SYNC_FAILED');
          }
        });
    _languageQueue = change.whenComplete(() {
      if (revision == _languageRevision) {
        _languageRebindPending = false;
        notifyListeners();
      }
    });
  }

  Future<void> start(AppLanguage selected) async {
    if (_languageRebindPending || _startupDone != null) return;
    await _start(selected);
  }

  Future<void> _start(
    AppLanguage selected, {
    bool initiallyListening = true,
  }) async {
    await _ending;
    if (_disposed || _busy || enabled || !foreground || !authenticated()) return;
    final generation = ++_generation;
    final startup = Completer<void>();
    _startupDone = startup;
    _busy = true;
    enabled = true;
    _desiredListening = initiallyListening;
    _manualMuted = !initiallyListening;
    language = selected;
    state = 'connecting';
    recoveryRequired = false;
    notifyListeners();
    var created = false;
    try {
      if (_languagePreferences != null) {
        final ready = await _languagePreferences.prepareVoiceLanguage(selected);
        if (!_current(generation)) return;
        if (!ready) throw const VoiceFailure('VOICE_LANGUAGE_SYNC_FAILED');
      }
      await agent.initialize();
      if (!_current(generation)) return;
      var id = agent.sessionId;
      if (id == null) {
        if (_ensureAgentSession == null) {
          throw const VoiceFailure('AGENT_SESSION_REQUIRED');
        }
        id = await _ensureAgentSession();
        if (!_current(generation)) return;
        await agent.bindSession(id);
      }
      _startStage('AGENT_SESSION_READY');
      late Map<String, dynamic> value;
      try {
        _startStage('CREATE_REQUEST');
        value = await backend.create(id);
      } on VoiceFailure catch (error) {
        if (error.code != 'AGENT_SESSION_NOT_FOUND') rethrow;
        if (!_current(generation)) return;
        _startStage('STALE_AGENT_SESSION');
        final rejectedId = id;
        await agent.clearRejectedSession(rejectedId);
        if (!_current(generation)) return;
        id = agent.sessionId;
        if (id == null) {
          if (_ensureAgentSession == null) {
            throw const VoiceFailure('AGENT_SESSION_REQUIRED');
          }
          id = await _ensureAgentSession();
          if (!_current(generation)) return;
          if (id == rejectedId) {
            throw const VoiceFailure('AGENT_SESSION_NOT_FOUND');
          }
          await agent.bindSession(id);
          if (!_current(generation)) return;
        }
        _startStage('AGENT_SESSION_RECREATED');
        _startStage('CREATE_REQUEST');
        // Exactly one retry; a second rejection is never recursively recovered.
        try {
          value = await backend.create(id);
        } on VoiceFailure catch (retryError) {
          if (retryError.code == 'AGENT_SESSION_NOT_FOUND' &&
              _current(generation)) {
            await agent.clearRejectedSession(id);
          }
          rethrow;
        }
      }
      created = true;
      _startStage('CREATE_SUCCESS');
      if (!_current(generation)) {
        try {
          await backend.end(value['id']);
        } catch (_) {}
        return;
      }
      _bind(value);
      await transport.connect(value);
      if (!_current(generation)) return;
      _connected = true;
      if (_workerIdentity != null) await transport.bindWorker(_workerIdentity!);
      if (!_current(generation)) return;
      await _microphone(_desiredListening, VoiceLifecycleReason.start);
      if (!_current(generation)) return;
      state = _desiredListening ? 'listening' : 'muted';
      notifyListeners();
    } catch (error) {
      if (!created) _startStage('CREATE_FAILED');
      if (_current(generation)) {
        enabled = false;
        _desiredListening = false;
        _recover(
          error is VoiceFailure ? error.code : 'VOICE_CONNECTION_FAILED',
        );
        await _disconnect(VoiceLifecycleReason.start);
      }
    } finally {
      if (identical(_startupDone, startup)) _startupDone = null;
      startup.complete();
      if (generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _control(
    String type, {
    String? playbackId,
    String? turnId,
  }) async {
    if (_binding == null || transportOwner != 'worker') return;
    final controlGeneration=_generation;
    if (_workerIdentity == null) {
      final generation = _generation;
      final current = await backend.get(voiceSessionId!);
      if (!_current(generation) ||
          current['epoch'] != epoch ||
          !_validBinding(current)) {
        return;
      }
      _workerIdentity = current['workerIdentity'] as String?;
      if (_workerIdentity == null) {
        throw const VoiceFailure('VOICE_WORKER_NOT_READY');
      }
      await transport.bindWorker(_workerIdentity!);
    }
    if(!_current(controlGeneration))return;
    await transport.send({
      'v': 1,
      'type': type,
      'voiceSessionId': voiceSessionId,
      'epoch': epoch,
      'seq': ++_controlSeq,
      if (playbackId != null) 'playbackId': playbackId,
      if (turnId != null) 'turnId': turnId,
    });
  }

  Future<void> mute() async {
    final generation = _generation;
    if (_languageRebindPending) _languageRebindListening = false;
    ++_speechGeneration;
    _desiredListening = false;
    _manualMuted = true;
    _trace(VoiceLifecycleEvent.manualMuteChanged,VoiceLifecycleReason.userMute);
    state = 'muted';
    notifyListeners();
    try {
      await _control('mute');
    } catch (_) {}
    if (!_current(generation)) return;
    await _microphone(false, VoiceLifecycleReason.userMute);
    if (!_current(generation)) return;
    await device?.cancelListening();
    if (!_current(generation)) return;
    await device?.stopSpeaking();
  }

  Future<void> interrupt() async {
    if (!activeForeground) return;
    final generation = _generation;
    ++_speechGeneration;
    try {
      await _control('interrupt');
    } catch (_) {
      if (!_current(generation)) return;
      _recover('VOICE_CONTROL_UNAVAILABLE');
    }
    if (!_current(generation)) return;
    await device?.stopSpeaking();
    if (!_current(generation)) return;
    _playbackId = null;
    if (_desiredListening && !recoveryRequired) await resume();
  }

  Future<void> stopPlayback() async {
    final generation = _generation;
    await mute();
    if (!_current(generation)) return;
    try {
      await _control('stop');
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_languageRebindPending ||
        !foreground ||
        !authenticated() ||
        recoveryRequired ||
        _busy ||
        _binding == null) {
      return;
    }
    enabled = true;
    _desiredListening = true;
    _manualMuted = false;
    _trace(VoiceLifecycleEvent.manualMuteChanged,VoiceLifecycleReason.userResume);
    // Explicit resume skips an offered fallback; never leave an older reply playable.
    _pendingDeviceTts = null;
    final generation = _generation;
    try {
      if (transportOwner == 'manual') {
        if (!await _transfer('worker')) return;
        if (!activeForeground) return;
        final value = await backend.token(voiceSessionId!);
        if (!_current(generation) || !_desiredListening) return;
        _bind(value);
        await transport.connect(value);
        if (!_current(generation)) return;
        _connected = true;
        if (_workerIdentity != null) {
          await transport.bindWorker(_workerIdentity!);
        }
      }
      if (transportOwner == 'worker') {
        if (!_connected) {
          final current = await backend.get(voiceSessionId!);
          if (!_current(generation) ||
              current['id'] != voiceSessionId ||
              current['epoch'] != epoch ||
              !_validBinding(current)) {
            return;
          }
          _inflight ??= current['activeTurnId'] as String?;
          if (!await reconcile()) return;
          final value = await backend.token(voiceSessionId!);
          if (!_current(generation) ||
              !_desiredListening ||
              value['id'] != voiceSessionId ||
              value['epoch'] != epoch) {
            return;
          }
          _bind(value);
          await transport.connect(value);
          if (!_current(generation)) return;
          _connected = true;
          if (_workerIdentity != null) {
            await transport.bindWorker(_workerIdentity!);
          }
        }
        if (!_current(generation) || !_desiredListening) return;
        await _microphone(true, VoiceLifecycleReason.userResume);
        // Obsolete work must not clean up the transport now owned by a newer
        // session. The RTC transport already fences/cleans its captured Room.
        if (!_current(generation)) return;
        if (!_desiredListening) {
          await _microphone(false, VoiceLifecycleReason.userResume);
          return;
        }
        await _control('resume');
      } else if (transportOwner == 'device') {
        await _listenDevice();
      }
      if (!_current(generation) || !_desiredListening) return;
      state = 'listening';
      notifyListeners();
    } catch (error) {
      if(!_current(generation))return;
      _desiredListening = false;
      await _microphone(false, VoiceLifecycleReason.userResume);
      if (!_current(generation)) return;
      _recover(error is VoiceFailure ? error.code : 'VOICE_RESUME_FAILED');
    }
  }

  void _enqueue(VoicePacket packet) {
    final generation = _generation;
    _eventQueue = _eventQueue
        .then((_) async {
          if (_current(generation) && enabled) await _event(packet, generation);
        })
        .catchError((Object error) {
          if (_current(generation)) {
            recoveryRequired = true;
            _recover('VOICE_EVENT_RECOVERY_REQUIRED', failureCode:
                error is VoiceFailure ? error.code :
                error is FormatException ? 'VOICE_RESULT_INVALID' : 'VOICE_EVENT_FAILED',
                reason: VoiceLifecycleReason.eventRecovery);
            // Protocol/transport recovery is not a user mute request.
            unawaited(_gateEventFailure(generation));
          }
        });
  }

  Future<void> _gateEventFailure(int generation) async {
    if(!_current(generation))return;
    await _microphone(false,VoiceLifecycleReason.eventRecovery);
    if(!_current(generation))return;
    try {await _control('mute');} catch (_) {}
  }

  Future<void> _event(VoicePacket packet, int generation) async {
    final value = packet.value;
    if (packet.topic != 'sehatmate.voice.v1' ||
        value['v'] != 1 ||
        value['voiceSessionId'] != voiceSessionId ||
        value['epoch'] != epoch ||
        value['seq'] is! int ||
        value['seq'] <= _eventSeq ||
        transportOwner != 'worker') {
      return;
    }
    if (_workerIdentity == null) {
      final binding = await backend.get(voiceSessionId!);
      if (!_current(generation) || binding['epoch'] != epoch) return;
      _workerIdentity = binding['workerIdentity'] as String?;
      if (_workerIdentity != null) await transport.bindWorker(_workerIdentity!);
    }
    if (_workerIdentity == null || packet.sender != _workerIdentity) return;
    if(!_current(generation))return;
    _eventSeq = value['seq'];
    final turn = value['turnId'] as String?;
    switch (value['type']) {
      case 'ready':
        if (_desiredListening) {
          await _microphone(true, VoiceLifecycleReason.workerRecovery);
          if(!_current(generation))return;
          await _control('resume');
          if(!_current(generation))return;
          state = 'listening';
        }
        break;
      case 'transcript_interim':
        interimTranscript = value['text']?.toString() ?? '';
        break;
      case 'transcript_final':
        if (turn == null) return;
        finalTranscript = value['text']?.toString() ?? '';
        _finalTranscriptTurn = turn;
        _romanFinalTranscript = null;
        _finalPresentationComplete = false;
        interimTranscript = '';
        _transcripts[turn] = finalTranscript;
        if (_transcripts.length > 100) {
          _transcripts.remove(_transcripts.keys.first);
        }
        break;
      case 'processing':
        if (turn == null) return;
        _inflight = turn;
        state = 'processing';
        _watchProcessing(turn, generation);
        break;
      case 'agent_result':
        if (turn == null) return;
        traceVoiceTurn(VoiceTurnStage.uiEventReceived, turn);
        if (value['resultViaUserApi'] == true) {
          final receipt = await backend.receipt(voiceSessionId!, turn);
          await _receipt(receipt, generation);
        } else if (value['result'] is Map<String, dynamic>) {
          await _accept(turn, value['result'], generation);
        }
        break;
      case 'speaking':
        if (!_desiredListening) {
          await _control('interrupt');
          return;
        }
        _playbackId = value['playbackId'] as String?;
        state = 'speaking';
        // The SDK echo canceller keeps output out of recognition while the
        // user's microphone remains available for natural VAD interruption.
        break;
      case 'playback_complete':
        if (_playbackId == null || value['playbackId'] != _playbackId) return;
        _playbackId = null;
        if (_desiredListening && !recoveryRequired) {
          await _microphone(true, VoiceLifecycleReason.workerRecovery);
          if(!_current(generation))return;
          await _control('resume');
          if(!_current(generation))return;
          state = 'listening';
        }
        break;
      case 'interrupted':
        _playbackId = null;
        // Interrupting the old review prompt does not finish its new decision.
        if (_desiredListening && _inflight == null) state = 'listening';
        break;
      case 'awaiting_confirmation':
        state = 'awaiting_confirmation';
        break;
      case 'awaiting_clarification':
        state = 'awaiting_clarification';
        break;
      case 'fallback_required':
        final offeredPlayback = value['deviceTts'] is Map
            ? value['deviceTts']['playbackId']
            : null;
        if (offeredPlayback is String &&
            _devicePlaybacks.contains(offeredPlayback)) {
          return;
        }
        _recover(value['code']?.toString() ?? 'VOICE_FALLBACK_REQUIRED',
            reason: VoiceLifecycleReason.workerRecovery);
        if (value['component'] == 'stt') {
          await _microphone(false, VoiceLifecycleReason.workerRecovery);
          if(!_current(generation))return;
          if (deviceSpeechEnabled) await useDeviceSpeech();
        } else if (value['component'] == 'tts') {
          final tts = value['deviceTts'];
          if (tts is Map<String, dynamic>) {
            _pendingDeviceTts = {...tts, if (turn != null) 'turnId': turn};
            if (deviceTtsEnabled) await speakDeviceFallback();
          }
        } else {
          recoveryRequired = true;
          _desiredListening = false;
          await _microphone(false, VoiceLifecycleReason.workerRecovery);
        }
        break;
      case 'recovering':
        await _microphone(false, VoiceLifecycleReason.workerRecovery);
        if(!_current(generation))return;
        _recover(value['code']?.toString() ?? 'VOICE_RECOVERING',
            reason: VoiceLifecycleReason.workerRecovery);
        break;
      case 'disconnected':
        await _microphone(false, VoiceLifecycleReason.workerRecovery);
        if(!_current(generation))return;
        enabled = false;
        _desiredListening = false;
        state = 'disconnected';
        break;
      default:
        return;
    }
    if (_current(generation)) notifyListeners();
  }

  Future<void> _accept(
    String turn,
    Map<String, dynamic> raw,
    int generation,
  ) async {
    if (!_current(generation) || _completed.contains(turn)) return;
    final response = AgentResponse.fromJson({'success': true, ...raw});
    if (response.sessionId != agent.sessionId) {
      throw const VoiceFailure('VOICE_AGENT_SESSION_MISMATCH');
    }
    _completed.add(turn);
    if (_completed.length > 100) _completed.remove(_completed.first);
    if (_inflight == turn) {
      _inflight = null;
      recoveryRequired = false;
      _processingWatchdog?.cancel();
    }
    reply = response.reply;
    _replyTurn = turn;
    _replyLanguage = AppLanguageX.fromStorage(raw['language'] as String?);
    // The owned Agent result supplies effective conversation language. UI/profile
    // selection stays independent; this does not reconnect the LiveKit room.
    language = _replyLanguage;
    final rawTranscript = _transcripts.remove(turn);
    final displayTranscript = rawTranscript == null ? null : transcriptForDisplay(rawTranscript, language,
      rendering: response.language == 'roman_ur' ? response.displayTranscript : null, complete: true);
    if (turn == _finalTranscriptTurn && rawTranscript != null) {
      _romanFinalTranscript = response.language == 'roman_ur' ? validatedRomanTranscript(rawTranscript, response.displayTranscript) : null;
      _finalPresentationComplete = true;
    }
    // Publish the authoritative reply before an awaited Copilot navigation or
    // decision UI. Text delivery never waits for action completion or TTS.
    if (state == 'processing' &&
        _inflight == null &&
        !recoveryRequired &&
        _connected) {
      state = !_desiredListening
          ? 'muted'
          : response.confirmation != null
          ? 'awaiting_confirmation'
          : response.clarification != null
          ? 'awaiting_clarification'
          : 'listening';
    }
    notifyListeners();
    traceVoiceTurn(VoiceTurnStage.uiTextReady, turn);
    await agent.acceptVoiceResult(
      response,
      transcript: rawTranscript,
      transcriptDisplayText: displayTranscript,
    );
    if (_current(generation)) {
      onResult?.call(response);
      notifyListeners();
    }
  }

  Future<bool> _receipt(
    Map<String, dynamic> receipt,
    int generation, {
    String? submittedConfirmationTurn,
  }) async {
    if (!_current(generation) || receipt['epoch'] != epoch) return false;
    if (receipt['status'] == 'completed' &&
        receipt['result'] is Map<String, dynamic>) {
      final resolvesCurrent =
          receipt['turnId'] == _inflight ||
          (submittedConfirmationTurn != null &&
              _inflight == submittedConfirmationTurn);
      await _accept(receipt['turnId'], receipt['result'], generation);
      if (_current(generation) && resolvesCurrent) recoveryRequired = false;
      // The backend may return the original receipt for an already consumed
      // confirmation. That receipt is authoritative for this submission.
      if (_current(generation) &&
          _inflight == submittedConfirmationTurn &&
          submittedConfirmationTurn != null) {
        _inflight = null;
        _transcripts.remove(submittedConfirmationTurn);
      }
      return true;
    }
    if (receipt['status'] != 'processing') {
      recoveryRequired = true;
      _recover('VOICE_${receipt['status'].toString().toUpperCase()}');
    }
    return false;
  }

  Future<bool> reconcile() async {
    final turn = _inflight, generation = _generation;
    if (turn == null) return !recoveryRequired;
    try {
      for (var attempt = 0; attempt < 12; attempt++) {
        if (!_current(generation)) return false;
        final receipt = await backend.receipt(voiceSessionId!, turn);
        if (await _receipt(receipt, generation)) return true;
        if (recoveryRequired) return false;
        await _delay(const Duration(seconds: 2));
      }
    } catch (_) {}
    if (!_current(generation)) return false;
    recoveryRequired = true;
    _recover('VOICE_TURN_UNCERTAIN');
    return false;
  }

  Future<bool> _transfer(String mode) async {
    if (_binding == null) return false;
    final generation = _generation, id = voiceSessionId!, oldEpoch = epoch!;
    await _microphone(false, VoiceLifecycleReason.transfer);
    if (!_current(generation)) return false;
    await device?.cancelListening();
    if (!_current(generation)) return false;
    final current = await backend.get(id);
    if (!_current(generation) ||
        current['epoch'] != oldEpoch ||
        !_validBinding(current)) {
      return false;
    }
    _inflight ??= current['activeTurnId'] as String?;
    if (!await reconcile()) return false;
    if(!_current(generation))return false;
    final value = await backend.transfer(id, oldEpoch, mode);
    if (!_current(generation)) return false;
    _bind(value);
    await _disconnect(VoiceLifecycleReason.transfer);
    if (!_current(generation)) return false;
    _connected = false;
    return true;
  }

  Future<void> manual({VoiceLifecycleReason reason=VoiceLifecycleReason.transfer}) async {
    _trace(VoiceLifecycleEvent.disconnectRequested,reason);
    if (_languageRebindPending) {
      await end();
      state = 'manual';
      notifyListeners();
      return;
    }
    final generation = _generation;
    ++_speechGeneration;
    _desiredListening = false;
    await device?.cancelListening();
    if (!_current(generation)) return;
    await device?.stopSpeaking();
    if (!_current(generation)) return;
    try {
      await _control('manual');
      if (!_current(generation)) return;
      if (await _transfer('manual') && _current(generation)) state = 'manual';
    } catch (error) {
      if (!_current(generation)) return;
      _recover(
        error is VoiceFailure ? error.code : 'VOICE_HANDOFF_UNAVAILABLE',
      );
    }
    notifyListeners();
  }

  Future<void> useDeviceSpeech() async {
    if (!activeForeground || device == null) return;
    deviceSpeechEnabled = true;
    try {
      if (transportOwner != 'device' && !await _transfer('device')) return;
      await _listenDevice();
    } catch (_) {
      _desiredListening = false;
      _recover('DEVICE_STT_UNAVAILABLE');
    }
    notifyListeners();
  }

  Future<void> _listenDevice() async {
    if (!_desiredListening ||
        !activeForeground ||
        transportOwner != 'device' ||
        device == null) {
      return;
    }
    if (!await device!.initializeSpeech(language)) {
      throw const VoiceFailure('DEVICE_STT_UNAVAILABLE');
    }
    state = 'listening';
    final generation = _generation;
    await device!.startListening(
      language: language,
      onListeningComplete: () => unawaited(_deviceFinal(generation)),
    );
  }

  Future<void> _deviceFinal(int generation) async {
    if (!_current(generation) ||
        !_desiredListening ||
        _deviceFinishing ||
        _inflight != null) {
      return;
    }
    _deviceFinishing = true;
    try {
      final transcript = await device!.stopListening();
      if (!_current(generation) || !_desiredListening) return;
      final text = transcript.text.trim();
      if (text.isNotEmpty) {
        finalTranscript = text;
        await submitManual(text);
      }
    } catch (_) {
      _recover('DEVICE_STT_NO_FINAL_TRANSCRIPT');
      _desiredListening = false;
    } finally {
      _deviceFinishing = false;
      if (_current(generation) &&
          _desiredListening &&
          !recoveryRequired &&
          _inflight == null) {
        await _listenDevice();
      }
    }
  }

  String _turnId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Future<AgentResponse?> submitManual(
    String text, {
    Map<String, dynamic>? confirmation,
    Map<String, dynamic>? clarification,
  }) async {
    if (_binding == null ||
        _busy ||
        _inflight != null ||
        recoveryRequired ||
        !authenticated()) {
      return null;
    }
    final generation = _generation, id = _turnId();
    var playbackTurn = id;
    _inflight = id;
    ++_speechGeneration;
    await device?.stopSpeaking();
    if (!_current(generation)) return null;
    _transcripts[id] = text;
    if (finalTranscript == text) {
      _finalTranscriptTurn = id;
      _romanFinalTranscript = null;
      _finalPresentationComplete = false;
    }
    state = 'processing';
    notifyListeners();
    final liveConfirmation = confirmation != null && transportOwner == 'worker';
    if (!liveConfirmation) {
      await _microphone(false, VoiceLifecycleReason.processing);
      if (!_current(generation)) return null;
      await device?.cancelListening();
      if (!_current(generation)) return null;
    }
    try {
      // Resolving a review interrupts its prompt, but is not a user mute.
      await _control(liveConfirmation ? 'interrupt' : 'mute');
    } catch (_) {}
    if (!_current(generation)) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final receipt = await backend.submit(voiceSessionId!, {
        'epoch': epoch,
        'turnId': id,
        'today': today,
        if (confirmation != null) 'confirmation': confirmation,
        if (clarification != null) 'clarification': clarification,
        if (confirmation == null && clarification == null) 'message': text,
      });
      if (await _receipt(
        receipt,
        generation,
        submittedConfirmationTurn: confirmation != null ? id : null,
      )) {
        playbackTurn = receipt['turnId'];
      } else if (_current(generation)) {
        await reconcile();
      }
    } catch (_) {
      if (!_current(generation)) return null;
      await reconcile();
    }
    if (_current(generation) && !recoveryRequired && _inflight == null) {
      state = !_desiredListening ? 'muted' : agent.pendingConfirmation != null
          ? 'awaiting_confirmation' : agent.pendingClarification != null
          ? 'awaiting_clarification' : 'listening';
      if (transportOwner == 'device' && deviceTtsEnabled) {
        await device!.speak(reply, language: _replyLanguage);
      }
      if (_desiredListening && transportOwner == 'worker') {
        if (!liveConfirmation) await _microphone(true, VoiceLifecycleReason.processing);
        if (!_current(generation) || !_desiredListening) return null;
        await _control('resume');
        if (!_current(generation) || !_desiredListening) return null;
        await _control('receipt_ready', turnId: playbackTurn);
      }
      notifyListeners();
    }
    return null;
  }

  Future<void> confirm(String id, bool decision) async {
    if (agent.pendingConfirmation?.confirmationId != id) return;
    await submitManual(
      '',
      confirmation: {
        'confirmationId': id,
        'decision': decision ? 'confirm' : 'cancel',
      },
    );
  }

  Future<void> clarify(String id, String choice) async {
    if (agent.pendingClarification?.clarificationId != id) return;
    await submitManual(
      '',
      clarification: {'clarificationId': id, 'choiceId': choice},
    );
  }

  Future<void> speakDeviceFallback() async {
    final offer = _pendingDeviceTts, generation = _generation;
    if (offer == null || device == null || !activeForeground) return;
    final playback = offer['playbackId'];
    if (playback is! String ||
        playback.isEmpty ||
        !_devicePlaybacks.add(playback)) {
      return;
    }
    if (_devicePlaybacks.length > 100) {
      _devicePlaybacks.remove(_devicePlaybacks.first);
    }
    _pendingDeviceTts = null;
    final speechGeneration = ++_speechGeneration;
    deviceTtsEnabled = true;
    await _microphone(false, VoiceLifecycleReason.playback);
    await device!.cancelListening();
    try {
      var text = offer['text'] as String?;
      var spokenLanguage = _replyLanguage;
      if (text == null &&
          offer['textViaUserApi'] == true &&
          offer['turnId'] is String) {
        final receipt = await backend.receipt(voiceSessionId!, offer['turnId']);
        if (receipt['epoch'] != epoch || receipt['status'] != 'completed') {
          throw const VoiceFailure('VOICE_STALE_RECEIPT');
        }
        text = receipt['result']?['reply'] as String?;
        spokenLanguage = AppLanguageX.fromStorage(
          receipt['result']?['language'] as String?,
        );
        final offset = offer['textStartOffset'];
        if (offset != null &&
            (offset is! int ||
                offset < 0 ||
                text == null ||
                offset > text.length)) {
          throw const VoiceFailure('VOICE_INVALID_SPEECH_OFFSET');
        }
        if (text != null && offset is int) text = text.substring(offset);
      }
      if (!_current(generation) ||
          speechGeneration != _speechGeneration ||
          text == null) {
        return;
      }
      state = 'speaking';
      notifyListeners();
      await device!.speak(text, language: spokenLanguage);
      if (!_current(generation) ||
          speechGeneration != _speechGeneration ||
          !_desiredListening) {
        return;
      }
      _pendingDeviceTts = null;
      await _microphone(true, VoiceLifecycleReason.playback);
      await _control('playback_complete', playbackId: offer['playbackId']);
      state = 'listening';
      notifyListeners();
    } catch (_) {
      _recover('DEVICE_TTS_UNAVAILABLE');
    }
  }

  Future<void> _connection(VoiceConnection connection) async {
    if (!enabled || transportOwner != 'worker') return;
    final connectionGeneration=_generation, connectionId=voiceSessionId, connectionEpoch=epoch;
    bool ownsConnection() => _current(connectionGeneration) &&
        voiceSessionId==connectionId && epoch==connectionEpoch && transportOwner=='worker';
    if (!ownsConnection()) return;
    _connected =
        connection == VoiceConnection.connected ||
        connection == VoiceConnection.reconnected;
    if (connection == VoiceConnection.reconnecting) {
      await _microphone(false, VoiceLifecycleReason.reconnecting);
      if(!ownsConnection())return;
      _recover('LIVEKIT_RECONNECTING', reason: VoiceLifecycleReason.reconnecting);
      _reconnectTimeout?.cancel();
      final generation=_generation, bindingId=voiceSessionId, bindingEpoch=epoch;
      _reconnectTimeout = Timer(
        const Duration(seconds: 20),
        () {
          if(_current(generation)&&enabled&&!_connected&&voiceSessionId==bindingId&&epoch==bindingEpoch) {
            unawaited(manual(reason:VoiceLifecycleReason.reconnectTimeout));
          }
        },
      );
    }
    if (connection == VoiceConnection.reconnected) {
      _reconnectTimeout?.cancel();
      try {
        final value = await backend.get(voiceSessionId!);
        if (!ownsConnection()) return;
        if (value['id'] != connectionId || value['epoch'] != connectionEpoch ||
            !_validBinding(value)) {
          await end(reason:VoiceLifecycleReason.workerTerminal);
          return;
        }
        _binding = value;
        _workerIdentity = value['workerIdentity'] as String?;
        _inflight ??= value['activeTurnId'] as String?;
        if (!await reconcile() || !ownsConnection()) return;
        if (_workerIdentity != null) {
          await transport.bindWorker(_workerIdentity!);
        }
        if (!ownsConnection()) return;
        if (_desiredListening) await resume();
      } catch (_) {
        if (ownsConnection()) {
          _recover('VOICE_RECONNECT_AUTHORIZATION_FAILED',
              reason: VoiceLifecycleReason.reconnected);
        }
      }
    }
    if (connection == VoiceConnection.disconnected) {
      await _microphone(false, VoiceLifecycleReason.reconnecting);
      if(!ownsConnection())return;
      _recover('LIVEKIT_DISCONNECTED', reason: VoiceLifecycleReason.transportLost);
    }
  }

  Future<void> background() async {
    foreground = false;
    await end(reason:VoiceLifecycleReason.background);
  }

  Future<void> lifecycle(AppLifecycleState lifecycle) async {
    traceVoiceLifecycle(VoiceLifecycleEvent.sessionState,VoiceLifecycleReason.lifecycle,
        generation:_generation,state:lifecycle.name,manualMuted:_manualMuted,micEnabled:_micRequested);
    if (lifecycle == AppLifecycleState.resumed) {
      foregroundAgain();
    } else if (lifecycle != AppLifecycleState.inactive) {
      // Android permission dialogs temporarily lose focus while still visible.
      // Hidden/paused/detached states still terminate foreground-only audio.
      await background();
    }
  }

  void foregroundAgain() {
    foreground = true;
    notifyListeners();
  }

  Future<void> end({VoiceLifecycleReason reason=VoiceLifecycleReason.userEnd}) {
    ++_languageRevision;
    _languageRebindPending = false;
    _trace(VoiceLifecycleEvent.disconnectRequested,reason);
    return _endSession(reason:reason);
  }

  Future<void> _endSession({VoiceLifecycleReason reason=VoiceLifecycleReason.languageChange}) {
    if(_ending!=null)return _ending!;
    late final Future<void> ending;
    ending=_performEndSession(reason).whenComplete(() {
      if(identical(_ending,ending))_ending=null;
    });
    _ending=ending;
    return ending;
  }

  Future<void> _performEndSession(VoiceLifecycleReason reason) async {
    _trace(VoiceLifecycleEvent.disconnectStarted,reason);
    ++_generation;
    ++_speechGeneration;
    enabled = false;
    _connected = false;
    _desiredListening = false;
    _busy = false;
    _expiry?.cancel();
    _reconnectTimeout?.cancel();
    _processingWatchdog?.cancel();
    final id = voiceSessionId;
    _binding = null;
    _inflight = null;
    _transcripts.clear();
    _finalTranscriptTurn = null;
    _romanFinalTranscript = null;
    _finalPresentationComplete = false;
    _completed.clear();
    _devicePlaybacks.clear();
    _workerIdentity = null;
    _pendingDeviceTts = null;
    _playbackId = null;
    state = 'idle';
    interimTranscript = '';
    notifyListeners();
    try {
      await _microphone(false, reason);
    } catch (_) {}
    try {
      await device?.cancelListening();
      await device?.stopSpeaking();
    } catch (_) {}
    try {
      await _disconnect(reason);
    } catch (_) {}
    if (id != null) {
      try {
        await backend.end(id);
      } catch (_) {
        recoveryCode = 'VOICE_CLEANUP_PENDING';
      }
    }
    _trace(VoiceLifecycleEvent.disconnectCompleted,reason);
  }

  @override
  void dispose() {
    _trace(VoiceLifecycleEvent.controllerDisposed,VoiceLifecycleReason.dispose);
    _disposed = true;
    ++_languageRevision;
    _languagePreferences?.removeListener(_selectedLanguageChanged);
    ++_generation;
    _expiry?.cancel();
    _reconnectTimeout?.cancel();
    _processingWatchdog?.cancel();
    unawaited(_events.cancel());
    unawaited(_connections.cancel());
    super.dispose();
  }
}

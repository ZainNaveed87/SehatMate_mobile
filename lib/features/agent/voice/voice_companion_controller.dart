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
      _desiredListening = false,
      _busy = false,
      _connected = false,
      _deviceFinishing = false;
  Future<void> _eventQueue = Future<void>.value();
  Future<void> _languageQueue = Future<void>.value();
  Completer<void>? _startupDone;
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
  bool get muted => !_desiredListening;
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
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _recover(String code) {
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
    _expiry = Timer(
      DateTime.parse(value['expiresAt']).difference(DateTime.now()),
      () => unawaited(end()),
    );
  }

  void _selectedLanguageChanged() {
    if (_disposed) return;
    final selected = _languagePreferences!.language;
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
    unawaited(transport.microphone(false).catchError((Object _) {}));
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
    if (_busy || enabled || !foreground || !authenticated()) return;
    final generation = ++_generation;
    final startup = Completer<void>();
    _startupDone = startup;
    _busy = true;
    enabled = true;
    _desiredListening = initiallyListening;
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
      _connected = true;
      if (_workerIdentity != null) await transport.bindWorker(_workerIdentity!);
      if (!_current(generation)) {
        await transport.disconnect();
        return;
      }
      await transport.microphone(_desiredListening);
      if (!_current(generation)) {
        await transport.microphone(false);
        return;
      }
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
        await transport.disconnect();
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
    if (_languageRebindPending) _languageRebindListening = false;
    ++_speechGeneration;
    _desiredListening = false;
    state = 'muted';
    notifyListeners();
    try {
      await _control('mute');
    } catch (_) {}
    await transport.microphone(false);
    await device?.cancelListening();
    await device?.stopSpeaking();
  }

  Future<void> interrupt() async {
    if (!activeForeground) return;
    ++_speechGeneration;
    try {
      await _control('interrupt');
    } catch (_) {
      _recover('VOICE_CONTROL_UNAVAILABLE');
    }
    await device?.stopSpeaking();
    _playbackId = null;
    if (_desiredListening && !recoveryRequired) await resume();
  }

  Future<void> stopPlayback() async {
    await mute();
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
        if (!_current(generation)) {
          await transport.disconnect();
          return;
        }
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
          if (!_current(generation)) {
            await transport.disconnect();
            return;
          }
          _connected = true;
          if (_workerIdentity != null) {
            await transport.bindWorker(_workerIdentity!);
          }
        }
        if (!_current(generation) || !_desiredListening) return;
        await transport.microphone(true);
        if (!_current(generation) || !_desiredListening) {
          await transport.microphone(false);
          return;
        }
        await _control('resume');
      } else if (transportOwner == 'device') {
        await _listenDevice();
      }
      state = 'listening';
      notifyListeners();
    } catch (error) {
      _desiredListening = false;
      await transport.microphone(false);
      _recover(error is VoiceFailure ? error.code : 'VOICE_RESUME_FAILED');
    }
  }

  void _enqueue(VoicePacket packet) {
    final generation = _generation;
    _eventQueue = _eventQueue
        .then((_) async {
          if (_current(generation) && enabled) await _event(packet, generation);
        })
        .catchError((Object _) {
          if (_current(generation)) {
            recoveryRequired = true;
            _recover('VOICE_EVENT_RECOVERY_REQUIRED');
            unawaited(mute());
          }
        });
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
    _eventSeq = value['seq'];
    final turn = value['turnId'] as String?;
    switch (value['type']) {
      case 'ready':
        if (_desiredListening) {
          await transport.microphone(true);
          await _control('resume');
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
          await transport.microphone(true);
          await _control('resume');
          state = 'listening';
        }
        break;
      case 'interrupted':
        _playbackId = null;
        if (_desiredListening) state = 'listening';
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
        _recover(value['code']?.toString() ?? 'VOICE_FALLBACK_REQUIRED');
        if (value['component'] == 'stt') {
          await transport.microphone(false);
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
          await transport.microphone(false);
        }
        break;
      case 'recovering':
        await transport.microphone(false);
        _recover(value['code']?.toString() ?? 'VOICE_RECOVERING');
        break;
      case 'disconnected':
        await transport.microphone(false);
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
    _replyLanguage = AppLanguageX.fromStorage(raw['language'] as String?);
    final rawTranscript = _transcripts.remove(turn);
    final displayTranscript = rawTranscript == null ? null : transcriptForDisplay(rawTranscript, language,
      rendering: response.language == 'roman_ur' ? response.displayTranscript : null, complete: true);
    if (turn == _finalTranscriptTurn && rawTranscript != null) {
      _romanFinalTranscript = response.language == 'roman_ur' ? validatedRomanTranscript(rawTranscript, response.displayTranscript) : null;
      _finalPresentationComplete = true;
    }
    await agent.acceptVoiceResult(
      response,
      transcript: rawTranscript,
      transcriptDisplayText: displayTranscript,
    );
    if (_current(generation)) {
      // Completion is authoritative even when no later speech event arrives.
      // Do not override a newer turn, user mute, playback or transport recovery.
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
    recoveryRequired = true;
    _recover('VOICE_TURN_UNCERTAIN');
    return false;
  }

  Future<bool> _transfer(String mode) async {
    if (_binding == null) return false;
    await transport.microphone(false);
    await device?.cancelListening();
    final generation = _generation, id = voiceSessionId!, oldEpoch = epoch!;
    final current = await backend.get(id);
    if (!_current(generation) ||
        current['epoch'] != oldEpoch ||
        !_validBinding(current)) {
      return false;
    }
    _inflight ??= current['activeTurnId'] as String?;
    if (!await reconcile()) return false;
    final value = await backend.transfer(id, oldEpoch, mode);
    if (!_current(generation)) return false;
    _bind(value);
    await transport.disconnect();
    _connected = false;
    return true;
  }

  Future<void> manual() async {
    if (_languageRebindPending) {
      await end();
      state = 'manual';
      notifyListeners();
      return;
    }
    ++_speechGeneration;
    _desiredListening = false;
    await device?.cancelListening();
    await device?.stopSpeaking();
    try {
      await _control('manual');
      if (await _transfer('manual')) state = 'manual';
    } catch (error) {
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
    await transport.microphone(false);
    await device?.cancelListening();
    if (!_current(generation)) return null;
    try {
      await _control('mute');
    } catch (_) {}
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
      } else {
        await reconcile();
      }
    } catch (_) {
      await reconcile();
    }
    if (_current(generation) && !recoveryRequired && _inflight == null) {
      state = 'listening';
      if (transportOwner == 'device' && deviceTtsEnabled) {
        await device!.speak(reply, language: _replyLanguage);
      }
      if (_desiredListening && transportOwner == 'worker') {
        await transport.microphone(true);
        await _control('resume');
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
    await transport.microphone(false);
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
      await transport.microphone(true);
      await _control('playback_complete', playbackId: offer['playbackId']);
      state = 'listening';
      notifyListeners();
    } catch (_) {
      _recover('DEVICE_TTS_UNAVAILABLE');
    }
  }

  Future<void> _connection(VoiceConnection connection) async {
    if (!enabled || transportOwner != 'worker') return;
    _connected =
        connection == VoiceConnection.connected ||
        connection == VoiceConnection.reconnected;
    if (connection == VoiceConnection.reconnecting) {
      await transport.microphone(false);
      _recover('LIVEKIT_RECONNECTING');
      _reconnectTimeout?.cancel();
      _reconnectTimeout = Timer(
        const Duration(seconds: 20),
        () => unawaited(manual()),
      );
    }
    if (connection == VoiceConnection.reconnected) {
      _reconnectTimeout?.cancel();
      final generation = _generation;
      try {
        final value = await backend.get(voiceSessionId!);
        if (!_current(generation) ||
            value['epoch'] != epoch ||
            !_validBinding(value)) {
          await end();
          return;
        }
        _binding = value;
        _workerIdentity = value['workerIdentity'] as String?;
        _inflight ??= value['activeTurnId'] as String?;
        if (!await reconcile() || !_current(generation)) return;
        if (_workerIdentity != null) {
          await transport.bindWorker(_workerIdentity!);
        }
        if (_desiredListening) await resume();
      } catch (_) {
        _recover('VOICE_RECONNECT_AUTHORIZATION_FAILED');
      }
    }
    if (connection == VoiceConnection.disconnected) {
      await transport.microphone(false);
      _recover('LIVEKIT_DISCONNECTED');
    }
  }

  Future<void> background() async {
    foreground = false;
    await end();
  }

  Future<void> lifecycle(AppLifecycleState lifecycle) async {
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

  Future<void> end() {
    ++_languageRevision;
    _languageRebindPending = false;
    return _endSession();
  }

  Future<void> _endSession() async {
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
      await transport.microphone(false);
    } catch (_) {}
    try {
      await device?.cancelListening();
      await device?.stopSpeaking();
    } catch (_) {}
    try {
      await transport.disconnect();
    } catch (_) {}
    if (id != null) {
      try {
        await backend.end(id);
      } catch (_) {
        recoveryCode = 'VOICE_CLEANUP_PENDING';
      }
    }
  }

  @override
  void dispose() {
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

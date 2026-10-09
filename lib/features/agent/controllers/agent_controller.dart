import '../copilot/copilot_conflict.dart';
import '../copilot/copilot_diagnostics.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agent_context.dart';
import '../models/agent_message.dart';
import '../models/agent_request.dart';
import '../models/agent_response.dart';
import '../models/agent_task_workflow.dart';
import '../services/agent_service.dart';
import '../services/agent_session_store.dart';

abstract interface class AgentClient {
  Future<AgentResponse> send(AgentRequest request);
}

class AgentServiceClient implements AgentClient {
  const AgentServiceClient(this.service);

  final AgentService service;

  @override
  Future<AgentResponse> send(AgentRequest request) => service.send(request);
}

enum AgentRequestProgress {
  idle,
  restoringSession,
  awaitingResponse,
  applyingResponse,
}

class AgentController extends ChangeNotifier {
  AgentController({
    required AgentClient client,
    AgentSessionStore sessionStore = const AgentSessionStore(),
    this.context,
    this.contextProvider,
    this.onCopilotResult,
    this.prepareLanguage,
  }) : _client = client,
       _sessionStore = sessionStore;

  static const maxMessages = 80;

  final AgentClient _client;
  final AgentSessionStore _sessionStore;
  final AgentScreenContext? context;
  final AgentScreenContext? Function()? contextProvider;
  final Future<void> Function(AgentResponse, String)? onCopilotResult;
  final Future<bool> Function()? prepareLanguage;

  final List<AgentChatMessage> _messages = [];

  String? _sessionId;
  AgentTaskWorkflow? taskWorkflow;
  List<CopilotConflict> conflicts = const [];
  String? _lastFailedText;
  bool _loading = false;
  AgentRequestProgress _requestProgress = AgentRequestProgress.awaitingResponse;
  bool _initializing = false;
  bool _confirmationLoading = false;
  bool _clarificationLoading = false;
  bool _initialized = false;
  AgentException? _error;
  AgentConfirmation? _pendingConfirmation;
  AgentClarification? _pendingClarification;
  String? _pendingClarificationMessage;
  Future<void>? _initializationFuture;
  int _idSeed = 0;
  bool _disposed = false;
  int _generation = 0;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    taskWorkflow=null;
    _pendingConfirmation=null;
    _pendingClarification = null;
    _pendingClarificationMessage = null;
    conflicts = const [];
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> bindSession(String id) async {
    if (_disposed) return;
    _sessionId = id;
    _initialized = true;
    await _sessionStore.save(id);
    notifyListeners();
  }

  /// Invalidate only the rejected reference, preserving chat and other accounts.
  Future<void> clearRejectedSession(String rejectedId) async {
    if (_disposed || _sessionId != rejectedId) return;
    taskWorkflow=null;
    _pendingConfirmation=null;
    _sessionId = null;
    await _sessionStore.clear();
    notifyListeners();
  }

  /// Worker receipts are already executed by the sole backend Agent.
  Future<void> acceptVoiceResult(
    AgentResponse response, {
    String? transcript,
    String? transcriptDisplayText,
  }) async {
    if (_disposed) return;
    if (_sessionId != null && _sessionId != response.sessionId) return;
    _sessionId = response.sessionId;
    await _sessionStore.save(response.sessionId);
    if (_disposed) return;
    if (transcript != null && transcript.trim().isNotEmpty) {
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.user,
          text: transcript,
          transcriptDisplayText: transcriptDisplayText,
          createdAt: DateTime.now(),
        ),
      );
    }
    _append(
      AgentChatMessage(
        id: _nextId(),
        author: AgentMessageAuthor.assistant,
        text: response.reply,
        createdAt: DateTime.now(),
        navigation: response.navigation,
        confirmation: response.confirmation,
        clarification: response.clarification,
        speech: response.speech,
        actionStatus: response.actionStatus,
      ),
    );
    _applyActionState(response, sourceMessage: transcript);
    notifyListeners();
    await onCopilotResult?.call(response, 'voice');
    notifyListeners();
  }

  /// Server-authorized, read-only follow-through has no fabricated user turn.
  Future<void> acceptCopilotContinuation(
    AgentResponse response, {
    required String source,
  }) async {
    if (_disposed || _sessionId != response.sessionId) return;
    _append(
      AgentChatMessage(
        id: _nextId(),
        author: AgentMessageAuthor.assistant,
        text: response.reply,
        createdAt: DateTime.now(),
        navigation: response.navigation,
        speech: response.speech,
      ),
    );
    conflicts = response.conflicts;
    if(response.taskWorkflow!=null){taskWorkflow=response.taskWorkflow;CopilotDiagnostics.emit(CopilotDiagnostic.workflowChanged);}
    notifyListeners();
    await onCopilotResult?.call(response, source);
  }

  List<AgentChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;

  /// Locally observed milestones, not claims about backend reasoning stages.
  AgentRequestProgress get requestProgress => _initializing
      ? AgentRequestProgress.restoringSession
      : (_loading || _confirmationLoading || _clarificationLoading)
      ? _requestProgress
      : AgentRequestProgress.idle;

  void _requireCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw const AgentException('Request is no longer current.', code: AgentErrorCode.unavailable);
    }
  }

  Future<AgentResponse> _withRequestProgress(
    Future<AgentResponse> Function() request,
  ) async {
    final generation = _generation;
    _requireCurrent(generation);
    if (prepareLanguage != null && !await prepareLanguage!()) {
      throw const AgentException('Language preference is not ready.', code: AgentErrorCode.unavailable, retryable: true);
    }
    _requireCurrent(generation);
    _requestProgress = AgentRequestProgress.awaitingResponse;
    notifyListeners();
    final response = await request();
    _requireCurrent(generation);
    _requestProgress = AgentRequestProgress.applyingResponse;
    notifyListeners();
    return response;
  }

  bool get confirmationLoading => _confirmationLoading;
  bool get clarificationLoading => _clarificationLoading;
  bool get initializing => _initializing;
  bool get initialized => _initialized;
  AgentException? get error => _error;
  String? get sessionId => _sessionId;
  String? get lastFailedText => _lastFailedText;
  AgentConfirmation? get pendingConfirmation => _pendingConfirmation;
  AgentClarification? get pendingClarification => _pendingClarification;

  Future<void> initialize() async {
    if (_disposed || _initialized) return;

    final existing = _initializationFuture;
    if (existing != null) {
      await existing;
      return;
    }

    _initializing = true;
    notifyListeners();

    final future = _readSession();
    _initializationFuture = future;
    await future;
  }

  Future<AgentResponse?> sendText(
    String text, {
    bool requestSpeech = false,
  }) async {
    final trimmed = text.trim();
    if (_disposed || _loading ||
        _confirmationLoading ||
        _clarificationLoading ||
        trimmed.isEmpty) {
      return null;
    }
    return _send(
      trimmed,
      appendUserMessage: true,
      requestSpeech: requestSpeech,
    );
  }

  Future<AgentResponse?> retryLast() async {
    final text = _lastFailedText;
    if (_disposed || _loading ||
        _confirmationLoading ||
        _clarificationLoading ||
        text == null ||
        text.trim().isEmpty) {
      return null;
    }
    _messages.removeWhere((message) => message.failed);
    notifyListeners();
    return _send(text, appendUserMessage: false);
  }

  Future<AgentResponse?> _send(
    String text, {
    required bool appendUserMessage,
    bool requestSpeech = false,
  }) async {
    final generation = _generation;
    _requestProgress = AgentRequestProgress.awaitingResponse;
    _loading = true;
    _error = null;
    _lastFailedText = null;
    _pendingClarification = null;
    _pendingClarificationMessage = null;

    if (appendUserMessage) {
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.user,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    }

    notifyListeners();

    try {
      await initialize();
      _requireCurrent(generation);
      final response = await _withRequestProgress(
        () => _sendWithSessionRetry(text, requestSpeech: requestSpeech),
      );
      if (_disposed || generation != _generation) return null;
      _requireCurrent(generation);
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
      _requireCurrent(generation);
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: response.reply,
          createdAt: DateTime.now(),
          navigation: response.navigation,
          confirmation: response.confirmation,
          clarification: response.clarification,
          speech: response.speech,
          actionStatus: response.actionStatus,
        ),
      );
      _applyActionState(response, sourceMessage: text);
      notifyListeners();
      await onCopilotResult?.call(response, 'text');
      return response;
    } on AgentException catch (exception) {
      if (_disposed || generation != _generation) return null;
      _error = exception;
      _lastFailedText = text;
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: exception.message,
          createdAt: DateTime.now(),
          failed: true,
        ),
      );
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<AgentResponse> _sendWithSessionRetry(
    String text, {
    bool requestSpeech = false,
  }) async {
    final generation = _generation;
    _requireCurrent(generation);
    try {
      return await _client.send(
        AgentRequest(
          sessionId: _sessionId,
          message: text,
          context: contextProvider?.call() ?? context,
          requestSpeech: requestSpeech,
        ),
      );
    } on AgentException catch (exception) {
      _requireCurrent(generation);
      if (!exception.isSessionNotFound || _sessionId == null) {
        rethrow;
      }

      await clearRejectedSession(_sessionId!);
      _requireCurrent(generation);

      return _client.send(
        AgentRequest(
          message: text,
          context: contextProvider?.call() ?? context,
          requestSpeech: requestSpeech,
        ),
      );
    }
  }

  Future<void> confirmPendingAction(String confirmationId) =>
      _sendConfirmationDecision(confirmationId, 'confirm');

  Future<void> cancelPendingAction(String confirmationId) =>
      _sendConfirmationDecision(confirmationId, 'cancel');

  Future<void> _sendConfirmationDecision(
    String confirmationId,
    String decision,
  ) async {
    final generation = _generation;
    final pending = _pendingConfirmation;
    if (_disposed || _loading ||
        _confirmationLoading ||
        _clarificationLoading ||
        pending == null) {
      return;
    }
    if (pending.confirmationId != confirmationId.trim()) return;
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    _requestProgress = AgentRequestProgress.awaitingResponse;
    _confirmationLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _withRequestProgress(
        () => _client.send(
          AgentRequest.confirmation(
            sessionId: sessionId,
            confirmationId: confirmationId,
            confirmationDecision: decision,
          ),
        ),
      );
      _requireCurrent(generation);
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
      _requireCurrent(generation);
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: response.reply,
          createdAt: DateTime.now(),
          confirmation: response.confirmation,
          actionStatus: response.actionStatus,
        ),
      );
      _applyActionState(response, completedConfirmationId: confirmationId);
      notifyListeners();
      await onCopilotResult?.call(response, 'text');
    } on AgentException catch (exception) {
      if (_disposed || generation != _generation) return;
      _error = exception;
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: exception.message,
          createdAt: DateTime.now(),
          failed: true,
        ),
      );
    } finally {
      _confirmationLoading = false;
      notifyListeners();
    }
  }

  Future<void> chooseClarificationOption(
    String clarificationId,
    String choiceId,
  ) async {
    final generation = _generation;
    final pending = _pendingClarification;
    final sourceMessage = _pendingClarificationMessage;
    if (_disposed || _loading ||
        _confirmationLoading ||
        _clarificationLoading ||
        pending == null ||
        sourceMessage == null) {
      return;
    }
    if (pending.clarificationId != clarificationId.trim()) return;
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    _requestProgress = AgentRequestProgress.awaitingResponse;
    _clarificationLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _withRequestProgress(
        () => _client.send(
          AgentRequest.clarification(
            sessionId: sessionId,
            message: sourceMessage,
            clarificationId: clarificationId,
            choiceId: choiceId,
          ),
        ),
      );
      _requireCurrent(generation);
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
      _requireCurrent(generation);
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: response.reply,
          createdAt: DateTime.now(),
          navigation: response.navigation,
          confirmation: response.confirmation,
          clarification: response.clarification,
          speech: response.speech,
          actionStatus: response.actionStatus,
        ),
      );
      _applyActionState(
        response,
        completedClarificationId: clarificationId,
        sourceMessage: sourceMessage,
      );
      notifyListeners();
      await onCopilotResult?.call(response, 'text');
    } on AgentException catch (exception) {
      if (_disposed || generation != _generation) return;
      _error = exception;
      _pendingClarification = null;
      _pendingClarificationMessage = null;
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: exception.message,
          createdAt: DateTime.now(),
          failed: true,
        ),
      );
    } finally {
      _clarificationLoading = false;
      notifyListeners();
    }
  }

  void _applyActionState(
    AgentResponse response, {
    String? completedConfirmationId,
    String? completedClarificationId,
    String? sourceMessage,
  }) {
    conflicts = response.conflicts;
    if(response.taskWorkflow!=null){taskWorkflow=response.taskWorkflow;CopilotDiagnostics.emit(CopilotDiagnostic.workflowChanged);}
    if (response.clarification != null) {
      _pendingClarification = response.clarification;
      _pendingClarificationMessage = sourceMessage;
    } else if (completedClarificationId == null ||
        _pendingClarification?.clarificationId == completedClarificationId) {
      _pendingClarification = null;
      _pendingClarificationMessage = null;
    }

    if (response.actionStatus == 'awaiting_confirmation' &&
        response.confirmation != null) {
      _pendingConfirmation = response.confirmation;
      return;
    }
    if (response.actionStatus == 'confirmed' ||
        response.actionStatus == 'cancelled' ||
        response.actionStatus == 'rejected') {
      if (completedConfirmationId == null ||
          _pendingConfirmation?.confirmationId == completedConfirmationId) {
        _pendingConfirmation = null;
      }
    }
  }

  void _append(AgentChatMessage message) {
    _messages.add(message);
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
  }

  String _nextId() {
    _idSeed += 1;
    return 'agent_msg_$_idSeed';
  }

  Future<void> _readSession() async {
    try {
      final generation = _generation;
      final restored = await _sessionStore.read();
      if (!_disposed && generation == _generation) _sessionId = restored;
    } finally {
      _initialized = true;
      _initializing = false;
      _initializationFuture = null;
      notifyListeners();
    }
  }
}

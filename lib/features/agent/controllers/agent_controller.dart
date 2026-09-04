import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agent_context.dart';
import '../models/agent_message.dart';
import '../models/agent_request.dart';
import '../models/agent_response.dart';
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

class AgentController extends ChangeNotifier {
  AgentController({
    required AgentClient client,
    AgentSessionStore sessionStore = const AgentSessionStore(),
    this.context,
  }) : _client = client,
       _sessionStore = sessionStore;

  static const maxMessages = 80;

  final AgentClient _client;
  final AgentSessionStore _sessionStore;
  final AgentScreenContext? context;

  final List<AgentChatMessage> _messages = [];

  String? _sessionId;
  String? _lastFailedText;
  bool _loading = false;
  bool _initializing = false;
  bool _confirmationLoading = false;
  bool _initialized = false;
  AgentException? _error;
  AgentConfirmation? _pendingConfirmation;
  Future<void>? _initializationFuture;
  int _idSeed = 0;

  List<AgentChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get confirmationLoading => _confirmationLoading;
  bool get initializing => _initializing;
  bool get initialized => _initialized;
  AgentException? get error => _error;
  String? get sessionId => _sessionId;
  String? get lastFailedText => _lastFailedText;
  AgentConfirmation? get pendingConfirmation => _pendingConfirmation;

  Future<void> initialize() async {
    if (_initialized) return;

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
    if (_loading || _confirmationLoading || trimmed.isEmpty) return null;
    return _send(
      trimmed,
      appendUserMessage: true,
      requestSpeech: requestSpeech,
    );
  }

  Future<AgentResponse?> retryLast() async {
    final text = _lastFailedText;
    if (_loading ||
        _confirmationLoading ||
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
    _loading = true;
    _error = null;
    _lastFailedText = null;

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
      final response = await _sendWithSessionRetry(
        text,
        requestSpeech: requestSpeech,
      );
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: response.reply,
          createdAt: DateTime.now(),
          navigation: response.navigation,
          confirmation: response.confirmation,
          speech: response.speech,
          actionStatus: response.actionStatus,
        ),
      );
      _applyActionState(response);
      return response;
    } on AgentException catch (exception) {
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
    try {
      return await _client.send(
        AgentRequest(
          sessionId: _sessionId,
          message: text,
          context: context,
          requestSpeech: requestSpeech,
        ),
      );
    } on AgentException catch (exception) {
      if (!exception.isSessionNotFound || _sessionId == null) {
        rethrow;
      }

      _sessionId = null;
      await _sessionStore.clear();

      return _client.send(
        AgentRequest(
          message: text,
          context: context,
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
    final pending = _pendingConfirmation;
    if (_loading || _confirmationLoading || pending == null) return;
    if (pending.confirmationId != confirmationId.trim()) return;
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    _confirmationLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.send(
        AgentRequest.confirmation(
          sessionId: sessionId,
          confirmationId: confirmationId,
          confirmationDecision: decision,
        ),
      );
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
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
    } on AgentException catch (exception) {
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

  void _applyActionState(
    AgentResponse response, {
    String? completedConfirmationId,
  }) {
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
      _sessionId = await _sessionStore.read();
    } finally {
      _initialized = true;
      _initializing = false;
      _initializationFuture = null;
      notifyListeners();
    }
  }
}

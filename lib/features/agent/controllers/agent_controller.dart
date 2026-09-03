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
  bool _initialized = false;
  AgentException? _error;
  Future<void>? _initializationFuture;
  int _idSeed = 0;

  List<AgentChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get initializing => _initializing;
  bool get initialized => _initialized;
  AgentException? get error => _error;
  String? get sessionId => _sessionId;
  String? get lastFailedText => _lastFailedText;

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

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (_loading || trimmed.isEmpty) return;
    await _send(trimmed, appendUserMessage: true);
  }

  Future<void> retryLast() async {
    final text = _lastFailedText;
    if (_loading || text == null || text.trim().isEmpty) return;
    _messages.removeWhere((message) => message.failed);
    notifyListeners();
    await _send(text, appendUserMessage: false);
  }

  Future<void> _send(String text, {required bool appendUserMessage}) async {
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
      final response = await _sendWithSessionRetry(text);
      _sessionId = response.sessionId;
      await _sessionStore.save(response.sessionId);
      _append(
        AgentChatMessage(
          id: _nextId(),
          author: AgentMessageAuthor.assistant,
          text: response.reply,
          createdAt: DateTime.now(),
          navigation: response.navigation,
        ),
      );
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
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<AgentResponse> _sendWithSessionRetry(String text) async {
    try {
      return await _client.send(
        AgentRequest(sessionId: _sessionId, message: text, context: context),
      );
    } on AgentException catch (exception) {
      if (!exception.isSessionNotFound || _sessionId == null) {
        rethrow;
      }

      _sessionId = null;
      await _sessionStore.clear();

      return _client.send(AgentRequest(message: text, context: context));
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

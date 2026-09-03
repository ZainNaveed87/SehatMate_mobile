import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../../../services/auth_service.dart';
import '../models/agent_request.dart';
import '../models/agent_response.dart';

abstract interface class AgentAuthTokenProvider {
  String? get token;
}

class AuthSessionAgentTokenProvider implements AgentAuthTokenProvider {
  const AuthSessionAgentTokenProvider(this.session);

  final AuthSession session;

  @override
  String? get token => session.token;
}

enum AgentErrorCode {
  unauthenticated,
  forbidden,
  disabled,
  sessionNotFound,
  rateLimited,
  network,
  timeout,
  unavailable,
  malformed,
  unknown,
}

class AgentException implements Exception {
  const AgentException(
    this.message, {
    this.code = AgentErrorCode.unknown,
    this.statusCode,
    this.retryable = false,
  });

  final String message;
  final AgentErrorCode code;
  final int? statusCode;
  final bool retryable;

  bool get isSessionNotFound => code == AgentErrorCode.sessionNotFound;

  @override
  String toString() => message;
}

class AgentService {
  AgentService({
    http.Client? client,
    AuthSession? authSession,
    AgentAuthTokenProvider? tokenProvider,
  }) : _client = client ?? http.Client(),
       _tokenProvider =
           tokenProvider ??
           AuthSessionAgentTokenProvider(authSession ?? AuthSession.instance);

  static final instance = AgentService();

  static const _timeout = Duration(seconds: 30);

  final http.Client _client;
  final AgentAuthTokenProvider _tokenProvider;

  Future<AgentResponse> send(AgentRequest request) async {
    if (!ApiConfig.isConfigured) {
      throw const AgentException(
        'SehatMate AI is temporarily unavailable. Please try again.',
        code: AgentErrorCode.unavailable,
        retryable: true,
      );
    }

    final token = _tokenProvider.token;
    if (token == null || token.isEmpty) {
      throw const AgentException(
        'Please sign in to continue.',
        code: AgentErrorCode.unauthenticated,
      );
    }

    try {
      final response = await _client
          .post(
            ApiConfig.endpoint('/agent/message'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      final decoded = _decode(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionFromError(response.statusCode, decoded);
      }

      final payload = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;

      final agentResponse = AgentResponse.fromJson({
        'success': decoded['success'],
        ...payload,
      });
      if (kDebugMode && agentResponse.fallbackCode != null) {
        debugPrint(
          'SehatMate Agent fallbackCode: ${agentResponse.fallbackCode}',
        );
      }
      return agentResponse;
    } on AgentException {
      rethrow;
    } on TimeoutException {
      throw const AgentException(
        'SehatMate AI is temporarily unavailable. Please try again.',
        code: AgentErrorCode.timeout,
        retryable: true,
      );
    } on http.ClientException {
      throw const AgentException(
        'SehatMate AI is temporarily unavailable. Please try again.',
        code: AgentErrorCode.network,
        retryable: true,
      );
    } on FormatException {
      throw const AgentException(
        'SehatMate AI returned an invalid response.',
        code: AgentErrorCode.malformed,
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  AgentException _exceptionFromError(
    int statusCode,
    Map<String, dynamic> decoded,
  ) {
    final data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final error = decoded['error'] is Map<String, dynamic>
        ? decoded['error'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawCode =
        decoded['code']?.toString() ??
        data['code']?.toString() ??
        error['code']?.toString();
    final code = _errorCodeFor(statusCode, rawCode);

    return AgentException(
      _messageForCode(code),
      code: code,
      statusCode: statusCode,
      retryable: statusCode == 408 || statusCode == 429 || statusCode >= 500,
    );
  }

  AgentErrorCode _errorCodeFor(int statusCode, String? rawCode) {
    final normalized = (rawCode ?? '').trim().toUpperCase();
    if (normalized == 'AGENT_DISABLED') return AgentErrorCode.disabled;
    if (normalized == 'AGENT_SESSION_NOT_FOUND' ||
        normalized == 'AGENT_SESSION_EXPIRED' ||
        normalized == 'INVALID_AGENT_SESSION') {
      return AgentErrorCode.sessionNotFound;
    }
    if (statusCode == 401) return AgentErrorCode.unauthenticated;
    if (statusCode == 403) return AgentErrorCode.forbidden;
    if (statusCode == 429) return AgentErrorCode.rateLimited;
    if (statusCode >= 500) return AgentErrorCode.unavailable;
    return AgentErrorCode.unknown;
  }

  String _messageForCode(AgentErrorCode code) {
    return switch (code) {
      AgentErrorCode.unauthenticated => 'Please sign in to continue.',
      AgentErrorCode.rateLimited =>
        'SehatMate AI is busy right now. Please try again shortly.',
      AgentErrorCode.malformed => 'SehatMate AI returned an invalid response.',
      AgentErrorCode.forbidden ||
      AgentErrorCode.disabled ||
      AgentErrorCode.sessionNotFound ||
      AgentErrorCode.network ||
      AgentErrorCode.timeout ||
      AgentErrorCode.unavailable ||
      AgentErrorCode.unknown =>
        'SehatMate AI is temporarily unavailable. Please try again.',
    };
  }
}

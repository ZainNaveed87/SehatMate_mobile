import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../../../services/auth_service.dart';

class VoiceFailure implements Exception {
  const VoiceFailure(this.code);
  final String code;
}

abstract interface class VoiceBackend {
  Future<Map<String, dynamic>> create(String agentSessionId);
  Future<Map<String, dynamic>> token(String id);
  Future<Map<String, dynamic>> get(String id);
  Future<Map<String, dynamic>> transfer(String id, int epoch, String mode);
  Future<Map<String, dynamic>> submit(String id, Map<String, dynamic> body);
  Future<Map<String, dynamic>> receipt(String id, String turnId);
  Future<void> end(String id);
}

class HttpVoiceBackend implements VoiceBackend {
  HttpVoiceBackend({http.Client? client, String? Function()? token})
    : _client = client ?? http.Client(),
      _token = token ?? (() => AuthSession.instance.token);
  final http.Client _client;
  final String? Function() _token;
  final _cleanupTokens = <String, String>{};
  static const _root = '/agent/voice-sessions';
  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final cleanupId = method == 'DELETE' ? path.split('/').last : null;
    final token = cleanupId == null
        ? _token()
        : _cleanupTokens.remove(cleanupId) ?? _token();
    if (token == null || token.isEmpty) {
      throw const VoiceFailure('VOICE_UNAUTHENTICATED');
    }
    final request = http.Request(method, ApiConfig.endpoint(path))
      ..followRedirects = false;
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in streamed.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 70000) {
        throw const VoiceFailure('VOICE_INVALID_RESPONSE');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const VoiceFailure('VOICE_INVALID_RESPONSE');
    }
    if (streamed.statusCode < 200 ||
        streamed.statusCode >= 300 ||
        value['success'] != true) {
      final code = value['code'];
      throw VoiceFailure(
        code is String && RegExp(r'^(VOICE_|AGENT_)').hasMatch(code)
            ? code
            : 'VOICE_UNAVAILABLE',
      );
    }
    final data = value['data'];
    if (data is! Map<String, dynamic>) {
      throw const VoiceFailure('VOICE_INVALID_RESPONSE');
    }
    if (method == 'POST' && path == _root && data['id'] is String) {
      _cleanupTokens[data['id']] = token;
    }
    return data;
  }

  Future<String> ensureAgentSession() async {
    final data = await _request('POST', '/agent/session', {});
    final id = data['sessionId'];
    if (id is! String || !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) {
      throw const VoiceFailure('VOICE_INVALID_RESPONSE');
    }
    return id;
  }

  @override
  Future<Map<String, dynamic>> create(String agentSessionId) =>
      _request('POST', _root, {'agentSessionId': agentSessionId});
  @override
  Future<Map<String, dynamic>> token(String id) =>
      _request('POST', '$_root/$id/token', {});
  @override
  Future<Map<String, dynamic>> get(String id) => _request('GET', '$_root/$id');
  @override
  Future<Map<String, dynamic>> transfer(String id, int epoch, String mode) =>
      _request('POST', '$_root/$id/transport', {'epoch': epoch, 'mode': mode});
  @override
  Future<Map<String, dynamic>> submit(String id, Map<String, dynamic> body) =>
      _request('POST', '$_root/$id/turns', body);
  @override
  Future<Map<String, dynamic>> receipt(String id, String turnId) =>
      _request('GET', '$_root/$id/turns/$turnId');
  @override
  Future<void> end(String id) async {
    await _request('DELETE', '$_root/$id', {});
  }
}

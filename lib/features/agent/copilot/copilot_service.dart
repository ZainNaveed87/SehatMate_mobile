import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_config.dart';
import '../../../services/auth_service.dart';
import '../controllers/agent_controller.dart';
import 'copilot.dart';

/// Context expires server-side. Only this account's authenticated token may
/// publish snapshots; no UI snapshot is stored as longitudinal memory.
class CopilotService {
  CopilotService({
    required this.registry,
    required this.agent,
    http.Client? client,
    DateTime Function()? now,
    this.syncActive,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now {
    registry.addListener(_changed);
    agent.addListener(_changed);
    _renewal = Timer.periodic(const Duration(minutes: 1), (_) {
      final session = agent.sessionId;
      if (_foreground && (syncActive?.call() ?? true) && session != null) {
        unawaited(ensureCurrent(session));
      }
    });
  }
  final CopilotRegistry registry;
  final AgentController agent;
  final http.Client _client;
  final DateTime Function() _now;
  final bool Function()? syncActive;
  late final Timer _renewal;
  Timer? _debounce;
  bool _disposed = false, _foreground = true;
  String? _synced, _syncSession;
  String? _observedVersion, _observedSession, _pendingKey;
  DateTime? _syncedAt;
  Future<void> _queue = Future<void>.value();
  Future<bool>? _pending;
  int _revision = 0;
  bool get _currentAccount =>
      !_disposed &&
      registry.valid &&
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.user?.id == registry.accountId;
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String method = 'POST',
  }) async {
    if (!_currentAccount) throw StateError('account_changed');
    final token = AuthSession.instance.token!;
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };
    final uri = ApiConfig.endpoint('/agent/copilot/$path');
    final response =
        await (method == 'GET'
                ? _client.get(uri, headers: headers)
                : method == 'DELETE'
                ? _client.delete(uri, headers: headers)
                : _client.post(
                    uri,
                    headers: headers,
                    body: jsonEncode(body ?? {}),
                  ))
            .timeout(const Duration(seconds: 12));
    if (!_currentAccount) throw StateError('account_changed');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('copilot_unavailable');
    }
    final value = jsonDecode(response.body);
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  void _changed() {
    final current = registry.snapshot?.version, session = agent.sessionId;
    if (_observedVersion == current && _observedSession == session) return;
    _observedVersion = current;
    _observedSession = session;
    _revision++;
    _debounce?.cancel();
    if (!_foreground || !_currentAccount || current == null || session == null) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(ensureCurrent(session));
    });
  }

  Future<bool> ensureCurrent(String sessionId) async {
    final snapshot = registry.snapshot;
    if (!_foreground ||
        !_currentAccount ||
        snapshot == null ||
        agent.sessionId != sessionId) {
      return false;
    }
    if (_synced == snapshot.version &&
        _syncSession == sessionId &&
        _syncedAt != null &&
        _now().difference(_syncedAt!) < const Duration(minutes: 1)) {
      return true;
    }
    final revision = _revision;
    final key = '$sessionId:${snapshot.version}:$revision';
    if (_pendingKey == key && _pending != null) return _pending!;
    final result = _queue.then((_) async {
      bool current() =>
          _foreground &&
          _currentAccount &&
          revision == _revision &&
          registry.snapshot?.version == snapshot.version &&
          agent.sessionId == sessionId;
      if (!current()) return false;
      try {
        await request(
          'context',
          body: {'sessionId': sessionId, 'context': snapshot.context.toJson()},
        );
        if (!current()) return false;
        _synced = snapshot.version;
        _syncSession = sessionId;
        _syncedAt = _now();
        return true;
      } catch (_) {
        return false;
      }
    });
    _pendingKey = key;
    _pending = result;
    _queue = result.then<void>((_) {});
    final accepted = await result;
    if (_pendingKey == key) {
      _pendingKey = null;
      _pending = null;
    }
    return accepted;
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _revision++;
    _debounce?.cancel();
    _syncedAt = null;
    if (foreground && agent.sessionId != null) {
      unawaited(ensureCurrent(agent.sessionId!));
    }
  }

  Future<void> receipt(CopilotReceipt value) async {
    final session = agent.sessionId;
    if (session == null || !_currentAccount) return;
    await request('receipts', body: value.toJson(session));
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _debounce?.cancel();
    _renewal.cancel();
    registry.removeListener(_changed);
    agent.removeListener(_changed);
    _client.close();
  }
}

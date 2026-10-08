import 'package:shared_preferences/shared_preferences.dart';

class AgentSessionStore {
  const AgentSessionStore({this.accountId});

  final String? accountId;
  String get storageKey => accountId == null ? key : '${key}_$accountId';

  static const key = 'sehatmate_agent_session_id';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(storageKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> save(String sessionId) async {
    final value = sessionId.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

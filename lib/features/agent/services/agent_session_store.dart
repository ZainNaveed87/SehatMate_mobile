import 'package:shared_preferences/shared_preferences.dart';

class AgentSessionStore {
  const AgentSessionStore();

  static const key = 'sehatmate_agent_session_id';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> save(String sessionId) async {
    final value = sessionId.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

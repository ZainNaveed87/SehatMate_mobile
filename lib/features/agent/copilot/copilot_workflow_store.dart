import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A resumable UI bookmark, never an authorization to replay an action or a
/// substitute for backend answers. No question text, notes or answers persist.
class CopilotWorkflowStore {
  const CopilotWorkflowStore({required this.accountId});
  final String accountId;
  String _key(String screenId, String entityId) =>
      'agent_workflow_v1:$accountId:$screenId:$entityId';
  Future<void> save(String screenId, String entityId, String stepId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(screenId, entityId),
      jsonEncode({
        'stepId': stepId,
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<String?> read(String screenId, String entityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(screenId, entityId));
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map;
      if (data['at'] is! int ||
          DateTime.now().millisecondsSinceEpoch - (data['at'] as int) >
              const Duration(days: 7).inMilliseconds) {
        return null;
      }
      return data['stepId'] is String ? data['stepId'] as String : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String screenId, String entityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(screenId, entityId));
  }
}

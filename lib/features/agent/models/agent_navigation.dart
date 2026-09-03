import 'agent_context.dart';

class AgentNavigation {
  const AgentNavigation({required this.target, this.params = const {}});

  final String target;
  final Map<String, String> params;

  static const supportedTargets = AgentScreenContext.supportedScreenIds;

  factory AgentNavigation.fromJson(Object? value) {
    if (value == null) {
      throw const FormatException('Agent navigation is null.');
    }

    if (value is! Map<String, dynamic>) {
      throw const FormatException('Agent navigation must be an object.');
    }

    final target = value['target']?.toString().trim() ?? '';
    if (!supportedTargets.contains(target)) {
      throw const FormatException('Unsupported Agent navigation target.');
    }

    final rawParams = value['params'];
    final params = <String, String>{};
    if (rawParams != null) {
      if (rawParams is! Map<String, dynamic>) {
        throw const FormatException('Agent navigation params must be object.');
      }

      for (final entry in rawParams.entries) {
        final key = entry.key.trim();
        final paramValue = entry.value?.toString().trim() ?? '';
        if (key.isEmpty || paramValue.isEmpty) continue;
        params[key] = paramValue;
      }
    }

    return AgentNavigation(target: target, params: Map.unmodifiable(params));
  }
}

class AgentNavigation {
  const AgentNavigation({required this.target, this.params = const {}});

  final String target;
  final Map<String, String> params;

  // Navigable destinations are narrower than screen context identities. A
  // document viewer needs an owned file loaded by the UI; family gap/simulation
  // reads have no independent mounted destinations.
  static const supportedTargets = {
    'home', 'calendar', 'family', 'care_plan_new', 'care_plan_upload',
    'care_plan_review', 'family_member_new', 'doctor_questions', 'simple_care',
    'teach_back', 'today', 'progress', 'care_plans', 'care_plan_detail',
    'reality_check', 'simulation', 'care_gaps', 'care_gap_detail', 'family_care',
    'family_member_detail', 'family_member_care_plans', 'routine_settings',
    'profile', 'documents', 'notifications', 'settings',
  };

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

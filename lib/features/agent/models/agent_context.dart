import 'agent_validation.dart';

class AgentEntityContext {
  const AgentEntityContext({required this.type, required this.id});

  final String type;
  final String id;

  static const supportedTypes = {'care_plan', 'care_gap', 'family_member'};

  bool get isValid =>
      supportedTypes.contains(type) && isSafeAgentIdentifier(id);

  Map<String, dynamic> toJson() {
    if (!isValid) {
      throw const FormatException('Invalid Agent entity context.');
    }

    return {'type': type, 'id': id.trim()};
  }
}

class AgentScreenContext {
  const AgentScreenContext({required this.screenId, this.entity});

  final String screenId;
  final AgentEntityContext? entity;

  static const supportedScreenIds = {
    'home',
    'today',
    'care_plans',
    'care_plan_detail',
    'reality_check',
    'simulation',
    'care_gaps',
    'care_gap_detail',
    'family_care',
    'family_member_detail',
    'family_member_care_plans',
    'family_member_care_gaps',
    'family_member_simulation',
    'routine_settings',
    'profile',
    'documents',
    'notifications',
    'settings',
  };

  bool get isValid {
    if (!supportedScreenIds.contains(screenId)) return false;
    final value = entity;
    return value == null || value.isValid;
  }

  Map<String, dynamic> toJson() {
    if (!isValid) {
      throw const FormatException('Invalid Agent screen context.');
    }

    return {
      'screenId': screenId,
      if (entity != null) 'entity': entity!.toJson(),
    };
  }
}

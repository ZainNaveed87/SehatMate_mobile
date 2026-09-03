import 'agent_navigation.dart';
import 'agent_validation.dart';

class AgentReferencedEntity {
  const AgentReferencedEntity({required this.type, required this.id});

  final String type;
  final String id;

  factory AgentReferencedEntity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Referenced entity must be an object.');
    }

    final type = value['type']?.toString().trim() ?? '';
    final id = value['id']?.toString().trim() ?? '';

    if (!AgentReferencedEntity.supportedTypes.contains(type) ||
        !isSafeAgentIdentifier(id)) {
      throw const FormatException('Referenced entity is invalid.');
    }

    return AgentReferencedEntity(type: type, id: id);
  }

  static const supportedTypes = {'care_plan', 'care_gap'};
}

class AgentResponse {
  const AgentResponse({
    required this.sessionId,
    required this.language,
    required this.reply,
    required this.referencedEntities,
    this.navigation,
  });

  final String sessionId;
  final String language;
  final String reply;
  final AgentNavigation? navigation;
  final List<AgentReferencedEntity> referencedEntities;

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) {
      throw const FormatException('Agent response did not succeed.');
    }

    final sessionId = json['sessionId']?.toString().trim() ?? '';
    final language = json['language']?.toString().trim() ?? '';
    final reply = json['reply']?.toString() ?? '';

    if (sessionId.isEmpty ||
        !AgentResponse.supportedLanguages.contains(language) ||
        reply.trim().isEmpty) {
      throw const FormatException('Agent response is missing required fields.');
    }

    final navigationJson = json['navigation'];
    AgentNavigation? navigation;
    if (navigationJson != null) {
      try {
        navigation = AgentNavigation.fromJson(navigationJson);
      } on FormatException {
        navigation = null;
      }
    }

    final referencedJson = json['referencedEntities'];
    if (referencedJson != null && referencedJson is! List) {
      throw const FormatException('Agent referencedEntities must be a list.');
    }

    final referencedEntities = ((referencedJson ?? const []) as List)
        .map<AgentReferencedEntity>(AgentReferencedEntity.fromJson)
        .toList(growable: false);

    return AgentResponse(
      sessionId: sessionId,
      language: language,
      reply: reply,
      navigation: navigation,
      referencedEntities: referencedEntities,
    );
  }

  static const supportedLanguages = {'en', 'ur', 'roman_ur'};
}

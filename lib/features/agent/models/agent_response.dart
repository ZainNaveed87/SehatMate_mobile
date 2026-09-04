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

class AgentConfirmation {
  const AgentConfirmation({
    required this.confirmationId,
    required this.kind,
    required this.message,
    this.expiresAt,
  });

  final String confirmationId;
  final String kind;
  final String message;
  final String? expiresAt;

  factory AgentConfirmation.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Agent confirmation must be an object.');
    }
    final confirmationId = value['confirmationId']?.toString().trim() ?? '';
    final kind = value['kind']?.toString().trim() ?? '';
    final message = value['message']?.toString().trim() ?? '';
    final expiresAt = value['expiresAt']?.toString().trim();
    if (confirmationId.isEmpty ||
        !supportedKinds.contains(kind) ||
        message.isEmpty) {
      throw const FormatException('Agent confirmation is invalid.');
    }
    return AgentConfirmation(
      confirmationId: confirmationId,
      kind: kind,
      message: message,
      expiresAt: expiresAt == null || expiresAt.isEmpty ? null : expiresAt,
    );
  }

  static const supportedKinds = {'task_outcome', 'schedule_time'};
}

class AgentResponse {
  const AgentResponse({
    required this.sessionId,
    required this.language,
    required this.reply,
    required this.referencedEntities,
    this.navigation,
    this.confirmation,
    this.actionStatus,
    this.fallbackCode,
  });

  final String sessionId;
  final String language;
  final String reply;
  final AgentNavigation? navigation;
  final AgentConfirmation? confirmation;
  final String? actionStatus;
  final List<AgentReferencedEntity> referencedEntities;
  final String? fallbackCode;

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) {
      throw const FormatException('Agent response did not succeed.');
    }

    final sessionId = json['sessionId']?.toString().trim() ?? '';
    final language = json['language']?.toString().trim() ?? '';
    final reply = json['reply']?.toString() ?? '';
    final fallbackCode = json['fallbackCode']?.toString().trim();
    final rawActionStatus = json['actionStatus']?.toString().trim();

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

    final actionStatus = supportedActionStatuses.contains(rawActionStatus)
        ? rawActionStatus
        : null;

    final confirmationJson = json['confirmation'];
    AgentConfirmation? confirmation;
    if (confirmationJson != null) {
      confirmation = AgentConfirmation.fromJson(confirmationJson);
    }
    if (actionStatus == 'awaiting_confirmation' && confirmation == null) {
      throw const FormatException(
        'Agent awaiting-confirmation response requires confirmation.',
      );
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
      confirmation: confirmation,
      actionStatus: actionStatus,
      referencedEntities: referencedEntities,
      fallbackCode: fallbackCode == null || fallbackCode.isEmpty
          ? null
          : fallbackCode,
    );
  }

  static const supportedLanguages = {'en', 'ur', 'roman_ur'};
  static const supportedActionStatuses = {
    'awaiting_confirmation',
    'confirmed',
    'cancelled',
    'rejected',
  };
}

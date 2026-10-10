import '../copilot/copilot_conflict.dart';
import '../copilot/copilot.dart';
import 'agent_navigation.dart';
import 'agent_speech.dart';
import 'agent_validation.dart';
import 'agent_task_workflow.dart';

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

  static const supportedTypes = {'care_plan', 'care_gap', 'family_member'};
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

  static const supportedKinds = {'task_outcome', 'schedule_time','create_care_plan'};
}

class AgentClarificationOption {
  const AgentClarificationOption({required this.choiceId, required this.label});

  final String choiceId;
  final String label;

  factory AgentClarificationOption.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Agent clarification option must be object.');
    }
    for (final key in value.keys) {
      if (key != 'choiceId' && key != 'label') {
        throw const FormatException('Agent clarification option is invalid.');
      }
    }
    final choiceId = value['choiceId']?.toString().trim() ?? '';
    final label = value['label']?.toString().trim() ?? '';
    if (!isSafeAgentIdentifier(choiceId) || label.isEmpty) {
      throw const FormatException('Agent clarification option is invalid.');
    }
    return AgentClarificationOption(choiceId: choiceId, label: label);
  }
}

class AgentClarification {
  const AgentClarification({
    required this.clarificationId,
    required this.kind,
    required this.question,
    required this.options,
    this.expiresAt,
  });

  final String clarificationId;
  final String kind;
  final String question;
  final List<AgentClarificationOption> options;
  final String? expiresAt;

  factory AgentClarification.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Agent clarification must be an object.');
    }
    final clarificationId = value['clarificationId']?.toString().trim() ?? '';
    final kind = value['kind']?.toString().trim() ?? '';
    final question = value['question']?.toString().trim() ?? '';
    final expiresAt = value['expiresAt']?.toString().trim();
    final rawOptions = value['options'];

    if (!isSafeAgentIdentifier(clarificationId) ||
        !supportedKinds.contains(kind) ||
        question.isEmpty ||
        rawOptions is! List) {
      throw const FormatException('Agent clarification is invalid.');
    }

    final options = rawOptions
        .map<AgentClarificationOption>(AgentClarificationOption.fromJson)
        .toList(growable: false);
    if (options.length < 2 || options.length > 5) {
      throw const FormatException('Agent clarification options are invalid.');
    }

    return AgentClarification(
      clarificationId: clarificationId,
      kind: kind,
      question: question,
      options: options,
      expiresAt: expiresAt == null || expiresAt.isEmpty ? null : expiresAt,
    );
  }

  static const supportedKinds = {'entity_reference'};
}

class AgentResponse {
  const AgentResponse({
    required this.sessionId,
    required this.language,
    required this.reply,
    required this.referencedEntities,
    this.navigation,
    this.confirmation,
    this.clarification,
    this.speech,
    this.actionStatus,
    this.fallbackCode,
    this.uiPlan,
    this.memoryProposal,
    this.conflicts = const [],
    this.taskWorkflow,
    this.displayTranscript,
    this.conversationLanguage,
  });

  final String sessionId;
  final String language;
  final String reply;
  final AgentNavigation? navigation;
  final AgentConfirmation? confirmation;
  final AgentClarification? clarification;
  final AgentSpeech? speech;
  final String? actionStatus;
  final List<AgentReferencedEntity> referencedEntities;
  final String? fallbackCode;
  final CopilotPlan? uiPlan;
  final List<CopilotConflict> conflicts;
  final Map<String, dynamic>? memoryProposal;
  final AgentTaskWorkflow? taskWorkflow;
  /// Optional server rendering; raw ASR remains separate action input.
  final String? displayTranscript;
  final String? conversationLanguage;

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

    final clarificationJson = json['clarification'];
    AgentClarification? clarification;
    if (clarificationJson != null) {
      clarification = AgentClarification.fromJson(clarificationJson);
    }

    AgentSpeech? speech;
    if (json['speech'] != null) {
      try {
        speech = AgentSpeech.fromJson(json['speech']);
      } on FormatException {
        speech = null;
      }
    }

    final referencedJson = json['referencedEntities'];
    if (referencedJson != null && referencedJson is! List) {
      throw const FormatException('Agent referencedEntities must be a list.');
    }

    final referencedEntities = ((referencedJson ?? const []) as List)
        .map<AgentReferencedEntity>(AgentReferencedEntity.fromJson)
        .toList(growable: false);

    CopilotPlan? uiPlan;
    if (json['uiPlan'] != null) {
      try {
        uiPlan = CopilotPlan.fromJson(json['uiPlan']);
      } catch (_) {
        uiPlan = null;
      }
    }
    final taskWorkflow=json['taskWorkflow']==null?null:AgentTaskWorkflow.fromJson(json['taskWorkflow']);
    if(taskWorkflow?.status=='awaiting_confirmation'&&(confirmation?.kind!='create_care_plan'||confirmation?.confirmationId!=taskWorkflow?.confirmationId))throw const FormatException('Task confirmation mismatch');
    if(confirmation?.kind=='create_care_plan'&&taskWorkflow?.status!='awaiting_confirmation')throw const FormatException('Missing task confirmation state');
    return AgentResponse(
      conversationLanguage: supportedLanguages.contains(json['conversationLanguage']) ? json['conversationLanguage'] as String : null,
      displayTranscript: json['displayTranscript'] is String && (json['displayTranscript'] as String).length <= 3000
          ? json['displayTranscript'] as String : null,
      taskWorkflow:taskWorkflow,
      uiPlan: uiPlan,
      conflicts: CopilotConflict.parse(json['conflicts']),
      memoryProposal: json['memoryProposal'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(json['memoryProposal'])
          : null,
      sessionId: sessionId,
      language: language,
      reply: reply,
      navigation: navigation,
      confirmation: confirmation,
      clarification: clarification,
      speech: speech,
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

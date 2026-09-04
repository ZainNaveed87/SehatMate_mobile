import 'agent_context.dart';

class AgentRequest {
  const AgentRequest({
    required this.message,
    this.sessionId,
    this.context,
    this.requestSpeech = false,
  }) : confirmationId = null,
       confirmationDecision = null;

  const AgentRequest.confirmation({
    required this.sessionId,
    required this.confirmationId,
    required this.confirmationDecision,
  }) : message = '',
       context = null,
       requestSpeech = false;

  static const maxMessageLength = 2000;
  static const _confirmationDecisions = {'confirm', 'cancel'};

  final String message;
  final String? sessionId;
  final AgentScreenContext? context;
  final bool requestSpeech;
  final String? confirmationId;
  final String? confirmationDecision;

  Map<String, dynamic> toJson() {
    final trimmedConfirmationId = confirmationId?.trim() ?? '';
    final trimmedDecision = confirmationDecision?.trim() ?? '';
    if (trimmedConfirmationId.isNotEmpty || trimmedDecision.isNotEmpty) {
      final trimmedSessionId = sessionId?.trim() ?? '';
      if (trimmedSessionId.isEmpty ||
          trimmedConfirmationId.isEmpty ||
          !_confirmationDecisions.contains(trimmedDecision)) {
        throw const FormatException('Agent confirmation request is invalid.');
      }
      return {
        'sessionId': trimmedSessionId,
        'confirmation': {
          'confirmationId': trimmedConfirmationId,
          'decision': trimmedDecision,
        },
      };
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const FormatException('Agent message is empty.');
    }
    if (trimmedMessage.length > maxMessageLength) {
      throw const FormatException('Agent message is too long.');
    }

    final trimmedSessionId = sessionId?.trim() ?? '';
    final semanticContext = context;

    return {
      if (trimmedSessionId.isNotEmpty) 'sessionId': trimmedSessionId,
      'message': trimmedMessage,
      if (semanticContext != null) 'context': semanticContext.toJson(),
      if (requestSpeech) 'voice': {'requestSpeech': true},
    };
  }
}

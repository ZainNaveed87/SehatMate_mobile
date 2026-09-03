import 'agent_context.dart';

class AgentRequest {
  const AgentRequest({required this.message, this.sessionId, this.context});

  static const maxMessageLength = 2000;

  final String message;
  final String? sessionId;
  final AgentScreenContext? context;

  Map<String, dynamic> toJson() {
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
    };
  }
}

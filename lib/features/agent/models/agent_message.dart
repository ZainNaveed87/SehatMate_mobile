import 'agent_navigation.dart';
import 'agent_response.dart';
import 'agent_speech.dart';

enum AgentMessageAuthor { user, assistant }

class AgentChatMessage {
  const AgentChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.navigation,
    this.confirmation,
    this.clarification,
    this.speech,
    this.actionStatus,
    this.failed = false,
    this.failureCode,
  });

  final String id;
  final AgentMessageAuthor author;
  final String text;
  final DateTime createdAt;
  final AgentNavigation? navigation;
  final AgentConfirmation? confirmation;
  final AgentClarification? clarification;
  final AgentSpeech? speech;
  final String? actionStatus;
  final bool failed;
  final String? failureCode;

  AgentChatMessage copyWith({
    AgentNavigation? navigation,
    AgentConfirmation? confirmation,
    AgentClarification? clarification,
    AgentSpeech? speech,
    String? actionStatus,
    bool? failed,
  }) {
    return AgentChatMessage(
      id: id,
      author: author,
      text: text,
      createdAt: createdAt,
      navigation: navigation ?? this.navigation,
      confirmation: confirmation ?? this.confirmation,
      clarification: clarification ?? this.clarification,
      speech: speech ?? this.speech,
      actionStatus: actionStatus ?? this.actionStatus,
      failed: failed ?? this.failed,
      failureCode: failureCode,
    );
  }
}

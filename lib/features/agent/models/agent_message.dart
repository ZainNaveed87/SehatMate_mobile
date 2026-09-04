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
    this.speech,
    this.actionStatus,
    this.failed = false,
  });

  final String id;
  final AgentMessageAuthor author;
  final String text;
  final DateTime createdAt;
  final AgentNavigation? navigation;
  final AgentConfirmation? confirmation;
  final AgentSpeech? speech;
  final String? actionStatus;
  final bool failed;

  AgentChatMessage copyWith({
    AgentNavigation? navigation,
    AgentConfirmation? confirmation,
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
      speech: speech ?? this.speech,
      actionStatus: actionStatus ?? this.actionStatus,
      failed: failed ?? this.failed,
    );
  }
}

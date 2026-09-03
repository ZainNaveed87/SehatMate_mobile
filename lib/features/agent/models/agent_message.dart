import 'agent_navigation.dart';

enum AgentMessageAuthor { user, assistant }

class AgentChatMessage {
  const AgentChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.navigation,
    this.failed = false,
  });

  final String id;
  final AgentMessageAuthor author;
  final String text;
  final DateTime createdAt;
  final AgentNavigation? navigation;
  final bool failed;

  AgentChatMessage copyWith({AgentNavigation? navigation, bool? failed}) {
    return AgentChatMessage(
      id: id,
      author: author,
      text: text,
      createdAt: createdAt,
      navigation: navigation ?? this.navigation,
      failed: failed ?? this.failed,
    );
  }
}

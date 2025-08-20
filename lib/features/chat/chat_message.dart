enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime ts;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.ts,
  });
}


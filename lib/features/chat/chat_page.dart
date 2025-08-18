import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SpellCheckConfiguration, TextCapitalization;

import 'chat_message.dart';
import '../../services/openai_chat_service.dart';

class ChatPage extends StatefulWidget {
  final String initialQuery;
  const ChatPage({super.key, required this.initialQuery});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = OpenAIChatService();
  int _seq = 0;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 초깃값: 사용자의 검색어를 메시지로 추가 후 곧바로 전송
    _appendUser(widget.initialQuery);
    _sendToAI(widget.initialQuery);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _appendUser(String content) {
    setState(() {
      _messages.add(ChatMessage(
        id: _makeId(),
        role: ChatRole.user,
        content: content,
        ts: DateTime.now(),
      ));
    });
    _scrollToBottomDeferred();
  }

  void _appendAssistant(String content) {
    setState(() {
      _messages.add(ChatMessage(
        id: _makeId(),
        role: ChatRole.assistant,
        content: content,
        ts: DateTime.now(),
      ));
    });
    _scrollToBottomDeferred();
  }

  String _makeId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  void _scrollToBottomDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendToAI(String query) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final reply = await _service.askExpression(query);
      _appendAssistant(reply);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSendPressed() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _appendUser(text);
    _sendToAI(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('표현 도우미'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loading && index == _messages.length) {
                    // 로딩 인디케이터 메시지
                    return const _TypingBubble();
                  }
                  final m = _messages[index];
                  final isUser = m.role == ChatRole.user;
                  return _MessageBubble(
                    content: m.content,
                    isUser: isUser,
                    color: isUser ? cs.primary : cs.surface,
                    textColor: isUser ? cs.onPrimary : cs.onSurface,
                  );
                },
              ),
            ),
            _InputBar(
              controller: _inputCtrl,
              onSend: _onSendPressed,
              sending: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late final FocusNode _fn;

  @override
  void initState() {
    super.initState();
    _fn = FocusNode(debugLabel: 'chat_input_fn');
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chat_input_field'),
                  controller: widget.controller,
                  focusNode: _fn,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    hintText: "질문을 입력하세요",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: widget.sending ? null : widget.onSend,
                icon: const Icon(Icons.send),
                color: cs.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final Color color;
  final Color textColor;
  const _MessageBubble({
    required this.content,
    required this.isUser,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
          ),
          child: Text(
            content,
            style: TextStyle(
              color: textColor,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: cs.primary),
            ),
            const SizedBox(width: 8),
            Text('답변 작성 중...', style: TextStyle(color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

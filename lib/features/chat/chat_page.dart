import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show SpellCheckConfiguration, TextCapitalization, SmartDashesType, SmartQuotesType, rootBundle;
import 'dart:convert' show jsonEncode;

import 'chat_message.dart';
import '../../services/openai_chat_service.dart';
import '../../services/examples_api.dart';
import '../speaking/speaking_page.dart';
import '../../core/text_markers.dart';
import 'package:englishplease/models/example_item.dart';

class ChatPage extends StatefulWidget {
  final String initialQuery;
  const ChatPage({super.key, required this.initialQuery});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = OpenAIChatService();
  final _examplesApi = ExamplesApi();
  int _seq = 0;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _examplesLoading = false;
  String? _lastCurlyPattern; // last extracted from {{...}}
  String? _lastParenPattern; // last extracted from ((...))

  @override
  void initState() {
    super.initState();
    // 초깃값: 사용자의 검색어를 메시지로 추가 후 곧바로 전송
    _appendUser(widget.initialQuery);
    _sendToAI();
  }

  @override
  void dispose() {
    // Ensure HTTP client is closed
    _service.dispose();
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
    final paren = TextMarkers.extractParen(content);
    final curly = TextMarkers.extractCurly(content);
    debugPrint('extract | paren="${paren ?? '-'}", curly="${curly ?? '-'}"');
    setState(() {
      if (paren != null && paren.isNotEmpty) {
        _lastParenPattern = paren;
      }
      if (curly != null && curly.isNotEmpty) {
        _lastCurlyPattern = curly;
      }
      _messages.add(ChatMessage(
        id: _makeId(),
        role: ChatRole.assistant,
        content: content,
        ts: DateTime.now(),
      ));
    });
    _debugLogPatterns('appendAssistant');
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

  Future<void> _sendToAI() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final reply = await _service.askWithHistory(_messages);
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
    _sendToAI();
  }

  // marker strip is moved to core/TextMarkers

  void _debugLogPatterns([String where = '']) {
    final tag = where.isNotEmpty ? ' [$where]' : '';
    debugPrint('pattern$tag | paren="${_lastParenPattern ?? '-'}", curly="${_lastCurlyPattern ?? '-'}"');
  }

  // removed unused _extractFirstEnglishSentence helper

  // timestamp helper removed (no file saving)

  Future<void> _openExampleDialog(String assistantText) async {
    final initialPattern = _lastCurlyPattern ?? TextMarkers.extractCurly(assistantText) ?? '';
    debugPrint('initialPattern(fromCurly)="$initialPattern", lastParen="${_lastParenPattern ?? '-'}", lastCurly="${_lastCurlyPattern ?? '-'}"');
    final res = await showModalBottomSheet<_ExampleGenResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExampleGenSheet(initialCount: 10, initialPattern: initialPattern),
    );
    if (!mounted) return;
    if (res != null) {
      // Begin loading and fire API + save flow
      setState(() => _examplesLoading = true);
      try {
        final prompt = await rootBundle.loadString('assets/prompts/examples_prompt.txt');
        // Use user-edited pattern first; fall back to lastCurly
        String pattern = (res.pattern).trim();
        if (pattern.isEmpty) {
          pattern = (_lastCurlyPattern ?? '').trim();
        }
        final sentence = (_lastParenPattern ?? '').trim();
        final count = res.count;
        debugPrint('[Examples] req | pattern(used)="$pattern", sentence(paren)="$sentence", count=$count');

        if (pattern.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('패턴이 비어 있습니다. {{...}}에서 패턴을 추출하거나 시트에서 입력해 주세요.')),
          );
          return;
        }
        if (sentence.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('영어 문장을 찾을 수 없습니다. ((...)) 형태로 문장을 포함해 주세요.')),
          );
          return;
        }

        final List<ExampleItem> data = await _examplesApi.generate(
          prompt: prompt,
          pattern: pattern,
          sentence: sentence,
          count: count,
        );

        // Debug print the received JSON
        try {
          debugPrint('[Examples] resp: ${jsonEncode(data)}');
        } catch (_) {
          debugPrint('[Examples] resp (non-encodable) type=${data.runtimeType}');
        }

        if (!mounted) return;
        // Turn off loading before navigation
        setState(() => _examplesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예문 생성 완료')), // optional feedback
        );
        // Navigate to SpeakingPage
        // Delay to ensure overlay teardown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SpeakingPage(examples: data),
            ),
          );
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예문 생성 실패: $e')),
        );
        debugPrint('[Examples] error: $e');
      } finally {
        // Ensure loading off if we haven't already cleared it
        if (mounted && _examplesLoading) setState(() => _examplesLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('표현 도우미'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                      final display = isUser ? m.content : TextMarkers.stripParen(TextMarkers.stripCurly(m.content));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MessageBubble(
                            content: display,
                            isUser: isUser,
                            color: isUser ? cs.primary : cs.surface,
                            textColor: isUser ? cs.onPrimary : Colors.black,
                          ),
                          if (!isUser)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _ExampleCtaBox(
                                onTap: () {
                                  if (_examplesLoading) return;
                                  _openExampleDialog(m.content);
                                },
                              ),
                            ),
                        ],
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
            if (_examplesLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: cs.primary),
                        const SizedBox(height: 12),
                        Text('예문 생성 중...', style: TextStyle(color: cs.onSurface)),
                      ],
                    ),
                  ),
                ),
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
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
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

class _ExampleCtaBox extends StatelessWidget {
  final VoidCallback onTap;
  const _ExampleCtaBox({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                Text('예문 생성하기', style: tt.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleGenResult {
  final int count;
  final String pattern;
  _ExampleGenResult({required this.count, required this.pattern});
}

class _ExampleGenSheet extends StatefulWidget {
  final int initialCount;
  final String initialPattern;
  const _ExampleGenSheet({required this.initialCount, required this.initialPattern});
  @override
  State<_ExampleGenSheet> createState() => _ExampleGenSheetState();
}

class _ExampleGenSheetState extends State<_ExampleGenSheet> {
  late TextEditingController _countCtrl;
  late TextEditingController _patternCtrl;
  @override
  void initState() {
    super.initState();
    _countCtrl = TextEditingController(text: widget.initialCount.toString());
    _patternCtrl = TextEditingController(text: widget.initialPattern);
  }
  @override
  void dispose() {
    _countCtrl.dispose();
    _patternCtrl.dispose();
    super.dispose();
  }
  void _submit() {
    final countText = _countCtrl.text.trim();
    int count = int.tryParse(countText) ?? widget.initialCount;
    if (count < 1) count = 1;
    if (count > 50) count = 50;
    final pattern = _patternCtrl.text.trim();
    Navigator.of(context).pop(_ExampleGenResult(count: count, pattern: pattern));
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('예문 생성', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '예문 생성 수',
                        hintText: '기본값 10',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _patternCtrl,
                      decoration: InputDecoration(
                        labelText: '예문 패턴',
                        hintText: '{{ 패턴 }} 에서 자동 추출',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('예문 생성하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

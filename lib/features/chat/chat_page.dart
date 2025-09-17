import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show SpellCheckConfiguration, TextCapitalization, SmartDashesType, SmartQuotesType, rootBundle, TextInputFormatter, FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'dart:convert' show jsonEncode;

import 'chat_message.dart';
import '../../services/openai_chat_service.dart';
import '../../services/examples_api.dart';
import '../speaking/speaking_page.dart';
import '../../core/text_markers.dart';
import 'package:englishplease/models/example_item.dart';
import 'package:englishplease/features/review/data/review_repository_prefs.dart';
import 'package:englishplease/features/review/models/review_card.dart';
import 'package:englishplease/features/review/utils/review_id.dart';
import 'package:englishplease/config/app_config.dart';
import 'package:englishplease/features/review/data/review_set_repository_prefs.dart';
import 'package:englishplease/features/review/models/review_set.dart';
import 'package:englishplease/features/review/scheduler/fsrs_scheduler.dart';

class ChatPage extends StatefulWidget {
  final String initialQuery;
  const ChatPage({super.key, required this.initialQuery});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = OpenAIChatService();
  final _examplesApi = ExamplesApi();
  final _reviewRepo = ReviewRepositoryPrefs();
  final _setRepo = ReviewSetRepositoryPrefs();
  int _seq = 0;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _examplesLoading = false;
  String? _streamingMessageId;
  bool _streamingInProgress = false;
  final Map<String, _AssistantMeta> _assistantMeta = {};
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
    final id = _makeId();
    setState(() {
      _messages.add(ChatMessage(
        id: id,
        role: ChatRole.assistant,
        content: content,
        ts: DateTime.now(),
      ));
    });
    _updateAssistantMeta(id, pattern: curly, sentence: paren);
    _debugLogPatterns('appendAssistant');
    _scrollToBottomDeferred();
  }

  void _updateStreamingAssistant(String id, String content, {bool finalize = false}) {
    if (!mounted) return;
    final paren = TextMarkers.extractParen(content);
    final curly = TextMarkers.extractCurly(content);
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      final updated = ChatMessage(
        id: id,
        role: ChatRole.assistant,
        content: content,
        ts: DateTime.now(),
      );
      if (idx >= 0) {
        _messages[idx] = updated;
      } else {
        _messages.add(updated);
      }
    });
    _updateAssistantMeta(id, pattern: curly, sentence: paren);
    if (finalize) {
      _debugLogPatterns('stream-final');
    }
    _scrollToBottomDeferred();
  }

  bool _isMessageStreaming(ChatMessage message) {
    return _streamingInProgress && message.id == _streamingMessageId;
  }

  void _updateAssistantMeta(String messageId, {String? pattern, String? sentence}) {
    final prev = _assistantMeta[messageId];
    final trimmedPattern = pattern?.trim();
    final trimmedSentence = sentence?.trim();
    final nextPattern = (trimmedPattern != null && trimmedPattern.isNotEmpty)
        ? trimmedPattern
        : prev?.pattern;
    final nextSentence = (trimmedSentence != null && trimmedSentence.isNotEmpty)
        ? trimmedSentence
        : prev?.sentence;
    _assistantMeta[messageId] = _AssistantMeta(pattern: nextPattern, sentence: nextSentence);
    if (nextPattern != null && nextPattern.isNotEmpty) {
      _lastCurlyPattern = nextPattern;
    }
    if (nextSentence != null && nextSentence.isNotEmpty) {
      _lastParenPattern = nextSentence;
    }
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
    final streamId = _makeId();
    final buffer = StringBuffer();
    setState(() => _loading = true);
    _streamingMessageId = streamId;
    _streamingInProgress = true;
    try {
      await for (final chunk in _service.askWithHistoryStream(_messages)) {
        if (_streamingMessageId != streamId) {
          _streamingInProgress = false;
          return;
        }
        buffer.write(chunk);
        _updateStreamingAssistant(streamId, buffer.toString());
      }
      if (_streamingMessageId == streamId) {
        final text = buffer.toString();
        if (text.trim().isEmpty) {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == streamId);
              if (idx >= 0) {
                _messages.removeAt(idx);
              }
            });
          }
          _assistantMeta.remove(streamId);
        } else {
          _updateStreamingAssistant(streamId, text, finalize: true);
        }
      }
    } catch (e) {
      if (_streamingMessageId == streamId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('요청 실패: $e')),
          );
        }
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == streamId);
            if (idx >= 0) {
              _messages.removeAt(idx);
            }
          });
        }
        _assistantMeta.remove(streamId);
        _streamingInProgress = false;
      }
    } finally {
      if (_streamingMessageId == streamId) {
        _streamingMessageId = null;
        _streamingInProgress = false;
      }
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

  Future<void> _openExampleDialog({required String messageId, required String assistantText}) async {
    final meta = _assistantMeta[messageId];
    final extractedPattern = TextMarkers.extractCurly(assistantText);
    final extractedSentence = TextMarkers.extractParen(assistantText);
    final fallbackPattern = (_lastCurlyPattern ?? extractedPattern ?? '').trim();
    final fallbackSentence = (_lastParenPattern ?? extractedSentence ?? '').trim();
    final initialPattern = (meta?.pattern?.trim().isNotEmpty == true)
        ? meta!.pattern!.trim()
        : fallbackPattern;
    final initialSentence = (meta?.sentence?.trim().isNotEmpty == true)
        ? meta!.sentence!.trim()
        : fallbackSentence;
    debugPrint('[ExampleSheet] init | msg=$messageId pattern="$initialPattern", sentence="$initialSentence"');
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
        // Use user-edited pattern first; fall back to stored/extracted values
        String pattern = (res.pattern).trim();
        if (pattern.isEmpty) {
          pattern = (meta?.pattern ?? extractedPattern ?? _lastCurlyPattern ?? '').trim();
        }
        final sentence = (meta?.sentence ?? extractedSentence ?? _lastParenPattern ?? '').trim();
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

        // Persist the resolved pattern/sentence for this message
        _updateAssistantMeta(messageId, pattern: pattern, sentence: sentence);

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

        // Auto-add to Review with default rating(2=Good) before navigating
        try {
          await _autoAddExamplesToReview(data);
        } catch (e) {
          debugPrint('[Examples] auto-add failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('복습 자동 추가 실패: $e')),
            );
          }
        }

        if (!mounted) return;
        // Turn off loading before navigation
        setState(() => _examplesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예문 생성 완료 · 복습에 자동 추가(보통)')),
        );
        // Navigate to SpeakingPage (only if we have examples)
        // Delay to ensure overlay teardown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (data.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('예문이 없습니다. 다시 시도해 주세요.')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SpeakingPage(
                examples: data,
                currentSetReps: 0,
                onCompleteRated: _handleSpeakingCompleteRated,
              ),
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

  Future<void> _autoAddExamplesToReview(List<ExampleItem> examples) async {
    if (examples.isEmpty) return;
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch;
    debugPrint('[AutoAdd] start | items=${examples.length}');

    // Ensure storage keys are initialized so first write succeeds
    try {
      await _reviewRepo.ensureInitialized();
    } catch (_) {}
    try {
      await _setRepo.ensureInitialized();
    } catch (_) {}

    // Fetch existing cards once for merging
    final existing = await _reviewRepo.fetchAll();
    final existingById = {for (final c in existing) c.id: c};

    final List<ReviewCard> toUpsert = [];
    final ids = <String>[];
    for (final ex in examples) {
      final id = makeReviewIdForSentence(ex.sentence);
      ids.add(id);
      if (existingById.containsKey(id)) {
        final cur = existingById[id]!;
        // Keep existing scheduling; just bump updatedAt
        toUpsert.add(cur.copyWith(updatedAt: ts));
      } else {
        toUpsert.add(ReviewCard(
          id: id,
          sentence: ex.sentence,
          meaning: ex.meaning,
          createdAt: ts,
          updatedAt: ts,
          due: ts, // available immediately
          reps: 0,
          lapses: 0,
          stability: 2.5,
          difficulty: 5.0,
          lastRating: 2, // default Good
        ));
      }
    }

    if (toUpsert.isNotEmpty) {
      debugPrint('[AutoAdd] upsert cards: ${toUpsert.length}');
      await _reviewRepo.upsertAll(toUpsert);
    }

    // Create/update a review set for these items and assign setId on cards
    final title = examples.first.sentence;
    final setId = await _setRepo.createSet(title: title, itemIds: ids, now: now);
    debugPrint('[AutoAdd] set created/updated: $setId');

    // Fetch again and update setId on the picked cards
    final allNow = await _reviewRepo.fetchAll();
    final picked = allNow.where((c) => ids.contains(c.id)).toList();
    final withSet = picked.map((c) => c.copyWith(setId: setId, updatedAt: ts)).toList();
    if (withSet.isNotEmpty) {
      debugPrint('[AutoAdd] upsert cards with setId: ${withSet.length}');
      await _reviewRepo.upsertAll(withSet);
    }

    debugPrint('[AutoAdd] done');
  }

  Future<void> _handleSpeakingCompleteRated(List<ExampleItem> examples, int rating) async {
    try {
      debugPrint('[SaveFlow][Chat] start | items=${examples.length}, rating=$rating');
      final now = DateTime.now();
      final ts = now.millisecondsSinceEpoch;
      final existing = await _reviewRepo.fetchAll();
      debugPrint('[SaveFlow][Chat] fetched existing cards: ${existing.length}');
      final existingById = {for (final c in existing) c.id: c};

      final List<ReviewCard> toUpsert = [];
      final ids = <String>[];
      for (final ex in examples) {
        final id = makeReviewIdForSentence(ex.sentence);
        ids.add(id);
        final due = AppConfig.immediateReviewAfterComplete
            ? ts
            : FsrsScheduler.dueAtStartOfDayPlusDays(now, 1);
        if (existingById.containsKey(id)) {
          // 기존 카드: reps 변경 없이 setId만 추후 주입, 테스트 모드면 due만 now로 조정
          final cur = existingById[id]!;
          toUpsert.add(cur.copyWith(
            updatedAt: ts,
            due: AppConfig.immediateReviewAfterComplete ? ts : cur.due,
          ));
        } else {
          toUpsert.add(ReviewCard(
            id: id,
            sentence: ex.sentence,
            meaning: ex.meaning,
            createdAt: ts,
            updatedAt: ts,
            due: due,
            reps: 0, // 최초 생성은 0으로, 첫 복습 때 1이 되도록
            lapses: 0,
            stability: 2.5,
            difficulty: 5.0,
            lastRating: 0,
          ));
        }
      }

      if (toUpsert.isNotEmpty) {
        debugPrint('[SaveFlow][Chat] upsert new/updated cards: ${toUpsert.length}');
        await _reviewRepo.upsertAll(toUpsert);
      }

      // 세트 생성 및 카드 setId 주입
      final allNow = await _reviewRepo.fetchAll();
      final picked = allNow.where((c) => ids.contains(c.id)).toList();
      final title = picked.isNotEmpty ? picked.first.sentence : '학습 세트';
      debugPrint('[SaveFlow][Chat] create review set with ${ids.length} items');
      final setId = await _setRepo.createSet(title: title, itemIds: ids, now: now);
      debugPrint('[SaveFlow][Chat] created setId=$setId');
      // 카드에 setId 부여
      final withSet = picked.map((c) => c.copyWith(setId: setId, updatedAt: ts)).toList();
      if (withSet.isNotEmpty) {
        debugPrint('[SaveFlow][Chat] upsert cards with setId: ${withSet.length}');
        await _reviewRepo.upsertAll(withSet);
      }

      // 평점 반영: 세트 + 카드들 1회만 적용
      debugPrint('[SaveFlow][Chat] update set after review | rating=$rating');
      await _setRepo.updateSetAfterReview(setId, rating: rating, now: now);
      for (final cid in ids) {
        debugPrint('[SaveFlow][Chat] update card after review | id=$cid, rating=$rating');
        await _reviewRepo.updateAfterReview(cid, rating: rating, now: now);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복습 카드가 저장되었습니다.')),
      );
      debugPrint('[SaveFlow][Chat] done: success');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
      debugPrint('[SaveFlow][Chat] error: $e');
    }
  }

  // onItemReviewed는 reps 증가에 사용하지 않습니다(중간 진행률 용도로만 남겨둘 수 있음).

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
                      if (!isUser && !_isMessageStreaming(m))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ExampleCtaBox(
                            onTap: () {
                              if (_examplesLoading) return;
                              _openExampleDialog(messageId: m.id, assistantText: m.content);
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                        _MaxIntInputFormatter(50),
                      ],
                      maxLength: 2,
                      decoration: InputDecoration(
                        labelText: '예문 생성 수',
                        hintText: '기본값 10',
                        counterText: '',
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

class _MaxIntInputFormatter extends TextInputFormatter {
  final int max;
  const _MaxIntInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    // digitsOnly already applied, but keep safe-guard
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final capped = n > max ? max : n;
    final s = capped.toString();
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
      composing: TextRange.empty,
    );
  }
}

class _AssistantMeta {
  final String? pattern;
  final String? sentence;
  const _AssistantMeta({this.pattern, this.sentence});
}

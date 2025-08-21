import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ExampleItem {
  final String sentence;
  final String meaning;
  ExampleItem({required this.sentence, required this.meaning});
}

class SpeakingPage extends StatefulWidget {
  final dynamic examples; // JSON from API (list or object)
  const SpeakingPage({super.key, this.examples});

  @override
  State<SpeakingPage> createState() => _SpeakingPageState();
}

class _SpeakingPageState extends State<SpeakingPage> {
  final _tts = FlutterTts();
  final _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _listening = false;
  bool _firstAutoplayDone = false;
  int _index = 0;
  late List<ExampleItem> _items;
  late List<String> _tokens; // normalized tokens (non-empty)
  late List<String> _displayTokens; // original tokens for display
  List<bool> _matchedFlags = const []; // per display token matched flag
  int _matchedCount = 0; // number of matched normalized tokens

  @override
  void initState() {
    super.initState();
    _items = _parseExamples(widget.examples);
    _prepareCard();
    _initTts().whenComplete(() {
      // Try autoplay after TTS initialized
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoplayFirst());
      _maybeAutoplayFirst();
    });
    _initStt();
    // Fallback: try once after first frame as well
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoplayFirst());
  }

  @override
  void dispose() {
    _tts.stop();
    if (_listening) {
      _stt.cancel();
    }
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(1);
    await _tts.setPitch(1.0);
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (s) => debugPrint('[STT] status: $s'),
      onError: (e) => debugPrint('[STT] error: $e'),
    );
    if (mounted) setState(() {});
  }

  List<ExampleItem> _parseExamples(dynamic data) {
    try {
      if (data is List) {
        return data
            .map((e) => ExampleItem(
                  sentence: (e['sentence'] ?? e.toString()).toString(),
                  meaning: (e['meaning'] ?? '').toString(),
                ))
            .toList();
      }
      if (data is Map && data['examples'] is List) {
        final list = data['examples'] as List;
        return list
            .map((e) => ExampleItem(
                  sentence: (e['sentence'] ?? e.toString()).toString(),
                  meaning: (e['meaning'] ?? '').toString(),
                ))
            .toList();
      }
      final s = data?.toString() ?? '';
      if (s.isNotEmpty) {
        return [ExampleItem(sentence: s, meaning: '')];
      }
    } catch (_) {}
    return [ExampleItem(sentence: 'Hello world', meaning: '안녕')];
  }

  void _prepareCard() {
    final item = _items[_index];
    final pair = _tokenize(item.sentence);
    _displayTokens = pair.display;
    _tokens = pair.norm;
    _matchedFlags = List<bool>.filled(_displayTokens.length, false);
    _matchedCount = 0;
    setState(() {});
  }

  ({List<String> display, List<String> norm}) _tokenize(String sentence) {
    final words = sentence.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final norm = <String>[];
    for (final w in words) {
      final cleaned = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleaned.isNotEmpty) norm.add(cleaned);
    }
    return (display: words, norm: norm);
  }

  Future<void> _speak() async {
    // Block TTS while listening (STT active)
    if (_listening) return;
    await _tts.stop();
    final text = _items[_index].sentence;
    await _tts.speak(text);
  }

  void _maybeAutoplayFirst() {
    if (_firstAutoplayDone) return;
    if (!mounted) return;
    if (_listening) return; // respect STT
    if (_items.isEmpty) return;
    _firstAutoplayDone = true; // set first to avoid double triggers
    // Small delayed start can improve reliability on some devices
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _speak();
    });
  }

  Future<void> _toggleListen() async {
    if (!_sttAvailable) return;
    if (_listening) {
      await _stt.cancel();
      setState(() => _listening = false);
      _checkPass();
      return;
    }
    await _tts.stop();
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (result) {
        final txt = result.recognizedWords.toLowerCase();
        final recTokens = txt
            .split(RegExp(r'\s+'))
            .map((e) => e.replaceAll(RegExp(r'[^a-z0-9]'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
        _recomputeMatches(recTokens);
        if (_matchedCount >= _tokens.length) {
          _autoPass();
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _recomputeMatches(List<String> recNormTokens) {
    // Build counts of recognized tokens
    final have = <String, int>{};
    for (final r in recNormTokens) {
      have[r] = (have[r] ?? 0) + 1;
    }
    // Used counters per token while assigning to display positions (left→right)
    final used = <String, int>{};
    final newFlags = List<bool>.filled(_displayTokens.length, false);
    int matched = 0;
    for (int i = 0; i < _displayTokens.length; i++) {
      final raw = _displayTokens[i];
      final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (norm.isEmpty) {
        newFlags[i] = false;
        continue;
      }
      final needAvailable = (have[norm] ?? 0) > (used[norm] ?? 0);
      if (needAvailable) {
        newFlags[i] = true;
        used[norm] = (used[norm] ?? 0) + 1;
        matched++;
      }
    }
    if (matched != _matchedCount || !_listEqualsBool(_matchedFlags, newFlags)) {
      setState(() {
        _matchedFlags = newFlags;
        _matchedCount = matched;
      });
    }
  }

  bool _listEqualsBool(List<bool> a, List<bool> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _checkPass() {
    if (_matchedCount >= _tokens.length) {
      _showPassAndNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 전부 인식되지 않았어요. 다시 시도해 보세요.')),
      );
    }
  }

  void _autoPass() async {
    if (_listening) {
      await _stt.cancel();
      setState(() => _listening = false);
    }
    _showPassAndNext(auto: true);
  }

  void _showPassAndNext({bool auto = false}) {
    // 안내 스낵바 제거: 사용자는 '다음' 버튼으로만 진행
  }

  void _next() {
    // Ensure immediate stop before switching to next item
    if (_listening) {
      _stt.cancel();
      setState(() => _listening = false);
    }
    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
      });
      _prepareCard();
      _speak();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 예문을 완료했습니다.')),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;
    final double cardWidth = math.min(520.0, screenW - 40);
    final double cardHeight = 380.0;
    final double shadowOffsetY = cardWidth * 0.045;
    final double shadowBlur = cardWidth * 0.08;
    final double shadowSpread = -cardWidth * 0.01;
    const double cardRadius = 24.0;

    final item = _items[_index];
    final progress = '${_index + 1}/${_items.length}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('스피킹 연습'), actions: [
        Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(progress)))
      ]),
      body: Align(
        alignment: const Alignment(0, -0.2),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: const Color(0xFF0F172A).withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, shadowOffsetY),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        runSpacing: 6,
                        spacing: 6,
                        children: [
                          for (int i = 0; i < _displayTokens.length; i++)
                            _WordChip(
                              text: _displayTokens[i],
                              matched: (i < _matchedFlags.length) ? _matchedFlags[i] : false,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.meaning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _listening ? null : _speak,
                        icon: const Icon(Icons.volume_up),
                        tooltip: _listening ? '스피킹 중에는 재생할 수 없어요' : 'TTS 재생',
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _sttAvailable ? _toggleListen : null,
                        icon: Icon(_listening ? Icons.stop : Icons.mic),
                        label: Text(_listening ? '스피킹 종료' : '스피킹 시작'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: _matchedCount >= _tokens.length ? _next : null,
                        child: const Text('다음'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String text;
  final bool matched;
  const _WordChip({required this.text, required this.matched});
  @override
  Widget build(BuildContext context) {
    final bg = matched ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = matched ? Colors.green.shade900 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 18, height: 1.2)),
    );
  }
}

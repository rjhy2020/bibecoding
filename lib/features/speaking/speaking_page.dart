import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show HapticFeedback;
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
  static const int _kTimeoutSec = 15;
  static const double _kPassThreshold = 0.5;
  final _tts = FlutterTts();
  final _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _listening = false;
  bool _firstAutoplayDone = false;
  bool _completed = false;
  bool _passHandled = false; // ensure pass handled once per card
  bool _passTtsPlayed = false; // ensure pass TTS plays once per card
  bool _passEffectPlayed = false; // ensure pass effect plays once per card
  int _round = 0; // 0,1,2 for 3 rounds
  int _index = 0;
  late List<ExampleItem> _items;
  late List<String> _tokens; // normalized tokens (non-empty)
  late List<String> _displayTokens; // original tokens for display
  List<bool> _matchedFlags = const []; // per display token matched flag
  List<bool> _maskFlags = const []; // per display token masked flag
  int _matchedCount = 0; // number of matched normalized tokens
  // Timeout / judgement
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  int _remainSec = 0;
  bool _timedOut = false;
  bool _successPulse = false;
  bool _failPulse = false;
  bool _revealMasked = false; // reveal masked words (e.g., after timeout)

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
    _maskFlags = _computeMaskFlags(_displayTokens, _round);
    _matchedCount = 0;
    _passHandled = false;
    _passTtsPlayed = false;
    _passEffectPlayed = false;
    _timedOut = false;
    _remainSec = 0;
    _successPulse = false;
    _failPulse = false;
    _revealMasked = false;
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

  Future<void> _speak({bool force = false}) async {
    // Block TTS while listening or in round 3 unless forced
    if ((_listening || _round == 2) && !force) return;
    if (_listening) {
      try {
        await _stt.cancel();
      } catch (_) {}
      if (mounted) setState(() => _listening = false);
    }
    await _tts.stop();
    final text = _items[_index].sentence;
    await _tts.speak(text);
  }

  List<bool> _computeMaskFlags(List<String> displayTokens, int round) {
    // Round 1: no mask; Round 2: partial mask; Round 3: full mask for content tokens
    final flags = List<bool>.filled(displayTokens.length, false);
    if (round == 0) return flags;
    // Determine which positions are content tokens (norm not empty)
    final contentIdx = <int>[];
    for (int i = 0; i < displayTokens.length; i++) {
      final norm = displayTokens[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (norm.isNotEmpty) contentIdx.add(i);
    }
    if (contentIdx.isEmpty) return flags;
    if (round == 2) {
      for (final i in contentIdx) {
        flags[i] = true;
      }
      return flags;
    }
    // round == 1: partial mask ~35% of content tokens, prefer length > 2
    final sentence = _items[_index].sentence;
    final baseHash = sentence.hashCode;
    int picked = 0;
    final pickedIdx = <int>[];
    for (final i in contentIdx) {
      final raw = displayTokens[i];
      final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final lenOk = norm.length > 2;
      final seed = (baseHash ^ (i * 1103515245 + 12345)) & 0x7fffffff;
      final pct = seed % 100; // 0..99
      final choose = pct < (lenOk ? 35 : 20); // bias toward longer tokens
      if (choose) {
        flags[i] = true;
        picked++;
        pickedIdx.add(i);
      }
    }
    // Ensure at least 2 masked when possible (>=2 content tokens)
    final minRequired = contentIdx.length >= 2 ? 2 : (contentIdx.isNotEmpty ? 1 : 0);
    if (picked < minRequired) {
      // Prefer longer tokens first among remaining
      final remaining = contentIdx.where((i) => !pickedIdx.contains(i)).toList();
      remaining.sort((a, b) {
        int la = displayTokens[a].replaceAll(RegExp(r'[^a-z0-9]'), '').length;
        int lb = displayTokens[b].replaceAll(RegExp(r'[^a-z0-9]'), '').length;
        return lb.compareTo(la);
      });
      for (final i in remaining) {
        flags[i] = true;
        picked++;
        if (picked >= minRequired) break;
      }
    }
    return flags;
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
      if (_round == 0) {
        _speak();
      }
    });
  }

  Future<void> _toggleListen() async {
    if (!_sttAvailable) return;
    if (_listening) {
      await _stt.cancel();
      setState(() => _listening = false);
      _clearTimeouts();
      _checkPass();
      return;
    }
    await _tts.stop();
    setState(() => _listening = true);
    _startTimeout();
    await _stt.listen(
      onResult: (result) {
        final txt = result.recognizedWords.toLowerCase();
        final recTokens = txt
            .split(RegExp(r'\s+'))
            .map((e) => e.replaceAll(RegExp(r'[^a-z0-9]'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
        _recomputeMatches(recTokens);
        if (_matchedCount >= _tokens.length && !_passHandled) {
          _passHandled = true;
          _autoPass();
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _recomputeMatches(List<String> recNormTokens) {
    // Sticky + multi-target substring matching
    final nextFlags = List<bool>.from(
      _matchedFlags.length == _displayTokens.length
          ? _matchedFlags
          : List<bool>.filled(_displayTokens.length, false),
    );
    for (int i = 0; i < _displayTokens.length; i++) {
      final raw = _displayTokens[i];
      final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (norm.isEmpty) continue;
      if (nextFlags[i]) continue; // keep previously matched
      bool hit = false;
      for (final rec in recNormTokens) {
        if (_tokensMatch(norm, rec)) { hit = true; break; }
      }
      if (hit) nextFlags[i] = true;
    }
    int matched = 0;
    for (int i = 0; i < _displayTokens.length; i++) {
      final norm = _displayTokens[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (norm.isEmpty) continue;
      if (i < nextFlags.length && nextFlags[i]) matched++;
    }
    if (matched != _matchedCount || !_listEqualsBool(_matchedFlags, nextFlags)) {
      setState(() {
        _matchedFlags = nextFlags;
        _matchedCount = matched;
      });
    }
  }

  bool _tokensMatch(String target, String rec) {
    if (rec.isEmpty || target.isEmpty) return false;
    if (target == rec) return true;
    // Allow substring match for tokens of length >= 2 (e.g., am ↔ 6am)
    if (rec.length >= 2 && target.contains(rec)) return true;
    if (target.length >= 2 && rec.contains(target)) return true;
    return false;
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
      if (!_passHandled) _passHandled = true;
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
    _clearTimeouts();
    _showPassAndNext(auto: true);
  }

  void _showPassAndNext({bool auto = false}) {
    // Autoplay TTS only once per pass
    if (_passTtsPlayed) return;
    _passTtsPlayed = true;
    // Use a slight delay to avoid contention with STT teardown
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      // Rounds 2 and 3 only: speak after user reads
      if (_round >= 1) {
        _speak(force: true);
      }
      // Play success effect once per pass
      if (!_passEffectPlayed) {
        _passEffectPlayed = true;
        _playSuccessEffect();
      }
    });
  }
  void _startTimeout() {
    _clearTimeouts();
    _timedOut = false;
    _remainSec = _kTimeoutSec;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainSec > 0) {
        setState(() => _remainSec--);
      }
    });
    _timeoutTimer = Timer(Duration(seconds: _kTimeoutSec), _onTimeout);
  }

  void _clearTimeouts() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _onTimeout() {
    if (!mounted) return;
    _timedOut = true;
    _clearTimeouts();
    if (_listening) {
      _stt.cancel();
      _listening = false;
    }
    final total = _tokens.isEmpty ? 1 : _tokens.length;
    final ratio = _matchedCount / total;
    if (ratio >= _kPassThreshold) {
      _playSuccessEffect();
    } else {
      _playFailEffect();
    }
    setState(() {
      _revealMasked = true; // reveal hidden tokens on timeout
    });
  }

  void _playSuccessEffect() {
    HapticFeedback.mediumImpact();
    setState(() => _successPulse = true);
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _successPulse = false);
    });
  }

  void _playFailEffect() {
    HapticFeedback.heavyImpact();
    setState(() => _failPulse = true);
    Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _failPulse = false);
    });
  }

  String _fmtRemainTime() {
    final s = _remainSec.clamp(0, 599);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _next() {
    // Ensure immediate stop before switching to next item
    if (_listening) {
      _stt.cancel();
      setState(() => _listening = false);
    }
    _clearTimeouts();
    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
      });
      _prepareCard();
      if (_round == 0) {
        _speak();
      }
    } else {
      if (_round + 1 < 3) {
        setState(() {
          _index = 0;
          _round++;
        });
        _prepareCard();
        if (_round == 0) {
          _speak();
        }
      } else {
        // Show completion inside the card; do not auto-pop
        setState(() {
          _completed = true;
        });
      }
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
    final progress = '${_round * _items.length + _index + 1}/${_items.length * 3}';

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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: _successPulse
                    ? Colors.green.withOpacity(0.6)
                    : (_failPulse
                        ? Colors.red.withOpacity(0.6)
                        : const Color(0xFF0F172A).withOpacity(0.08)),
                width: _successPulse || _failPulse ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, shadowOffsetY),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                  color: (_successPulse
                          ? Colors.green
                          : (_failPulse ? Colors.red : const Color(0xFF0F172A)))
                      .withOpacity(0.12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_completed)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('완료', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                            SizedBox(height: 12),
                            Text(
                              '모든 예문을 완료했어요! 수고하셨어요 👏',
                              style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
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
                                masked: (i < _maskFlags.length) ? _maskFlags[i] : false,
                                reveal: _revealMasked,
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
                  ],
                  if (_completed)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text('돌아가기'),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (_listening && !_timedOut)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '남은시간 ${_fmtRemainTime()}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _remainSec <= 10
                                    ? Colors.red
                                    : (_remainSec <= 20 ? Colors.orange : Colors.grey[700]),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: (_listening || _round == 2) ? null : _speak,
                              icon: const Icon(Icons.volume_up),
                              tooltip: _round == 2
                                  ? '라운드 3에서는 TTS를 사용할 수 없어요'
                                  : (_listening ? '스피킹 중에는 재생할 수 없어요' : 'TTS 재생'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _sttAvailable ? _toggleListen : null,
                              icon: Icon(_listening ? Icons.stop : Icons.mic),
                              label: Text(_listening ? '스피킹 종료' : '스피킹 시작'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                              onPressed: (_matchedCount >= _tokens.length || _timedOut) ? _next : null,
                              child: Text((_round == 2 && _index == _items.length - 1) ? '완료' : '다음'),
                            ),
                          ],
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
  final bool masked;
  final bool reveal;
  const _WordChip({required this.text, required this.matched, required this.masked, required this.reveal});
  @override
  Widget build(BuildContext context) {
    final bool hide = masked && !matched && !reveal;
    final bg = matched
        ? Colors.green.shade100
        : (hide ? Colors.grey.shade300 : Colors.grey.shade200);
    final fg = matched ? Colors.green.shade900 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hide ? '•••' : text,
        style: TextStyle(color: hide ? Colors.transparent.withOpacity(0.0) : fg, fontSize: 18, height: 1.2),
      ),
    );
  }
}

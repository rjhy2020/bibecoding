import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:englishplease/models/example_item.dart';
import 'package:englishplease/features/review/scheduler/fsrs_scheduler.dart';

class SpeakingPage extends StatefulWidget {
  final List<ExampleItem> examples;
  final ValueChanged<List<ExampleItem>>? onComplete; // deprecated: prefer onCompleteRated
  final Future<void> Function(List<ExampleItem> items, int rating)? onCompleteRated; // 1=어려움,2=보통,3=쉬움
  final ValueChanged<ExampleItem>? onItemReviewed; // 카드별 진행 중간 반영 콜백
  final int? currentSetReps; // 세트의 현재 reps(없으면 0)
  const SpeakingPage({
    super.key,
    required this.examples,
    this.onComplete,
    this.onCompleteRated,
    this.onItemReviewed,
    this.currentSetReps,
  });

  @override
  State<SpeakingPage> createState() => _SpeakingPageState();
}

class _SpeakingPageState extends State<SpeakingPage> {
  // Inactivity timer behavior
  static const int _kInitialInactivitySec = 30; // no input yet
  static const int _kInactivityAfterInputSec = 5; // after any input
  static const double _kPassThreshold = 0.5;
  final _tts = FlutterTts();
  final _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _listening = false;
  bool _firstAutoplayDone = false;
  bool _completed = false;
  bool _completeNotified = false; // notify onComplete once
  bool _passHandled = false; // ensure pass handled once per card
  bool _passTtsPlayed = false; // ensure pass TTS plays once per card
  bool _passEffectPlayed = false; // ensure pass effect plays once per card
  bool _autoListenAfterTtsPending = false; // auto-start STT after TTS in round 1
  int _round = 0; // 0,1,2 for 3 rounds
  int _index = 0;
  late List<ExampleItem> _items;
  late List<String> _tokens; // normalized tokens (non-empty)
  late List<String> _displayTokens; // original tokens for display
  List<bool> _matchedFlags = const []; // per display token matched flag
  List<bool> _maskFlags = const []; // per display token masked flag
  int _matchedCount = 0; // number of matched normalized tokens
  // Timeout / judgement
  late final _InactivityController _inactivity; // handles inactivity timeout
  bool _hadAnyInput = false; // whether any speech input was detected
  bool _timedOut = false;
  bool _successPulse = false;
  bool _failPulse = false;
  bool _revealMasked = false; // reveal masked words (e.g., after timeout)

  @override
  void initState() {
    super.initState();
    _items = widget.examples;
    _prepareCard();
    _initTts().whenComplete(() {
      // Try autoplay after TTS initialized
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoplayFirst());
      _maybeAutoplayFirst();
    });
    _inactivity = _InactivityController(onTimeout: _onTimeout);
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
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (s) => debugPrint('[STT] status: $s'),
      onError: (e) => debugPrint('[STT] error: $e'),
    );
    if (mounted) setState(() {});
  }

  // Examples are now provided as a typed list via the constructor

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
    _hadAnyInput = false;
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
    // If pending, auto-start listening after TTS completes (round 1 only)
    if (_autoListenAfterTtsPending && !_listening && !_passHandled && !_timedOut && _sttAvailable) {
      _autoListenAfterTtsPending = false;
      Future<void>.microtask(() {
        if (mounted && !_listening && !_passHandled && !_timedOut && _sttAvailable) {
          _toggleListen();
        }
      });
    } else {
      _autoListenAfterTtsPending = false;
    }
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
        _autoListenAfterTtsPending = true;
        _speak();
      }
    });
  }

  Future<void> _toggleListen() async {
    if (!_sttAvailable) return;
    if (_listening) {
      await _stt.cancel();
      setState(() => _listening = false);
      _clearInactivityTimer();
      // Evaluate like timeout: score by current match ratio and show effect
      _evaluateManualStop();
      return;
    }
    // Manual start overrides any pending auto-start after TTS
    _autoListenAfterTtsPending = false;
    await _tts.stop();
    setState(() => _listening = true);
    _startInactivityTimer(_kInitialInactivitySec);
    await _stt.listen(
      onResult: (result) {
        // Guard: ignore any late results after pass/timeout or when not listening
        if (!_listening || _passHandled || _timedOut) {
          return;
        }
        final txt = result.recognizedWords.toLowerCase();
        final recTokens = txt
            .split(RegExp(r'\s+'))
            .map((e) => e.replaceAll(RegExp(r'[^a-z0-9]'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
        // Any input (not necessarily correct) resets inactivity timer to 5s
        if (txt.trim().isNotEmpty) {
          if (!_hadAnyInput) _hadAnyInput = true;
          _restartInactivityTimer(_kInactivityAfterInputSec);
        }
        _recomputeMatches(recTokens);
        if (_matchedCount >= _tokens.length && !_passHandled) {
          _autoPass();
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      // Increase silence tolerance to 30s so recognition doesn't stop too quickly
      pauseFor: const Duration(seconds: 30),
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

  void _forcePass() {
    // Mark all content tokens as matched and finalize pass
    final nextFlags = List<bool>.from(
      _matchedFlags.length == _displayTokens.length
          ? _matchedFlags
          : List<bool>.filled(_displayTokens.length, false),
    );
    for (int i = 0; i < _displayTokens.length; i++) {
      final norm = _displayTokens[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (norm.isNotEmpty) nextFlags[i] = true;
    }
    setState(() {
      _matchedFlags = nextFlags;
      _matchedCount = _tokens.length;
    });
    _autoPass();
  }

  void _evaluateManualStop() {
    // Mimic timeout behavior: evaluate current progress and show success/fail effect,
    // reveal masked tokens, enable Next by setting _timedOut.
    _autoListenAfterTtsPending = false;
    _timedOut = true;
    _clearInactivityTimer();
    if (_listening) {
      try { _stt.cancel(); } catch (_) {}
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
      _revealMasked = true;
    });
    _speak(force: true);
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
    _finalizePass();
  }

  void _showPassAndNext({bool auto = false}) {
    // Success effect: trigger immediately (only once)
    if (!_passEffectPlayed) {
      _passEffectPlayed = true;
      _playSuccessEffect();
    }
    // Rounds 2 and 3 (round >= 1): play TTS immediately on pass
    if (_round >= 1 && !_passTtsPlayed) {
      _passTtsPlayed = true;
      if (_listening) {
        try {
          _stt.cancel();
        } catch (_) {}
        setState(() => _listening = false);
      }
      _autoListenAfterTtsPending = false;
      _speak(force: true);
    }
  }
  void _startInactivityTimer(int seconds) {
    _timedOut = false;
    _inactivity.start(seconds);
  }

  void _restartInactivityTimer(int seconds) {
    _inactivity.bump(seconds);
  }

  void _clearInactivityTimer() {
    _inactivity.cancel();
  }

  void _onTimeout() {
    if (!mounted) return;
    // Guard: if already passed or not actively listening, ignore spurious timeout
    if (_passHandled || !_listening) {
      return;
    }
    _autoListenAfterTtsPending = false;
    _timedOut = true;
    _clearInactivityTimer();
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
    // After timeout, always read the sentence via TTS regardless of round
    _speak(force: true);
  }

  void _finalizePass() {
    if (_passHandled) return;
    _passHandled = true;
    _timedOut = false;
    _clearInactivityTimer();
    _showPassAndNext(auto: true);
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

  void _next() {
    // 현재 카드에 대해 콜백 통지 (Good 고정)
    if (_index >= 0 && _index < _items.length) {
      final cbItem = widget.onItemReviewed;
      if (cbItem != null) {
        try { cbItem(_items[_index]); } catch (_) {}
      }
    }
    // Ensure immediate stop before switching to next item
    if (_listening) {
      _stt.cancel();
      setState(() => _listening = false);
    }
    _clearInactivityTimer();
    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
      });
      _prepareCard();
      if (_round == 0) {
        _autoListenAfterTtsPending = true;
        _speak();
      } else {
        _autoListenAfterTtsPending = false;
        Future<void>.microtask(() {
          if (mounted && !_listening && _sttAvailable) _toggleListen();
        });
      }
    } else {
      if (_round + 1 < 3) {
        setState(() {
          _index = 0;
          _round++;
        });
        _prepareCard();
        if (_round == 0) {
          _autoListenAfterTtsPending = true;
          _speak();
        } else {
          _autoListenAfterTtsPending = false;
          Future<void>.microtask(() {
            if (mounted && !_listening && _sttAvailable) _toggleListen();
          });
        }
      } else {
        // Show completion inside the card; do not auto-pop
        setState(() {
          _completed = true;
        });
        if (!_completeNotified) {
          _completeNotified = true;
          final cb = widget.onComplete;
          if (cb != null) {
            try {
              cb(_items);
            } catch (_) {}
          }
        }
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
                    _RatingSelector(
                      currentReps: widget.currentSetReps ?? 0,
                      onSelect: (rating) async {
                        // 중복 실행 방지 로직 제거하고 직접 실행
                        final cbRated = widget.onCompleteRated;
                        final cbLegacy = widget.onComplete;

                        if (cbRated != null) {
                          try {
                            await cbRated(_items, rating);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('저장 실패: $e')),
                            );
                            return; // 실패 시 현재 화면 유지
                          }
                        } else if (cbLegacy != null) {
                          try {
                            cbLegacy(_items);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('저장 실패: $e')),
                            );
                            return;
                          }
                        }

                        if (!mounted) return;
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    Column(
                      children: [
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

class _InactivityController {
  final VoidCallback onTimeout;
  Timer? _timer;
  bool _fired = false;

  _InactivityController({required this.onTimeout});

  void start(int seconds) {
    cancel();
    _fired = false;
    _timer = Timer(Duration(seconds: seconds), _fire);
  }

  void bump(int seconds) {
    start(seconds);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    onTimeout();
  }
}

class _RatingSelector extends StatelessWidget {
  final int currentReps; // 세트의 현재 reps
  final Future<void> Function(int) onSelect; // 1,2,3
  const _RatingSelector({required this.currentReps, required this.onSelect});

  String _label(int rating) {
    final nextReps = currentReps + 1;
    final days = FsrsScheduler.intervalDaysForRating(nextReps, rating);
    final text = days <= 0 ? '오늘' : '${days}일 뒤';
    switch (rating) {
      case 1:
        return '어려움 · $text';
      case 2:
        return '보통 · $text';
      case 3:
      default:
        return '쉬움 · $text';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text('난이도를 선택해 주세요', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonal(
              onPressed: () { onSelect(1); },
              child: Text(_label(1)),
            ),
            FilledButton(
              onPressed: () { onSelect(2); },
              child: Text(_label(2)),
            ),
            FilledButton.tonal(
              onPressed: () { onSelect(3); },
              child: Text(_label(3)),
            ),
          ],
        ),
      ],
    );
  }
}

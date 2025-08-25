import 'package:flutter/material.dart';

import 'package:englishplease/features/review/data/review_repository_prefs.dart';
import 'package:englishplease/features/review/data/review_set_repository_prefs.dart';
import 'package:englishplease/features/review/models/review_set.dart';
import 'package:englishplease/features/review/models/review_card.dart';
import 'package:englishplease/models/example_item.dart';
import 'package:englishplease/features/speaking/speaking_page.dart';

class ReviewHomePage extends StatefulWidget {
  const ReviewHomePage({super.key});
  @override
  State<ReviewHomePage> createState() => _ReviewHomePageState();
}

class _ReviewHomePageState extends State<ReviewHomePage> {
  final _cardRepo = ReviewRepositoryPrefs();
  final _setRepo = ReviewSetRepositoryPrefs();
  bool _loading = true;
  List<ReviewSet> _dueSets = const [];
  List<ReviewSet> _allSets = const [];
  int _kpiDueToday = 0;
  int _kpiOverdue = 0;
  int _kpiTotal = 0;
  bool _starting = false;
  String? _currentSetId;

  _Filter _filter = _Filter.due; // 기본: 오늘/지연 포함 due 기준

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _setRepo.fetchDueSets();
      final all = await _setRepo.fetchAllSets();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final sod = startOfDay.millisecondsSinceEpoch;
      final eod = endOfDay.millisecondsSinceEpoch;
      int dueToday = 0;
      int overdue = 0;
      for (final s in all) {
        if (s.due <= eod) dueToday++;
        if (s.due < sod) overdue++;
      }
      if (!mounted) return;
      setState(() {
        _dueSets = list;
        _allSets = all;
        _kpiTotal = all.length;
        _kpiDueToday = dueToday;
        _kpiOverdue = overdue;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSet(String setId) async {
    // 세트 삭제 + 포함 카드도 삭제(간단 구현)
    final set = await _setRepo.getById(setId);
    await _setRepo.deleteSet(setId);
    if (set != null) {
      for (final id in set.itemIds) {
        await _cardRepo.delete(id);
      }
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('세트를 삭제했습니다.')),
    );
  }

  Future<void> _startReview() async {
    if (_visibleSets.isEmpty || _starting) return;
    setState(() => _starting = true);
    final set = _visibleSets.first; // 현재 필터에서 가장 먼저 due된 세트 하나만 실행
    _currentSetId = set.id;
    // 세트의 카드 로드
    final allCards = await _cardRepo.fetchAll();
    final cards = allCards.where((c) => set.itemIds.contains(c.id)).toList();
    final examples = cards.map((c) => ExampleItem(sentence: c.sentence, meaning: c.meaning)).toList(growable: false);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpeakingPage(
            examples: examples,
            onComplete: _onSpeakingComplete,
            onItemReviewed: _onItemReviewed,
          ),
        ),
      );
      // 돌아오면 리스트 갱신
      await _load();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _onItemReviewed(ExampleItem it) async {
    // 중간 저장에서는 reps를 증가시키지 않음(무시)
  }

  Future<void> _onSpeakingComplete(List<ExampleItem> items) async {
    // 세트 완료: 세트 Good(2) 스케줄 갱신 + 포함 카드들 1회만 Good 적용
    final setId = _currentSetId;
    if (setId != null) {
      final now = DateTime.now();
      await _setRepo.updateSetAfterReview(setId, rating: 2, now: now);
      final s = await _setRepo.getById(setId);
      if (s != null) {
        for (final cid in s.itemIds) {
          await _cardRepo.updateAfterReview(cid, rating: 2, now: now);
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('세트 복습 완료!')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('복습'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _KpiChip(label: '오늘', value: _kpiDueToday.toString(), color: cs.primary),
                        const SizedBox(width: 8),
                        _KpiChip(label: '지연', value: _kpiOverdue.toString(), color: Colors.redAccent),
                        const SizedBox(width: 8),
                        _KpiChip(label: '전체', value: _kpiTotal.toString(), color: cs.secondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 필터 토글
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('오늘/지연'),
                          selected: _filter == _Filter.due,
                          onSelected: (_) => setState(() => _filter = _Filter.due),
                        ),
                        ChoiceChip(
                          label: const Text('지연만'),
                          selected: _filter == _Filter.overdue,
                          onSelected: (_) => setState(() => _filter = _Filter.overdue),
                        ),
                        // '전체' 필터는 제거
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_dueSets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          '오늘 복습할 세트가 없어요',
                          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _visibleSets.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = _visibleSets[i];
                        return Dismissible(
                          key: ValueKey('revset_${s.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteSet(s.id),
                          child: ListTile(
                            title: Text(s.title),
                            subtitle: Text('예문 ${s.count}개 · 다음 복습: ${DateTime.fromMillisecondsSinceEpoch(s.due)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteSet(s.id),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _visibleSets.isEmpty || _starting ? null : _startReview,
              child: _starting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Text('복습 시작하기 (세트 ${_visibleSets.length})'),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

enum _Filter { due, overdue }

extension on _ReviewHomePageState {
  List<ReviewSet> get _visibleSets {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    switch (_filter) {
      case _Filter.due:
        return _allSets.where((s) => s.due <= DateTime.now().millisecondsSinceEpoch).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
      case _Filter.overdue:
        return _allSets.where((s) => s.due < startOfDay).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    }
  }
}

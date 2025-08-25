import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SpellCheckConfiguration, TextCapitalization, SmartDashesType, SmartQuotesType;
import 'package:englishplease/ui/constants.dart';
import 'package:englishplease/features/chat/chat_page.dart';

import 'models/recent_phrase.dart';
import 'widgets/font_warm_up.dart';
import 'widgets/metric_card.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/recent_phrase_tile.dart';
import '../review/ui/review_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final _recent = const [
    RecentPhrase(text: "I'm over the moon", meaning: "매우 기뻤다", difficulty: "쉬움"),
    RecentPhrase(text: "Break a leg", meaning: "행운을 빌어!", difficulty: "보통"),
  ];

  void _onSearch() {
    final q = _searchCtrl.text.trim();
    FocusScope.of(context).unfocus();
    if (q.isEmpty) return;
    _searchCtrl.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(initialQuery: q)),
    );
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            final kpiTwoColumn = constraints.maxWidth < 520;
            final isTiny = constraints.maxWidth < 380;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(kGap16, kGap16, kGap16, kGap24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FontWarmUp(),
                  Text(
                    '안녕하세요! 👋',
                    style: text.bodySmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: kGap8),
                  Text(
                    '오늘도 영어 공부해볼까요?',
                    style: text.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: kGap16),

                  Container(
                    padding: const EdgeInsets.all(kGap20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kRadius20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6A4DF5), Color(0xFF8A63FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '궁금한 영어 표현이 있나요?',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: kGap4),
                        Text(
                          '자연스러운 원어민 표현을 알려드릴게요!',
                          style: text.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.95)),
                        ),
                        const SizedBox(height: kGap12),
                        if (isTiny)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 48,
                                child: TextField(
                                  key: const ValueKey('home_search_input'),
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  onSubmitted: (_) => _onSearch(),
                                  textInputAction: TextInputAction.search,
                                  maxLines: 1,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textCapitalization: TextCapitalization.none,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: "예: '화가 날 때' 표현을 알고 싶어요",
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: kGap8),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: cs.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _onSearch,
                                  child: const Text('검색'),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: TextField(
                                    key: const ValueKey('home_search_input'),
                                    controller: _searchCtrl,
                                    focusNode: _searchFocus,
                                    onSubmitted: (_) => _onSearch(),
                                    textInputAction: TextInputAction.search,
                                    maxLines: 1,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textCapitalization: TextCapitalization.none,
                                    smartDashesType: SmartDashesType.disabled,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.search),
                                      hintText: "예: '화가 날 때' 표현을 알고 싶어요",
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: kGap8),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: cs.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _onSearch,
                                  child: const Text('검색'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: kGap20),

                  if (!kpiTwoColumn)
                    Row(
                      children: const [
                        Expanded(child: MetricCard(icon: Icons.trending_up, title: '학습 연속일', value: '7일')),
                        SizedBox(width: kGap12),
                        Expanded(child: MetricCard(icon: Icons.sticky_note_2, title: '복습 대기', value: '12개')),
                        SizedBox(width: kGap12),
                        Expanded(child: MetricCard(icon: Icons.mic, title: '지금까지 연습한 문장', value: '24개')),
                      ],
                    )
                  else
                    Wrap(
                      spacing: kGap12,
                      runSpacing: kGap12,
                      children: [
                        SizedBox(
                          width: (constraints.maxWidth - kGap12) / 2,
                          child: const MetricCard(icon: Icons.trending_up, title: '학습 연속일', value: '7일'),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - kGap12) / 2,
                          child: const MetricCard(icon: Icons.sticky_note_2, title: '복습 대기', value: '12개'),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - kGap12) / 2,
                          child: const MetricCard(icon: Icons.mic, title: '지금까지 연습한 문장', value: '24개'),
                        ),
                      ],
                    ),

                  const SizedBox(height: kGap20),

                  Text('빠른 복습', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
                  const SizedBox(height: kGap12),
                  if (isNarrow)
                    SizedBox(
                      height: 130,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          QuickActionCard(
                            icon: Icons.autorenew,
                            title: '복습하기',
                            caption: '오늘 예정 카드 보기',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewHomePage())),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: QuickActionCard(
                            icon: Icons.autorenew,
                            title: '복습하기',
                            caption: '오늘 예정 카드 보기',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewHomePage())),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: kGap20),

                  Text('최근 학습한 표현', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
                  const SizedBox(height: kGap12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recent.length,
                    separatorBuilder: (_, __) => const SizedBox(height: kGap8),
                    itemBuilder: (context, i) {
                      final item = _recent[i];
                      return RecentPhraseTile(phrase: item);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: Center(child: Text('학습 페이지 준비중', style: tt.titleLarge)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/chat/chat_page.dart';

Future<void> _preloadFonts() async {
  final loader = FontLoader('GowunDodum')
    ..addFont(rootBundle.load('assets/fonts/GowunDodum-Regular.ttf'));
  await loader.load();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _preloadFonts();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const EnglishPlease());
}

class EnglishPlease extends StatelessWidget {
  const EnglishPlease({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnglishPlease',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'GowunDodum',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8DEF)),
        // Flutter 최신: CardThemeData 사용 + 표면 틴트 제거(어둑함 방지)
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

/* ============================== Constants ============================== */
const double kGap4 = 4.0;
const double kGap8 = 8.0;
const double kGap12 = 12.0;
const double kGap16 = 16.0;
const double kGap20 = 20.0;
const double kGap24 = 24.0;
const double kRadius16 = 16.0;
const double kRadius20 = 20.0;

/* ============================== Data Models ============================== */
class RecentPhrase {
  final String text;
  final String meaning;
  final String difficulty;
  const RecentPhrase({required this.text, required this.meaning, required this.difficulty});
}

class FontWarmUp extends StatelessWidget {
  const FontWarmUp({super.key});
  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: Text(
        '가나다라마바사아자차카타파하',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/* ============================== Home Page ============================== */
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
    // 채팅으로 이동 후 홈 입력창은 초기화
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

    return Scaffold( // ✅ 핵심 수정: Scaffold 추가
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
                // 1) Top greeting
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

                  // 2) Purple gradient hero card
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

                  // 3) KPI row (responsive)
                  if (!kpiTwoColumn)
                    Row(
                      children: const [
                        Expanded(
                          child: MetricCard(
                            icon: Icons.trending_up,
                            title: '학습 연속일',
                            value: '7일',
                          ),
                        ),
                        SizedBox(width: kGap12),
                        Expanded(
                          child: MetricCard(
                            icon: Icons.sticky_note_2,
                            title: '복습 대기',
                            value: '12개',
                          ),
                        ),
                        SizedBox(width: kGap12),
                        Expanded(
                          child: MetricCard(
                            icon: Icons.mic,
                            title: '지금까지 연습한 문장',
                            value: '24개',
                          ),
                        ),
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

                  // 4) "빠른 복습" + action cards (responsive)
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
                            caption: '12개 대기중',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearnPage())),
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
                            caption: '12개 대기중',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearnPage())),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: kGap20),

                  // 5) Recent phrases
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

/* ============================== Small Widgets ============================== */
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const MetricCard({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 88,
      padding: const EdgeInsets.all(kGap16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: tt.bodySmall?.copyWith(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: kGap4),
                Text(value, style: tt.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bool light = Theme.of(context).brightness == Brightness.light;

    return SizedBox(
      width: 280,
      height: 120,
      child: Card(
        // 라이트: 흰색 / 다크: surface
        color: light ? Colors.white : cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius20),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius20),
          overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.pressed)) return cs.primary.withOpacity(0.08);
            if (states.contains(MaterialState.hovered) || states.contains(MaterialState.focused)) {
              return cs.primary.withOpacity(0.04);
            }
            return Colors.transparent;
          }),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(kGap16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: kGap12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: kGap4),
                      Text(caption, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecentPhraseTile extends StatelessWidget {
  final RecentPhrase phrase;
  const RecentPhraseTile({super.key, required this.phrase});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(kRadius16),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kGap16, vertical: kGap12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phrase.text, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: kGap4),
                    Text(phrase.meaning, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================== Placeholder Pages ============================== */
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(title: '학습');
  }
}

class SpeakingPage extends StatefulWidget {
  const SpeakingPage({super.key});
  @override
  State<SpeakingPage> createState() => _SpeakingPageState();
}

class _SpeakingPageState extends State<SpeakingPage> {
  final List<_Msg> _messages = <_Msg>[
    const _Msg(text: '안녕하세요! 표현을 알려드릴게요 😊', mine: false),
  ];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  void _send() {
    final t = _inputCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: t, mine: true));
      _messages.add(const _Msg(text: '예문과 함께 연습문장을 만들어드릴게요!', mine: false));
    });
    _inputCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final tinyChat = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      // ✅ FIX: 여기서도 자동 리사이즈 끔. 아래 AnimatedPadding만으로 처리.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('채팅')),
      body: Column(
        children: [
          // messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: m.mine ? cs.primaryContainer : cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                    ),
                    child: Text(
                      m.text,
                      style: tt.bodyMedium?.copyWith(color: m.mine ? cs.onPrimaryContainer : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          // input bar
          AnimatedPadding(
            // ✅ 창 줄이거나 키보드 올라올 때 overflow 없이 위로 안전하게 올림
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets),
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.25))),
                ),
                child: tinyChat
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _inputCtrl,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: '메시지를 입력하세요',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 40,
                        width: 40,
                        child: FilledButton(
                          onPressed: _send,
                          child: const Icon(Icons.send, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _inputCtrl,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      width: 48,
                      child: FilledButton(
                        onPressed: _send,
                        child: const Icon(Icons.send, size: 18),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool mine;
  const _Msg({required this.text, required this.mine});
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(title: '프로필');
  }
}

class _PlaceholderScaffold extends StatelessWidget {
  final String title;
  const _PlaceholderScaffold({required this.title});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title 페이지 준비중', style: tt.titleLarge),
      ),
    );
  }
}

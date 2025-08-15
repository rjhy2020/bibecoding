import 'package:flutter/material.dart';

void main() => runApp(const EnglishPlease());

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8DEF)),
      ),
      home: const MainNav(),
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

/* ============================== Navigation Shell ============================== */
class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    LearnPage(),
    SpeakingPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '집'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: '학습'),
          NavigationDestination(icon: Icon(Icons.mic), label: '스피킹'),
          NavigationDestination(icon: Icon(Icons.person), label: '프로필'),
        ],
        indicatorColor: cs.primaryContainer.withOpacity(0.4),
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

  final _recent = const [
    RecentPhrase(text: "I'm over the moon", meaning: "매우 기뻤다", difficulty: "쉬움"),
    RecentPhrase(text: "Break a leg", meaning: "행운을 빌어!", difficulty: "보통"),
  ];

  void _onSearch() {
    final q = _searchCtrl.text.trim();
    // Behavior: print query to console
    // ignore: avoid_print
    print('Search query: $q');
    if (q.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색: $q')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final kpiTwoColumn = constraints.maxWidth < 520;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kGap16, kGap16, kGap16, kGap24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                height: 120,
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
                    Text('궁금한 영어 표현이 있나요?',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                    const SizedBox(height: kGap4),
                    Text('자연스러운 원어민 표현을 알려드릴게요!',
                        style: text.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.95))),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => _onSearch(),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: const Icon(Icons.search),
                              hintText: "예: '화가 날 때' 표현을 알고 싶어요",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        const SizedBox(width: kGap8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.trending_up,
                        title: '학습 연속일',
                        value: '7일',
                      ),
                    ),
                    const SizedBox(width: kGap12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.sticky_note_2,
                        title: '복습 대기',
                        value: '12개',
                      ),
                    ),
                    const SizedBox(width: kGap12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.mic,
                        title: '발음 점수',
                        value: '85점',
                      ),
                    ),
                  ],
                )
              else
                // 2x2 느낌 (narrow): Wrap with 2 columns
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
                      child: const MetricCard(icon: Icons.mic, title: '발음 점수', value: '85점'),
                    ),
                  ],
                ),
              const SizedBox(height: kGap20),

              // 4) "빠른 학습" + action cards (responsive)
              Text('빠른 학습', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
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
                      const SizedBox(width: kGap12),
                      QuickActionCard(
                        icon: Icons.record_voice_over,
                        title: '스피킹 연습',
                        caption: '발음 향상',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakingPage())),
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
                    const SizedBox(width: kGap12),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.record_voice_over,
                        title: '스피킹 연습',
                        caption: '발음 향상',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakingPage())),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: kGap20),

              // 5) Recent phrases
              Text('최근 학습한 표현', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
              const SizedBox(height: kGap12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
                child: ListView.separated(
                  itemCount: _recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: kGap8),
                  itemBuilder: (context, i) {
                    final item = _recent[i];
                    return RecentPhraseTile(phrase: item);
                  },
                ),
              ),
            ],
          ),
        );
      },
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

    return SizedBox(
      width: 280,
      height: 120,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(kGap16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(phrase.text, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: kGap4),
                  Text(phrase.meaning, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 14)),
                ]),
              ),
              const SizedBox(width: kGap12),
              Chip(
                label: Text(phrase.difficulty, style: tt.labelMedium),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                backgroundColor: cs.surfaceVariant.withOpacity(0.4),
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

class SpeakingPage extends StatelessWidget {
  const SpeakingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(title: '스피킹');
  }
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

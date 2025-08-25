import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/home/home_page.dart';

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
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}


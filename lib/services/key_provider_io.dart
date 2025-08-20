import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

Future<String> loadOpenAIKey() async {
  try {
    // Highest priority: direct env var
    final envKey = Platform.environment['OPENAI_API_KEY'];
    if (envKey != null && envKey.trim().isNotEmpty) {
      debugPrint('[KeyProvider][io] using OPENAI_API_KEY env');
      return envKey.trim();
    }

    // Next: env var pointing to a file
    final pathFromEnv = Platform.environment['OPENAI_API_KEY_FILE'];
    if (pathFromEnv != null && pathFromEnv.trim().isNotEmpty) {
      final f = File(pathFromEnv.trim());
      if (await f.exists()) {
        debugPrint('[KeyProvider][io] reading from OPENAI_API_KEY_FILE: ${f.path}');
        return (await f.readAsString()).trim();
      }
    }

    // User request: a single file outside the project folder (Desktop/openai.key)
    // Windows native path
    try {
      if (Platform.isWindows) {
        final candidateWin = r"C:\\Users\\Sang Yoon Yang\\Desktop\\openai.key";
        final f = File(candidateWin);
        if (await f.exists()) {
          debugPrint('[KeyProvider][io] reading from Desktop (Windows): ${f.path}');
          return (await f.readAsString()).trim();
        }
      }
    } catch (_) {}
    // WSL/Linux view of the same Desktop path
    try {
      final candidateWsl = '/mnt/c/Users/Sang Yoon Yang/Desktop/openai.key';
      final f = File(candidateWsl);
      if (await f.exists()) {
        debugPrint('[KeyProvider][io] reading from Desktop (WSL): ${f.path}');
        return (await f.readAsString()).trim();
      }
    } catch (_) {}

    // Default path: ~/.englishplease/openai.key (Windows: %USERPROFILE%)
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final defaultPath = Platform.isWindows
        ? '$home\\.englishplease\\openai.key'
        : '$home/.englishplease/openai.key';
    final f = File(defaultPath);
    if (await f.exists()) {
      debugPrint('[KeyProvider][io] reading from default path: ${f.path}');
      return (await f.readAsString()).trim();
    }

    debugPrint('[KeyProvider][io] no key found at env/desktop/default path');
    return '';
  } catch (e) {
    debugPrint('[KeyProvider][io] error: $e');
    return '';
  }
}

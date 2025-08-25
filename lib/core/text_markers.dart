/// Utilities for extracting and stripping custom markers
/// - Curly pattern: {{ ... }}
/// - Paren pattern: (( ... ))

class TextMarkers {
  /// Extract the first occurrence inside {{ ... }}; returns null if none.
  static String? extractCurly(String text) {
    final re = RegExp(r"\{\{\s*(.*?)\s*\}\}", dotAll: true);
    final m = re.firstMatch(text);
    if (m != null && m.groupCount >= 1) {
      final s = m.group(1)!.trim();
      return s.isEmpty ? null : s;
    }
    return null;
    }

  /// Extract the first occurrence inside (( ... )); returns null if none.
  static String? extractParen(String text) {
    final re = RegExp(r"\(\(\s*(.*?)\s*\)\)", dotAll: true);
    final m = re.firstMatch(text);
    if (m != null && m.groupCount >= 1) {
      final s = m.group(1)!.trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }

  /// Remove all {{ ... }} markers, preserving line breaks and normalizing spaces.
  static String stripCurly(String text) {
    final re = RegExp(r'\{\{\s*[\s\S]*?\s*\}\}');
    final stripped = text.replaceAll(re, '');
    return _normalizeSpaces(stripped);
  }

  /// Remove all (( ... )) markers, preserving line breaks and normalizing spaces.
  static String stripParen(String text) {
    final re = RegExp(r'\(\(\s*[\s\S]*?\s*\)\)');
    final stripped = text.replaceAll(re, '');
    return _normalizeSpaces(stripped);
  }

  static String _normalizeSpaces(String input) {
    return input
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }
}


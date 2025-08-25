String normalizeSentence(String input) {
  return input.toLowerCase().replaceAll(RegExp(r"\s+"), ' ').trim();
}

// FNV-1a 32-bit 해시로 결정적 ID 생성
String makeReviewIdForSentence(String sentence) {
  final norm = normalizeSentence(sentence);
  const int fnvOffset = 0x811c9dc5;
  const int fnvPrime = 0x01000193;
  int hash = fnvOffset;
  for (int i = 0; i < norm.length; i++) {
    hash ^= norm.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  // 36진수 문자열로 압축 + 접두사
  final id = hash.toUnsigned(32).toRadixString(36);
  return 's-$id';
}

String makeReviewSetIdForItems(List<String> itemIds) {
  final sorted = List<String>.from(itemIds)..sort();
  final joined = sorted.join('|');
  const int fnvOffset = 0x811c9dc5;
  const int fnvPrime = 0x01000193;
  int hash = fnvOffset;
  for (int i = 0; i < joined.length; i++) {
    hash ^= joined.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  final id = hash.toUnsigned(32).toRadixString(36);
  return 'rs-$id';
}

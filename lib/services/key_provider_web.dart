Future<String> loadOpenAIKey() async {
  // On web, only --dart-define can provide the key; no file access.
  const key = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  return key;
}


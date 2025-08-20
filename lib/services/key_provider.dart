import 'key_provider_io.dart' if (dart.library.html) 'key_provider_web.dart' as impl;

class KeyProvider {
  static Future<String> loadOpenAIKey() => impl.loadOpenAIKey();
}


import 'json_storage_io.dart' if (dart.library.html) 'json_storage_web.dart' as storage_impl;

class JsonStorage {
  /// Saves [jsonObj] to a file and returns a description (path or download hint).
  static Future<String> saveJson(dynamic jsonObj, String filename) {
    return storage_impl.saveJson(jsonObj, filename);
  }
}


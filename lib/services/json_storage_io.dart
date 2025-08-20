import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

Future<String> saveJson(dynamic jsonObj, String filename) async {
  final jsonStr = jsonObj is String ? jsonObj : jsonEncode(jsonObj);
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/examples');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsString(jsonStr);
  debugPrint('[JsonStorage][io] saved: ${file.path}');
  return file.path;
}


import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint;

Future<String> saveJson(dynamic jsonObj, String filename) async {
  final jsonStr = jsonObj is String ? jsonObj : jsonEncode(jsonObj);
  final bytes = utf8.encode(jsonStr);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  debugPrint('[JsonStorage][web] download triggered: $filename');
  return 'download:$filename';
}


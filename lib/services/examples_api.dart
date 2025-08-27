import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'openai_chat_service.dart';
import 'package:englishplease/models/example_item.dart';

class ExamplesApi {
  static const _openaiUrl = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o';

  final http.Client _client;
  ExamplesApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ExampleItem>> generate({
    required String prompt,
    required String pattern,
    required String sentence,
    required int count,
    String? apiKeyOverride,
  }) async {
    // Guard: Clamp count to 1..50 at the service layer
    final int safeCount = count < 1 ? 1 : (count > 50 ? 50 : count);
    final apiKey = apiKeyOverride ?? await OpenAIChatService.resolveApiKey();
    if (apiKey.isEmpty) {
      throw StateError('OPENAI_API_KEY is not set');
    }

    final userInput = '{{${pattern}}}\n원래문장: ${sentence}\n${safeCount}';
    final body = <String, dynamic>{
      'model': _model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': userInput},
      ],
    };

    debugPrint('[ExamplesApi] POST $_openaiUrl (model=$_model)');
    final resp = await _client
        .post(
          Uri.parse(_openaiUrl),
          headers: {
            'authorization': 'Bearer $apiKey',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('Empty choices');
    }
    final msg = choices.first['message'] as Map<String, dynamic>?;
    final content = msg?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw StateError('No content in response');
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((e) => ExampleItem.fromMap(e as Map<String, dynamic>)).toList();
      }
      if (decoded is Map && decoded['examples'] is List) {
        return (decoded['examples'] as List)
            .map((e) => ExampleItem.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      debugPrint('[ExamplesApi] content not JSON-decodable; returning fallback list');
    }
    // fallback: return a single item with raw content
    return [ExampleItem(sentence: content.trim(), meaning: '')];
  }
}

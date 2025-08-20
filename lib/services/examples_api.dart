import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'openai_chat_service.dart';

class ExamplesApi {
  static const _openaiUrl = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o';

  Future<dynamic> generate({
    required String prompt,
    required String pattern,
    required String sentence,
    required int count,
  }) async {
    final apiKey = await OpenAIChatService.resolveApiKey();
    if (apiKey.isEmpty) {
      throw StateError('OPENAI_API_KEY is not set');
    }

    // Build messages: system(prompt) + user(formatted input)
    final userInput = '{{${pattern}}}\n원래문장: ${sentence}\n${count}';
    final body = <String, dynamic>{
      'model': _model,
      'temperature': 0.2,
      'messages': [
        { 'role': 'system', 'content': prompt },
        { 'role': 'user', 'content': userInput },
      ],
    };

    debugPrint('[ExamplesApi] POST $_openaiUrl (model=$_model)');
    final resp = await http
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

    // Try decoding the content as JSON. If it fails, return raw string.
    try {
      return jsonDecode(content);
    } catch (_) {
      debugPrint('[ExamplesApi] content not JSON-decodable; returning raw string');
      return content;
    }
  }
}

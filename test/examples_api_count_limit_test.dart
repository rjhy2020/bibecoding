import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:englishplease/services/examples_api.dart';

void main() {
  test('ExamplesApi clamps count to 50 in request body', () async {
    final mock = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      // Find the last user message
      final userMsg = messages.reversed.firstWhere((m) => m['role'] == 'user');
      final content = (userMsg['content'] ?? '').toString().trim();
      // The last line should be the clamped count 50
      expect(content.split('\n').last, '50');

      // Return a minimal valid OpenAI response
      final resp = {
        'choices': [
          {
            'message': {
              'content': jsonEncode([
                {'sentence': 'Hello', 'meaning': '안녕'}
              ])
            }
          }
        ]
      };
      return http.Response(jsonEncode(resp), 200);
    });

    final api = ExamplesApi(client: mock);
    final list = await api.generate(
      prompt: 'p',
      pattern: 'pat',
      sentence: 's',
      count: 999, // should clamp to 50
      apiKeyOverride: 'test',
    );
    expect(list.isNotEmpty, true);
  });
}


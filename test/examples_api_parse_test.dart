import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:englishplease/services/examples_api.dart';
import 'package:englishplease/models/example_item.dart';

void main() {
  test('ExamplesApi parses JSON array content to ExampleItem list', () async {
    final mock = MockClient((req) async {
      final body = jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode([
                {'sentence': 'Hello there.', 'meaning': '안녕.'},
                {'sentence': 'Nice to meet you.', 'meaning': '반가워.'}
              ])
            }
          }
        ]
      });
      return http.Response(body, 200);
    });

    final api = ExamplesApi(client: mock);
    final list = await api.generate(prompt: 'p', pattern: 'pat', sentence: 's', count: 2, apiKeyOverride: 'test');
    expect(list, isA<List<ExampleItem>>());
    expect(list.length, 2);
    expect(list.first.sentence, 'Hello there.');
    expect(list.first.meaning, '안녕.');
  });
}

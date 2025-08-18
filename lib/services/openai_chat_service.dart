import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIChatService {
  // 테스트용: --dart-define로 주입하세요 (키 커밋 금지)
  // 예) flutter run -d chrome --dart-define=OPENAI_API_KEY=sk-...
  static const String kOpenAIKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o'; // 비용 절감 시 'gpt-4o-mini'

  final http.Client _client;
  OpenAIChatService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> askExpression(String userQuery) async {
    if (kOpenAIKey.isEmpty) {
      return 'API 키가 설정되지 않았습니다. flutter run 실행 시 --dart-define=OPENAI_API_KEY=... 를 전달해 주세요.';
    }

    final systemPrompt =
        'You are an English expression tutor for Korean learners. '
        'Given a situation or topic from the user, provide 3~5 natural, native-like expressions with short Korean explanations/nuances. '
        'Then provide 10 very short practice sentences (A2~B1), easy to speak aloud. '
        'Keep it concise and practical. Use simple bullet lists. Mix Korean and English to aid understanding.';

    final body = {
      'model': _model,
      'temperature': 0.7,
      'max_tokens': 700,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': userQuery,
        },
      ],
    };

    try {
      final resp = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $kOpenAIKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final msg = choices.first['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
        return '응답을 파싱하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      } else {
        // 서버가 에러를 반환한 경우, 에러 메시지 추출 시도
        try {
          final err = jsonDecode(resp.body) as Map<String, dynamic>;
          final msg = err['error']?['message']?.toString();
          if (msg != null) {
            return '오류: $msg';
          }
        } catch (_) {}
        return '서버 오류(${resp.statusCode}). 잠시 후 다시 시도해 주세요.';
      }
    } on http.ClientException catch (e) {
      return '네트워크 오류: ${e.message}';
    } on FormatException catch (_) {
      return '응답 형식 오류가 발생했습니다.';
    } on Exception catch (e) {
      return '예상치 못한 오류: $e';
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/chat/chat_message.dart';

class OpenAIChatService {
  // 테스트용: --dart-define로 주입하세요 (키 커밋 금지)
  // 예) flutter run -d chrome --dart-define=OPENAI_API_KEY=sk-...
  static const String kOpenAIKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o'; // 비용 절감 시 'gpt-4o-mini'
  static const int _defaultMaxTurns = 12; // 최근 N개 메시지 유지(user/assistant 합계)

  final http.Client _client;
  OpenAIChatService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> askExpression(String userQuery) async {
    if (kOpenAIKey.isEmpty) {
      return 'API 키가 설정되지 않았습니다. flutter run 실행 시 --dart-define=OPENAI_API_KEY=... 를 전달해 주세요.';
    }

    final body = {
      'model': _model,
      'temperature': 0.7,
      'max_tokens': 2000,
      'messages': [
        _systemMessage(),
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

  Future<String> askWithHistory(List<ChatMessage> history, {int? maxTurns}) async {
    if (kOpenAIKey.isEmpty) {
      return 'API 키가 설정되지 않았습니다. flutter run 실행 시 --dart-define=OPENAI_API_KEY=... 를 전달해 주세요.';
    }

    int limit = maxTurns ?? _defaultMaxTurns;

    Map<String, dynamic> buildBody(int turns) {
      final msgs = <Map<String, dynamic>>[];
      msgs.add(_systemMessage());
      for (final m in _trimHistory(history, turns)) {
        if (m.role == ChatRole.user || m.role == ChatRole.assistant) {
          msgs.add({
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          });
        }
      }
      return {
        'model': _model,
        'temperature': 0.7,
        'max_tokens': 2000,
        'messages': msgs,
      };
    }

    Future<http.Response> postOnce(int turns) {
      return _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $kOpenAIKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(buildBody(turns)),
          )
          .timeout(const Duration(seconds: 30));
    }

    try {
      var resp = await postOnce(limit);
      if (resp.statusCode == 413 || _isContextOverflow(resp)) {
        // 컨텍스트 초과: 턴을 줄여 1회 재시도
        limit = (limit / 2).ceil().clamp(2, _defaultMaxTurns);
        resp = await postOnce(limit);
      }

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
        try {
          final err = jsonDecode(resp.body) as Map<String, dynamic>;
          final msg = err['error']?['message']?.toString();
          if (msg != null) return '오류: $msg';
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

  static Map<String, dynamic> _systemMessage() => {
        'role': 'system',
        'content':
          '''**Your Role:** You are an AI assistant designed to help Korean speakers learn natural English expressions. Your task is to take a single Korean sentence from the user, provide a natural English translation, and then offer a structured breakdown of the expression's pattern and usage.

**Input:**
<A single Korean sentence provided by the user will be placed here>

**Output Rules (Strict):**
-   The entire output must be in Korean, except for the English example sentences and vocabulary, which should be written in their original English form.
-   Strictly no formatting: Do not use bold, italics, underlines, emojis, markdown headers (e.g., ##), or code blocks.
-   Numbering: You must use the format `1)` through `8)`. Each subtitle must be followed by a colon.
-   Pattern Consistency: The example sentences in section 7) must strictly adhere to the English pattern presented in section 2).
-   Conventions: Prioritize American English spelling and punctuation. Pronunciation guides must include both IPA and a simple Korean phonetic hint.
-   Grammar Explanations: Keep grammar descriptions concise and clear, focusing on the core concepts to avoid misunderstanding.
-   The very last line of your output must be the English pattern enclosed in double curly braces, like `{{English Pattern}}`, and nothing else.( '9) 영어패턴' 이런거 출력하지마)
-   At the end, print it out like this ((English sentence)). And don't create anything.( '10)영어문장' 이런거 출력하지마)

**Analysis Guidelines (Apply these internally):**
-   Analyze the input Korean sentence for its core meaning (e.g., statement of fact, emotional intensity, preference, habit), conversational context (formality), and lexical tone (casual, neutral, formal).
-   Generate one primary, natural English translation. Also, provide one alternative expression that is either more emotionally emphatic or more neutral.
-   Extract a reusable and structurally sound English pattern (e.g., Gerund as a subject, comparative/superlative, conditional, causative verbs like make/let, `be used to ~ing`). The pattern should be clear and not overly simplified.

**Output Format (Use this exact structure):**

좋아요! 이 표현은 입력 문장의 뉘앙스를 반영해, 단순한 직역을 넘어서 자연스러운 영어 선호/감정/상황을 전달합니다. 아래 형식을 따라 알려드릴게요.

1) 영어 표현:
[One primary English sentence]
(또는 대안: [One alternative sentence, either more emotional or neutral])

2) 패턴:
[The extracted English pattern in a simple template format]
Example: [Gerund] + is my favorite thing in the world

3) 쉽게 이해하기:
A one-sentence summary in Korean of what the expression conveys.
A brief explanation of why this pattern naturally expresses the input's meaning.

4) 뉘앙스/격식:
Describe the expression's tone (casual/neutral/formal), situations where it's appropriate, and contexts to avoid in one or two sentences.

5) 자주 하는 실수:
- 오류: [A common mistake learners make] / 수정: [The corrected form]
- 오류: [Another common mistake] / 수정: [The corrected form]

6) 발음 팁:
Provide 2-3 key phrases with their IPA transcription and a simple Korean phonetic hint.
Example: going home /ˈɡoʊ.ɪŋ hoʊm/ → 고잉 홈 (pronounce it smoothly)
favorite thing /ˈfeɪvərɪt θɪŋ/ → distinguish the 'v' and 'th' sounds

7) 사용 상황 예시 (반드시 패턴 그대로 사용):
One-line context description:
→ [Example sentence 1 using the exact pattern]
One-line context description:
→ [Example sentence 2 using the exact pattern]
One-line context description:
→ [Example sentence 3 using the exact pattern]
→ A one-line guide on the tone of voice (e.g., gently, matter-of-factly).

8) 단어 해설:
Briefly explain 3-5 key vocabulary words.
Example: going (gerund), home (used without 'to'), favorite (most liked), thing (item/concept), in the world (for emphasis)

9) 영어문장 패턴
{{[The English Pattern from section 2]}}

10) 처음 영어문장
((The English Sentence from section 1))

---

**Sample Output (For your reference only. Do not reproduce this. Respond only to the user's new input.)**

좋아요! 이 표현은 단순히 "집에 가고 싶다"를 넘어서, "집에 가는 게 세상에서 제일 좋다", 즉 강한 애정과 선호를 담고 있죠. 그 느낌을 자연스럽게 담은 영어 표현을 아래 형식에 맞춰 안내드릴게요.

1) 영어 표현:
Going home is my favorite thing in the world.
(또는 대안: I absolutely love going home.)

2) 패턴:
[동명사] + is my favorite thing in the world

3) 쉽게 이해하기:
이 표현은 "~하는 것이 세상에서 제일 좋다"는 말이에요. 한국어 "제일 좋아해"처럼 감정을 강조할 때 쓰기 좋습니다. "Going home"은 동명사(동사 + ~ing)로, '집에 가는 것'을 의미합니다.

4) 뉘앙스/격식:
my favorite thing in the world는 아주 일상적이고 감정 표현이 강한 말입니다. 친구나 SNS, 일기 등 비격식적 상황에 딱 어울려요. 더 캐주얼하게는 "I love going home so much."도 가능하고, 공손하거나 감정을 덜 드러내고 싶다면 "I really enjoy going home."이라고 할 수도 있어요.

5) 자주 하는 실수:
- 오류: Go home is my favorite... / 수정: Going home is my favorite...
- 오류: The going home is... / 수정: Going home is...

6) 발음 팁:
Going home은 /ˈɡoʊ.ɪŋ hoʊm/ 으로, "고잉 홈"보다는 "고잉—홈"처럼 자연스럽게 이어지게 발음하세요. favorite thing은 /ˈfeɪ.vər.ɪt θɪŋ/ → '페이버릿 씽'처럼 들리는데, v 발음과 th 발음을 정확히 구분해 주는 게 포인트예요.

7) 사용 상황 예시 (반드시 패턴 그대로 사용):
친구와 노는 중, 조용히 말함:
→ Taking the bus home is my favorite thing in the world.
엄마와 대화 중, 웃으면서 말함:
→ Going home after school is my favorite thing in the world.
여행 중 피곤한 상태에서:
→ Returning home after a long trip is my favorite thing in the world.
→ 톤은 부드럽고 감정을 살려서 말하는 게 자연스럽습니다.

8) 단어 해설:
Going(동명사): go의 ~ing형으로, '가는 것'이라는 뜻.
home: '집'이라는 뜻이지만, 전치사 없이 go home처럼 씀 (go to home X).
favorite: 가장 좋아하는.
thing: 여기서는 '것'을 뜻하는 아주 일반적인 단어예요.
in the world: 세상에서. 감정을 강조하는 표현으로 자주 씁니다.

((Going home is my favorite thing in the world.))
{{[동명사] + is my favorite thing in the world}}

---

**[IMPORTANT] Now, process the user's request based on all the rules above.**
 '''

      };

  static bool _isContextOverflow(http.Response r) {
    if (r.statusCode == 413) return true;
    try {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final code = m['error']?['code']?.toString();
      final message = m['error']?['message']?.toString() ?? '';
      if (code != null && code.contains('context')) return true;
      if (message.contains('maximum') && message.contains('tokens')) return true;
    } catch (_) {}
    return false;
  }

  static List<ChatMessage> _trimHistory(List<ChatMessage> history, int maxTurns) {
    final filtered = history.where((m) => m.role != ChatRole.system).toList();
    if (filtered.length <= maxTurns) return filtered;
    return filtered.sublist(filtered.length - maxTurns);
  }
}

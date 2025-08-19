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
          '''당신의 역할: 한국인 영어 학습자를 위한 설명자. 사용자가 준 한국어 문장을 영어로 자연스럽게 표현하고, 패턴과 사용법을 구조적으로 안내하라.

입력:
<여기에 사용자의 한국어 문장 1개를 넣으세요>

출력 규칙(엄격):
- 전체 출력은 한국어 설명 위주로 하되, 영어 예시 문장과 단어는 원문 그대로 표기한다.
- 굵게/기울임/밑줄 등 어떤 형태의 강조도 금지한다. 이모지 금지. 마크다운 헤더 금지. 코드블록 금지.
- 숫자 목록은 반드시 1)~8)까지 사용한다. 각 소제목 뒤에 콜론을 붙인다.
- 섹션 7의 예문은 반드시 2)에서 제시한 영어 패턴을 그대로 포함해야 한다.
- 미국식 표기와 구두점을 우선한다. 발음은 IPA 표기와 간단한 한국어 발음 힌트를 함께 제시한다.
- 문법 설명은 간결하되 오해가 없도록 핵심만 명시한다.
- 마지막 줄에는 항상 그대로 이 텍스트를 출력한다: {{영어 패턴}}

분석 지침(보이지 않게 적용):
- 입력 문장의 핵심 의미(사실 여부, 감정 세기, 선호/의지/습관 등), 담화 상황(격식도), 어휘 톤(캐주얼/중립/격식)을 파악한다.
- 가장 자연스러운 대표 문장 1개와, 감정 강조형 또는 중립 대안 1개를 추가로 제시한다.
- 영어 패턴은 학습자가 재활용하기 좋은 구조(예: 동명사 주어형, 비교급/최상급, 가정법, make/cause/let형, be used to ~ing 등)로 고르고, 가능한 한 간명한 형태로 제시한다.

출력 형식(그대로 사용):

좋아요! 이 표현은 입력 문장의 뉘앙스를 반영해, 단순한 직역을 넘어서 자연스러운 영어 선호/감정/상황을 전달합니다. 아래 형식을 따라 알려드릴게요.

1) 영어 표현:
[대표 문장 1개]
(또는 대안: [감정 강조형 또는 중립형 1개])

2) 패턴:
[여기에 이번 문장에 사용한 영어 패턴을 간단한 틀로 제시]
예: [동명사] + is my favorite thing in the world

3) 쉽게 이해하기:
이 표현이 전달하는 의미를 한국어로 한 줄 요약.
왜 이 패턴이 입력 의미를 자연스럽게 표현하는지 간단히 설명.

4) 뉘앙스/격식:
이 표현의 톤(캐주얼/중립/격식), 사용하기 좋은 상황, 피해야 할 맥락을 한두 문장으로 설명.

5) 자주 하는 실수:
- 오류: [학습자가 하기 쉬운 오해나 문법 오류] / 수정: [올바른 형태]
- 오류: [또 다른 흔한 오류] / 수정: [올바른 형태]

6) 발음 팁:
핵심 구 2~3개를 IPA로 제시하고 간단한 한국어 힌트를 덧붙인다.
예: going home /ˈɡoʊ.ɪŋ hoʊm/ → 고잉 홈(자연스럽게 이어 발음)
favorite thing /ˈfeɪvərɪt θɪŋ/ → v와 th 소리를 구분

7) 사용 상황 예시 (반드시 패턴 그대로 사용):
상황 설명 1줄:
→ [패턴을 그대로 포함한 예문 1]
상황 설명 1줄:
→ [패턴을 그대로 포함한 예문 2]
상황 설명 1줄:
→ [패턴을 그대로 포함한 예문 3]
→ 말투 가이드를 한 줄로 제시(부드럽게/담백하게 등).

8) 단어 해설:
핵심 단어 3~5개를 간단히 풀이한다.
예: going(동명사), home(전치사 없이 go home), favorite(가장 좋아하는), thing(것), in the world(세상에서; 강조)

9) 영어문장 패턴
마지막줄에 아무것도 붙이지 말고 {{영어패턴}} 이것만 생성한다. 코드에서 인식하기 위함이다.
예: {{[동명사] + is my favorite thing in the world}}

샘플 출력(참고용):
좋아요! 이 표현은 단순히 "집에 가고 싶다"를 넘어서, "집에 가는 게 세상에서 제일 좋다", 즉 강한 애정과 선호를 담고 있죠. 그 느낌을 자연스럽게 담은 영어 표현을 아래 형식에 맞춰 안내드릴게요.

1) 영어 표현:
Going home is my favorite thing in the world.
(또는 감정 강조형: I absolutely love going home.)

2) 패턴:
[동명사] + is my favorite thing in the world

3) 쉽게 이해하기:
이 표현은 "~하는 것이 세상에서 제일 좋다"는 말이에요.
한국어 "제일 좋아해"처럼 감정을 강조할 때 쓰기 좋습니다.
"Going home"은 동명사(동사 + ~ing)로, '집에 가는 것'을 의미합니다.

4) 뉘앙스/격식:
my favorite thing in the world는 아주 일상적이고 감정 표현이 강한 말입니다.
→ 친구나 SNS, 일기 등 비격식적 상황에 딱 어울려요.
더 캐주얼하게는 "I love going home so much."도 가능하고,
공손하거나 감정을 덜 드러내고 싶다면 "I really enjoy going home."이라고 할 수도 있어요.

5) 자주 하는 실수:
Go home is my favorite... → Going home is my favorite...
→ 동사를 문장 주어로 쓸 때는 동명사(동사+ing) 형태가 필요합니다.
The going home is... → Going home is...
→ 동명사는 the 없이 그대로 씁니다.

6) 발음 팁:
Going home은 /ˈɡoʊ.ɪŋ hoʊm/ 으로, "고잉 홈"보다는 "고잉—홈"처럼 자연스럽게 이어지게 발음하세요.
favorite thing은 /ˈfeɪ.vər.ɪt θɪŋ/ → '페이버릿 씽'처럼 들리는데, v 발음과 th 발음을 정확히 구분해 주는 게 포인트예요.

7) 사용 상황 예시 (반드시 패턴 그대로 사용):
친구와 노는 중, 조용히 말함:
→ Taking the bus home is my favorite thing in the world. (버스타고 집에 가는 게 제일 좋아.)
엄마와 대화 중, 웃으면서 말함:
→ Going home after school is my favorite thing in the world. (학교 끝나고 집 가는 게 세상에서 제일 행복해.)
여행 중 피곤한 상태에서:
→ Returning home after a long trip is my favorite thing in the world. (긴 여행 끝에 집에 돌아가는 게 최고야.)
→ 톤은 부드럽고 감정을 살려서 말하는 게 자연스럽습니다.

8) 단어 해설:
Going(동명사): go의 ~ing형으로, '가는 것'이라는 뜻. 동작을 명사처럼 만들어줍니다.
home: '집'이라는 뜻이지만, 전치사 없이 go home처럼 씀 (go to home X).
favorite: 가장 좋아하는.
thing: 여기서는 '것'을 뜻하는 아주 일반적인 단어예요.
in the world: 세상에서. 감정을 강조하는 표현으로 자주 씁니다.

이 "동명사 + is my favorite thing in the world" 패턴으로 예문을 생성할까요?

{{동명사 + is my favorite thing in the world}}

이 예는 출력할때는 없는걸로 치고 답변해.
사용자가 질문하는거에 대한것만 답변해.
그리고 패턴을 너무 단순화시키지마

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

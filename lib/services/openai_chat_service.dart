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
          '''[역할]
  너는 한국어 사용자를 위한 “친절하고 자세한 영어 표현 코치”다. 사용자가 한국어로 “~를 영어로 뭐라고 해?”라고 묻거나 짧은 한국어 표현만 입력해도:
  1) 자연스러운 영어 문장 1개를 제시하고,
  2) 그 문장의 핵심 패턴을 눈에 띄게 표시하며,
  3) 의미/뉘앙스/자주 하는 실수/발음 팁/사용 상황을 “친절하게” 설명하고,
  4) 같은 패턴으로 예문을 (기본 12개) 제시한다.
  설명은 한국어로, 예문/표현은 영어로.

  [출력 규격 — 길이 가드레일]
  항상 아래 섹션을 “모두” 포함하고, 각 섹션은 최소 분량을 지켜라.
  1) 영어 표현: <문장 1개>  ← 굵게 표기
  2) 패턴: <패턴 템플릿 한 줄>  ← 굵게 표기
  3) 쉽게 이해하기(최소 2문장):
  - 이 표현이 무엇을 뜻하고, 어떤 상황에서 자연스러운지 친절하게 설명.
  4) 뉘앙스/격식(최소 2문장):
  - 구어/격식/정중 대안(있으면 1–2개)과 차이 설명.
  5) 자주 하는 실수(최소 2개, 불릿):
  - 한국어식 직역/전치사/어순 등 흔한 오류를 짚고 바로잡는 예시를 함께 제공.
  6) 발음 팁(최소 1문장):
  - 강세/연음/축약을 초급자도 따라 하기 쉽게 설명(간단 IPA 허용).
  7) 사용 상황 예시(최소 3문장):
  - 실제 대화 장면을 한국어로 짧게 그림처럼 제시하고, 어떤 톤이 자연스러운지 말해 줌.
  8) 예문 생성 제안(마무리 질문 1문장):
  - “이 패턴으로 영어 예문들을 생성할까요?”
  9) 예문(사용자가 동의하거나 즉시 요청한 경우에만 출력):
  - 기본 12개(요청 시 개수 맞춤). 모두 동일 패턴.
  - 각 문장 12단어 이내, 미국 일상 톤.
  - 각 문장 아래 한국어 뜻 1줄.
  - 주제가 주어지면 그 주제에 맞는 예문을 최소 30% 포함.

  [핵심 동작]
  - 입력이 “집가고싶다” 같이 짧은 어구여도 위 규격을 그대로 적용.
  - 가장 자연스러운 표현 1개를 고르고, 필요하면 괄호로 대안 1개만 덧붙일 수 있음.
  - 예문 섹션은 사용자가 동의하면 생성. (동의 없이 미리보기 3–5개만 보여달라면 따름.)

  [후속질문 처리]
  - 단어/문법 질문(예: “want가 무슨 뜻?”)에 답할 때 템플릿:
  1) 정의(간단/정확) + 품사/형태(3인칭/과거형 등)
  2) 주요 의미 1–2개
  3) 짧은 예문 2개(영어) + 한국어 뜻
  4) 뉘앙스/주의 1–2개
  5) 관련 대안 1개만(있으면)

  [AVM(음성) 입력 시]
  - 단어 발음: (1) 천천히 정확히 → (2) 자연 속도로 → (3) 사용자가 5회 따라 말하기 루프.
  - 문장 발음: 설명은 한국어, 영어 문장은 미국식 발음으로 또렷하게.

  [스타일 가이드]
  - 톤: 따뜻하고 격려하는 교사 톤. 과한 이모지 금지. 전문용어는 풀어서 설명.
  - 형식: 불릿을 적극 활용하되, 각 섹션 최소 분량 준수. 섹션 생략 절대 금지.
  - 금지: “간단히”, “짧게” 같은 축약 지시. 사용자 요청 없이는 요약하지 말 것.

  [작동 예시]
  사용자 입력: 집가고싶다
  출력(요약 형태 미리보기 — 실제 응답은 아래 규격의 최소 분량을 반드시 채움):
  - 영어 표현: **I want to go home.**
  - 패턴: **I want to + [동사원형]**
  - 쉽게 이해하기: 하고 싶은 ‘행동’을 말하는 가장 기본 패턴입니다. 일상 대화에서 매우 자연스럽습니다.
  - 뉘앙스/격식: want to는 캐주얼합니다. 더 공손하게는 would like to를 씁니다.
  - 자주 하는 실수:
  • go to home ❌ → go home ⭕ (home은 보통 전치사 없이 씀)
  • I’m want to ❌ → I want to ⭕ (be동사와 혼용 금지)
  - 발음 팁: want to는 /wɑnə/처럼 ‘워너’로 약하게 연결됩니다.
  - 사용 상황 예시: 퇴근길, 가족 모임 뒤, 여행 중 피곤할 때 자연스럽습니다. 친한 사이라면 “I really want to go home.”처럼 강조 가능.
  - 예문 생성 제안: 이 패턴으로 영어 예문들을 생성할까요? '''

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

# WORK.md — EnglishPlease 작업 계획 보드

목적: 메인 화면 검색 → 채팅 화면으로 이동 → GPT‑4o API 호출로 답변을 표시하는 채팅 기능을 설계·구현한다. 현재는 테스트 단계이므로 API Key는 코드 내 상수로 임베드한다(후속으로 Functions로 이전).

## Design (UX/UI)
- 흐름: 메인(Home) 검색창에 자유 형식 입력 → 검색 누르면 `ChatPage`로 이동 → 첫 로딩 메시지 표시 후 GPT‑4o 호출 결과를 채팅에 표시 → 하단 입력창으로 후속 질문 가능.
- 라우팅: `HomePage._onSearch()`에서 빈 값만 제외하고 모두 `ChatPage(initialQuery: q)`로 이동.
- 패턴 인식: 형식 제한 없음. 정규식 추출 단계 제거.
- 채팅 UI: 상단 AppBar(제목: "표현 도우미"), 본문은 `ListView`로 메시지 버블(사용자/어시스턴트 구분), 하단 고정 입력바(TextField + Send 아이콘). 로딩 중에는 타이핑 인디케이터(점 3개 애니메이션 또는 CircularProgressIndicator) 노출.
- 메시지 스타일: 사용자 버블는 오른쪽 정렬/primary 색, 어시스턴트는 왼쪽 정렬/surface 색, 긴 텍스트 자동 줄바꿈, 복사 버튼은 후속 개선 항목으로.
- 오류 처리: 네트워크 오류 시 스낵바 + 재시도 버튼, 전송 중 중복 전송 방지(disabled), 응답 시간 초과 시 안내 문구.

## Data & State
- 모델: `ChatMessage { String id, String role(user|assistant|system), String content, DateTime ts }`.
- 상태: `StatefulWidget` 내부에서 `List<ChatMessage> messages`, `bool loading`; 필요 시 `ChangeNotifier`로 분리(초기엔 단순 구현).
- 초기 메시지: 사용자의 `initialQuery`를 즉시 메시지로 추가 후 비동기 API 호출 시작 → 결과를 assistant 메시지로 append.

## API 설계 (테스트용, 키 하드코딩)
- 서비스: `lib/services/openai_chat_service.dart`
  - `class OpenAIChatService { Future<String> askExpression(String contextOrQuery) }`
  - 내부 상수: `const String kOpenAIKey = 'YOUR_TEST_KEY_HERE';` (테스트용 — 커밋 시 키는 임시값으로 유지)
- 엔드포인트: `POST https://api.openai.com/v1/chat/completions`
- 모델: `gpt-4o` (또는 비용 절감을 위해 `gpt-4o-mini` 옵션화)
- 요청 예시 body:
  ```json
  {
    "model": "gpt-4o",
    "temperature": 0.7,
    "max_tokens": 700,
    "messages": [
      {"role": "system", "content": "You are an English expression tutor..."},
      {"role": "user", "content": "화가 날 때 표현을 알고 싶어요"}
    ]
  }
  ```
- 시스템 프롬프트 지침(요약):
  - 사용자가 요청한 상황에 맞춰 자연스러운 원어민 표현 3~5개 제시(각각 한글 설명/뉘앙스 포함)
  - 아주 짧은 연습문장 10개 제공(입·발화하기 쉬운 길이, CEFR A2~B1 정도)
  - 한국어+영어 혼용으로 이해를 돕고, 과도한 장문 설명은 금지(간결/실용 위주)
  - 출력 형식: 간단한 불릿/번호 목록 텍스트(추후 포맷 고도화 예정)

## 파일/구조 변경 계획
- `pubspec.yaml`: `http: ^1.2.x` 의존성 추가
- `lib/services/openai_chat_service.dart`: OpenAI 호출 래퍼(POST, 에러 처리)
- `lib/features/chat/chat_message.dart`: 메시지 모델
- `lib/features/chat/chat_page.dart`: 채팅 화면(UI/상태/전송 로직)
- `lib/main.dart`: `HomePage._onSearch()`에서 `ChatPage`로 내비게이션(자유 형식). 하단 탭 네비게이션 제거.

## 구현 단계 (순서/상태)
1. 의존성 추가: `http` — status: completed
2. 서비스 추가: `openai_chat_service.dart` — status: completed
3. 모델 추가: `chat_message.dart` — status: completed
4. UI 추가: `chat_page.dart` 골격(버블/리스트/입력창) — status: completed
5. 네비게이션 연결: `HomePage._onSearch()` → `ChatPage` — status: completed
6. API 연동: 초기 쿼리 전송·응답 표시 — status: completed
7. 오류/로딩 처리: 스낵바/재시도/중복전송 방지 — status: completed
8. 폴리시 정리: 키 하드코딩 주석/후속 태스크 기록 — status: pending
9. 한글 IME 깜빡임 완화: TextField 재빌드 최소화/제안 비활성 — status: completed
10. 홈 검색 입력 초기화: 채팅 이동 시 clear — status: completed

## Acceptance Criteria
- 메인 검색창에서 "~~표현을 알고싶어요" 입력 후 검색 → 채팅 화면으로 전환된다.
- 채팅 화면에서 초기 사용자 메시지가 보이고, 10초 내 첫 어시스턴트 응답이 나타난다(정상 네트워크 가정).
- 추가 질문을 이어서 보낼 수 있고, 각 요청마다 로딩 인디케이터가 표시된다.
- 오류 상황에서 사용자에게 명확한 피드백과 재시도 옵션이 제공된다.

## Decisions/Notes
- 2025-08-18 — 테스트 단계에서는 OpenAI 키를 코드에 상수로 임베드. 실서비스 이전 시 Firebase Functions 경유로 전환 + 키 제거 필수.
- 2025-08-18 — 초기엔 스트리밍 미사용(간단성 우선). 추후 `/v1/responses` 스트리밍으로 전환 검토.

## Backlog (후속)
- 메시지 복사, 북마크, TTS 버튼
- 스트리밍 응답 UX 개선(토큰 스트림 표시)
- 서버 사이드 프롬프트 표준화 및 사용자 수준/목표(CEFR, 시험 대비 등) 반영
- 테스트(Widget/Service) 추가 및 모킹

## 한글 IME 깜빡임/깨짐 대응 계획
- 증상: 빠르게 한국어를 입력할 때 조합 중 글자가 잠깐 분리/깨져 보였다가 복원되는 현상(특히 Web/Chrome).
- 원인 후보:
  - Web HTML renderer의 IME 처리 특성(플러터에서 DOM 갱신 시 포커스/컴포지션 흔들림)
  - 상위 위젯 `setState`로 입력창이 잦게 리빌드/재마운트됨
  - 스펠체크/자동완성 개입으로 조합 상태가 간섭됨

### 해결 전략(우선순위 순)
1) Web 렌더러 전환: CanvasKit 사용
   - 개발: `flutter run -d chrome --web-renderer canvaskit`
   - 배포: `flutter build web --web-renderer canvaskit`
   - 효과: HTML 렌더러 대비 IME 조합 안정성이 높은 편(메모리/용량은 증가)

2) 입력 위젯 안정화(리빌드 최소화)
   - `TextField`에 안정 키/포커스 노드 부여: `key: ValueKey('home_search_input')`, `final FocusNode _fn = FocusNode()` 재사용
   - 입력 바를 별도 StatefulWidget(`ChatInputBar`)로 분리하고 상위의 `setState`가 입력 위젯을 재생성하지 않도록 구조화
   - `RepaintBoundary`로 입력 바의 리페인트 범위를 분리(스크롤/리스트 갱신 영향 감소)

3) 스펠체크/제안 비활성화(이미 부분 적용, 보강)
   - `spellCheckConfiguration: SpellCheckConfiguration.disabled()`
   - `autocorrect: false`, `enableSuggestions: false`, `textCapitalization: TextCapitalization.none`

4) 상태 갱신 격리
   - 메시지 리스트와 입력 바 상태를 분리(`ChangeNotifier`/`ValueNotifier`)
   - 로딩 인디케이터는 리스트 영역에서만 갱신하고 입력 바는 리빌드하지 않도록 분리 렌더링
   - 리스트 아이템에 `Key` 부여, 필요 시 `AnimatedList` 채택

5) 환경 업데이트/대안
   - 최신 Flutter 안정채널로 업그레이드(IME 관련 패치 포함 가능)
   - 브라우저 별 확인(Chrome/Edge) 및 플랫폼 별(IM/Windows/macOS) 교차 검증

### 구현 단계(IME 이슈 전용)
I1. CanvasKit 기본 런/빌드 설정 추가 — status: pending
I2. 입력 바 위젯 분리 + FocusNode/Key 적용 — status: pending
I3. `spellCheckConfiguration` 명시적으로 비활성화 — status: pending
I4. 메시지/로딩 상태 격리(Provider/ChangeNotifier) — status: pending
I5. 크로스 브라우저/플랫폼 테스트 체크리스트 수행 — status: pending

### Acceptance Criteria
- 고속 한글 입력 중에도 조합(가-가ㅏ 등) 깨짐/깜빡임 없이 연속 입력이 가능하다.
- 채팅 전송/로딩 등 UI 갱신 상황에서도 입력창 커서/조합 상태가 유지된다.

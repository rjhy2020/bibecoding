WORK PLAN — 스피킹 플로우(TTS + 단어별 STT 하이라이트 + 패스/다음)

목표
- 예문(JSON) 데이터를 카드에 반영하고, TTS로 재생한다.
- 스피킹 버튼을 누르면 음성 인식을 시작하고, 인식된 단어를 목표 문장 토큰과 매칭하여 맞춘 단어를 초록색으로 표시한다.
- 스피킹 버튼을 다시 누르거나 모든 단어가 맞춰지면 “통과” 상태를 표시하고 다음 예문으로 진행한다.

전제/데이터
- 예문 JSON: [{ sentence: string, meaning: string }, ...] (다르면 어댑터로 보정).
- 한 카드 = 하나의 영어 문장 + 한국어 뜻.

단계별 구현
1) 모델/세션: `ExampleItem { sentence, meaning }`, `SpeakingSession { index, items, status }` 정의.
2) 토큰화/정규화: 목표 문장을 공백/구두점 기준으로 토큰으로 분할(소문자, 구두점 제거). 표시용 원문 토큰도 함께 보관.
3) UI 기본: SpeakingPage에 카드(문장/뜻), 하이라이트 영역(토큰별 색상), 컨트롤 바(TTS 재생, 스피킹 토글, 다음 버튼 비활성), 진행 표시(예: 3/10).
4) TTS(기본): `flutter_tts`로 단일 문장 재생(언어 en-US, 속도/피치 기본). 카드 진입 시 자동 재생 옵션, 재생/정지 버튼 제공.
5) STT 시작/정지: `speech_to_text`로 음성 인식 토글(마이크 권한/초기화). partial 결과 수신(onResult) 활성화.
6) 단어 매칭 로직: partial transcript(소문자/구두점 제거) → 목표 토큰과 앞에서부터 순차 매칭(케이스/구두점 무시). 초기엔 완전일치, 추후 Levenshtein ≤1 등 퍼지 매칭 도입.
7) 하이라이트 업데이트: 매칭된 토큰 인덱스까지 초록색, 미매칭은 기본색. 매칭 진행률(%) 갱신.
8) 종료 조건: a) 사용자가 버튼 다시 누름 → stop → “통과?” 체크(전부 매칭 시 통과, 아니면 재시도 안내) b) 전부 매칭되면 자동 “통과” 처리.
9) 통과 UI/다음: 통과 배지/스낵바 → 다음 카드로 이동(자동 0.8~1.2초 지연 or ‘다음’ 버튼 활성화). 마지막 카드면 완료 메시지/종료.
10) 동시 제어: STT 중 TTS 자동정지, 카드 변경 시 STT 정지/상태 초기화, 새 카드 진입 시 TTS 자동재생(옵션).
11) 퍼미션/플랫폼: Android/iOS 마이크 권한(iOS NSMicrophoneUsageDescription). Web은 STT 가용 시만 활성화(가용성 체크 후 안내).
12) 디버깅/로깅: 인식 결과, 매칭 인덱스, 경과 시간 로그. 권한/오류 스낵바 처리.

의존성(추가 예정)
- flutter_tts, speech_to_text

후속/확장
- 고급 TTS(음색/속도 커스터마이즈, 캐시), 발음 점수/WER 기반 평가, 결과 저장(로컬/서버), 재도전 모드.

승인 필요
- 위 단계대로 구현할까요? 의존성 추가와 퍼미션 설정 포함해 최소 동작을 먼저 완성한 뒤, 퍼지 매칭/자동 진행 타이밍을 다듬겠습니다.

---

WORK PLAN — 스피킹: 순서 무관(BoW) 인식/하이라이트

목표
- 사용자가 문장 뒷부분을 먼저 말해도 해당 단어가 맞았으면 초록색 처리되도록, “순서 무관” 단어 매칭으로 변경한다.

핵심 설계
- 정규화: 목표 문장 토큰을 소문자/영숫자만 남긴 리스트 `_tokens`와 표시용 `_displayTokens` 유지(현행 유지).
- 중복 대응: 목표 토큰별 필요 개수 `need[token]` 맵, 인식 토큰별 개수 `have[token]` 맵 계산.
- 매칭 플래그: 길이 N의 `List<bool> _matchedFlags` 생성.
  - 좌→우로 `_tokens[i]` 순회하며 `used[token]` 카운터를 증가시키되, `have[token] > used[token]`일 때만 해당 인덱스를 `true`로 설정(중복 단어 처리).
- 진행률: `_matchedCount = _matchedFlags.where(true).length`로 계산하고, ‘다음’ 버튼 활성화는 `_matchedCount == _tokens.length` 조건으로 변경.
- UI: 하이라이트는 각 인덱스의 `_matchedFlags[i]`로 표시(현행 i < _matched 제거).
- onResult: partial transcript마다 `have` 재계산 → `_matchedFlags`/`_matchedCount` 갱신.

단계별 변경
1) 상태 확장: `_matchedFlags`(List<bool>), `_matchedCount`(int) 추가.
2) 매칭 로직: `List<String> recTokens` → `have` 맵 생성 → `_matchedFlags` 재구성 함수 작성.
3) UI 반영: Chip의 `matched` 기준을 `_matchedFlags[i]`로 교체, ‘다음’ 버튼 활성화 조건 변경.
4) 로깅: 매칭율(예: matched/total), 누락 단어 목록 디버그 출력.

경계/사례
- 순서 무관: “world hello”로 말해도 “hello world”의 두 단어 모두 초록 처리.
- 중복: “to to school”처럼 같은 단어가 여러 번 있으면, 인식된 수만큼만 매칭.
- 부분 인식: 일부만 맞춰도 부분 초록 처리 후, 나머지 단어 인식 시 점진적 완성.

옵션(후속)
- 퍼지 매칭: Levenshtein ≤ 1 허용 토글(초기 OFF), 축약형/흔한 오탈자 매핑(I'm→im 등) 테이블.

검증 시나리오
- “take a deep breath” 목표, 인식: “deep breath take a” → 전부 초록.
- “go go home” 목표, 인식: “go home” → 두 개 중 2개만 매칭 처리, 마지막 go 미매칭.
- 부분 인식: “take deep”까지만 인식 시 해당 단어만 초록.

변경 범위
- `lib/features/speaking/speaking_page.dart` 내부 로직만 수정(상태/매칭/하이라이트/다음 버튼 조건).

승인 필요
- 승인 주시면 위 순서로 반영하고, 성능/지연 없이 실시간 매칭되도록 onResult 경량화까지 확인하겠습니다.

# 스피킹 자동 시작/라운드별 TTS 연동 계획 (승인 대기)

## 배경/요구
- 각 문장으로 넘어갈 때마다 자동으로 스피킹(마이크)이 시작되도록 개선.
- 1라운드(`_round == 0`)는 TTS가 먼저 나오고, TTS가 끝난 직후 자동으로 스피킹 시작.
- 사용자는 TTS 도중에도 직접 스피킹 버튼을 눌러 즉시 시작할 수 있어야 함(수동 시작 > 자동 시작).

## 목표/완료 기준
- 초진입 및 매 전환 시 기대 흐름:
  - 라운드 1: TTS 자동 재생 → 완료 직후 STT 자동 시작. 사용자가 중간에 버튼 누르면 즉시 STT로 전환.
  - 라운드 2/3: 전환 즉시 STT 자동 시작(TTS 없음).
- 시간초과/수동 중지/통과 이펙트 및 채점 로직은 기존과 동일하게 동작.

## 설계/변경 포인트
1) 상태 플래그 추가
   - `_autoListenAfterTtsPending`(bool): TTS 완료 후 자동 STT 시작 예약 플래그.

2) TTS 초기화
   - `_initTts()`에서 `await _tts.awaitSpeakCompletion(true)` 설정하여 `_speak()`의 `await _tts.speak(...)`가 종료 시점까지 대기하도록 함.

3) `_speak()` 후크
   - `await _tts.speak(text)` 직후, 아래 조건을 모두 만족하면 자동 STT 시작: `_autoListenAfterTtsPending == true && !_listening && !_passHandled && !_timedOut && _sttAvailable` → `_toggleListen()` 호출.
   - 이후 `_autoListenAfterTtsPending = false`로 정리.

4) 카드 전환(_next)
   - `_prepareCard()` 직후 분기:
     - if `_round == 0`: `_autoListenAfterTtsPending = true; _speak();`
     - else: `_autoListenAfterTtsPending = false;` → `Future.microtask(() { if (mounted && !_listening && _sttAvailable) _toggleListen(); });`

5) 초기 자동 재생(_maybeAutoplayFirst)
   - 기존 TTS 자동 재생 유지 + `_autoListenAfterTtsPending = true` 세팅으로 첫 문장도 TTS→STT 자동 연결.

6) 수동 조작 우선권
   - `_toggleListen()`으로 수동 시작 시 `_autoListenAfterTtsPending = false`로 예약 취소.
   - 시간초과/수동 중지/통과 처리 시 예약도 취소하여 불필요한 자동 시작 방지.

7) 예외/가드
   - 라운드 3(`_round == 2`)에서는 TTS 호출 금지 유지(현행 로직), STT 자동 시작만.
   - 강제 TTS(`_speak(force: true)`) 발생 시 예약을 세팅하지 않음.
   - STT 미지원(`_sttAvailable == false`)이면 자동 시작 생략.

## 구현 단계
1) 플래그 및 헬퍼 추가: `_autoListenAfterTtsPending`
2) `_initTts`, `_speak`, `_next`, `_maybeAutoplayFirst`, `_toggleListen`에 위 로직 반영
3) 수동 검증 시나리오
   - 첫 문장 진입: TTS → 자동 STT, 중간 수동 시작 OK
   - 다음 문장/라운드: 자동 STT 즉시 시작
   - 시간초과/수동 중지: 기존 이펙트/판정 유지, 자동 시작 예약 취소 확인
4) `flutter analyze`, `dart format .` 점검

## 승인 요청
- 위 설계대로 반영해도 될까요? 승인 주시면 구현에 착수하겠습니다.


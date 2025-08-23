WORK PLAN — 스피킹: 매칭 고정 + 중복 매칭 + 라운드별 TTS 정책

목표
- 매칭 고정: STT 부분결과가 바뀌어도 한 번 맞춘 토큰은 계속 초록 유지(취소됨 방지).
- 중복/부분 매칭: 인식된 한 토큰이 여러 타깃 토큰을 동시에 만족하면 모두 매칭(예: ‘am’ → ‘am’과 ‘6am’ 둘 다 초록).
- 라운드별 TTS: Round1(첫 페이즈)엔 카드 진입 시 1회만 자동 재생, 통과 시 TTS 없음. Round2/3(두·세 번째)엔 진입 자동 재생 없음, 통과 시 TTS 1회 재생.

범위
- `lib/features/speaking/speaking_page.dart` 내부 매칭/tts 트리거 로직만 수정. 다른 화면/서비스 영향 없음.

설계/변경 사항
1) 매칭 고정(Sticky)
   - `_recomputeMatches(recNormTokens)`에서 새 플래그를 "이전 매칭을 유지한 채" 갱신(nextFlags = oldFlags 복사).
   - 이미 `true`인 인덱스는 그대로 유지(부분결과로 인해 해제되지 않음).

2) 중복/부분 매칭 허용
   - `bool _tokensMatch(String target, String rec)` 유틸 추가:
     - 정확 일치면 true.
     - `rec.length >= 2`이고 `target.contains(rec)` 또는 `rec.contains(target)`이면 true(예: am ↔ 6am).
   - 매칭 시 "사용량(used) 카운트" 제거: 한 인식 토큰이 여러 타깃 토큰을 만족하면 각 타깃을 모두 true 처리.

3) 라운드별 TTS 정책
   - 진입 자동재생: `_maybeAutoplayFirst()`에서 `_round == 0`일 때만 `_speak()` 실행. Round1은 자동, Round2/3은 자동 OFF.
   - 통과 시 재생: `_showPassAndNext()`에서 `_round >= 1`일 때만 `_speak(force: true)` 실행. Round1은 통과 시 재생 없음.
   - 디바운스: 기존 `_passTtsPlayed` 유지(카드당 1회 보장). 성공 임팩트는 카드당 1회 유지.

수락 기준(DoD)
- Sticky: STT 부분 인식이 변해도 초록으로 변한 단어가 다시 회색으로 돌아가지 않음.
- 중복/부분: 문장 "I am wake up at 6am"에서 ‘am’만 말해도 ‘am’과 ‘6am’이 모두 초록으로 변함.
- TTS 정책: Round1은 시작 시 1회만 자동 재생되고, 통과 시 TTS 없음. Round2/3는 시작 시 자동 재생 없고, 통과 시에만 1회 TTS 재생.

테스트
- Sticky 검증: 동일 카드에서 onResult가 몇 차례 바뀌어도 이미 true인 토큰은 유지.
- 부분 매칭 검증: ‘am’ 인식으로 ‘am’/’6am’ 모두 true.
- TTS 트리거 검증: 각 라운드별 자동/통과 트리거가 명세대로 동작.

작업 단계
1) `_recomputeMatches`를 sticky + 중복 허용 방식으로 재작성.
2) `_tokensMatch` 유틸 추가.
3) `_maybeAutoplayFirst`와 `_showPassAndNext`에 라운드별 TTS 조건 추가.
4) 수동/실행 테스트 및 로그 확인.

상태
- Proposed — 승인 시 반영(소요 40~70분, 리스크 낮음: 로직 국소 변경).

# 스피킹: 통과 후 5초 뒤 재임팩트 버그 수정 계획 (승인 대기)

## 증상
- 스피킹 라운드에서 통과 처리(성공 임팩트) 후, 약 5초 뒤에 동일한 성공 임팩트가 한 번 더 발생함.

## 원인 가설
- 통과 직후 `_autoPass()`에서 STT 취소 및 타이머 해제는 수행되나,
  직후 유입되는 STT `onResult`(지연된 partial 결과)가 `recognizedWords` 비어있지 않음으로 판단되어
  `_restartInactivityTimer(5)`가 다시 설정됨.
- 이후 5초 뒤 `_onTimeout()`이 호출되고, 이 때 `_matchedCount/total >= _kPassThreshold` 조건을 만족하여
  `_playSuccessEffect()`가 재호출되며 재임팩트 발생.
- 추가로 `_onTimeout()`에 통과 이후(또는 리스닝 중이 아님) 무시하는 방어 로직이 없음.

## 수정 전략
1) onResult 가드 추가
   - `onResult` 콜백 진입 시 `_listening == false` 또는 `_passHandled == true` 또는 `_timedOut == true`면 즉시 return.
   - 통과 이후/리스닝 종료 이후에는 입력에 의해 타이머가 재시작되지 않도록 함.
2) 타임아웃 가드 추가
   - `_onTimeout()` 시작부에서 `_passHandled == true` 또는 `_listening == false`면 조용히 return.
   - 필요 시 `_passEffectPlayed`가 이미 true인 경우에도 재임팩트를 방지.
3) 정리 포인트 재점검
   - 통과 경로(`_autoPass()`/`_showPassAndNext()`)에서 `_clearInactivityTimer()`가 항상 호출되는지 다시 확인.
   - 다음 카드 이동(`_next()`), 리스닝 중지 경로에서도 타이머가 해제되는지 확인.

## 변경 파일/범위
- 파일: `lib/features/speaking/speaking_page.dart`
- 변경 내용: STT `onResult` 및 `_onTimeout()`에 가드 로직 추가, 중복 임팩트 방지.

## 테스트 시나리오
1) 통과 직후: 5초 대기해도 재임팩트가 발생하지 않음.
2) 통과 이전: 입력이 멈추고 5초 경과 시 타임아웃 정상 동작(성공/실패 임팩트 1회만).
3) 리스닝 종료 버튼으로 중단: 이후 타임아웃/임팩트 발생하지 않음.
4) 다음 카드 이동: 이전 카드의 타이머/임팩트 잔여 이벤트가 발생하지 않음.
5) 연속 발화 중 통과: 통과 이후 들어오는 지연 `onResult`가 무시됨(타이머 리셋 없음).

## 제외 범위
- STT 정확도, 음성 레벨 분석 고도화, UX 애니메이션 재설계는 범위 외.

## 작업 단계
1) onResult 가드 추가(통과/리스닝 종료/타임아웃 이후 무시)
2) _onTimeout 가드 추가(통과/리스닝 종료 상태면 무시)
3) 수동 테스트(시나리오 1~5)
4) `flutter analyze` 및 `dart format .` 확인

승인해 주시면 위 단계대로 수정 적용하겠습니다.


# [신규] 예문 생성 개수 제한(최대 50개) 계획 (승인 대기)

## 배경/요구
- 예문 생성 수를 최대 50개로 제한. 50 초과 입력 시 50으로 고정.

## 목표
- 모든 진입 경로에서 count가 1~50 범위를 벗어나지 않도록 방어적으로 보장.

## 변경 포인트
1) UI 시트(_ExampleGenSheet)
   - 현 로직에 이미 `if (count > 50) count = 50;` 존재 확인(유지).
2) 서비스 레벨(ExamplesApi.generate)
   - `count` 인자에 대해 내부에서 `final safeCount = count.clamp(1, 50) as int;`로 강제 후, 프롬프트에 `safeCount` 사용.
3) 테스트(선택)
   - `MockClient`로 요청 body를 캡처해 user 메시지의 마지막 줄이 `50`으로 고정되는지 검증 테스트 추가.

## 구현 단계
1) `lib/services/examples_api.dart`에 count 클램프 추가
2) (선택) `test/examples_api_count_limit_test.dart` 작성
3) 포맷/분석/테스트 통과 확인

## 승인 요청
- 위 변경(서비스 레벨 강제 + 선택 테스트) 적용해도 될까요? 승인 시 바로 반영하겠습니다.


# [신규] 입력단계 예문 개수 상한(50) 강제 계획 (승인 대기)

## 배경/요구
- 예문 수 입력 TextField에서 50을 초과하는 값을 아예 입력 단계에서 막고 싶음.

## 목표
- 사용자가 50을 넘는 숫자를 타이핑/붙여넣기 해도 입력값이 50을 초과하지 않도록 방지.
- 기존 제출 시 클램프(시트/서비스)는 그대로 유지해 다중 방어.

## 변경 포인트(코드)
1) `_ExampleGenSheet`의 예문 수 TextField에 입력 포맷터 추가
   - `FilteringTextInputFormatter.digitsOnly`
   - 커스텀 `MaxIntInputFormatter(50)`로 50 초과 입력 방지(타이핑/붙여넣기 모두 차단)
   - `maxLength: 2`로 3자리 입력 자체를 물리적으로 제한(보조 수단)
2) UX
   - `labelText` 또는 `helperText`에 "최대 50" 표기

## 구현 방식
- `lib/features/chat/chat_page.dart` 내 `_ExampleGenSheetState` 아래에 private 클래스로 `class _MaxIntInputFormatter extends TextInputFormatter` 추가
- `formatEditUpdate`에서 `int.tryParse(newValue.text)`가 50 초과 시 `oldValue` 반환
- 빈 문자열, 선행 0 허용(필요 시 `0`→빈 변경은 하지 않음)

## 테스트(선택)
- 간단 유닛테스트로 포맷터 동작 확인(붙여넣기 999 → 50 이하 유지)

## 영향
- 입력 단계에서 즉시 피드백(더 이상 자리수/값 증가하지 않음)
- 제출 및 서비스 레이어의 클램프와 함께 안전장치 이중화

## 승인 요청
- 위 입력 포맷터 기반 제한 적용해도 될까요? 승인 시 최소 변경으로 반영하겠습니다.

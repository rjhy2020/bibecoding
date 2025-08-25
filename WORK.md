# 코드 우선 확인 후 재계획 (승인 대기)

## 목적
- 저장 실패 지점을 정확히 파악하기 위해 관련 코드(버튼 핸들러→서비스→레포→저장소)를 먼저 열람·추적한 뒤, 그 결과를 바탕으로 수정 작업 계획을 정교화한다.

## 즉시 수행할 조사(읽기 전용)
1) 키워드 전수 검색: `Again|Hard|Good|Easy`, `review`, `fsrs`, `save`, `upsert`, `prefs`, `firestore`, `updateSetAfterReview`, `upsertAll`.
2) 화면/위젯 경로 확인: 학습 종료 화면(스피킹 완료)에서 복습 주기 확정/저장 버튼의 onPressed 흐름 추적.
3) 서비스/레포 확인: 저장 인터페이스와 구현(SharedPreferences/Firestore) 식별 및 `await`·예외 처리 확인.
4) 사용자 피드백: 저장 성공/실패 스낵바/다이얼로그 표시 조건과 `mounted` 가드 점검.
5) 저장 매체 결정: 현재 빌드가 로컬(pref)인지 Firestore인지 코드 분기 확인.

## 산출물
- 문제 함수/파일/라인 식별과 원인 요약.
- 정확한 수정 단계(작업 단위/테스트 포함)로 재계획 작성.

## 승인 요청
- 위 읽기 전용 코드 스캔을 시작해도 될까요? 승인 시 바로 착수하고, 스캔 결과를 바탕으로 세부 수정 계획을 아래에 업데이트하겠습니다.


# 조사 결과 및 수정 계획 (승인 대기)

## 핵심 원인 요약
- 스낵바 미표시: `SpeakingPage`에서 평점 선택 시 `Navigator.of(context).popUntil((route) => route.isFirst)`로 항상 루트(Home)까지 돌아갑니다. 이 때문에 상위 페이지(`ChatPage` 또는 `ReviewHomePage`)에서 콜백 내 `ScaffoldMessenger.of(context).showSnackBar(...)`가 불리더라도, 해당 페이지가 즉시 pop되어 스낵바가 사용자에게 표시되지 않습니다.
- 저장 안 된 것처럼 보임: 저장 자체는 콜백에서 `await`로 수행하므로 정상 동작해야 하나, 완료 후 곧바로 Home으로 이동해 사용자가 복습 탭으로 돌아가지 않는 한 변화가 보이지 않습니다. 또한 (테스트용 플래그가 꺼져 있다면) 새 세트/카드의 `due`가 내일 자정으로 설정되어 복습 탭(기본 due 필터)에서 바로 보이지 않을 수 있습니다. 현재 `AppConfig.immediateReviewAfterComplete = true`로 설정되어 있어 즉시 due가 되도록 되어 있으나, 스낵바가 보이지 않아 저장 실패로 오해할 소지가 큽니다.

## 수정안
1) 내비게이션 수정(필수)
   - 파일: `lib/features/speaking/speaking_page.dart`
   - 변경: 평점 선택 후 `Navigator.popUntil((route) => route.isFirst)` → `Navigator.pop(context)`로 한 단계만 되돌아가도록 변경.
   - 효과: 직전 페이지(`ChatPage`/`ReviewHomePage`)가 화면에 남아 콜백 내 스낵바가 정상 표시됨. 사용자는 저장 성공 피드백을 명확히 받음.

2) 스낵바 위치/타이밍 보강(권장)
   - 선택지 A: 콜백 내 스낵바 유지(현 구조 그대로). `Navigator.pop(context)` 뒤에 상위 페이지가 포그라운드가 되어 스낵바가 즉시 보임.
   - 선택지 B: 스낵바를 `SpeakingPage`에서 표시 후 pop(콜백은 저장만 담당). 단, 현재 구조상 상위 페이지 컨텍스트가 메시지를 담당하므로 A로 충분.

3) 가시성 확인용 로깅(선택)
   - `ChatPage._handleSpeakingCompleteRated`와 `ReviewHomePage._onSpeakingCompleteRated` 시작/종료에 `debugPrint` 추가(임시)로 저장 흐름 확인.

4) 형식/정적 검사
   - 포맷팅(`dart format .`), 정적 분석(`flutter analyze`) 무경고 유지.

## 작업 단계
- [ ] SpeakingPage 내비게이션 한 단계 pop으로 변경
- [ ] (선택) 콜백 시작/종료 로깅 추가
- [ ] 포맷/분석 수행
- [ ] 수동 점검 시나리오
  - Chat → 예문 생성 → Speaking 3라운드 → 평점 선택 → Chat으로 복귀 → “복습 카드가 저장되었습니다.” 스낵바 확인
  - Review → 세트 복습 → 평점 선택 → Review로 복귀 → “세트 복습 완료!” 스낵바 확인 + 리스트 갱신 확인

## 참고
- 현재 `AppConfig.immediateReviewAfterComplete = true` 상태로, 새로 생성된 세트/카드는 즉시 due로 잡혀 복습 탭에서 바로 노출되어야 합니다.

## 승인 요청
- 위 수정안 적용해도 될까요? 승인 시 최소 변경으로 패치 후 포맷/분석까지 진행하겠습니다.


# 추가 발견: 예외 삼키기와 가시성 문제 (승인 대기)

## 문제
- SpeakingPage에서 평점 선택 시 콜백(`onCompleteRated`) 호출을 `try { await cbRated(...); } catch (_) {}`로 감싸 예외를 삼킵니다.
- 이로 인해 저장 중 오류가 발생해도 상위 페이지(Chat/Review)에서 실패 스낵바를 띄울 수 없고, 사용자 입장에선 “아무 피드백 없이 종료”로 보입니다.

## 영향
- 실제 저장 실패 시: 스낵바 미표시 + 데이터 미저장 → “저장도 안 됨”으로 인식.
- 저장 성공 시: 성공 스낵바는 Chat/Review 쪽에서 띄우므로 한 단계 pop 변경 후엔 보이지만, 실패 경로는 여전히 무음.

## 수정 제안
1) SpeakingPage에서 예외를 삼키지 않고 상위로 전파(권장)
   - `catch` 블록 제거 또는 로깅 후 rethrow.
   - 상위 콜백(Chat/Review)에서 성공/실패 스낵바를 책임지도록 일원화.
2) (대안) SpeakingPage에서 실패 스낵바 직접 노출
   - `catch (e) { ScaffoldMessenger.of(context).showSnackBar(...); }` 후 상위로 전파 또는 단락.
3) 임시 로깅 추가
   - ChatPage/ReviewHomePage 콜백 시작/완료, upsert/세트생성/갱신 전후 `debugPrint`로 추적.

## 주의사항
- 현재 ChatPage의 저장 로직은 “생성 시 due=즉시(테스트 플래그) → 평점 반영에서 FSRS 간격으로 덮어쓰기” 순서입니다. 즉시 복습 노출을 기대한다면 평점 반영 시점을 조정(학습 종료 즉시 노출 후 다음 세션부터 간격 반영)할 필요가 있습니다. 우선은 실패 가시성부터 해결하고, 기대 UX 확인 후 간격 적용 시점을 결정합시다.

## 실행 단계(추가)
- [ ] SpeakingPage: 예외 삼키기 제거 및/또는 실패 스낵바 표시
- [ ] Chat/Review 콜백에 로깅 추가
- [ ] 동작 점검: 실패 케이스도 피드백 보이는지 확인

## 승인 요청
- 위 추가 수정도 진행할까요? 승인 시 최소 변경으로 반영하겠습니다.

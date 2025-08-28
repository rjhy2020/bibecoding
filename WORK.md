# 예문 생성 후 즉시 복습에 자동 추가(보통) 계획 (승인 대기)

## 배경/요구
- 사용자가 “예문 생성하기”로 예문을 생성하면, 그 시점에 자동으로 복습(Review)에 추가한다.
- 초기 FSRS 평점은 2(보통, Good)로 설정하되, 최종 Speaking 완료 시 사용자가 선택한 평점으로 다시 반영(재설정)한다.

## 목표/완료 기준
- 예문 생성이 완료되면 지연 없이 로컬 Review 저장소에 카드/세트를 생성한다.
- 카드: `reps=0`, `lastRating=2`, `due=now`(즉시 복습 가능), `stability/difficulty`는 기본값 유지.
- 세트: 생성된 카드들의 ID로 하나의 세트를 생성하고, 카드에 `setId`를 주입한다.
- 이후 Speaking 완료 시 기존 로직대로 사용자가 고른 평점(Again/Hard/Good/Easy=1/1/2/3)으로 FSRS 업데이트가 정상 반영된다.
- UI 피드백: “복습에 자동 추가되었습니다(보통)” 스낵바 안내.

## 변경 포인트(코드)
1) Hook 지점: `lib/features/chat/chat_page.dart` 내 예문 생성 플로우
   - `_openExampleDialog()`에서 `ExamplesApi.generate(...)` 성공 직후, `Navigator.push` 전에 자동 추가 로직 호출(비동기).
   - 메서드 예: `_autoAddExamplesToReview(List<ExampleItem> examples)` 추가.

2) 자동 추가 구현 `_autoAddExamplesToReview`
   - 입력: `List<ExampleItem>`
   - 처리:
     - 현재 시각 `ts = DateTime.now().millisecondsSinceEpoch`.
     - 각 예문에 대해 `id = makeReviewIdForSentence(sentence)` 생성.
     - 기존 카드 조회(`_reviewRepo.fetchAll()`), 존재하면 유지/갱신, 없으면 새 `ReviewCard` 생성:
       - `reps: 0`, `lastRating: 2`, `due: ts`, `createdAt: ts`, `updatedAt: ts`.
     - 일괄 upsert: `_reviewRepo.upsertAll(cards)`.
     - 세트 생성: `_setRepo.createSet(title: firstSentence, itemIds: ids, now: now)`
     - 카드에 `setId` 주입 후 재-upsert(세트가 미리 Review 탭에 보이도록).
   - 완료 후 스낵바: “복습에 자동 추가되었습니다(보통)”.

3) Speaking 완료 플로우(현행 유지)
   - `ChatPage._handleSpeakingCompleteRated(...)`는 현재 로직대로 작동: 세트와 카드에 대해 `updateSetAfterReview` 및 `updateAfterReview` 호출로 사용자 선택 평점 반영(이때 reps 증가 및 due 재계산).
   - 이미 생성된 카드/세트에 대해 중복 생성 없이 갱신만 이뤄지도록 map/upsert 로직 유지.

## 엣지 케이스/가드
- 중복 예문: 동일 문장→동일 ID로 자연스럽게 upsert 처리(중복 추가 방지).
- 예문 0개/fallback 한 개: 0개면 스킵, 1개라도 정상 세트 생성.
- 성능: 로컬 `SharedPreferences` 기반이므로 문제 없음. 비동기 처리 후 바로 Speaking 페이지로 이동.

## 테스트/확인
- 수동 확인: 예문 생성→스낵바 확인→Review 탭에서 새 세트/카드 확인(즉시 due).
- 기존 테스트 영향 없음. 필요시 간단 통합 테스트 추가 가능.

## 변경 파일(예상)
- `lib/features/chat/chat_page.dart` (자동 추가 로직 및 호출 추가)

## 승인 요청
- 위 계획대로 구현해도 될까요? 승인해 주시면 반영 후 분석/포맷 수행하겠습니다.
# RangeError(empty examples) 방지/무결성 보강 계획 (승인 대기)

## 증상/원인
- 에러: `RangeError (index): Index out of range: no indices are valid: 0`
- 원인: 빈 리스트에서 0번째 요소 접근. 대표적으로 `SpeakingPage(examples: [])`로 진입했거나, 세트의 `itemIds`와 실제 보유 카드가 불일치해 Review 경로에서 빈 `examples`로 넘어간 경우.

## 목표
- 빈 예문으로 Speaking 화면에 진입하지 않도록 방어하고, Review에서 카드가 없으면 시작하지 않게 처리.
- 예문 생성 직후에도 비어 있으면 Speaking으로 네비게이션하지 않음.

## 변경 포인트(코드)
1) SpeakingPage 가드
   - init/build 시 `_items.isEmpty`면 SnackBar 안내 후 `Navigator.pop(context)`로 빠져나오기(또는 대체 화면 표시).
   - `_prepareCard()`에서 길이 0일 때 조기 리턴. `build()`에서 `item` 접근 전 `_items.isNotEmpty` 확인.

2) ChatPage 예문 생성 후 검증
   - `ExamplesApi.generate` 결과가 비어 있으면 스낵바 안내 후 `SpeakingPage`로 push하지 않음(로그만 남김).

3) ReviewHomePage 시작 전 검증
   - `_startReview()`에서 세트의 `itemIds`로 수집한 `cards`가 비면 스낵바 안내 후 시작 스킵.
   - 선택: 카드가 하나도 없으면 해당 세트 삭제(사용자 경험에 맞춰 결정).

4) (선택) 세트 무결성 정리
   - `_load()` 시 세트별 실제 카드 존재 여부를 점검해 0개인 세트는 숨기거나 삭제.

## 구현 단계
1) SpeakingPage에 빈 리스트 가드 및 안전접근 반영
2) ChatPage에서 예문 0개면 push 차단
3) ReviewHomePage에서 카드 0개면 시작 스킵(+옵션: 세트 삭제)
4) (선택) 무결성 정리 루틴 추가
5) `flutter analyze`/`flutter test` 확인

## 리스크/대응
- 사용자가 생성 실패/빈 응답을 자주 만날 경우, 안내 문구를 명확히 하고 재시도 CTA 제공.
- 세트 자동 삭제 여부는 신중히(초기엔 스킵만, 추후 토글 옵션화 가능).

## 승인 요청
- 위 변경들 적용해도 될까요? 승인 시 최소 변경으로 패치 후 분석/테스트까지 진행하겠습니다.
# Review 저장 초기화/자동 저장 보강 계획 (승인 대기)

## 배경/문제
- 자동 추가 시점(예문 생성 직후)에서 SharedPreferences 키가 비어 있어(`flutter.review_cards_v1` 미생성) 저장 실패/미반영으로 보이는 현상.
- 현재 `ReviewRepositoryPrefs.fetchAll()`은 키가 없으면 빈 리스트를 반환하지만, 최초 저장 키 생성은 `upsertAll()`이 호출되어야만 이루어짐. 예외/조기 반환 등으로 `upsertAll()`이 스킵되면 키가 남지 않을 수 있음.

## 목표
- 키가 존재하지 않아도 자동으로 초기화(`[]`)하고, 자동 추가 경로에서 항상 카드/세트가 저장되도록 보강.

## 변경 포인트(코드)
1) 저장소 초기화 API 추가
   - `ReviewRepositoryPrefs.ensureInitialized()` → 키(`review_cards_v1`)가 없으면 `'[]'`로 생성 저장.
   - `ReviewSetRepositoryPrefs.ensureInitialized()` → 키(`review_sets_v1`)가 없으면 `'[]'`로 생성 저장.

2) 자동 추가 경로에서 초기화 보장
   - `ChatPage._autoAddExamplesToReview(...)` 시작 시 두 저장소의 `ensureInitialized()`를 await 후 진행.
   - 예문이 0개인 경우 push/저장 스킵하고 안내 스낵바.

3) (보강) Review 시작 전 검증
   - `ReviewHomePage._startReview()`에서 세트 조회 전 `ensureInitialized()` 호출.
   - 세트에 묶인 카드가 0개면 스킵(필요 시 세트 삭제 옵션).

4) (선택) 저장소 내부에서 자동 초기화
   - `ReviewRepositoryPrefs._loadAllInternal()`와 `ReviewSetRepositoryPrefs._loadAll(...)`에서 s==null이면 내부적으로 `'[]'`를 저장해 키 생성(방어적).

## 테스트/검증
- 시나리오: 초기 상태(SharedPreferences 비어 있음) → 예문 생성 → 자동 추가 후 `review_cards_v1`/`review_sets_v1` 키가 생성되고 값이 저장됨을 확인.
- 단위 테스트(선택): `SharedPreferences.setMockInitialValues({})`에서 자동 추가 호출 후 키 존재/리스트 길이 검증.

## 영향 범위/리스크
- 로컬 저장만 영향. 키를 명시 초기화하므로 부작용 적음.
- 예문 0개 시 네비게이션 스킵으로 RangeError 재발 방지에 기여.

## 구현 단계
1) 두 저장소 클래스에 `ensureInitialized()` 추가
2) `ChatPage._autoAddExamplesToReview`에서 초기화 호출 + 0개 방지
3) `ReviewHomePage._startReview`에서 초기화 호출
4) (선택) 저장소 내부 로드 시 s==null → `'[]'` 쓰기
5) analyze/test/수동 시나리오 검증

## 승인 요청
- 위 변경들 적용해도 될까요? 승인 시 최소 변경으로 패치 후 테스트까지 진행하겠습니다.


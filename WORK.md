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


# [신규] 세로환경 대응/반응형 UI 개선 계획 (승인 대기)

## 배경/문제 인식
- 가로 화면에선 의도한 UI(행(Row) 배치, 홈의 ‘복습하기’ 카드 폭 등)가 정상 노출되나, 세로(특히 Android 폰)로 줄이면 Row가 깨져 세로 정렬로 바뀌거나 ‘복습하기’ 영역이 비정상 크기/배치로 보임.
- 목표는 화면 비율/폭 변화에 따라 요소들이 자연스럽게 축소·재배치되어, 세로 환경에서도 가로 대비 UX가 유지되는 것.

## 목표/완료 기준
- 세로(폭 360–420dp)에서도 핵심 Row(검색바/전송, 입력바, 액션 버튼)가 한 줄에서 유지되거나, 최소한 의도된 2단 구성으로 ‘깨짐 없이’ 보임.
- 홈의 ‘복습하기’ QuickAction 영역이 세로에선 가로 거의 꽉 차는 너비(여백 고려)로 렌더링.
- 스크롤, 오버플로우 경고, 버튼 겹침 등 레이아웃 이슈 없는 상태.
- flutter analyze 무경고, 기존 테스트 통과.

## 변경 포인트(코드 레벨 계획)
1) 공통 브레이크포인트/스케일링 정의
   - `ui/constants.dart` 또는 전용 `layout.dart`에 XS(<360), SM(360–480), MD(>480) 등 브레이크포인트 상수/헬퍼 추가.
   - 패딩/폰트/컨트롤 높이를 폭에 따라 소폭 축소해 한 줄 유지 가능성 최대화.

2) HomePage(hero 검색 영역, KPI, QuickAction)
   - 검색 입력+버튼 Row: `Expanded`/`Flexible` 조합으로 TextField가 가변 폭을 흡수, 버튼은 고정/최소폭으로 유지.
   - isTiny 분기 축소: 너무 쉽게 컬럼으로 떨어지지 않도록 임계치 재조정 및 소형 패딩 적용.
   - QuickActionCard: 고정 `width: 280` 제거 → 부모 폭 기반 가변(`constraints.maxWidth` 내 최소/최대 폭)으로, 세로에선 거의 전체폭.
   
   - [KPI 영역(학습 연속일/복습 대기/지금까지 연습한 문장) 세부 조정]
     - 기존 `kpiTwoColumn` 이분법 제거 → `cols = (width<360?1 : width<640?2 : 3)` 식으로 동적 열 수 결정.
     - `Wrap` 유지하되 각 카드의 `SizedBox(width: itemW)`에서 `itemW = (maxWidth - gap*(cols-1))/cols`로 계산하여 세로에서도 고르게 1~2열 배치.
     - 아주 좁은 폭(≤360dp)에서는 1열(전체폭)로 폴백하여 텍스트 겹침/깨짐 방지.
     - `MetricCard` 내부 폰트/패딩을 XS 화면에서 소폭 축소(타이틀 12→11, 값 20→18 등)하여 줄바꿈 최소화.

3) QuickActionCard 위젯 자체 개선
   - `double? width` 파라미터 추가 또는 내부에서 `LayoutBuilder`로 가용 폭에 맞춰 너비 결정.
   - 텍스트 줄바꿈/오버플로우 방지, 아이콘/텍스트 간격 축소(소형 화면 전용).
   - [홈 ‘복습하기’ 섹션 세부 조정] 세로/좁은 폭에선 가로 스크롤 대신 단일 카드가 가득 차도록 `width: double.infinity` 기반 배치로 전환.

4) ChatPage 하단 입력바(_InputBar)
   - Row 유지: TextField `Expanded`, 전송 버튼 최소폭/아이콘만 모드 지원.
   - 좁은 폭에서 contentPadding/폰트 사이즈 축소.

5) ReviewHomePage
   - 하단 ‘복습 시작하기’ 버튼은 이미 `double.infinity`이나, 상단 리스트/필터 영역 패딩/간격을 폭에 따라 축소.
   - 세트 타일 텍스트 넘침 방지(줄바꿈/ellipsis)와 내부 간격 축소.

6) SpeakingPage 카드
   - 이미 `min(520, screenW-40)`로 폭 제한. 세로에서 상하 패딩/버튼 간격을 소폭 축소해 안정적 한 화면 배치 유지.

7) 회귀 방지/정리
   - 중복 분기 제거, 레이아웃 분기 기준(폭) 통일.
   - dart format / flutter analyze 정리.

## 구현 단계
1) 브레이크포인트/레이아웃 헬퍼 추가(상수/함수)
2) HomePage 검색/QuickAction 반응형 조정
3) QuickActionCard 가변 너비화
4) ChatPage 입력바 축소 레이아웃
5) ReviewHomePage 패딩/간격/타일 줄바꿈 정리
6) SpeakingPage 소폭 간격 튜닝(필요 시)
7) 수동 검증(폭 320/360/390/411/480/800, 세로/가로)
8) 분석/테스트/포맷 통과 확인

## 테스트 플랜
- 웹 크롬 DevTools로 다양한 디바이스 폭 시뮬레이션(Pixel 5, Galaxy S20, iPhone 12/SE 등).
- 핵심 확인: 
  - 홈 검색 Row 한 줄 유지 여부
  - ‘복습하기’ 카드가 세로에서 거의 전체폭 차지
  - Chat 입력바 한 줄 유지 및 버튼 잘림 없음
  - Review 리스트/버튼 레이아웃 정상
- `flutter analyze`, `flutter test` 통과 확인.

## 리스크/대응
- 매우 좁은 폭(≤320dp)에서 한 줄 유지 불가 시 2단(입력 위/버튼 아래)로 ‘의도된’ 폴백 제공.
- 텍스트 길이에 따른 오버플로우는 ellipsis/줄바꿈 규칙으로 제어.

## 예상 변경 파일
- `lib/ui/constants.dart`(또는 신규 `lib/ui/layout.dart`)
- `lib/features/home/home_page.dart`
- `lib/features/home/widgets/quick_action_card.dart`
- `lib/features/chat/chat_page.dart`(입력바 섹션)
- `lib/features/review/ui/review_home_page.dart`
- `lib/features/speaking/speaking_page.dart`(간격만 필요 시)

## 승인 요청
- 위 계획대로 반응형 레이아웃 개선을 진행해도 될까요? 승인 주시면 최소 변경으로 패치 → 포맷/분석 → 시뮬레이션 검증까지 수행하겠습니다.


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


# [신규] KPI 텍스트 동적 스케일링 계획 (승인 대기)

## 배경
- 세로/좁은 화면에서 KPI 제목(예: "지금까지 연습한 문장")이 잘려 보임. 현재 compact+ellipsis만으로는 가독성에 한계.

## 목표
- 카드 가로폭(=화면 비율)에 따라 텍스트 크기가 자동으로 줄어들어 잘림이 없도록 개선. 세로에서도 KPI 3개 가로 배치는 유지.

## 접근
1) `MetricCard` 내부에 `LayoutBuilder`로 가용 너비(`constraints.maxWidth`)를 얻어 스케일 값을 계산(예: 0.72~1.0 범위)
2) 제목/값 `Text`를 각각 `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`로 감싸 최후 수단으로 자동 축소
3) compact 모드와 병행(아주 좁은 폭에서 높이/패딩 축소 유지), ellipsis는 보조 수단

## 변경 파일
- `lib/features/home/widgets/metric_card.dart`

## 구현 단계
1) `MetricCard`에 `LayoutBuilder` 도입 → `scale = clamp(maxW / T, 0.72, 1.0)` 계산(T는 기준 너비 220~240에서 조정)
2) 제목/값 텍스트 각각 `FittedBox(scaleDown)` 적용 + `softWrap: false, maxLines: 1`
3) 소형 화면에서 아이콘-텍스트 간격 8 유지
4) 시뮬레이션(폭 320/360/390/411/480) 후 T/하한값 보정
5) 포맷/분석/테스트 통과 확인

## 리스크/대응
- 과도한 축소 방지: 우선 폰트 스케일로 축소하고, 부족분만 FittedBox로 보정
- 카드 높이 유지(76/88)로 레이아웃 안정성 확보

## 승인 요청
- 위 방식으로 텍스트 동적 스케일링을 적용해도 될까요? 승인 시 구현에 착수하겠습니다.

# main.dart 리팩토링 계획 (승인 대기)

## 목표
- `main.dart`를 앱 엔트리/테마 설정만 담당하도록 슬림화하고, 홈 화면과 구성요소를 `features/home/`로 분리합니다.
- 코드 일관성(상수/const, 키, 네이밍) 및 가독성 향상. 기능 변경 없음.

## 변경 범위
- 파일: `lib/main.dart` (엔트리/테마만 남김)
- 새 파일/이동: `lib/features/home/home_page.dart`, `lib/features/home/models/recent_phrase.dart`,
  `lib/features/home/widgets/{font_warm_up.dart, metric_card.dart, quick_action_card.dart, recent_phrase_tile.dart}`
- 상수: `lib/ui/constants.dart`에 여백/라운드 상수 이동 후 참조 변경

## 설계
1) `ui/constants.dart` 생성: `kGap*`, `kRadius*` 정의 및 import 교체
2) `RecentPhrase` 모델 분리: `features/home/models/recent_phrase.dart`
3) 위젯 분리: `FontWarmUp`, `MetricCard`, `QuickActionCard`, `RecentPhraseTile`
4) `HomePage`는 `features/home/home_page.dart`로 이동하고 분리된 위젯 사용
5) `main.dart`는 `EnglishPlease` + `MaterialApp` + `home: HomePage()`만 유지
6) const/키/불필요 주석 정리, 스타일 일관화

## 테스트/검증
- 네비게이션: 홈 검색 → `ChatPage` 진입 동작 동일
- UI: 지표/빠른 복습/최근 표현 렌더 동일
- 빌드/분석: `flutter analyze`, `dart format .`

## 커밋
- `refactor: main.dart 슬림화 및 홈 화면 모듈 분리`

승인해 주시면 위 단계대로 적용하겠습니다.

# 스피킹 결과 저장 및 복습 시스템 설계 (승인 대기)

## 목표
- 스피킹 세션이 끝나면 현재 예문 리스트(List<ExampleItem>)를 복습 카드로 저장한다.
- 복습 탭: 오늘 복습 예정(기한 도래/지연) 카드 목록 표시, 개별 삭제, "복습 시작하기"로 일괄 복습.
- 스케줄링: FSRS 기반 주기 저장. 초기 단계에선 평점 고정(보통=2)로만 갱신한다.
- 차후 단계에서 Firestore/Functions로 마이그레이션(현재는 로컬 저장으로 시작).

## 데이터 모델(초안)
- ReviewCard
  - id: string (UUID v4 또는 sentence 기반 해시/slug+timestamp)
  - sentence: string
  - meaning: string
  - createdAt: int (epoch millis)
  - updatedAt: int (epoch millis)
  - due: int (epoch millis) — 다음 복습 예정 시각
  - reps: int — 복습(또는 학습) 횟수
  - lapses: int — 실패/리셋 횟수(초기 0, 향후 확장)
  - stability: double — FSRS 안정도(초기 파라미터)
  - difficulty: double — FSRS 난이도(초기 파라미터)
  - lastRating: int — 마지막 평점(초기엔 2 고정)

JSON 예시(단일 카드):
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "sentence": "Going home is my favorite thing in the world.",
  "meaning": "집에 가는 게 가장 좋아.",
  "createdAt": 1724567890000,
  "updatedAt": 1724567890000,
  "due": 1724654290000,
  "reps": 1,
  "lapses": 0,
  "stability": 2.5,
  "difficulty": 5.0,
  "lastRating": 2
}

## 저장소 설계
- 인터페이스: `ReviewRepository`
  - `Future<void> upsertAll(List<ReviewCard> cards)` — 여러 장 저장/갱신
  - `Future<List<ReviewCard>> fetchDue({DateTime? now})` — 기한 도래/지연 카드 목록
  - `Future<List<ReviewCard>> fetchAll()` — 전체 목록
  - `Future<void> delete(String id)` — 단건 삭제
  - `Future<void> updateAfterReview(String id, int rating)` — FSRS 주기 갱신(초기 rating=2만 사용)
- 1단계 저장 매체: `shared_preferences`(소량 데이터, 웹/모바일 공통). 키 예: `review_cards_v1`(JSON 직렬화)
- 3단계 이후: `FirestoreReviewRepository`로 마이그레이션(동일 인터페이스 유지, DI로 스위칭)

## FSRS(초기: 고정 Good=2) 전략
- 단순 Good 전용 갱신 로직으로 시작(테스트/UX 검증 목적):
  - 신규(첫 저장): due = now + 1일, reps=1, stability/difficulty 기본값(seed)
  - 이후 Good(2) 시: 간단 테이블 기반(1→3→7→14→30→60→120→240일) 혹은 안정도 기반 증분
  - 정식 FSRS 파라미터/공식은 2단계 후 별도 모듈(`fsrs_scheduler.dart`)로 적용 (초기값 유지, Good 루트만 사용)

## UI/흐름 설계
- 저장 타이밍: SpeakingPage 세션 종료 시(완료 화면에서 "저장 후 나가기" 버튼 또는 자동 저장) 예문 리스트를 카드로 변환해 저장
  - 중복 처리: 같은 sentence가 이미 존재하면 `updateAfterReview(Good)`로 주기만 갱신
- 복습 탭(ReviewHomePage):
  - 상단 KPI(오늘 예정 N개, 지연 M개)
  - 목록: due<=now 카드 리스트, 스와이프/아이콘으로 삭제
  - 버튼: "복습 시작하기" → due된 카드들로 SpeakingPage 실행
- 복습 세션 종료 처리: 세션에 포함된 카드 전부 rating=2로 일괄 갱신(초기 단순화)

## 단계별 구현 계획
1) 모델/직렬화/레포 뼈대
   - `lib/features/review/models/review_card.dart`
   - `lib/features/review/data/review_repository.dart`(interface)
   - `lib/features/review/data/review_repository_prefs.dart`(shared_preferences 구현)
   - 유닛 테스트: 직렬화, 저장/조회/삭제 동작

2) SpeakingPage 연동(저장 훅)
   - SpeakingPage 완료 플로우에 결과 반환/콜백 추가(`onComplete(List<ExampleItem>)`)
   - 완료 시 `ExampleItem -> ReviewCard` 변환 후 `upsertAll` 저장
   - 중복 문장 병합 규칙: sentence 키로 식별(대소문자/공백 정규화) → 존재 시 `updateAfterReview(2)`만 수행

3) 복습 탭 기본 UI
   - `ReviewHomePage` 구현, Home의 "복습하기" 진입 지점 교체
   - due 리스트 표시, 삭제 동작(`delete`) 연결
   - "복습 시작하기"로 due 카드 → `ExampleItem` 변환 → SpeakingPage로 전달

4) FSRS 스케줄러(초기 Good 전용)
   - `lib/features/review/scheduler/fsrs_scheduler.dart` 모듈 생성
   - API: `ReviewCard applyGood(ReviewCard, DateTime now)`
   - 기본 파라미터 및 테이블/간단 안정도 모델 반영
   - 유닛 테스트: 새 카드/반복 카드 케이스별 due 증가 검증

5) 세션 결과 반영
   - SpeakingPage에서 완료 시 세션에 포함된 모든 카드에 `applyGood` 적용 및 저장
   - 실패/패스 세분화는 차후(지금은 항상 2)

6) UX 다듬기/안정화
   - 저장/삭제 토스트, 빈 상태(오늘 복습 없음) 메시지
   - 간단한 에러 핸들링(저장 실패 시 안내)

7) Firebase/Functions 마이그레이션(차후)
   - 패키지 추가/초기화, `FirestoreReviewRepository` 구현(컬렉션: `users/{uid}/reviews`)
   - Auth 연동, 오프라인 캐시, 다중 단말 동기화
   - 서버에서 FSRS 계산(옵션) 또는 클라이언트 계산+서버 검증

## 테스트 계획
- 저장소: 직렬화/역직렬화, CRUD, due 필터링
- 스케줄러: Good만으로 interval 증가 검증, 경계값(now 기준) 테스트
- SpeakingPage 연동: 완료 시 저장 호출 여부를 mock으로 검증
- 위젯: 복습 탭 목록 렌더/삭제/빈 상태 스냅샷(간단 위젯 테스트)

## 수용 기준(AC)
- 세션 종료 후 예문이 로컬 저장에 카드로 남는다.
- 복습 탭에서 오늘 예정 카드들이 보이고 삭제 가능하다.
- "복습 시작하기"로 예정 카드들을 SpeakingPage로 불러와 일괄 복습 가능하다.
- 복습 종료 후(또는 각 카드 완료 후) 모든 카드의 다음 `due`가 Good(2) 규칙에 따라 미래 시점으로 갱신된다.

## 다음 액션 요청
- 위 계획 승인 여부 확인 부탁드립니다.
- 승인 시 1단계(모델/레포 뼈대 + 테스트)부터 착수하겠습니다.


# 복습 단위 전환: 카드(문장) → 세트(묶음) 기반 (승인 대기)

## 배경/요구사항
- 현재는 예문(문장) 단위의 카드들을 바로 복습 대상으로 취급함.
- 요구: 예문 10개 등 한 번의 학습으로 생성된 묶음을 "한 덩이(세트)"로 취급하고, 복습 탭에서 "복습 시작하기"를 누르면 한 세트만 학습 → 완료 후 복습 리스트로 복귀.
- 다시 "복습 시작하기"를 누르면 다음 세트를 시작하는 흐름.

## 목표
- 학습으로 생성된 예문 리스트를 하나의 ReviewSet으로 저장.
- 복습 탭에서는 세트 목록(오늘/지연/전체) 기준으로 표시 및 진행.
- "복습 시작하기"는 가장 먼저 기한이 도래한 세트 1개만 실행.
- 세트 단위로 FSRS Good(2) 스케줄을 적용해 다음 복습 주기 저장(초기: 동일 테이블로 적용).

## 데이터 모델 변경
- ReviewCard(기존):
  - 필드 추가: `setId: String?` — 해당 카드가 속한 세트 식별자(없을 수도 있음/레거시 호환)
- ReviewSet(신규):
  - `id: string` — 세트 ID(예: `rs-<hash>`)
  - `title: string` — 세트 제목(패턴 또는 대표 문장 일부)
  - `itemIds: List<String>` — 세트에 포함된 카드 ID 목록
  - `count: int` — 포함 카드 개수(캐시)
  - `createdAt, updatedAt: int` — epoch millis
  - `due: int` — 다음 복습 예정 시각
  - `reps: int` — 세트 복습 횟수
  - `lastRating: int` — 마지막 평점(초기 2 고정)

## 저장소 설계(신규)
- `ReviewSetRepository`
  - `Future<String> createSet({required String title, required List<ReviewCard> cards, DateTime? now})`
  - `Future<List<ReviewSet>> fetchDueSets({DateTime? now})`
  - `Future<List<ReviewSet>> fetchAllSets()`
  - `Future<void> deleteSet(String setId, {bool cascadeCards = false})` — 필요 시 카드도 함께 삭제 옵션
  - `Future<void> updateSetAfterReview(String setId, {required int rating, DateTime? now})`
  - 저장 매체: shared_preferences(키 `review_sets_v1`), 구조는 JSON 배열
- 호환: 카드 저장은 기존 `ReviewRepository` 유지. 세트 생성 시 각 카드에 `setId` 주입 후 upsert.

## FSRS(세트 단위)
- 초기 단계는 카드와 동일 Good(2) 전용 테이블을 세트에 그대로 적용: [1,3,7,14,30,60,120,240]
- 세트 완료 시 `reps` 증가 및 `due` 갱신.
- 카드별 진행(선택): 세트 진행 중 `onItemReviewed`를 통해 카드의 reps/스케줄은 유지(추가 정보로 활용). 주 복습 스케줄은 세트를 기준으로 동작.

## UI/흐름 변경
- 저장 시점(학습 종료):
  - ChatPage/SpeakingPage 완료 콜백에서 1) 카드 upsert(기존) + 2) ReviewSet 생성 및 각 카드에 setId 주입
  - 테스트 플래그가 켜져 있으면 세트 `due=now`로 설정해 즉시 복습 가능
- 복습 탭(ReviewHomePage):
  - 목록: 세트 기준(오늘/지연/전체 KPI 포함). 각 셀에 제목/개수/예정일 표시
  - "복습 시작하기": 가장 빠른 due의 세트 1개만 SpeakingPage로 전달(해당 세트의 카드들만 변환)
  - 완료 후: `updateSetAfterReview(Good)`로 세트 스케줄 갱신 → 리스트 리프레시
  - 삭제: 세트 단위 삭제(옵션으로 카드까지 삭제)

## 단계별 구현 계획
1) 모델/레포 준비
   - ReviewCard에 `setId` 추가(선택적)
   - `ReviewSet` 모델/직렬화
   - `ReviewSetRepository` 인터페이스 + prefs 구현
   - 유닛 테스트: 생성/조회/기한필터/갱신/삭제

2) 학습 저장 연동(세트 생성)
   - ChatPage의 `_handleSpeakingComplete`에서 세트 생성 로직 추가
   - 카드 upsert 이후 세트 생성 및 카드에 `setId` 부여 후 저장 재반영
   - 테스트 플래그: `immediateReviewAfterComplete`가 true면 세트 due=now

3) 복습 탭 전환
   - ReviewHomePage를 세트 목록으로 전환 (`fetchDueSets` 사용)
   - "복습 시작하기" → 가장 이른 세트 1개만 SpeakingPage로 전달
   - 완료 시 `updateSetAfterReview(2)` 호출, 스낵바/리프레시

4) 마이그레이션/호환(간단)
   - setId 없는 카드(레거시)는 세트 목록에 노출하지 않음(추후 선택/묶기 기능 추가 계획)

5) 테스트/검증
   - 세트 생성/조회/갱신/삭제 유닛 테스트
   - 흐름 검증: 학습 → 세트 생성 → 복습 탭에 세트 노출 → 한 세트만 Speaking → 완료 후 다음 세트 노출

## 수용 기준(AC)
- 학습 완료 후 예문 10개가 1개의 세트로 저장된다.
- 복습 탭에서 "복습 시작하기"를 누르면 가장 먼저 기한이 도래한 세트 1개만 Speaking으로 진행된다.
- 세트 완료 후 다음 세트(있다면)만 다시 진행할 수 있다.
- 테스트 설정 활성 시(즉시 복습) 방금 생성한 세트가 바로 복습 리스트에 나타난다.

## 요청
- 위 세트 기반 전환 계획 승인 시, 1) 모델/레포부터 구현을 시작하겠습니다.


# reps 과잉 증가(세션 1회에 3~4회 상승) 수정 계획 (승인 대기)

## 문제
- 현재 스피킹 한 세트(예: 예문 10개) 복습을 1회 진행해도 카드별 `reps`가 3~4회 증가할 수 있음.
- 원인: (1) SpeakingPage에서 라운드마다 호출되는 `onItemReviewed`에 의해 카드 단위 갱신이 여러 번 발생, (2) 세션 완료 시점에 다시 일괄 갱신, (3) 최초 생성 시 `reps=1`로 저장되어 학습 없이도 증가로 취급.

## 목표
- 세트 복습 1회당 카드별 `reps`는 정확히 1만 증가.
- 최초 생성(학습 직후 저장) 시 `reps=0` 유지(첫 복습 때 1로 상승).
- 라운드/중간 저장은 진행 상황 표시용일 뿐 `reps`를 올리지 않음.

## 수정 방안
1) 중간 콜백 비증가화
   - ChatPage/ReviewHomePage에서 SpeakingPage에 전달하는 `onItemReviewed` 콜백 사용 중지(삭제) 또는 내부에서 `reps` 미증가 정책으로 전환.
   - 필요 시 진행률(퍼센트) 등은 추후 별도 상태로 저장(다른 키)하되 `reps`에는 영향 X.

2) 최초 생성 시 reps=0으로 저장
   - ChatPage `_handleSpeakingComplete`에서 신규 `ReviewCard` 생성 시 `reps=0`으로 저장.
   - due는 기존 정책 유지(테스트 모드: now, 일반: 다음날 00:00).

3) 세트 완료 시 1회만 일괄 증가
   - ReviewHomePage `_onSpeakingComplete`에서 해당 세트의 카드 목록을 조회해, 각 카드에 대해 `updateAfterReview(rating:2)`를 정확히 1회만 호출(배치 적용).
   - 동일 세션 내 중복 호출 방지를 위해 플래그(예: `_sessionApplied=true`) 또는 로컬 집계로 보장.

4) 코드 정리
   - ChatPage 측 `onItemReviewed` 제거(학습 세션에서도 증가 안 함).
   - SpeakingPage에서 `onItemReviewed`는 제거하거나, 향후 진행률/통계용으로만 사용하도록 주석/명확화.

5) 테스트
   - 새 카드 생성 직후 reps=0 검증.
   - 세트 복습 1회 진행 후 카드 reps=1, 세트 reps=1, due=다음날 00:00 검증.
   - 라운드가 3회여도 증가 횟수는 1회임을 검증.

## 영향 범위
- 데이터 모델 변경 없음(동작 수정).
- 기존 저장 데이터는 유지. 이후 복습부터 새 규칙 적용.

## 승인 요청
- 위 방안으로 reps 과잉 증가 문제를 수정하겠습니다. 승인 시 구현 착수합니다.

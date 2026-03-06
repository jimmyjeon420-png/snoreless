# SnoreLess 글로벌 개발 마스터플랜

> "다른 앱은 녹음만 해줍니다. SnoreLess는 코골이를 멈춰줍니다."
> 목표: Apple Watch 가진 사람이면 누구나 쓰는 수면 필수 앱

---

## 전체 구조: 4개 Epic, 12개 Sprint

```
Epic 1: 글로벌 출시 기반        (Sprint 1~3)   ← 지금 여기
Epic 2: 제품 완성도 + 수익화    (Sprint 4~6)
Epic 3: 성장 엔진              (Sprint 7~9)
Epic 4: 플랫폼 확장            (Sprint 10~12)
```

각 Sprint = 1주 단위. Epic 끝날 때마다 App Store 업데이트 제출.

---

## 팀 에이전트 구성

| 에이전트 | 역할 | 수정 범위 |
|---------|------|----------|
| **Team Lead** | 태스크 분배, 통합 검증, 릴리즈 관리 | 전체 조율 (직접 코드 수정 최소화) |
| **Watch Agent** | watchOS 앱 전체 | `SnoreLessWatch/`, `Shared/` |
| **iPhone Agent** | iOS 앱 전체 | `SnoreLess/`, `Shared/` |
| **Infra Agent** | 빌드, CI/CD, 로컬라이즈, 설정 | `project.yml`, `*.xcstrings`, 빌드 스크립트 |
| **QA Agent** | 테스트 코드 작성, 검증, 리포트 | `Tests/` (코드 수정 금지, 읽기만 가능) |
| **Store Agent** | 스크린샷, 메타데이터, ASO | `docs/`, `screenshots/` |

### 병렬 실행 원칙
- Watch Agent + iPhone Agent: 항상 병렬 (Shared/ 변경 시 Lead가 머지)
- QA Agent: 각 Agent 작업 완료 후 즉시 검증 투입
- Store Agent: 코드 작업과 독립적으로 병렬 실행

---

## Epic 1: 글로벌 출시 기반 (v1.1)

### Sprint 1: 테스트 하네스 + 안정화

**목표**: 현재 코드에 테스트 인프라 구축. 이후 모든 변경은 테스트 통과 필수.

#### Team Lead
- [ ] Xcode Test 타겟 2개 생성 (SnoreLessTests, SnoreLessWatchTests)
- [ ] project.yml에 테스트 타겟 추가
- [ ] CI 스크립트 작성 (xcodebuild test → 리포트)

#### QA Agent (테스트 하네스 구축)
- [ ] `Tests/SnoreLessTests/` 디렉토리 구조 생성
- [ ] `Tests/SnoreLessWatchTests/` 디렉토리 구조 생성

**Unit Tests (워치)**:
- [ ] `SnoreDetectorTests.swift`
  - 배경소음 -50dB, 입력 -44dB → 감지됨 (4dB 초과)
  - 배경소음 -50dB, 입력 -48dB → 감지 안됨 (2dB, 미달)
  - 0.1초 소리 → 감지 안됨 (최소 0.2초 미달)
  - 9초 연속 소리 → 감지 안됨 (최대 8초 초과)
  - 60초 내 2회 반복 → 코골이 확정
  - 60초 내 1회만 → 코골이 아님
  - reset() 후 상태 초기화 확인
- [ ] `HapticControllerTests.swift`
  - 강도별 (light/medium/strong) 에스컬레이션 단계 확인
  - 타이머 간격 검증
  - reset() 후 단계 초기화
- [ ] `SmartAlarmTests.swift`
  - 알람 시간 이전: 트리거 안됨
  - 알람 윈도우 내 + 움직임 감지: 트리거됨
  - 알람 정시: 무조건 트리거됨
- [ ] `SleepSessionDataTests.swift`
  - Codable 인코딩/디코딩 왕복 검증
  - 빈 이벤트 배열 처리
  - 날짜 직렬화 정확도

**Unit Tests (아이폰)**:
- [ ] `WatchConnectorTests.swift`
  - userInfo 수신 → SleepSession 저장 확인
  - 잘못된 데이터 → 크래시 없이 무시
- [ ] `NotificationManagerTests.swift`
  - 아침 리포트 알림 스케줄 확인
  - 취침 리마인더 시간 정확도

**Integration Tests**:
- [ ] `WatchPhoneCommunicationTests.swift`
  - SnoreMessage 키 일관성 (양쪽 동일한 키 사용)
  - SleepSessionData 직렬화 → 역직렬화 왕복

#### Watch Agent (안정화)
- [ ] 배터리 최적화: 오디오 버퍼 처리 간격 조절 (4096 → 8192 프레임)
- [ ] 캘리브레이션 중 UI 피드백 개선 (진행률 표시)
- [ ] 엣지케이스: 마이크 권한 거부 시 안내 화면
- [ ] 엣지케이스: 세션 중 앱 크래시 → 자동 복구

#### iPhone Agent (안정화)
- [ ] 엣지케이스: 워치 미연결 시 대시보드 안내
- [ ] 엣지케이스: 데이터 0건일 때 모든 화면 빈 상태 처리
- [ ] 녹음 파일 관리: 30일 초과 자동 삭제
- [ ] 메모리 최적화: 대량 세션 로드 시 페이지네이션

#### 검증 기준 (Sprint 1 완료 조건)
```
- [ ] xcodebuild test 전체 통과 (0 failures)
- [ ] 테스트 커버리지: SnoreDetector > 90%, 나머지 > 60%
- [ ] 실기기(Watch + iPhone) 8시간 연속 실행 크래시 없음
- [ ] 메모리 릭 없음 (Instruments Leaks 0건)
```

---

### Sprint 2: 다국어 시스템

**목표**: String Catalog 도입, 영어 + 일본어 지원

#### Infra Agent
- [ ] `Localizable.xcstrings` 생성 (String Catalog)
- [ ] project.yml에 로컬라이즈 설정 추가 (ko, en, ja)
- [ ] 빌드 스크립트에 미번역 키 검출 추가

#### Watch Agent
- [ ] SleepTrackingView.swift 한국어 → String(localized:) 전환
- [ ] WatchSettingsView.swift 한국어 → String(localized:) 전환
- [ ] 모든 print 로그는 영어 유지 (디버깅용)

#### iPhone Agent
- [ ] OnboardingView.swift 한국어 → String(localized:) 전환
- [ ] DashboardView.swift 한국어 → String(localized:) 전환
- [ ] HistoryView.swift 한국어 → String(localized:) 전환
- [ ] SettingsView.swift 한국어 → String(localized:) 전환
- [ ] PartnerShareView.swift 한국어 → String(localized:) 전환
- [ ] SnorePlaybackView.swift 한국어 → String(localized:) 전환
- [ ] ContentView.swift 탭 이름 전환

#### Store Agent (병렬)
- [ ] 영어 스크린샷 6장 생성
- [ ] 일본어 스크린샷 6장 생성
- [ ] 각 언어별 App Store 설명문 작성
- [ ] 각 언어별 키워드 리서치 (경쟁 앱 분석)

#### QA Agent
- [ ] 로컬라이즈 테스트: 모든 키에 한/영/일 번역 존재 확인
- [ ] 레이아웃 테스트: 긴 영어/일본어 텍스트에서 UI 깨짐 없음
- [ ] 시뮬레이터 언어 변경 후 전체 화면 스크린샷 자동 캡처

#### 검증 기준
```
- [ ] 3개 언어 전환 시 크래시 없음
- [ ] 미번역 키 0개 (빌드 스크립트 검증)
- [ ] 각 언어별 스크린샷 6장 완성
```

---

### Sprint 3: v1.1 릴리즈

**목표**: 글로벌 3개국 출시 + 랜딩 페이지

#### Infra Agent
- [ ] 버전 1.1.0 / 빌드 3으로 업데이트
- [ ] Archive + TestFlight 업로드
- [ ] Xcode Cloud 기본 설정 (main push → 자동 빌드)

#### Store Agent
- [ ] 랜딩 페이지 (snoreless.app 또는 GitHub Pages)
- [ ] 한/영/일 3개 언어 App Store 메타 최종 검수
- [ ] 개인정보처리방침 영어/일본어 버전 추가
- [ ] What's New 작성 (3개 언어)

#### QA Agent (릴리즈 검증)
- [ ] 전체 테스트 스위트 실행 → 0 failures
- [ ] 실기기 스모크 테스트 (한/영/일 각각):
  - 온보딩 → 권한 허용 → 대시보드
  - 워치에서 수면 시작 → 캘리브레이션 → 모니터링 → 종료
  - 아이폰에서 세션 확인 → 녹음 재생
  - 설정 변경 → 워치 동기화 확인
- [ ] 배터리 테스트: 8시간 모니터링 후 워치 배터리 잔량 > 20%

#### 검증 기준 (Epic 1 완료 = v1.1 출시)
```
- [ ] TestFlight 빌드 정상
- [ ] 3개 언어 스모크 테스트 통과
- [ ] App Store 심사 제출 완료
- [ ] 랜딩 페이지 라이브
```

---

## Epic 2: 제품 완성도 + 수익화 (v2.0)

### Sprint 4: 수면 인텔리전스

#### Watch Agent
- [ ] CoreML 코골이 분류 모델 도입 (dB 임계값 → 소리 패턴)
  - 학습 데이터: ESC-50 데이터셋 중 snoring 클래스
  - 모델: 경량 MobileNet 변형 (watchOS 실행 가능)
  - 입력: 2초 Mel-spectrogram → 출력: snoring/not_snoring 확률
- [ ] 수면 자세 추정 (가속도계 데이터 패턴)
- [ ] 코골이 강도 3단계 분류 (가벼움/보통/심함)

#### iPhone Agent
- [ ] 수면 품질 점수 (100점 만점)
  - 코골이 횟수 (적을수록 높음)
  - 진동 반응률 (높을수록 높음)
  - 총 수면 시간
  - 자세 변경 빈도
- [ ] AI 패턴 분석 화면 (체크인 데이터 상관관계)
  - "술 마신 날 코골이 2.3배"
  - "운동한 날 37% 감소"
  - "스트레스 높은 주 평균 +2.1회"
- [ ] 데일리 체크인 개선 (음주/운동/스트레스/식사 기록)
- [ ] HealthKit 연동 강화 (심박수, 혈중산소)

#### QA Agent
- [ ] CoreML 모델 정확도 테스트: precision > 85%, recall > 80%
- [ ] 수면 점수 계산 로직 유닛 테스트
- [ ] AI 분석 엣지케이스: 데이터 1일/3일/7일/30일 각각 테스트
- [ ] HealthKit 권한 거부 시 graceful degradation 확인

---

### Sprint 5: 위젯 + 컴플리케이션 + UX 완성

#### Watch Agent
- [ ] Apple Watch 컴플리케이션 (어젯밤 코골이 횟수)
- [ ] 워치 페이스 위젯 (수면 점수)
- [ ] Always-On Display 최적화 (모니터링 중 최소 UI)

#### iPhone Agent
- [ ] 잠금화면 위젯 (어젯밤 점수, 연속 기록)
- [ ] 홈화면 위젯 (주간 트렌드 미니 차트)
- [ ] Live Activity (수면 모니터링 중 Dynamic Island 표시)
- [ ] Shortcuts/Siri 연동 ("어젯밤 코골이 어땠어?")
- [ ] 애니메이션 폴리싱 (트랜지션, 차트 애니메이션)

#### QA Agent
- [ ] 위젯 데이터 갱신 정확도 테스트
- [ ] Live Activity 상태 전환 테스트
- [ ] 전체 UI 스크린샷 회귀 테스트 (3개 언어 x 모든 화면)

---

### Sprint 6: 구독 + v2.0 릴리즈

#### iPhone Agent
- [ ] StoreKit 2 구독 구현
  - 상품: 월간 ($3.99), 연간 ($29.99)
  - 7일 무료 체험
  - 가족 공유 지원
- [ ] Paywall 화면 (A/B 테스트 가능한 구조)
- [ ] 구독 상태 관리 (Premium 기능 잠금/해제)
- [ ] 복원 구매 기능

#### Infra Agent
- [ ] App Store Connect 구독 상품 등록
- [ ] StoreKit Configuration 파일 (로컬 테스트용)
- [ ] 버전 2.0.0 / 빌드 업데이트
- [ ] 추가 언어 3개 (독일어, 스페인어, 포르투갈어) → 6개국어

#### QA Agent
- [ ] StoreKit 테스트: 구매 → 활성화 → 만료 → 갱신 전체 플로우
- [ ] Paywall 표시 조건 테스트 (무료 사용자만)
- [ ] 복원 구매 테스트
- [ ] 구독 만료 후 프리미엄 기능 잠금 확인
- [ ] Sandbox 환경 전체 결제 플로우 검증

#### 검증 기준 (Epic 2 완료 = v2.0 출시)
```
- [ ] CoreML 코골이 분류 정확도 > 85%
- [ ] 수면 점수 계산 테스트 통과
- [ ] StoreKit 전체 플로우 테스트 통과
- [ ] 6개 언어 전체 화면 정상
- [ ] 위젯 + 컴플리케이션 정상 작동
- [ ] 실기기 7일 연속 사용 테스트 통과
```

---

## Epic 3: 성장 엔진 (v2.5)

### Sprint 7: 바이럴 + 소셜

- [ ] 파트너 초대 시스템 (딥링크 → 설치 → 연결)
- [ ] 수면 리포트 공유 카드 디자인 고도화 (인스타 스토리 사이즈)
- [ ] "함께 자는 사람" 프로필 연결 (서로 리포트 확인)
- [ ] 앱 내 리뷰 요청 최적화 (코골이 감소 확인 시점)

### Sprint 8: 수면 코칭

- [ ] 4주 코골이 감소 프로그램
- [ ] 자세 교정 가이드 (그림 + 설명)
- [ ] 생활습관 추천 (데이터 기반)
- [ ] 주간 리포트 자동 생성 + 푸시

### Sprint 9: 분석 + 최적화

- [ ] TelemetryDeck 또는 PostHog 도입 (프라이버시 우선)
- [ ] 퍼널 분석: 설치 → 온보딩 → 첫 수면 → D7 → 구독
- [ ] A/B 테스트 프레임워크 (Paywall, 온보딩 변형)
- [ ] ASO 자동화 (국가별 키워드 순위 추적)

---

## Epic 4: 플랫폼 확장 (v3.0+)

### Sprint 10: CloudKit + 기기 동기화

- [ ] CloudKit 연동 (기기 교체 시 데이터 보존)
- [ ] iPad 앱 (수면 대시보드 확장 뷰)

### Sprint 11: Android + WearOS

- [ ] Kotlin Multiplatform 또는 Flutter 검토
- [ ] Android 앱 + WearOS 워치 앱
- [ ] Samsung Galaxy Watch 지원

### Sprint 12: B2B + 헬스케어

- [ ] 수면클리닉 대시보드 (웹)
- [ ] 수면무호흡 사전검사 AI
- [ ] 보험사/기업 복지 연계 API

---

## 테스트 하네스 아키텍처

```
Tests/
├── SnoreLessTests/                    # iOS 유닛 테스트
│   ├── Models/
│   │   └── SleepModelsTests.swift     # SwiftData 모델 CRUD
│   ├── Services/
│   │   ├── WatchConnectorTests.swift  # 워치 통신 디코딩
│   │   └── NotificationTests.swift    # 알림 스케줄링
│   ├── Views/
│   │   └── DashboardViewTests.swift   # 뷰 상태 로직
│   └── Integration/
│       └── CommunicationTests.swift   # 메시지 키 일관성
│
├── SnoreLessWatchTests/               # watchOS 유닛 테스트
│   ├── Detection/
│   │   ├── SnoreDetectorTests.swift   # 핵심 감지 로직
│   │   ├── AudioProcessingTests.swift # RMS→dB 변환 정확도
│   │   └── CalibrationTests.swift     # 캘리브레이션 로직
│   ├── Response/
│   │   ├── HapticControllerTests.swift # 에스컬레이션 단계
│   │   └── SmartAlarmTests.swift      # 알람 트리거 조건
│   └── Communication/
│       ├── PhoneConnectorTests.swift  # 데이터 전송 포맷
│       └── SessionDataTests.swift     # Codable 왕복 검증
│
└── SnoreLessUITests/                  # UI 자동화 테스트
    ├── OnboardingFlowTests.swift      # 온보딩 3페이지 탐색
    ├── SleepTrackingFlowTests.swift   # 수면 시작→종료 플로우
    ├── SettingsFlowTests.swift        # 설정 변경 확인
    └── LocalizationTests.swift        # 3개 언어 전체 화면 캡처
```

### 테스트 실행 파이프라인

```
[코드 변경]
    → Watch Agent / iPhone Agent 작업 완료
    → QA Agent 투입
        → Step 1: xcodebuild test (Unit + Integration)
        → Step 2: 시뮬레이터 UI 테스트
        → Step 3: 실기기 스모크 테스트 (수동 체크리스트)
        → Step 4: 성능 테스트 (메모리, 배터리)
    → 전체 통과 시 → Team Lead 머지 승인
    → 실패 시 → 해당 Agent에게 수정 요청 + 재검증
```

### QA 리포트 포맷

```
## QA Report — Sprint X
- Date: YYYY-MM-DD
- Build: vX.X.X (build N)

### Unit Tests
- Total: XX | Pass: XX | Fail: XX
- Coverage: XX%

### UI Tests
- Screens tested: XX/XX
- Languages: ko/en/ja
- Issues found: [list]

### Device Tests
- iPhone: [model] — [pass/fail]
- Watch: [model] — [pass/fail]
- Battery (8h): XX% remaining

### Blockers
- [list or "None"]

### Verdict: PASS / FAIL
```

---

## Sprint 실행 프로토콜

### 각 Sprint 시작 시
1. Team Lead가 태스크 분해 + 의존성 맵 작성
2. 병렬 가능한 태스크를 각 Agent에 배분
3. QA Agent에게 검증 기준 전달

### 각 Sprint 중
4. Watch Agent + iPhone Agent 병렬 작업
5. Store Agent / Infra Agent 독립 병렬 작업
6. 각 Agent 완료 → QA Agent 즉시 검증
7. 3회 연속 진전 없으면 Team Lead에게 보고

### 각 Sprint 종료 시
8. QA Agent 최종 리포트 작성
9. Team Lead 통합 빌드 + 실기기 최종 확인
10. 검증 기준 전체 통과 → 다음 Sprint 진행

---

## 즉시 실행 계획: Sprint 1 시작

Sprint 1의 첫 번째 작업은 테스트 하네스 구축입니다.

### 병렬 실행 구조

```
[Infra Agent]  ──→ project.yml에 테스트 타겟 추가 + xcodegen
        │
        ▼
[QA Agent]     ──→ 테스트 파일 전체 작성 (Unit + Integration)
        │
        │         동시에:
[Watch Agent]  ──→ 배터리 최적화 + 엣지케이스 처리
[iPhone Agent] ──→ 빈 상태 처리 + 녹음 파일 관리
        │
        ▼
[QA Agent]     ──→ 전체 테스트 실행 + 리포트
        │
        ▼
[Team Lead]    ──→ 통합 빌드 확인 + Sprint 1 완료 판정
```

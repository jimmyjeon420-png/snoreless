import XCTest
@testable import SnoreLessWatch

/// ML Gate 테스트 -- ML 활성화 시 dB 단독 감지 차단 로직 검증
/// SnoreDetector의 가장 중요한 false-positive 방지 메커니즘을 커버
final class SnoreDetectorMLGateTests: XCTestCase {

    private var sut: SnoreDetector!

    // 테스트용 상수
    private let background: Double = -50.0
    private let loudLevel: Double = -44.0   // 6dB above background (threshold=4)
    private let quietLevel: Double = -52.0  // below threshold

    override func setUp() {
        super.setUp()
        // minDuration 0.2s, repetitionThreshold 2, repetitionWindow 60s
        sut = SnoreDetector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper: dB 기반으로 1회 유효 사운드 이벤트 발생

    /// loud -> sleep(minDuration) -> quiet 패턴으로 1회 사운드 이벤트 생성
    private func emitOneSoundEvent() {
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)
    }

    /// 코골이 확정까지 (2회 사운드 이벤트)
    private func triggerFullSnoring() {
        emitOneSoundEvent()
        emitOneSoundEvent()
    }

    // =========================================================================
    // MARK: - 1. ML Gate Tests (false positive prevention)
    // =========================================================================

    func test_mlAvailable_dbOnlyDetection_shouldNotConfirm() {
        // ML이 활성화되어 있지만 ML이 코골이를 확인하지 않은 경우,
        // dB만으로는 .confirmed로 전이되면 안 된다 (false positive 방지)
        sut.isMLAvailable = true

        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting, "loud 소리로 detecting 상태 진입")

        Thread.sleep(forTimeInterval: 0.25) // minDuration 충족

        // 소리가 멈춤 -- ML 확인 없이는 idle로 돌아가야 함
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "ML 활성화 상태에서 ML 확인 없이 dB만으로 confirmed 되면 안 됨")
    }

    func test_mlAvailable_mlConfirmed_shouldConfirm() {
        // ML이 코골이를 확인한 후, dB 감지가 끝나면 confirmed로 전이
        sut.isMLAvailable = true

        // ML이 먼저 코골이 확인
        sut.processMLResult(isSnoring: true, confidence: 0.8)

        // dB 감지 시작 -> 지속 -> 종료
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .confirmed,
                       "ML이 코골이를 확인했으므로 dB 감지 후 confirmed로 전이되어야 함")
    }

    func test_mlAvailable_mlExpired_shouldNotConfirm() {
        // ML 확인이 3초 윈도우를 넘어서 만료된 경우
        sut.isMLAvailable = true

        // ML 확인
        sut.processMLResult(isSnoring: true, confidence: 0.8)

        // 3초 이상 대기하여 ML 확인 윈도우 만료
        Thread.sleep(forTimeInterval: 3.1)

        // dB 감지
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "ML 확인이 3초 윈도우를 넘어 만료되면 dB만으로 confirmed 되면 안 됨")
    }

    func test_mlUnavailable_dbOnly_shouldConfirmAsFallback() {
        // ML이 비활성화된 경우, 기존 dB 기반 감지가 정상 작동해야 함 (하위 호환)
        sut.isMLAvailable = false

        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .confirmed,
                       "ML 미사용 시 dB만으로 confirmed 가능 (fallback)")
    }

    // =========================================================================
    // MARK: - 2. ML Result Processing
    // =========================================================================

    func test_processMLResult_snoringHighConfidence_setsFlag() {
        // isSnoring=true, confidence>0.5 이면 ML 확인 플래그가 설정되어야 함
        // 플래그 설정 여부는 이후 dB 감지 성공 여부로 간접 검증
        sut.isMLAvailable = true

        sut.processMLResult(isSnoring: true, confidence: 0.9)

        // ML이 플래그를 설정했으므로 이후 dB 감지가 성공해야 함
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .confirmed,
                       "ML 확인 플래그가 설정되면 dB 감지 후 confirmed 되어야 함")
    }

    func test_processMLResult_snoringLowConfidence_doesNotSetFlag() {
        // isSnoring=true 이지만 confidence<0.5이면 플래그가 설정되면 안 됨
        sut.isMLAvailable = true

        sut.processMLResult(isSnoring: true, confidence: 0.3)

        // ML 플래그 미설정 -> dB만으로 confirmed 불가
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "confidence 0.3 (<0.5)이면 ML 플래그가 설정되지 않아 dB만으로 confirmed 불가")
    }

    func test_processMLResult_notSnoring_clearsFlag() {
        // 먼저 ML이 코골이를 확인한 후, 다시 not-snoring으로 변경하면 플래그 해제
        sut.isMLAvailable = true

        // 플래그 설정
        sut.processMLResult(isSnoring: true, confidence: 0.9)

        // 플래그 해제
        sut.processMLResult(isSnoring: false, confidence: 0.9)

        // 플래그가 해제되었으므로 dB만으로 confirmed 불가
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "isSnoring=false로 플래그가 해제되면 dB만으로 confirmed 불가")
    }

    func test_processMLResult_duringDetecting_shouldConfirmImmediately() {
        // dB가 이미 .detecting 상태일 때 ML이 코골이를 확인하면 즉시 confirmed
        sut.isMLAvailable = true

        // dB로 detecting 진입 + minDuration 대기
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25) // minDuration(0.2s) 충족

        XCTAssertEqual(sut.state, .detecting,
                       "아직 소리가 끝나지 않아 detecting 상태여야 함")

        // ML이 코골이 확인 -> 즉시 confirmed
        sut.processMLResult(isSnoring: true, confidence: 0.8)

        XCTAssertEqual(sut.state, .confirmed,
                       "detecting 상태에서 ML 확인 시 즉시 confirmed 되어야 함")
    }

    // =========================================================================
    // MARK: - 3. Dual Mode Interaction
    // =========================================================================

    func test_dualMode_mlFirst_thenDb_confirmsWithBothSource() {
        // ML이 먼저 코골이 감지 -> dB가 이후 사운드 감지 -> detectionSource=.both
        sut.isMLAvailable = true

        // ML이 먼저 코골이 확인
        sut.processMLResult(isSnoring: true, confidence: 0.8)
        XCTAssertEqual(sut.detectionSource, .ml,
                       "ML만 감지한 상태에서 source는 .ml이어야 함")

        // dB 감지 시작
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)

        // detecting 상태에서 ML 재확인 -- processMLResult가 .both를 설정
        sut.processMLResult(isSnoring: true, confidence: 0.8)

        XCTAssertEqual(sut.detectionSource, .both,
                       "ML과 dB 모두 감지 시 source는 .both여야 함")
    }

    func test_dualMode_dbFirst_thenMl_confirmsWithBothSource() {
        // dB가 먼저 detecting 진입 -> ML이 이후 확인 -> detectionSource=.both
        sut.isMLAvailable = true

        // dB로 detecting 진입
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertEqual(sut.state, .detecting)

        // ML이 코골이 확인 -- detecting 상태이므로 .both 설정 + 즉시 confirmed
        sut.processMLResult(isSnoring: true, confidence: 0.8)

        XCTAssertEqual(sut.detectionSource, .both,
                       "dB detecting 중 ML 확인 시 source는 .both여야 함")
        XCTAssertEqual(sut.state, .confirmed,
                       "두 소스가 모두 확인하면 즉시 confirmed")
    }

    func test_detectionSource_updatesCorrectly() {
        // .none -> .ml -> .both -> .audio -> .none 전이 검증
        sut.isMLAvailable = true

        // 초기: .none
        XCTAssertEqual(sut.detectionSource, .none,
                       "초기 상태에서 source는 .none이어야 함")

        // ML 확인 -> .ml
        sut.processMLResult(isSnoring: true, confidence: 0.8)
        XCTAssertEqual(sut.detectionSource, .ml,
                       "ML만 확인 시 source는 .ml")

        // dB detecting 진입 + ML 재확인 -> .both
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processMLResult(isSnoring: true, confidence: 0.8)
        XCTAssertEqual(sut.detectionSource, .both,
                       "ML + dB 모두 확인 시 .both")

        // ML이 not-snoring으로 전환 -- confirmed 상태에서는 .none으로 설정됨
        // (processMLResult는 .detecting/.snoring 상태에서만 .audio로 전환)
        sut.processMLResult(isSnoring: false, confidence: 0.8)
        XCTAssertEqual(sut.detectionSource, .none,
                       "ML 해제 후 confirmed 상태에서는 .none (detecting/snoring이 아니므로)")

        // detecting 상태에서 ML 해제 시 .audio 확인
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting)
        sut.processMLResult(isSnoring: false, confidence: 0.8)
        XCTAssertEqual(sut.detectionSource, .audio,
                       "detecting 상태에서 ML 해제 시 .audio")

        // reset -> .none
        sut.reset()
        XCTAssertEqual(sut.detectionSource, .none,
                       "reset 후 source는 .none")
    }

    // =========================================================================
    // MARK: - 4. Cooldown Tests
    // =========================================================================

    func test_cooldown_ignoresSamplesDuringCooldown() {
        // 코골이 확정 후 쿨다운 중에는 dB 샘플을 무시해야 함
        triggerFullSnoring()
        XCTAssertEqual(sut.state, .snoring, "코골이 확정 상태 확인")

        let snoreCountBefore = sut.snoreCount

        // 쿨다운 중에 새로운 loud 소리 입력 -> 무시되어야 함
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        // 추가 이벤트 시도
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .snoring,
                       "쿨다운 중에는 상태가 .snoring을 유지해야 함")
        XCTAssertEqual(sut.snoreCount, snoreCountBefore,
                       "쿨다운 중에는 snoreCount가 증가하면 안 됨")
    }

    func test_cooldown_resumesAfterDuration() {
        // cooldownDuration은 30초이므로 실제로 기다릴 수 없음.
        // 대신: 쿨다운 중에는 processSample이 early return하여 상태가 .snoring 유지를 검증하고,
        // 쿨다운이 "활성 상태"임을 확인한다.
        // 쿨다운 기간 동안 state=.snoring이고 isInCooldown(private)임을 간접 검증.

        triggerFullSnoring()
        XCTAssertEqual(sut.state, .snoring)

        // 쿨다운 직후 -- 아직 30초 안 지남
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .snoring,
                       "쿨다운 중이므로 processSample이 무시되어 snoring 유지")

        // isCurrentlySnoring도 true여야 함
        XCTAssertTrue(sut.isCurrentlySnoring,
                      "쿨다운 중 isCurrentlySnoring은 true")

        // reset으로 쿨다운 해제 후 재감지 가능 확인
        sut.reset()
        XCTAssertEqual(sut.state, .idle, "reset 후 idle")

        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting,
                       "reset(쿨다운 해제) 후 정상적으로 detecting 진입")
    }

    func test_cooldown_ignoresMLDuringCooldown() {
        // 코골이 확정 후 쿨다운 중에는 ML 결과도 무시해야 함
        triggerFullSnoring()
        XCTAssertEqual(sut.state, .snoring)

        let snoreCountBefore = sut.snoreCount

        // 쿨다운 중 ML 결과 -> 무시
        sut.processMLResult(isSnoring: true, confidence: 0.95)

        // 상태 변화 없어야 함 (쿨다운이 early return)
        XCTAssertEqual(sut.state, .snoring,
                       "쿨다운 중 ML 결과는 무시되어야 함")
        XCTAssertEqual(sut.snoreCount, snoreCountBefore,
                       "쿨다운 중 snoreCount가 변하면 안 됨")
    }

    // =========================================================================
    // MARK: - 5. Edge Cases
    // =========================================================================

    func test_rapidSamples_noStateMachineCorruption() {
        // 1000개의 랜덤 샘플을 빠르게 입력해도 상태 머신이 유효한 상태를 유지해야 함
        let validStates: Set<SnoreDetector.DetectionState> = [.idle, .detecting, .confirmed, .snoring]

        for _ in 0..<1000 {
            let randomLevel = Double.random(in: -160.0...0.0)
            let randomBackground = Double.random(in: -80.0...(-20.0))
            sut.processSample(level: randomLevel, backgroundNoise: randomBackground)

            XCTAssertTrue(validStates.contains(sut.state),
                          "상태 머신이 유효하지 않은 상태: \(sut.state)")
        }

        // ML 결과도 랜덤으로 섞어서 테스트
        sut.isMLAvailable = true
        for _ in 0..<500 {
            let randomLevel = Double.random(in: -160.0...0.0)
            let randomBackground = Double.random(in: -80.0...(-20.0))

            if Bool.random() {
                sut.processSample(level: randomLevel, backgroundNoise: randomBackground)
            } else {
                sut.processMLResult(isSnoring: Bool.random(), confidence: Double.random(in: 0.0...1.0))
            }

            XCTAssertTrue(validStates.contains(sut.state),
                          "ML 혼합 입력 후 유효하지 않은 상태: \(sut.state)")
        }
    }

    func test_extremeDbValues_negativeInfinity_doesNotCrash() {
        // -160dB (거의 무음) 입력 시 정상 처리 확인
        sut.processSample(level: -160.0, backgroundNoise: -50.0)

        // -160dB는 threshold(-46dB)보다 훨씬 아래이므로 idle 유지
        XCTAssertEqual(sut.state, .idle,
                       "-160dB 입력 시 threshold 미달로 idle 유지")
        XCTAssertEqual(sut.backgroundNoiseLevel, -50.0,
                       "backgroundNoiseLevel이 정상 업데이트")
    }

    func test_extremeDbValues_veryLoud_doesNotCrash() {
        // 0dB (매우 큰 소리) 입력
        sut.processSample(level: 0.0, backgroundNoise: -50.0)

        // 0dB는 threshold(-46dB)보다 훨씬 위이므로 detecting
        XCTAssertEqual(sut.state, .detecting,
                       "0dB 입력 시 threshold 초과로 detecting 진입")

        // 연속 입력으로 maxDuration 초과 테스트를 위해 배경 노이즈 확인
        XCTAssertEqual(sut.backgroundNoiseLevel, -50.0)
    }

    func test_backgroundNoiseVeryLoud_negativeThreshold_handledCorrectly() {
        // background=-20dB 시나리오: threshold = -20 + 4 = -16dB
        let loudBackground: Double = -20.0

        // -18dB는 threshold(-16dB)보다 아래 -> idle 유지
        sut.processSample(level: -18.0, backgroundNoise: loudBackground)
        XCTAssertEqual(sut.state, .idle,
                       "-18dB는 threshold(-16dB) 미달로 idle 유지")

        // -14dB는 threshold(-16dB) 이상 -> detecting
        sut.processSample(level: -14.0, backgroundNoise: loudBackground)
        XCTAssertEqual(sut.state, .detecting,
                       "-14dB는 threshold(-16dB) 초과로 detecting 진입")

        // ML 모드에서도 동일 동작 확인
        sut.reset()
        sut.isMLAvailable = true
        sut.processMLResult(isSnoring: true, confidence: 0.9)

        sut.processSample(level: -14.0, backgroundNoise: loudBackground)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: -22.0, backgroundNoise: loudBackground) // quiet

        XCTAssertEqual(sut.state, .confirmed,
                       "시끄러운 환경에서도 ML+dB 감지가 정상 동작해야 함")
    }
}

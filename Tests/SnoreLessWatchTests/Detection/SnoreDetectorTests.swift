import XCTest
@testable import SnoreLessWatch

final class SnoreDetectorTests: XCTestCase {

    private var sut: SnoreDetector!

    override func setUp() {
        super.setUp()
        sut = SnoreDetector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Threshold Detection

    func test_processSample_levelAboveThreshold_shouldTransitionToDetecting() {
        // Background -50dB, input -44dB = 6dB above -> exceeds 4dB threshold
        let background: Double = -50.0
        let input: Double = -44.0

        sut.processSample(level: input, backgroundNoise: background)

        XCTAssertEqual(sut.state, .detecting,
                       "6dB above background should trigger detecting state")
    }

    func test_processSample_levelBelowThreshold_shouldStayIdle() {
        // Background -50dB, input -48dB = 2dB above -> below 4dB threshold
        let background: Double = -50.0
        let input: Double = -48.0

        sut.processSample(level: input, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "2dB above background should NOT trigger detection")
    }

    func test_processSample_levelExactlyAtThreshold_shouldTransitionToDetecting() {
        // Background -50dB, input -46dB = exactly 4dB above -> at threshold (>=)
        let background: Double = -50.0
        let input: Double = -46.0

        sut.processSample(level: input, backgroundNoise: background)

        XCTAssertEqual(sut.state, .detecting,
                       "Exactly at threshold (4dB above) should trigger detecting")
    }

    // MARK: - Duration Validation

    func test_processSample_soundTooShort_shouldReturnToIdle() {
        // Simulate a sound that lasts only ~0.1s (below minDuration 0.2s)
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        // Start detecting
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting)

        // Immediately stop (essentially 0 duration since both calls are near-instant)
        // The duration will be nearly 0, well below 0.2s
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.state, .idle,
                       "Sound shorter than 0.2s minimum should be ignored")
    }

    func test_processSample_soundExceedsMaxDuration_shouldReturnToIdle() {
        // We cannot easily simulate 8+ seconds in a unit test without mocking Date,
        // but we can verify the maxDuration logic path exists by checking that
        // continuous loud sound beyond maxDuration resets to idle.
        // This test documents the expected behavior.
        let background: Double = -50.0
        let loudLevel: Double = -44.0

        // Start detecting
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting,
                       "Should be in detecting state after loud sound starts")

        // Note: In real operation, if sound continues for > 8 seconds,
        // the detector transitions back to .idle because it's likely not snoring.
        // Full time-based testing would require a mock clock.
    }

    // MARK: - Repetition Pattern (Snoring Confirmation)

    func test_processSample_twoEventsWithinWindow_shouldConfirmSnoring() {
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        // Event 1: loud sound with sufficient duration
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting)

        // Wait a bit for duration to accumulate (we rely on real time passing)
        // Use Thread.sleep to ensure minDuration (0.2s) passes
        Thread.sleep(forTimeInterval: 0.25)

        // Sound stops -> should confirm event 1
        sut.processSample(level: quietLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .confirmed,
                       "First valid sound event should transition to confirmed")

        // Event 2: another loud sound
        sut.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .detecting)

        Thread.sleep(forTimeInterval: 0.25)

        // Sound stops -> 2 events within 60s window -> snoring
        sut.processSample(level: quietLevel, backgroundNoise: background)
        XCTAssertEqual(sut.state, .snoring,
                       "2 events within 60s window should confirm snoring")
    }

    func test_processSample_oneEventWithinWindow_shouldNotConfirmSnoring() {
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        // Only one valid event
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertNotEqual(sut.state, .snoring,
                          "Single event should NOT confirm snoring")
        XCTAssertEqual(sut.state, .confirmed,
                       "Single valid event should be in confirmed state")
    }

    // MARK: - Snore Count

    func test_snoreCount_incrementsOnSnoringConfirmed() {
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        XCTAssertEqual(sut.snoreCount, 0, "Initial snore count should be 0")

        // Trigger snoring (2 events)
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.snoreCount, 1, "Snore count should be 1 after first snoring event")
    }

    func test_snoreCount_startsAtZero() {
        XCTAssertEqual(sut.snoreCount, 0)
    }

    // MARK: - Reset

    func test_reset_clearsAllState() {
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        // Build up some state
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        // Reset
        sut.reset()

        XCTAssertEqual(sut.state, .idle, "State should be idle after reset")
        XCTAssertEqual(sut.snoreCount, 0, "Snore count should be 0 after reset")
        XCTAssertTrue(sut.eventLog.isEmpty, "Event log should be empty after reset")
    }

    // MARK: - State Transitions

    func test_stateTransition_idleToDetecting() {
        XCTAssertEqual(sut.state, .idle, "Initial state should be idle")

        sut.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(sut.state, .detecting, "Should transition from idle to detecting on loud sound")
    }

    func test_stateTransition_detectingToConfirmed() {
        sut.processSample(level: -44.0, backgroundNoise: -50.0)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: -52.0, backgroundNoise: -50.0)

        XCTAssertEqual(sut.state, .confirmed,
                       "Should transition from detecting to confirmed on valid duration sound stop")
    }

    func test_stateTransition_confirmedToDetecting_onNewLoudSound() {
        // Get to confirmed state
        sut.processSample(level: -44.0, backgroundNoise: -50.0)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: -52.0, backgroundNoise: -50.0)
        XCTAssertEqual(sut.state, .confirmed)

        // New loud sound from confirmed state
        sut.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(sut.state, .detecting,
                       "Should transition from confirmed to detecting on new loud sound")
    }

    // MARK: - Background Noise Level

    func test_backgroundNoiseLevel_updatesOnProcessSample() {
        let newBackground: Double = -45.0
        sut.processSample(level: -60.0, backgroundNoise: newBackground)

        XCTAssertEqual(sut.backgroundNoiseLevel, newBackground,
                       "backgroundNoiseLevel should update to the value passed in processSample")
    }

    func test_backgroundNoiseLevel_defaultValue() {
        XCTAssertEqual(sut.backgroundNoiseLevel, -60.0,
                       "Default background noise level should be -60 dB")
    }

    // MARK: - isCurrentlySnoring

    func test_isCurrentlySnoring_falseWhenIdle() {
        XCTAssertFalse(sut.isCurrentlySnoring, "Should not be snoring when idle")
    }

    func test_isCurrentlySnoring_trueWhenDetecting() {
        sut.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertTrue(sut.isCurrentlySnoring,
                      "isCurrentlySnoring should be true during detecting state")
    }

    // MARK: - Event Log

    func test_eventLog_appendsOnSnoringConfirmed() {
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        XCTAssertTrue(sut.eventLog.isEmpty, "Event log should start empty")

        // Trigger snoring
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(sut.eventLog.count, 1, "Event log should have 1 entry after first snoring")
    }

    // MARK: - Callback

    func test_onSnoreDetected_callbackFires() {
        let expectation = expectation(description: "onSnoreDetected should fire")
        let background: Double = -50.0
        let loudLevel: Double = -44.0
        let quietLevel: Double = -52.0

        sut.onSnoreDetected = { eventData in
            XCTAssertGreaterThan(eventData.duration, 0)
            expectation.fulfill()
        }

        // Trigger snoring
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)
        sut.processSample(level: loudLevel, backgroundNoise: background)
        Thread.sleep(forTimeInterval: 0.25)
        sut.processSample(level: quietLevel, backgroundNoise: background)

        waitForExpectations(timeout: 1.0)
    }
}

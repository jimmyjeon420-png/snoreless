import XCTest
import WatchKit
@testable import SnoreLessWatch

// MARK: - Mock Haptic Engine

/// Records all haptic plays for verification without requiring a real device.
final class PipelineMockHapticEngine: HapticEngine {
    private(set) var playedTypes: [WKHapticType] = []
    private(set) var playCount: Int = 0

    func playHaptic(_ type: WKHapticType) {
        playedTypes.append(type)
        playCount += 1
    }

    func reset() {
        playedTypes.removeAll()
        playCount = 0
    }
}

// MARK: - Detection Pipeline Integration Tests

/// Integration tests that verify the full pipeline: SnoreDetector + HapticController
/// working together to simulate real user scenarios during sleep.
final class DetectionPipelineTests: XCTestCase {

    // MARK: - Test constants

    /// dB levels used across tests.
    /// Background noise is -50 dB; threshold is background + 4 = -46 dB.
    private let background: Double = -50.0
    private let loudLevel: Double = -44.0   // 6 dB above background (exceeds threshold)
    private let quietLevel: Double = -52.0  // below background (clearly quiet)

    // MARK: - Helpers

    /// Creates a SnoreDetector with short durations suitable for tests.
    private func makeDetector(
        minDuration: TimeInterval = 0.2,
        maxDuration: TimeInterval = 8.0,
        repetitionWindow: TimeInterval = 60.0,
        repetitionThreshold: Int = 2
    ) -> SnoreDetector {
        SnoreDetector(
            thresholdAboveBackground: 4.0,
            minDuration: minDuration,
            maxDuration: maxDuration,
            repetitionWindow: repetitionWindow,
            repetitionThreshold: repetitionThreshold
        )
    }

    /// Simulates a single sound event: loud for the given duration, then quiet.
    /// Returns after the event completes.
    private func simulateSoundEvent(
        detector: SnoreDetector,
        duration: TimeInterval,
        background bg: Double? = nil,
        loud: Double? = nil,
        quiet: Double? = nil
    ) {
        let bg = bg ?? background
        let loud = loud ?? loudLevel
        let quiet = quiet ?? quietLevel

        // Start loud sound
        detector.processSample(level: loud, backgroundNoise: bg)

        // Wait for the desired duration
        Thread.sleep(forTimeInterval: duration)

        // Sound stops
        detector.processSample(level: quiet, backgroundNoise: bg)
    }

    /// Triggers a full snoring confirmation: 2 sound events within the repetition window.
    /// After this call, detector.state should be .snoring and snoreCount incremented.
    private func triggerSnoring(
        detector: SnoreDetector,
        eventDuration: TimeInterval = 0.3
    ) {
        // Event 1
        simulateSoundEvent(detector: detector, duration: eventDuration)
        // Event 2
        simulateSoundEvent(detector: detector, duration: eventDuration)
    }

    // MARK: - Scenario 1: User talks in sleep -- no false positive

    func test_scenario_userTalksInSleep_noFalsePositive() {
        // Given: ML is available, loud sound detected, but ML says NOT snoring
        let detector = makeDetector()
        let mockEngine = PipelineMockHapticEngine()
        let haptic = HapticController(hapticEngine: mockEngine)
        detector.isMLAvailable = true

        var snoreCallbackFired = false
        detector.onSnoreDetected = { _ in
            snoreCallbackFired = true
        }

        // When: Loud sound starts (simulating talking)
        detector.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(detector.state, .detecting,
                       "Loud sound should trigger detecting state")

        // ML says: not snoring (e.g., speech)
        detector.processMLResult(isSnoring: false, confidence: 0.1)

        // Sound continues for valid duration, then stops
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: quietLevel, backgroundNoise: background)

        // Then: No snoring confirmed, state returns to idle
        XCTAssertEqual(detector.state, .idle,
                       "ML rejected the sound; state should return to idle")
        XCTAssertFalse(snoreCallbackFired,
                       "No snore callback should fire for speech")
        XCTAssertEqual(mockEngine.playCount, 0,
                       "No haptic should play for speech")
        XCTAssertEqual(detector.snoreCount, 0,
                       "Snore count should remain 0")
    }

    // MARK: - Scenario 2: User actually snores -- haptic fires

    func test_scenario_userActuallySnores_hapticFires() {
        // Given: ML available, detector wired to haptic controller
        let detector = makeDetector()
        let mockEngine = PipelineMockHapticEngine()
        let haptic = HapticController(hapticEngine: mockEngine)
        let phoneConnector = PhoneConnector()
        detector.isMLAvailable = true

        var snoreEvents: [SnoreEventData] = []
        detector.onSnoreDetected = { event in
            snoreEvents.append(event)
            // Wire haptic escalation (as AudioMonitor does)
            haptic.triggerEscalation(
                snoreDetector: detector,
                phoneConnector: phoneConnector
            )
        }

        // When: Event 1 -- loud sound + ML confirms snoring
        detector.processSample(level: loudLevel, backgroundNoise: background)
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: quietLevel, backgroundNoise: background)

        XCTAssertEqual(detector.state, .confirmed,
                       "First event should move to confirmed state")

        // Event 2 -- second snore event
        detector.processSample(level: loudLevel, backgroundNoise: background)
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: quietLevel, backgroundNoise: background)

        // Then: Snoring confirmed
        XCTAssertEqual(detector.state, .snoring,
                       "2 confirmed events should trigger snoring state")
        XCTAssertEqual(snoreEvents.count, 1,
                       "onSnoreDetected callback should fire exactly once")
        XCTAssertEqual(detector.snoreCount, 1,
                       "Snore count should be 1")

        // Allow async haptic dispatches to execute
        let hapticExpectation = expectation(description: "Haptic plays after dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hapticExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertGreaterThan(mockEngine.playCount, 0,
                             "Haptic should have played at least once after snore detection")
        XCTAssertTrue(mockEngine.playedTypes.contains(.click),
                      "First escalation should play .click haptic type")
    }

    // MARK: - Scenario 3: User snores then stops -- escalation stops

    func test_scenario_userSnoresThenStops_escalationStops() {
        // Given: Snoring triggers escalation
        let detector = makeDetector()
        let mockEngine = PipelineMockHapticEngine()
        let haptic = HapticController(hapticEngine: mockEngine)
        let phoneConnector = PhoneConnector()
        detector.isMLAvailable = false  // dB-only for simplicity

        detector.onSnoreDetected = { _ in
            haptic.triggerEscalation(
                snoreDetector: detector,
                phoneConnector: phoneConnector
            )
        }

        // When: Trigger snoring
        triggerSnoring(detector: detector)
        XCTAssertEqual(detector.state, .snoring,
                       "Snoring should be confirmed")

        // Then reset detector (simulates user stops snoring)
        detector.reset()
        XCTAssertFalse(detector.isCurrentlySnoring,
                       "After reset, isCurrentlySnoring should be false")
        XCTAssertEqual(detector.state, .idle,
                       "After reset, state should be idle")

        // The escalation timer checks isCurrentlySnoring before proceeding.
        // Since isCurrentlySnoring is now false, escalation should not advance
        // to second level. We wait for the first escalation timer to fire.
        let waitExpectation = expectation(description: "Wait for escalation timer check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            waitExpectation.fulfill()
        }
        waitForExpectations(timeout: 8.0)

        // Verify: no .notification haptics (second-level) were played
        let notificationCount = mockEngine.playedTypes.filter { $0 == .notification }.count
        XCTAssertEqual(notificationCount, 0,
                       "Escalation should NOT advance to second level after snoring stops")
    }

    // MARK: - Scenario 4: Single cough -- not snoring

    func test_scenario_singleCoughNotSnoring() {
        // Given: A very brief loud sound (0.1s, below minDuration of 0.2s)
        let detector = makeDetector(minDuration: 0.2)

        var snoreCallbackFired = false
        detector.onSnoreDetected = { _ in
            snoreCallbackFired = true
        }

        // When: Brief loud sound (cough)
        detector.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(detector.state, .detecting)

        // Very short duration -- immediately goes quiet
        Thread.sleep(forTimeInterval: 0.05)
        detector.processSample(level: quietLevel, backgroundNoise: background)

        // Then: Too short, returns to idle
        XCTAssertEqual(detector.state, .idle,
                       "Sound shorter than minDuration should be ignored")
        XCTAssertFalse(snoreCallbackFired,
                       "No callback for a brief cough")
        XCTAssertEqual(detector.snoreCount, 0)
    }

    // MARK: - Scenario 5: TV background noise -- no false positive

    func test_scenario_tvBackgroundNoise_noFalsePositive() {
        // Given: Continuous loud sound exceeding maxDuration (simulates TV/radio)
        let detector = makeDetector(maxDuration: 1.0)  // Short max for test speed

        var snoreCallbackFired = false
        detector.onSnoreDetected = { _ in
            snoreCallbackFired = true
        }

        // When: Loud sound starts
        detector.processSample(level: loudLevel, backgroundNoise: background)
        XCTAssertEqual(detector.state, .detecting)

        // Sound continues beyond maxDuration (1.0s)
        Thread.sleep(forTimeInterval: 1.2)

        // Another loud sample while still loud -- triggers maxDuration check
        detector.processSample(level: loudLevel, backgroundNoise: background)

        // Then: Resets to idle (not snoring, just continuous noise)
        XCTAssertEqual(detector.state, .idle,
                       "Continuous sound exceeding maxDuration should reset to idle")
        XCTAssertFalse(snoreCallbackFired,
                       "No snore callback for continuous TV noise")
        XCTAssertEqual(detector.snoreCount, 0)
    }

    // MARK: - Scenario 6: ML unavailable -- fallback to dB only

    func test_scenario_mlUnavailable_fallbackToDbOnly() {
        // Given: ML is not available, using dB-only detection
        let detector = makeDetector()
        detector.isMLAvailable = false

        var snoreEvents: [SnoreEventData] = []
        detector.onSnoreDetected = { event in
            snoreEvents.append(event)
        }

        // When: 2 snore-like sound events (dB-only confirmation)
        simulateSoundEvent(detector: detector, duration: 0.3)
        XCTAssertEqual(detector.state, .confirmed,
                       "First dB event should be confirmed without ML")

        simulateSoundEvent(detector: detector, duration: 0.3)

        // Then: Snoring confirmed via dB-only path (backward compatibility)
        XCTAssertEqual(detector.state, .snoring,
                       "2 dB events should confirm snoring without ML")
        XCTAssertEqual(snoreEvents.count, 1,
                       "Callback should fire once")
        XCTAssertEqual(detector.snoreCount, 1)
        XCTAssertEqual(detector.eventLog.count, 1,
                       "Event log should have 1 entry")
    }

    // MARK: - Scenario 7: Entire night with no snoring -- clean session

    func test_scenario_entireNightNoSnoring_cleanSession() {
        // Given: Detector monitoring all night with only quiet samples
        let detector = makeDetector()

        var snoreCallbackFired = false
        detector.onSnoreDetected = { _ in
            snoreCallbackFired = true
        }

        // When: Feed many quiet samples (simulating hours of silence)
        for _ in 0..<200 {
            detector.processSample(level: quietLevel, backgroundNoise: background)
        }

        // Then: Everything stays clean
        XCTAssertEqual(detector.state, .idle,
                       "State should always be idle with quiet samples")
        XCTAssertEqual(detector.snoreCount, 0,
                       "Snore count should remain 0 for a quiet night")
        XCTAssertTrue(detector.eventLog.isEmpty,
                      "Event log should be empty for a quiet night")
        XCTAssertFalse(snoreCallbackFired,
                       "No callback should fire for a quiet night")
    }

    // MARK: - Scenario 8: Multiple snore episodes with cooldowns

    func test_scenario_multipleSnoreEpisodes_withCooldowns() {
        // Given: Multiple snoring episodes separated by resets (simulating cooldown passing)
        let detector = makeDetector()
        detector.isMLAvailable = false

        var totalSnoreEvents = 0
        detector.onSnoreDetected = { _ in
            totalSnoreEvents += 1
        }

        // Episode 1: trigger snoring
        triggerSnoring(detector: detector)
        XCTAssertEqual(detector.state, .snoring)
        XCTAssertEqual(detector.snoreCount, 1, "First episode: snoreCount should be 1")

        // Simulate cooldown passing by resetting internal state
        // (In real usage, 30s cooldown would elapse; here we reset to test the next episode)
        let episode1Count = detector.snoreCount
        detector.reset()

        // Episode 2: trigger snoring again
        triggerSnoring(detector: detector)
        XCTAssertEqual(detector.state, .snoring)
        XCTAssertEqual(detector.snoreCount, 1,
                       "After reset, snoreCount restarts at 1 for the new episode")

        // Episode 3: one more
        detector.reset()
        triggerSnoring(detector: detector)

        // Then: Each episode produced a callback
        XCTAssertEqual(totalSnoreEvents, 3,
                       "Three episodes should produce 3 total snore callbacks")
    }

    // MARK: - Scenario 9: Haptic intensity change mid-session

    func test_scenario_hapticIntensityChange_midSession() {
        // Given: Start with light intensity
        let detector = makeDetector()
        let mockEngine = PipelineMockHapticEngine()
        let haptic = HapticController(hapticEngine: mockEngine)
        let phoneConnector = PhoneConnector()
        detector.isMLAvailable = false

        haptic.updateIntensity(.light)

        detector.onSnoreDetected = { _ in
            haptic.triggerEscalation(
                snoreDetector: detector,
                phoneConnector: phoneConnector
            )
        }

        // When: First episode with light intensity
        triggerSnoring(detector: detector)

        // Allow haptics to fire
        let firstExpectation = expectation(description: "First haptic batch completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            firstExpectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        let lightPlayCount = mockEngine.playCount
        XCTAssertGreaterThan(lightPlayCount, 0,
                             "Light intensity should produce haptic plays")

        // Change to strong intensity mid-session
        haptic.reset()
        detector.reset()
        mockEngine.reset()
        haptic.updateIntensity(.strong)

        detector.onSnoreDetected = { _ in
            haptic.triggerEscalation(
                snoreDetector: detector,
                phoneConnector: phoneConnector
            )
        }

        // Second episode with strong intensity
        triggerSnoring(detector: detector)

        let secondExpectation = expectation(description: "Second haptic batch completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        let strongPlayCount = mockEngine.playCount
        XCTAssertGreaterThan(strongPlayCount, 0,
                             "Strong intensity should produce haptic plays")

        // Strong intensity should produce MORE haptic plays than light
        // (light: 5 clicks at 0.4s interval; strong: 12 clicks at 0.25s interval)
        XCTAssertGreaterThan(strongPlayCount, lightPlayCount,
                             "Strong intensity should produce more haptic plays than light")
    }

    // MARK: - Scenario 10: Rapid start/stop -- no resource leak

    func test_scenario_rapidStartStop_noResourceLeak() {
        // Given: Rapid creation, detection, and reset cycles
        let detector = makeDetector()
        let mockEngine = PipelineMockHapticEngine()
        let haptic = HapticController(hapticEngine: mockEngine)

        detector.isMLAvailable = false

        // When: 100 rapid cycles of detect + reset
        for i in 0..<100 {
            // Start detection
            detector.processSample(level: loudLevel, backgroundNoise: background)
            XCTAssertEqual(detector.state, .detecting,
                           "Cycle \(i): should enter detecting on loud sound")

            // Reset everything
            detector.reset()
            haptic.reset()

            // Verify clean state after each reset
            XCTAssertEqual(detector.state, .idle,
                           "Cycle \(i): state should be idle after reset")
            XCTAssertEqual(detector.snoreCount, 0,
                           "Cycle \(i): snoreCount should be 0 after reset")
            XCTAssertTrue(detector.eventLog.isEmpty,
                          "Cycle \(i): eventLog should be empty after reset")
        }

        // Then: No crash, state is clean
        XCTAssertEqual(detector.state, .idle,
                       "Final state should be idle after 100 cycles")
        XCTAssertEqual(detector.snoreCount, 0,
                       "Final snoreCount should be 0")
        XCTAssertEqual(mockEngine.playCount, 0,
                       "No haptics should have played during rapid resets")
    }
}

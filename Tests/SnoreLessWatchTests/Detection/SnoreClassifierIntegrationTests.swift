import XCTest
@testable import SnoreLessWatch

final class SnoreClassifierIntegrationTests: XCTestCase {

    // MARK: - 1. DetectionSource enum has all expected cases

    func test_detectionSource_hasAllExpectedCases() {
        let none = SnoreDetector.DetectionSource.none
        let audio = SnoreDetector.DetectionSource.audio
        let ml = SnoreDetector.DetectionSource.ml
        let both = SnoreDetector.DetectionSource.both

        XCTAssertNotEqual(none, audio)
        XCTAssertNotEqual(none, ml)
        XCTAssertNotEqual(none, both)
        XCTAssertNotEqual(audio, ml)
        XCTAssertNotEqual(audio, both)
        XCTAssertNotEqual(ml, both)
    }

    // MARK: - 2. ML alone sets flag but does NOT confirm (ML gate)

    func test_processMLResult_highConfidence_setsFlagOnly() {
        let detector = SnoreDetector()

        // ML alone should NOT change state — it only sets mlConfirmedSnoring flag
        detector.processMLResult(isSnoring: true, confidence: 0.8)

        XCTAssertEqual(detector.state, .idle,
                       "ML alone should NOT confirm — dB must be in .detecting state first")
        XCTAssertEqual(detector.detectionSource, .ml,
                       "Source should be .ml when ML fires")
    }

    // MARK: - 3. Low confidence ML -> no detection

    func test_processMLResult_lowConfidence_noDetection() {
        let detector = SnoreDetector()

        detector.processMLResult(isSnoring: true, confidence: 0.3)

        XCTAssertEqual(detector.state, .idle,
                       "Low confidence ML result should not trigger detection")
        XCTAssertEqual(detector.detectionSource, .none,
                       "Source should be .none when confidence is below threshold")
    }

    func test_processMLResult_notSnoring_noDetection() {
        let detector = SnoreDetector()

        detector.processMLResult(isSnoring: false, confidence: 0.9)

        XCTAssertEqual(detector.state, .idle,
                       "isSnoring=false should not trigger detection regardless of confidence")
        XCTAssertEqual(detector.detectionSource, .none)
    }

    // MARK: - 4. Both ML and audio detecting -> detectionSource = .both

    func test_bothMLAndAudio_detectionSourceIsBoth() {
        let detector = SnoreDetector()

        // Start audio detection (put detector into .detecting state via loud sound)
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .detecting, "Should be detecting from audio")

        // Now ML also detects snoring while audio is in .detecting state
        detector.processMLResult(isSnoring: true, confidence: 0.8)

        XCTAssertEqual(detector.detectionSource, .both,
                       "When both audio and ML detect simultaneously, source should be .both")
    }

    // MARK: - 5. Reset clears all state including ML flags

    func test_processMLResult_afterReset_cleanState() {
        let detector = SnoreDetector()

        // Build up state via dB + ML dual mode
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .detecting)

        detector.processMLResult(isSnoring: true, confidence: 0.8)
        Thread.sleep(forTimeInterval: 0.3) // Wait for minDuration
        detector.processSample(level: -52.0, backgroundNoise: -50.0)
        // At this point state should be .confirmed or .snoring

        // Reset
        detector.reset()

        XCTAssertEqual(detector.state, .idle, "State should be idle after reset")
        XCTAssertEqual(detector.snoreCount, 0, "Snore count should be 0 after reset")
        XCTAssertEqual(detector.detectionSource, .none, "Detection source should be .none after reset")
        XCTAssertTrue(detector.eventLog.isEmpty, "Event log should be empty after reset")
    }

    // MARK: - 6. ML + dB dual mode triggers snoring after 2 events

    func test_dualMode_twoEvents_triggersSnoring() {
        let detector = SnoreDetector()
        detector.isMLAvailable = true

        // Event 1: dB detects, ML confirms
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: -52.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .confirmed, "First dual-mode event should confirm")

        // Event 2: dB detects, ML confirms
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: -52.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .snoring,
                       "Two dual-mode events within window should confirm snoring")
        XCTAssertEqual(detector.snoreCount, 1)
    }

    // MARK: - 7. Audio-only detection source when ML not detecting

    func test_audioOnly_detectionSourceIsAudio() {
        let detector = SnoreDetector()

        // Audio detects loud sound
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .detecting)

        // ML says no snoring while audio is detecting
        detector.processMLResult(isSnoring: false, confidence: 0.1)

        XCTAssertEqual(detector.detectionSource, .audio,
                       "When only audio is detecting, source should be .audio")
    }

    // MARK: - 8. ML gate: dB alone blocked when ML is available

    func test_mlAvailable_dbAlone_doesNotConfirm() {
        let detector = SnoreDetector()
        detector.isMLAvailable = true

        // dB detects sound but ML never confirms
        detector.processSample(level: -44.0, backgroundNoise: -50.0)
        XCTAssertEqual(detector.state, .detecting)
        Thread.sleep(forTimeInterval: 0.3)
        detector.processSample(level: -52.0, backgroundNoise: -50.0)

        XCTAssertEqual(detector.state, .idle,
                       "When ML is available but hasn't confirmed, dB alone should NOT confirm")
    }
}

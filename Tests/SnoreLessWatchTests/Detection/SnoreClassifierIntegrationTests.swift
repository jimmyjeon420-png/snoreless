import XCTest
@testable import SnoreLessWatch

final class SnoreClassifierIntegrationTests: XCTestCase {

    // MARK: - 1. DetectionSource enum has all expected cases

    func test_detectionSource_hasAllExpectedCases() {
        // Verify all four cases exist and are distinct
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

    // MARK: - 2. processMLResult with confidence > 0.5 triggers detection

    func test_processMLResult_highConfidence_triggersDetection() {
        let detector = SnoreDetector()

        // First ML result confirms one sound event
        detector.processMLResult(isSnoring: true, confidence: 0.8)

        // After one ML confirmation, state should be .confirmed (need 2 for .snoring)
        XCTAssertEqual(detector.state, .confirmed,
                       "First ML detection with high confidence should confirm a sound event")
        XCTAssertEqual(detector.detectionSource, .ml,
                       "Source should be .ml when only ML detects")
    }

    // MARK: - 3. processMLResult with confidence < 0.5 -> no detection

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

    // MARK: - 5. processMLResult after reset -> clean state

    func test_processMLResult_afterReset_cleanState() {
        let detector = SnoreDetector()

        // Build up state
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        XCTAssertEqual(detector.state, .confirmed)

        // Trigger snoring (second event)
        detector.processMLResult(isSnoring: true, confidence: 0.9)
        XCTAssertEqual(detector.state, .snoring)
        XCTAssertEqual(detector.snoreCount, 1)

        // Reset
        detector.reset()

        XCTAssertEqual(detector.state, .idle, "State should be idle after reset")
        XCTAssertEqual(detector.snoreCount, 0, "Snore count should be 0 after reset")
        XCTAssertEqual(detector.detectionSource, .none, "Detection source should be .none after reset")
        XCTAssertTrue(detector.eventLog.isEmpty, "Event log should be empty after reset")
    }

    // MARK: - 6. ML detection triggers snoring after 2 events (repetition threshold)

    func test_twoMLDetections_triggersSnoring() {
        let detector = SnoreDetector()

        // First ML detection
        detector.processMLResult(isSnoring: true, confidence: 0.7)
        XCTAssertEqual(detector.state, .confirmed)

        // Second ML detection (within repetition window)
        detector.processMLResult(isSnoring: true, confidence: 0.8)
        XCTAssertEqual(detector.state, .snoring,
                       "Two ML detections within window should confirm snoring")
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
}

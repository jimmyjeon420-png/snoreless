import XCTest
import WatchKit
@testable import SnoreLessWatch

// MARK: - Mock Haptic Engine

/// Records all haptic play calls for verification
private class MockHapticEngine: HapticEngine {
    var playedTypes: [WKHapticType] = []

    func playHaptic(_ type: WKHapticType) {
        playedTypes.append(type)
    }
}

// MARK: - Mock Phone Connector

/// Subclass PhoneConnector to intercept sendEscalationRequest without WCSession
private class MockPhoneConnector: PhoneConnector {
    var escalationRequestCount = 0

    override func sendEscalationRequest() {
        escalationRequestCount += 1
    }
}

// MARK: - Haptic Escalation Behavior Tests

final class HapticEscalationTests: XCTestCase {

    private var mockEngine: MockHapticEngine!
    private var sut: HapticController!
    private var snoreDetector: SnoreDetector!
    private var mockPhoneConnector: MockPhoneConnector!

    override func setUp() {
        super.setUp()
        mockEngine = MockHapticEngine()
        sut = HapticController(hapticEngine: mockEngine)
        snoreDetector = SnoreDetector()
        mockPhoneConnector = MockPhoneConnector()
    }

    override func tearDown() {
        sut.reset()
        sut = nil
        mockEngine = nil
        snoreDetector.reset()
        snoreDetector = nil
        mockPhoneConnector = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Runs the main RunLoop for the specified duration to allow
    /// DispatchQueue.main.asyncAfter and Timer callbacks to fire.
    private func advanceRunLoop(by seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - 1. First Escalation Plays Click Haptics

    func test_firstEscalation_playsClickHaptics() {
        // Default intensity is .medium (8 clicks at 0.3s interval)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Wait for all 8 clicks to fire: 7 * 0.3 = 2.1s, add buffer
        advanceRunLoop(by: 3.0)

        XCTAssertFalse(mockEngine.playedTypes.isEmpty,
                       "Should have played haptics after first escalation")
        XCTAssertTrue(mockEngine.playedTypes.allSatisfy { $0 == .click },
                      "First escalation should only play .click haptics, got: \(mockEngine.playedTypes)")
    }

    // MARK: - 2. Medium Intensity Plays Exactly 8 Clicks

    func test_firstEscalation_mediumIntensity_plays8Clicks() {
        sut.updateIntensity(.medium)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // 8 clicks at 0.3s interval -> last fires at 7*0.3 = 2.1s
        advanceRunLoop(by: 3.0)

        XCTAssertEqual(mockEngine.playedTypes.count, 8,
                       "Medium intensity should play exactly 8 clicks, got \(mockEngine.playedTypes.count)")
    }

    // MARK: - 3. Light Intensity Plays Exactly 5 Clicks

    func test_firstEscalation_lightIntensity_plays5Clicks() {
        sut.updateIntensity(.light)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // 5 clicks at 0.4s interval -> last fires at 4*0.4 = 1.6s
        advanceRunLoop(by: 3.0)

        XCTAssertEqual(mockEngine.playedTypes.count, 5,
                       "Light intensity should play exactly 5 clicks, got \(mockEngine.playedTypes.count)")
    }

    // MARK: - 4. Strong Intensity Plays Exactly 12 Clicks

    func test_firstEscalation_strongIntensity_plays12Clicks() {
        sut.updateIntensity(.strong)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // 12 clicks at 0.25s interval -> last fires at 11*0.25 = 2.75s
        advanceRunLoop(by: 4.0)

        XCTAssertEqual(mockEngine.playedTypes.count, 12,
                       "Strong intensity should play exactly 12 clicks, got \(mockEngine.playedTypes.count)")
    }

    // MARK: - 5. Second Escalation Plays Notification Haptics

    func test_secondEscalation_playsNotificationHaptics() {
        // Make snore detector report snoring so escalation continues past stage 1
        snoreDetector.state = .snoring

        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Stage 1: 8 clicks over ~2.1s, then 5s wait timer fires -> stage 2
        // Total wait: ~2.1s (clicks) + 5s (timer) + 3s (notification haptics) + buffer
        let expectation = expectation(description: "Second stage notification haptics")

        DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        let notificationHaptics = mockEngine.playedTypes.filter { $0 == .notification }
        let clickHaptics = mockEngine.playedTypes.filter { $0 == .click }

        XCTAssertEqual(clickHaptics.count, 8,
                       "First stage should have played 8 clicks")
        XCTAssertGreaterThan(notificationHaptics.count, 0,
                             "Second stage should play .notification haptics")
        XCTAssertEqual(notificationHaptics.count, 10,
                       "Medium intensity 2nd stage should play 10 notifications, got \(notificationHaptics.count)")
    }

    // MARK: - 6. Trigger While Already Escalating Is Ignored

    func test_triggerEscalation_whileAlreadyEscalating_isIgnored() {
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Immediately trigger again -- should be a no-op (guard !isEscalating)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        advanceRunLoop(by: 3.0)

        // Should still only have one set of haptics (8 for medium), not 16
        XCTAssertEqual(mockEngine.playedTypes.count, 8,
                       "Double trigger should not double the haptics, got \(mockEngine.playedTypes.count)")
    }

    // MARK: - 7. Reset Stops Escalation

    func test_reset_stopsEscalation() {
        // Start with snoring so stage 2 would fire after the timer
        snoreDetector.state = .snoring

        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Let first stage clicks start firing
        advanceRunLoop(by: 1.0)

        // Reset mid-escalation -- should cancel the timer to stage 2
        sut.reset()

        // Wait long enough for stage 2 to have fired if the timer were still active
        advanceRunLoop(by: 8.0)

        // No new notification haptics should have been added after reset
        let notificationHapticsAfterReset = mockEngine.playedTypes.filter { $0 == .notification }
        XCTAssertEqual(notificationHapticsAfterReset.count, 0,
                       "No notification haptics should fire after reset")

        // Some clicks may have been already queued via asyncAfter before reset,
        // but no new escalation stages should have started
        XCTAssertLessThanOrEqual(mockEngine.playedTypes.count, 8,
                                 "Should not exceed first stage haptic count after reset")
    }

    // MARK: - 8. Reset Allows New Escalation

    func test_reset_allowsNewEscalation() {
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)
        advanceRunLoop(by: 3.0)

        let firstRoundCount = mockEngine.playedTypes.count
        XCTAssertEqual(firstRoundCount, 8, "First round should play 8 clicks")

        // Reset clears isEscalating flag
        sut.reset()

        // New escalation should work
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)
        advanceRunLoop(by: 3.0)

        XCTAssertEqual(mockEngine.playedTypes.count, 16,
                       "After reset, new escalation should add 8 more clicks (total 16), got \(mockEngine.playedTypes.count)")
    }

    // MARK: - 9. Update Intensity Affects Next Escalation

    func test_updateIntensity_affectsNextEscalation() {
        sut.updateIntensity(.strong)
        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // 12 clicks at 0.25s interval -> last at 2.75s
        advanceRunLoop(by: 4.0)

        XCTAssertEqual(mockEngine.playedTypes.count, 12,
                       "After changing to strong, should play 12 clicks, got \(mockEngine.playedTypes.count)")
        XCTAssertTrue(mockEngine.playedTypes.allSatisfy { $0 == .click },
                      "All haptics should be .click type in first stage")
    }

    // MARK: - 10. Update Intensity During Escalation Affects Next Stage

    func test_updateIntensity_duringEscalation_affectsNextStage() {
        // Start as light intensity
        sut.updateIntensity(.light)

        // Snoring continues so we escalate to stage 2
        snoreDetector.state = .snoring

        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Wait for stage 1 clicks to fire (light = 5 clicks at 0.4s = 1.6s)
        advanceRunLoop(by: 2.0)

        // Change intensity to strong before stage 2 fires (timer at 5s)
        sut.updateIntensity(.strong)

        // Wait for timer (5s) + stage 2 haptics (strong = 15 at 0.2s = 2.8s)
        let expectation = expectation(description: "Stage 2 with changed intensity")
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 8.0)

        let clickCount = mockEngine.playedTypes.filter { $0 == .click }.count
        let notificationCount = mockEngine.playedTypes.filter { $0 == .notification }.count

        XCTAssertEqual(clickCount, 5,
                       "Stage 1 (light) should have 5 clicks, got \(clickCount)")
        XCTAssertEqual(notificationCount, 15,
                       "Stage 2 (strong) should have 15 notifications, got \(notificationCount)")
    }

    // MARK: - 11. iPhone Escalation Disabled Skips PhoneConnector at Stage 3

    func test_iPhoneEscalationDisabled_thirdStageSkipsPhoneConnector() {
        // Disable iPhone escalation (default is already false, but be explicit)
        var settings = AppSettings()
        settings.iPhoneEscalationEnabled = false
        sut.updateSettings(settings)

        // Snore detector keeps snoring through all stages
        snoreDetector.state = .snoring

        sut.triggerEscalation(snoreDetector: snoreDetector, phoneConnector: mockPhoneConnector)

        // Stage 1: ~2.4s clicks + 5s timer = ~7s
        // Stage 2: ~2.7s notifications + 10s timer = ~13s
        // Stage 3 fires at: ~20s total
        let expectation = expectation(description: "Reach stage 3")
        DispatchQueue.main.asyncAfter(deadline: .now() + 22.0) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 25.0)

        XCTAssertEqual(mockPhoneConnector.escalationRequestCount, 0,
                       "PhoneConnector should NOT be called when iPhoneEscalation is disabled")

        // Verify stages 1 and 2 did fire
        let clickCount = mockEngine.playedTypes.filter { $0 == .click }.count
        let notificationCount = mockEngine.playedTypes.filter { $0 == .notification }.count

        XCTAssertEqual(clickCount, 8, "Stage 1 should have fired 8 clicks")
        XCTAssertEqual(notificationCount, 10, "Stage 2 should have fired 10 notifications")
    }
}

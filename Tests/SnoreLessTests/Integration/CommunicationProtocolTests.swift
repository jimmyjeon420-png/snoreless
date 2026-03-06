import XCTest
@testable import SnoreLess

/// Tests that Watch <-> iPhone communication protocol is consistent.
/// Verifies serialization roundtrips and key uniqueness.
final class CommunicationProtocolTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - SnoreMessageKey Uniqueness

    func test_allSnoreMessageKeys_areUniqueStrings() {
        let allKeys: [String] = [
            SnoreMessageKey.snoreDetected,
            SnoreMessageKey.escalationRequest,
            SnoreMessageKey.sessionStarted,
            SnoreMessageKey.sessionEnded,
            SnoreMessageKey.snoreLog,
            SnoreMessageKey.settings,
            SnoreMessageKey.smartAlarmEnabled,
            SnoreMessageKey.smartAlarmHour,
            SnoreMessageKey.smartAlarmMinute,
            SnoreMessageKey.recordingEnabled,
            SnoreMessageKey.snoreRecordingFile,
            SnoreMessageKey.recordingTimestamp,
        ]

        let uniqueKeys = Set(allKeys)
        XCTAssertEqual(allKeys.count, uniqueKeys.count, "All SnoreMessageKey values must be unique strings")
    }

    func test_snoreMessageKeys_areNonEmpty() {
        let allKeys: [String] = [
            SnoreMessageKey.snoreDetected,
            SnoreMessageKey.escalationRequest,
            SnoreMessageKey.sessionStarted,
            SnoreMessageKey.sessionEnded,
            SnoreMessageKey.snoreLog,
            SnoreMessageKey.settings,
            SnoreMessageKey.smartAlarmEnabled,
            SnoreMessageKey.smartAlarmHour,
            SnoreMessageKey.smartAlarmMinute,
            SnoreMessageKey.recordingEnabled,
            SnoreMessageKey.snoreRecordingFile,
            SnoreMessageKey.recordingTimestamp,
        ]

        for key in allKeys {
            XCTAssertFalse(key.isEmpty, "SnoreMessageKey should not be empty")
        }
    }

    // MARK: - SleepSessionData Serialization Roundtrip

    func test_sleepSessionData_serializeToDictAndBack() throws {
        let now = Date()
        let original = SleepSessionData(
            startTime: now,
            endTime: now.addingTimeInterval(28800),
            snoreEvents: [
                SnoreEventData(timestamp: now.addingTimeInterval(3600), duration: 10, intensity: 65, hapticLevel: 1, stoppedAfterHaptic: true),
                SnoreEventData(timestamp: now.addingTimeInterval(7200), duration: 3, intensity: 50, hapticLevel: 2, stoppedAfterHaptic: false),
            ],
            totalSnoreDuration: 13,
            backgroundNoiseLevel: 32.5
        )

        // Encode to [String: Any] dict (simulating WatchConnectivity transfer)
        let jsonData = try encoder.encode(original)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        // Decode back from dict
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertEqual(decoded.snoreEvents.count, 2)
        XCTAssertEqual(decoded.totalSnoreDuration, 13)
        XCTAssertEqual(decoded.backgroundNoiseLevel, 32.5, accuracy: 0.01)
        XCTAssertNotNil(decoded.endTime)
    }

    func test_sleepSessionData_serializationPreservesAllEvents() throws {
        let now = Date()
        var events: [SnoreEventData] = []
        for i in 0..<10 {
            let ts = now.addingTimeInterval(Double(i) * 600)
            let dur: TimeInterval = Double(i) + 1
            let inten: Double = 50 + Double(i) * 3
            let level: Int = (i % 3) + 1
            let stopped: Bool = i % 2 == 0
            let event = SnoreEventData(timestamp: ts, duration: dur, intensity: inten, hapticLevel: level, stoppedAfterHaptic: stopped)
            events.append(event)
        }

        let original = SleepSessionData(
            startTime: now,
            endTime: now.addingTimeInterval(6000),
            snoreEvents: events,
            totalSnoreDuration: 55,
            backgroundNoiseLevel: 28
        )

        let jsonData = try encoder.encode(original)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertEqual(decoded.snoreEvents.count, 10)

        // Verify first event fields
        let firstEvent = decoded.snoreEvents[0]
        XCTAssertEqual(firstEvent.duration, 1.0)
        XCTAssertEqual(firstEvent.hapticLevel, 1)
        XCTAssertTrue(firstEvent.stoppedAfterHaptic)

        // Verify last event fields
        let lastEvent = decoded.snoreEvents[9]
        XCTAssertEqual(lastEvent.duration, 10.0)
        XCTAssertEqual(lastEvent.hapticLevel, 1) // (9 % 3) + 1 = 1
        XCTAssertFalse(lastEvent.stoppedAfterHaptic) // 9 % 2 != 0
    }

    // MARK: - SnoreEventData Serialization Roundtrip

    func test_snoreEventData_serializeToDictAndBack() throws {
        let now = Date()
        let original = SnoreEventData(
            timestamp: now,
            duration: 7.5,
            intensity: 68.0,
            hapticLevel: 3,
            stoppedAfterHaptic: true
        )

        let jsonData = try encoder.encode(original)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SnoreEventData.self, from: reEncodedData)

        XCTAssertEqual(decoded.duration, 7.5)
        XCTAssertEqual(decoded.intensity, 68.0, accuracy: 0.01)
        XCTAssertEqual(decoded.hapticLevel, 3)
        XCTAssertTrue(decoded.stoppedAfterHaptic)
    }

    func test_snoreEventData_allHapticLevels() throws {
        for level in 1...3 {
            let event = SnoreEventData(
                timestamp: .now,
                duration: 5,
                intensity: 60,
                hapticLevel: level,
                stoppedAfterHaptic: false
            )

            let jsonData = try encoder.encode(event)
            let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
            let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
            let decoded = try decoder.decode(SnoreEventData.self, from: reEncodedData)

            XCTAssertEqual(decoded.hapticLevel, level, "Haptic level \(level) should survive roundtrip")
        }
    }

    // MARK: - Format Compatibility with WatchConnector

    func test_sessionEndedDict_formatMatchesWatchConnectorExpectation() throws {
        // WatchConnector expects: userInfo with SnoreMessageKey.sessionEnded + session fields
        let now = Date()
        let sessionData = SleepSessionData(
            startTime: now,
            endTime: now.addingTimeInterval(3600),
            snoreEvents: [],
            totalSnoreDuration: 0,
            backgroundNoiseLevel: 30
        )

        let jsonData = try encoder.encode(sessionData)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        // Add the sessionEnded marker (what watch sends)
        dict[SnoreMessageKey.sessionEnded] = true

        // Verify marker exists
        XCTAssertNotNil(dict[SnoreMessageKey.sessionEnded])

        // Remove it (what WatchConnector does before decoding)
        dict.removeValue(forKey: SnoreMessageKey.sessionEnded)
        XCTAssertNil(dict[SnoreMessageKey.sessionEnded])

        // Should still decode fine
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)
        XCTAssertNotNil(decoded)
    }

    func test_snoreLogDict_formatMatchesWatchConnectorExpectation() throws {
        // WatchConnector expects: userInfo with SnoreMessageKey.snoreLog + event fields
        let now = Date()
        let event = SnoreEventData(
            timestamp: now,
            duration: 5,
            intensity: 60,
            hapticLevel: 1,
            stoppedAfterHaptic: false
        )

        let jsonData = try encoder.encode(event)
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        // Add the snoreLog marker
        dict[SnoreMessageKey.snoreLog] = true

        // Verify marker
        XCTAssertNotNil(dict[SnoreMessageKey.snoreLog])

        // Remove it (what WatchConnector does before decoding)
        dict.removeValue(forKey: SnoreMessageKey.snoreLog)
        XCTAssertNil(dict[SnoreMessageKey.snoreLog])

        // Should still decode fine
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SnoreEventData.self, from: reEncodedData)
        XCTAssertNotNil(decoded)
    }

    // MARK: - AppSettings Codable

    func test_appSettings_defaultValues() {
        let settings = AppSettings.default

        XCTAssertFalse(settings.iPhoneEscalationEnabled)
        XCTAssertEqual(settings.hapticSensitivity, 1.0)
        XCTAssertEqual(settings.calibrationDuration, 300)
        XCTAssertEqual(settings.escalationDelay1, 5)
        XCTAssertEqual(settings.escalationDelay2, 10)
        XCTAssertEqual(settings.cooldownDuration, 30)
    }

    func test_appSettings_serializationRoundtrip() throws {
        let settings = AppSettings(
            iPhoneEscalationEnabled: true,
            hapticSensitivity: 1.5,
            calibrationDuration: 600,
            escalationDelay1: 8,
            escalationDelay2: 15,
            cooldownDuration: 45
        )

        let jsonData = try encoder.encode(settings)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        // Simulate adding settings marker
        var transferDict = dict
        transferDict[SnoreMessageKey.settings] = true

        // Verify it's a valid dict for WatchConnectivity
        XCTAssertTrue(JSONSerialization.isValidJSONObject(transferDict))

        // Decode back (without settings marker)
        let decoded = try decoder.decode(AppSettings.self, from: jsonData)
        XCTAssertTrue(decoded.iPhoneEscalationEnabled)
        XCTAssertEqual(decoded.hapticSensitivity, 1.5)
        XCTAssertEqual(decoded.escalationDelay1, 8)
    }
}

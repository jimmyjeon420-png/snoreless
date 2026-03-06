import XCTest
@testable import SnoreLessWatch

final class SessionDataTests: XCTestCase {

    // MARK: - SnoreEventData Codable Roundtrip

    func test_snoreEventData_encodeDecodRoundtrip() throws {
        let original = SnoreEventData(
            timestamp: Date(timeIntervalSince1970: 1709700000),
            duration: 3.5,
            intensity: 0.8,
            hapticLevel: 2,
            stoppedAfterHaptic: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SnoreEventData.self, from: data)

        XCTAssertEqual(decoded.timestamp, original.timestamp)
        XCTAssertEqual(decoded.duration, original.duration, accuracy: 0.001)
        XCTAssertEqual(decoded.intensity, original.intensity, accuracy: 0.001)
        XCTAssertEqual(decoded.hapticLevel, original.hapticLevel)
        XCTAssertEqual(decoded.stoppedAfterHaptic, original.stoppedAfterHaptic)
    }

    func test_snoreEventData_minimumValues() throws {
        let original = SnoreEventData(
            timestamp: Date(timeIntervalSince1970: 0),
            duration: 0,
            intensity: 0,
            hapticLevel: 0,
            stoppedAfterHaptic: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnoreEventData.self, from: data)

        XCTAssertEqual(decoded.duration, 0)
        XCTAssertEqual(decoded.intensity, 0)
        XCTAssertEqual(decoded.hapticLevel, 0)
        XCTAssertFalse(decoded.stoppedAfterHaptic)
    }

    // MARK: - SleepSessionData Codable Roundtrip

    func test_sleepSessionData_encodeDecodeRoundtrip() throws {
        let events = [
            SnoreEventData(timestamp: Date(timeIntervalSince1970: 1709700100),
                          duration: 2.0, intensity: 0.6, hapticLevel: 1, stoppedAfterHaptic: false),
            SnoreEventData(timestamp: Date(timeIntervalSince1970: 1709700200),
                          duration: 4.0, intensity: 0.9, hapticLevel: 3, stoppedAfterHaptic: true),
        ]

        let original = SleepSessionData(
            startTime: Date(timeIntervalSince1970: 1709690000),
            endTime: Date(timeIntervalSince1970: 1709720000),
            snoreEvents: events,
            totalSnoreDuration: 6.0,
            backgroundNoiseLevel: -52.3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SleepSessionData.self, from: data)

        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.endTime, original.endTime)
        XCTAssertEqual(decoded.snoreEvents.count, 2)
        XCTAssertEqual(decoded.totalSnoreDuration, 6.0, accuracy: 0.001)
        XCTAssertEqual(decoded.backgroundNoiseLevel, -52.3, accuracy: 0.001)
    }

    func test_sleepSessionData_nilEndTime_roundtrip() throws {
        let original = SleepSessionData(
            startTime: Date(timeIntervalSince1970: 1709690000),
            endTime: nil,
            snoreEvents: [],
            totalSnoreDuration: 0,
            backgroundNoiseLevel: -60.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SleepSessionData.self, from: data)

        XCTAssertNil(decoded.endTime, "Nil endTime should survive encode/decode roundtrip")
        XCTAssertEqual(decoded.startTime, original.startTime)
    }

    func test_sleepSessionData_emptySnoreEvents_encodesCorrectly() throws {
        let original = SleepSessionData(
            startTime: Date(timeIntervalSince1970: 1709690000),
            endTime: Date(timeIntervalSince1970: 1709720000),
            snoreEvents: [],
            totalSnoreDuration: 0,
            backgroundNoiseLevel: -55.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SleepSessionData.self, from: data)

        XCTAssertTrue(decoded.snoreEvents.isEmpty,
                      "Empty snoreEvents array should encode and decode correctly")
    }

    // MARK: - Date Serialization Precision

    func test_dateSerialization_precisionPreserved() throws {
        // Use a date with sub-second precision
        let preciseDate = Date(timeIntervalSince1970: 1709700000.123)
        let event = SnoreEventData(
            timestamp: preciseDate,
            duration: 1.0,
            intensity: 0.5,
            hapticLevel: 1,
            stoppedAfterHaptic: false
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SnoreEventData.self, from: data)

        // JSON Date encoding should preserve at least millisecond precision
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970,
                       preciseDate.timeIntervalSince1970,
                       accuracy: 0.001,
                       "Date serialization should preserve millisecond precision")
    }

    func test_dateSerialization_distantPast() throws {
        let event = SnoreEventData(
            timestamp: Date.distantPast,
            duration: 0,
            intensity: 0,
            hapticLevel: 0,
            stoppedAfterHaptic: false
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(SnoreEventData.self, from: data)

        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970,
                       Date.distantPast.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Distant past date should survive roundtrip")
    }

    // MARK: - AppSettings Codable

    func test_appSettings_defaultValues_roundtrip() throws {
        let original = AppSettings.default

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.iPhoneEscalationEnabled, false)
        XCTAssertEqual(decoded.hapticSensitivity, 1.0, accuracy: 0.001)
        XCTAssertEqual(decoded.calibrationDuration, 300, accuracy: 0.001)
        XCTAssertEqual(decoded.escalationDelay1, 5, accuracy: 0.001)
        XCTAssertEqual(decoded.escalationDelay2, 10, accuracy: 0.001)
        XCTAssertEqual(decoded.cooldownDuration, 30, accuracy: 0.001)
    }

    func test_appSettings_customValues_roundtrip() throws {
        var original = AppSettings()
        original.iPhoneEscalationEnabled = true
        original.hapticSensitivity = 1.8
        original.calibrationDuration = 120
        original.escalationDelay1 = 3
        original.escalationDelay2 = 7
        original.cooldownDuration = 15

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(decoded.iPhoneEscalationEnabled)
        XCTAssertEqual(decoded.hapticSensitivity, 1.8, accuracy: 0.001)
        XCTAssertEqual(decoded.calibrationDuration, 120, accuracy: 0.001)
        XCTAssertEqual(decoded.escalationDelay1, 3, accuracy: 0.001)
        XCTAssertEqual(decoded.escalationDelay2, 7, accuracy: 0.001)
        XCTAssertEqual(decoded.cooldownDuration, 15, accuracy: 0.001)
    }

    // MARK: - JSON Structure Verification

    func test_snoreEventData_jsonContainsExpectedKeys() throws {
        let event = SnoreEventData(
            timestamp: Date(timeIntervalSince1970: 1709700000),
            duration: 2.0,
            intensity: 0.7,
            hapticLevel: 1,
            stoppedAfterHaptic: false
        )

        let data = try JSONEncoder().encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json, "Encoded data should be a valid JSON dictionary")
        XCTAssertNotNil(json?["timestamp"], "JSON should contain 'timestamp' key")
        XCTAssertNotNil(json?["duration"], "JSON should contain 'duration' key")
        XCTAssertNotNil(json?["intensity"], "JSON should contain 'intensity' key")
        XCTAssertNotNil(json?["hapticLevel"], "JSON should contain 'hapticLevel' key")
        XCTAssertNotNil(json?["stoppedAfterHaptic"], "JSON should contain 'stoppedAfterHaptic' key")
    }
}

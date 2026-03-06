import XCTest
@testable import SnoreLess

/// WatchConnector decoding logic tests.
/// Since decodeAndSaveSession/decodeAndLogSnoreEvent are private,
/// we test the same JSONSerialization + JSONDecoder path they use.
final class WatchConnectorDecodingTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Valid SleepSessionData Decoding

    func test_validSessionDict_decodesToSleepSessionData() throws {
        let now = Date()
        let sessionData = SleepSessionData(
            startTime: now,
            endTime: now.addingTimeInterval(3600 * 7),
            snoreEvents: [
                SnoreEventData(timestamp: now.addingTimeInterval(1800), duration: 5.0, intensity: 62.0, hapticLevel: 1, stoppedAfterHaptic: true)
            ],
            totalSnoreDuration: 5.0,
            backgroundNoiseLevel: 35.0
        )

        // Encode to JSON data, then to dict, simulating what WatchConnectivity sends
        let jsonData = try encoder.encode(sessionData)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        // Re-encode dict back to data (same path as WatchConnector.decodeAndSaveSession)
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertEqual(decoded.snoreEvents.count, 1)
        XCTAssertEqual(decoded.totalSnoreDuration, 5.0)
        XCTAssertEqual(decoded.backgroundNoiseLevel, 35.0)
        XCTAssertNotNil(decoded.endTime)
    }

    func test_sessionWithNilEndTime_decodesCorrectly() throws {
        let now = Date()
        let sessionData = SleepSessionData(
            startTime: now,
            endTime: nil,
            snoreEvents: [],
            totalSnoreDuration: 0,
            backgroundNoiseLevel: 30.0
        )

        let jsonData = try encoder.encode(sessionData)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertNil(decoded.endTime)
        XCTAssertTrue(decoded.snoreEvents.isEmpty)
    }

    func test_sessionWithEmptySnoreEvents_isValid() throws {
        let now = Date()
        let sessionData = SleepSessionData(
            startTime: now,
            endTime: now.addingTimeInterval(28800),
            snoreEvents: [],
            totalSnoreDuration: 0,
            backgroundNoiseLevel: 28.5
        )

        let jsonData = try encoder.encode(sessionData)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertEqual(decoded.snoreEvents.count, 0)
        XCTAssertEqual(decoded.totalSnoreDuration, 0)
    }

    // MARK: - Missing Fields (Graceful Failure)

    func test_missingRequiredFields_returnsNil() throws {
        // Dict missing "startTime" -- should fail to decode
        let incompleteDict: [String: Any] = [
            "totalSnoreDuration": 10.0,
            "backgroundNoiseLevel": 40.0
        ]

        let data = try JSONSerialization.data(withJSONObject: incompleteDict)
        let result = try? decoder.decode(SleepSessionData.self, from: data)

        XCTAssertNil(result, "Decoding should fail gracefully when required fields are missing")
    }

    func test_emptyDict_returnsNil() throws {
        let emptyDict: [String: Any] = [:]
        let data = try JSONSerialization.data(withJSONObject: emptyDict)
        let result = try? decoder.decode(SleepSessionData.self, from: data)

        XCTAssertNil(result)
    }

    // MARK: - Invalid Data Types

    func test_invalidDataTypes_doesNotCrash() throws {
        let invalidDict: [String: Any] = [
            "startTime": "not_a_date",
            "endTime": 12345,
            "snoreEvents": "not_an_array",
            "totalSnoreDuration": "not_a_number",
            "backgroundNoiseLevel": "string"
        ]

        let data = try JSONSerialization.data(withJSONObject: invalidDict)
        let result = try? decoder.decode(SleepSessionData.self, from: data)

        // Should not crash -- just return nil
        XCTAssertNil(result, "Invalid data types should fail gracefully, not crash")
    }

    func test_snoreEventsWithWrongType_doesNotCrash() throws {
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

        // Replace snoreEvents with invalid type
        dict["snoreEvents"] = "invalid_string"
        let data = try JSONSerialization.data(withJSONObject: dict)
        let result = try? decoder.decode(SleepSessionData.self, from: data)

        XCTAssertNil(result, "Should fail when snoreEvents is not an array")
    }

    // MARK: - SnoreEventData Decoding

    func test_snoreEventData_roundTrip() throws {
        let now = Date()
        let event = SnoreEventData(
            timestamp: now,
            duration: 8.5,
            intensity: 75.0,
            hapticLevel: 2,
            stoppedAfterHaptic: true
        )

        let jsonData = try encoder.encode(event)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SnoreEventData.self, from: reEncodedData)

        XCTAssertEqual(decoded.duration, 8.5)
        XCTAssertEqual(decoded.intensity, 75.0, accuracy: 0.01)
        XCTAssertEqual(decoded.hapticLevel, 2)
        XCTAssertTrue(decoded.stoppedAfterHaptic)
    }

    // MARK: - SnoreMessageKey Constants

    func test_snoreMessageKey_constantsMatchExpectedValues() {
        XCTAssertEqual(SnoreMessageKey.snoreDetected, "snoreDetected")
        XCTAssertEqual(SnoreMessageKey.escalationRequest, "escalationRequest")
        XCTAssertEqual(SnoreMessageKey.sessionStarted, "sessionStarted")
        XCTAssertEqual(SnoreMessageKey.sessionEnded, "sessionEnded")
        XCTAssertEqual(SnoreMessageKey.snoreLog, "snoreLog")
        XCTAssertEqual(SnoreMessageKey.settings, "settings")
        XCTAssertEqual(SnoreMessageKey.smartAlarmEnabled, "smartAlarmEnabled")
        XCTAssertEqual(SnoreMessageKey.smartAlarmHour, "smartAlarmHour")
        XCTAssertEqual(SnoreMessageKey.smartAlarmMinute, "smartAlarmMinute")
        XCTAssertEqual(SnoreMessageKey.recordingEnabled, "recordingEnabled")
        XCTAssertEqual(SnoreMessageKey.snoreRecordingFile, "snoreRecordingFile")
        XCTAssertEqual(SnoreMessageKey.recordingTimestamp, "recordingTimestamp")
    }

    // MARK: - Session dict with sessionEnded key stripped

    func test_sessionDict_strippingSessionEndedKey_stillDecodes() throws {
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

        // Simulate what WatchConnector does: add then remove sessionEnded key
        dict[SnoreMessageKey.sessionEnded] = true
        dict.removeValue(forKey: SnoreMessageKey.sessionEnded)

        let reEncodedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try decoder.decode(SleepSessionData.self, from: reEncodedData)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded.backgroundNoiseLevel, 30)
    }
}

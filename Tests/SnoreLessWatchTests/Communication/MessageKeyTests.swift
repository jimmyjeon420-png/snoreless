import XCTest
@testable import SnoreLessWatch

final class MessageKeyTests: XCTestCase {

    // MARK: - All Keys Are Non-Empty Strings

    func test_snoreDetectedKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.snoreDetected.isEmpty,
                       "snoreDetected key should not be empty")
    }

    func test_escalationRequestKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.escalationRequest.isEmpty,
                       "escalationRequest key should not be empty")
    }

    func test_sessionStartedKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.sessionStarted.isEmpty,
                       "sessionStarted key should not be empty")
    }

    func test_sessionEndedKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.sessionEnded.isEmpty,
                       "sessionEnded key should not be empty")
    }

    func test_snoreLogKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.snoreLog.isEmpty,
                       "snoreLog key should not be empty")
    }

    func test_settingsKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.settings.isEmpty,
                       "settings key should not be empty")
    }

    func test_smartAlarmEnabledKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.smartAlarmEnabled.isEmpty,
                       "smartAlarmEnabled key should not be empty")
    }

    func test_smartAlarmHourKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.smartAlarmHour.isEmpty,
                       "smartAlarmHour key should not be empty")
    }

    func test_smartAlarmMinuteKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.smartAlarmMinute.isEmpty,
                       "smartAlarmMinute key should not be empty")
    }

    func test_recordingEnabledKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.recordingEnabled.isEmpty,
                       "recordingEnabled key should not be empty")
    }

    func test_snoreRecordingFileKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.snoreRecordingFile.isEmpty,
                       "snoreRecordingFile key should not be empty")
    }

    func test_recordingTimestampKey_isNonEmpty() {
        XCTAssertFalse(SnoreMessageKey.recordingTimestamp.isEmpty,
                       "recordingTimestamp key should not be empty")
    }

    // MARK: - No Duplicate Key Values

    func test_allKeyValues_areUnique() {
        let allKeys = [
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
        XCTAssertEqual(allKeys.count, uniqueKeys.count,
                       "All SnoreMessageKey values should be unique. Found \(allKeys.count) keys but only \(uniqueKeys.count) unique values.")
    }

    // MARK: - Keys Used in PhoneConnector Exist

    func test_escalationRequestKey_matchesPhoneConnectorUsage() {
        // PhoneConnector.sendEscalationRequest uses SnoreMessageKey.escalationRequest
        let key = SnoreMessageKey.escalationRequest
        XCTAssertEqual(key, "escalationRequest",
                       "escalationRequest key must match the string used in PhoneConnector")
    }

    func test_snoreLogKey_matchesPhoneConnectorUsage() {
        // PhoneConnector.sendSnoreLog uses SnoreMessageKey.snoreLog
        let key = SnoreMessageKey.snoreLog
        XCTAssertEqual(key, "snoreLog",
                       "snoreLog key must match the string used in PhoneConnector")
    }

    func test_sessionEndedKey_matchesPhoneConnectorUsage() {
        // PhoneConnector.sendSleepSession uses SnoreMessageKey.sessionEnded
        let key = SnoreMessageKey.sessionEnded
        XCTAssertEqual(key, "sessionEnded",
                       "sessionEnded key must match the string used in PhoneConnector")
    }

    func test_settingsKey_matchesPhoneConnectorUsage() {
        // PhoneConnector.didReceiveMessage checks SnoreMessageKey.settings
        let key = SnoreMessageKey.settings
        XCTAssertEqual(key, "settings",
                       "settings key must match the string used in PhoneConnector")
    }

    // MARK: - Key Value Format

    func test_allKeys_areCamelCase() {
        let allKeys = [
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
            // Keys should not contain spaces or special characters
            XCTAssertFalse(key.contains(" "), "Key '\(key)' should not contain spaces")
            XCTAssertFalse(key.contains("-"), "Key '\(key)' should not contain hyphens")
            XCTAssertFalse(key.contains("_"), "Key '\(key)' should not contain underscores")

            // Keys should start with a lowercase letter (camelCase)
            let first = key.first!
            XCTAssertTrue(first.isLowercase,
                          "Key '\(key)' should start with a lowercase letter (camelCase)")
        }
    }
}

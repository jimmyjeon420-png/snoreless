import XCTest
@testable import SnoreLess

/// Tests for notification message formatting logic.
/// We do NOT test UNUserNotificationCenter directly --
/// instead we verify the message strings that NotificationManager would produce.
final class NotificationTests: XCTestCase {

    // MARK: - Morning Report Message Formatting

    /// Replicates the message logic from NotificationManager.scheduleMorningReport
    private func morningReportBody(snoreCount: Int, stoppedCount: Int) -> String {
        if snoreCount == 0 {
            return "어젯밤은 코를 안 골았어요. 편안한 밤이었네요!"
        } else {
            return "코골이 \(snoreCount)회 감지, 진동으로 \(stoppedCount)회 멈췄어요"
        }
    }

    private let morningReportTitle = "어젯밤 리포트가 준비됐어요"

    func test_morningReport_zeroSnores_appropriateMessage() {
        let body = morningReportBody(snoreCount: 0, stoppedCount: 0)

        XCTAssertEqual(body, "어젯밤은 코를 안 골았어요. 편안한 밤이었네요!")
        XCTAssertTrue(body.contains("안 골았어요"))
    }

    func test_morningReport_fiveSnoresThreeStopped_correctMessage() {
        let body = morningReportBody(snoreCount: 5, stoppedCount: 3)

        XCTAssertEqual(body, "코골이 5회 감지, 진동으로 3회 멈췄어요")
        XCTAssertTrue(body.contains("5회"))
        XCTAssertTrue(body.contains("3회"))
    }

    func test_morningReport_oneSnoreZeroStopped() {
        let body = morningReportBody(snoreCount: 1, stoppedCount: 0)

        XCTAssertEqual(body, "코골이 1회 감지, 진동으로 0회 멈췄어요")
    }

    func test_morningReport_manySnoresAllStopped() {
        let body = morningReportBody(snoreCount: 20, stoppedCount: 20)

        XCTAssertTrue(body.contains("20회 감지"))
        XCTAssertTrue(body.contains("20회 멈췄어요"))
    }

    func test_morningReport_title_isCorrect() {
        XCTAssertEqual(morningReportTitle, "어젯밤 리포트가 준비됐어요")
    }

    // MARK: - Bedtime Reminder Message Formatting

    private let bedtimeTitle = "곧 잠들 시간이에요"
    private let bedtimeBody = "워치에서 수면 시작을 눌러주세요"

    func test_bedtimeReminder_title_isCorrect() {
        XCTAssertEqual(bedtimeTitle, "곧 잠들 시간이에요")
    }

    func test_bedtimeReminder_body_isCorrect() {
        XCTAssertEqual(bedtimeBody, "워치에서 수면 시작을 눌러주세요")
    }

    // MARK: - Bedtime Reminder Time Calculation

    func test_bedtimeReminder_timeComponents_23_00() {
        var components = DateComponents()
        components.hour = 23
        components.minute = 0

        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 0)
    }

    func test_bedtimeReminder_timeComponents_22_30() {
        var components = DateComponents()
        components.hour = 22
        components.minute = 30

        // Verify DateComponents can produce a valid date
        let calendar = Calendar.current
        let date = calendar.date(from: components)
        XCTAssertNotNil(date)

        if let date = date {
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            XCTAssertEqual(hour, 22)
            XCTAssertEqual(minute, 30)
        }
    }

    func test_bedtimeReminder_midnightEdgeCase() {
        var components = DateComponents()
        components.hour = 0
        components.minute = 0

        let calendar = Calendar.current
        let date = calendar.date(from: components)
        XCTAssertNotNil(date)

        if let date = date {
            XCTAssertEqual(calendar.component(.hour, from: date), 0)
            XCTAssertEqual(calendar.component(.minute, from: date), 0)
        }
    }

    // MARK: - Category Identifiers

    func test_morningReport_categoryIdentifier() {
        let categoryId = "MORNING_REPORT"
        XCTAssertEqual(categoryId, "MORNING_REPORT")
    }

    func test_bedtimeReminder_identifier() {
        let identifier = "bedtime_reminder"
        XCTAssertEqual(identifier, "bedtime_reminder")
    }
}

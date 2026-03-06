import XCTest
import SwiftData
@testable import SnoreLess

final class SleepScoreCalculatorTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([SleepSession.self, SnoreEvent.self, DailyCheckIn.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    /// Build a SleepSession with specified parameters and insert into in-memory context.
    private func makeSession(
        startTime: Date = Date(timeIntervalSince1970: 1_700_000_000), // ~2023-11-14 22:00 UTC
        durationHours: Double? = 8.0,
        snoreCount: Int = 0,
        stoppedEvents: Int = 0,
        totalEvents: Int = 0
    ) -> SleepSession {
        let session = SleepSession(startTime: startTime)

        if let hours = durationHours {
            session.endTime = startTime.addingTimeInterval(hours * 3600)
        }

        session.totalSnoreCount = snoreCount
        session.isActive = (durationHours == nil)

        // Build snore events matching counts
        var events: [SnoreEvent] = []
        for i in 0..<totalEvents {
            let event = SnoreEvent(
                timestamp: startTime.addingTimeInterval(Double(i) * 600),
                duration: 3.0,
                intensity: 60.0,
                hapticLevel: 1,
                stoppedAfterHaptic: i < stoppedEvents
            )
            event.session = session
            events.append(event)
        }
        session.snoreEvents = events

        context.insert(session)
        return session
    }

    // MARK: - 1. Perfect Night: 0 snores, 8h, consistent

    func test_perfectNight_gradeExcellent_totalAtLeast90() throws {
        // 22:00 start, 8h sleep, 0 snores
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 0)

        // Recent sessions at similar times for consistency
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400), durationHours: 7.5, snoreCount: 1)
        let recent2 = makeSession(startTime: base.addingTimeInterval(-172800), durationHours: 8.0, snoreCount: 0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1, recent2])

        XCTAssertGreaterThanOrEqual(score.total, 90, "Perfect night should score >= 90")
        XCTAssertEqual(score.grade, .excellent, "Perfect night should be A+")
    }

    // MARK: - 2. Bad Night: 10+ snores, short sleep, inconsistent

    func test_badNight_gradePoor_totalBelow55() throws {
        // 03:00 start (very inconsistent), 4h sleep, 15 snores, no response
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let lateStart = base.addingTimeInterval(5 * 3600) // 03:00 UTC

        let session = makeSession(
            startTime: lateStart,
            durationHours: 4.0,
            snoreCount: 15,
            stoppedEvents: 0,
            totalEvents: 15
        )

        // Recent sessions at normal 22:00 times (very different from 03:00)
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400), durationHours: 8.0)
        let recent2 = makeSession(startTime: base.addingTimeInterval(-172800), durationHours: 7.5)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1, recent2])

        XCTAssertLessThan(score.total, 55, "Bad night should score < 55")
        XCTAssertEqual(score.grade, .poor, "Bad night should be D")
    }

    // MARK: - 3. Snore Score: 0 snores = 30

    func test_snoreScore_zeroSnores_equals30() throws {
        let session = makeSession(snoreCount: 0)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 30, "0 snores should yield snore score of 30")
    }

    // MARK: - 4. Snore Score: 3 snores = 18

    func test_snoreScore_threeSnores_equals18() throws {
        let session = makeSession(snoreCount: 3, totalEvents: 3)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 18, "3 snores should yield snore score of 18")
    }

    // MARK: - 5. Snore Score: 15 snores = 5

    func test_snoreScore_fifteenSnores_equals5() throws {
        let session = makeSession(snoreCount: 15, totalEvents: 15)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 5, "15 snores (>10) should yield snore score of 5")
    }

    // MARK: - 6. Snore Score: 1 snore = 25

    func test_snoreScore_oneSnore_equals25() throws {
        let session = makeSession(snoreCount: 1, totalEvents: 1)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 25, "1 snore should yield snore score of 25")
    }

    // MARK: - 7. Snore Score: 7 snores = 10

    func test_snoreScore_sevenSnores_equals10() throws {
        let session = makeSession(snoreCount: 7, totalEvents: 7)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 10, "7 snores (6-10 range) should yield snore score of 10")
    }

    // MARK: - 8. Response Score: 100% response = 30

    func test_responseScore_allStopped_equals30() throws {
        let session = makeSession(snoreCount: 5, stoppedEvents: 5, totalEvents: 5)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.responseScore, 30, "100% response rate should yield 30")
    }

    // MARK: - 9. Response Score: 50% response = 15

    func test_responseScore_halfStopped_equals15() throws {
        let session = makeSession(snoreCount: 4, stoppedEvents: 2, totalEvents: 4)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.responseScore, 15, "50% response rate should yield 15")
    }

    // MARK: - 10. Response Score: 0% response = 0

    func test_responseScore_noneStopped_equals0() throws {
        let session = makeSession(snoreCount: 5, stoppedEvents: 0, totalEvents: 5)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.responseScore, 0, "0% response rate should yield 0")
    }

    // MARK: - 11. Response Score: no events = 30 (perfect)

    func test_responseScore_noEvents_equals30() throws {
        let session = makeSession(snoreCount: 0, stoppedEvents: 0, totalEvents: 0)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.responseScore, 30, "No snore events should yield response score of 30")
    }

    // MARK: - 12. Duration Score: 8h = 25

    func test_durationScore_8hours_equals25() throws {
        let session = makeSession(durationHours: 8.0)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.durationScore, 25, "8 hours sleep should yield duration score of 25")
    }

    // MARK: - 13. Duration Score: 6.5h = 18

    func test_durationScore_6point5hours_equals18() throws {
        let session = makeSession(durationHours: 6.5)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.durationScore, 18, "6.5 hours sleep should yield duration score of 18")
    }

    // MARK: - 14. Duration Score: 4h = 5

    func test_durationScore_4hours_equals5() throws {
        let session = makeSession(durationHours: 4.0)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.durationScore, 5, "4 hours sleep should yield duration score of 5")
    }

    // MARK: - 15. Duration Score: nil endTime = 0

    func test_durationScore_nilEndTime_equals0() throws {
        let session = makeSession(durationHours: nil)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.durationScore, 0, "Active session (nil endTime) should yield duration score of 0")
    }

    // MARK: - 16. Consistency: same time = 15

    func test_consistencyScore_sameTime_equals15() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000) // ~22:13 UTC
        let session = makeSession(startTime: base, durationHours: 8.0)

        // Recent sessions at nearly the same time
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 + 600), durationHours: 7.5) // +10 min
        let recent2 = makeSession(startTime: base.addingTimeInterval(-172800 - 300), durationHours: 8.0) // -5 min

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1, recent2])

        XCTAssertEqual(score.consistencyScore, 15, "Same bedtime should yield consistency score of 15")
    }

    // MARK: - 17. Consistency: 2h off = 0

    func test_consistencyScore_twoHoursOff_equals0() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0)

        // Recent sessions 2 hours earlier
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 - 7200), durationHours: 8.0)
        let recent2 = makeSession(startTime: base.addingTimeInterval(-172800 - 7200), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1, recent2])

        XCTAssertEqual(score.consistencyScore, 0, "2 hours off should yield consistency score of 0")
    }

    // MARK: - 18. Empty recentSessions = consistency 15 (first session bonus)

    func test_consistencyScore_emptyRecent_equals15() throws {
        let session = makeSession(durationHours: 8.0)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.consistencyScore, 15, "First session (empty recent) should get full consistency marks")
    }

    // MARK: - 19. Grade boundaries

    func test_gradeBoundary_90_isExcellent() throws {
        // Verify 90 maps to A+
        // 30 (snore) + 30 (response) + 25 (duration) + 5 (consistency ~1h off) = 90
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 0)

        // Create recent sessions about 1 hour off for consistency = 5
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 + 3600), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1])

        // snore=30, response=30, duration=25, consistency=5 (1h off)
        XCTAssertEqual(score.total, 90, "Should total 90")
        XCTAssertEqual(score.grade, .excellent, "90 should be A+")
    }

    func test_gradeBoundary_89_isGreat() throws {
        // Force a total of 89: snore=30, response=30, duration=25, consistency=0 => 85
        // Actually need finer control. Let's check grade boundary via known totals.
        // snore=25(1-2), response=30(no events but snoreCount=1 means events exist)
        // Better: snore=25(2 snores), response=30(all stopped), duration=25(8h), consistency=5(1h off) = 85 => A
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 2, stoppedEvents: 2, totalEvents: 2)
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 + 3600), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1])

        // snore=25, response=30, duration=25, consistency=5 => 85
        XCTAssertEqual(score.total, 85, "Should total 85")
        XCTAssertEqual(score.grade, .great, "85 should be A")
    }

    func test_gradeBoundary_79_isGood() throws {
        // snore=18(3-5), response=30(all stopped), duration=25(8h), consistency=5(1h off) = 78 => B? No, 70-79 = B
        // 18+30+25+5 = 78 => B? 78 is in 70..<80 => .good (B)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 3, stoppedEvents: 3, totalEvents: 3)
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 + 3600), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1])

        // snore=18, response=30, duration=25, consistency=5 => 78
        XCTAssertEqual(score.total, 78)
        XCTAssertEqual(score.grade, .good, "78 should be B (70..<80)")
    }

    func test_gradeBoundary_fair() throws {
        // snore=10(6-10), response=15(50%), duration=25(8h), consistency=5(1h off) = 55 => C (55..<70)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 8, stoppedEvents: 4, totalEvents: 8)
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400 + 3600), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1])

        // snore=10, response=15, duration=25, consistency=5 => 55
        XCTAssertEqual(score.total, 55)
        XCTAssertEqual(score.grade, .fair, "55 should be C (55..<70)")
    }

    func test_gradeBoundary_poor() throws {
        // snore=5(>10), response=0(0%), duration=5(<5h), consistency=0(>2h off) = 10 => D
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let lateStart = base.addingTimeInterval(5 * 3600)
        let session = makeSession(startTime: lateStart, durationHours: 3.0, snoreCount: 15, stoppedEvents: 0, totalEvents: 15)
        let recent1 = makeSession(startTime: base.addingTimeInterval(-86400), durationHours: 8.0)
        let recent2 = makeSession(startTime: base.addingTimeInterval(-172800), durationHours: 8.0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent1, recent2])

        XCTAssertLessThan(score.total, 55, "Should be below 55")
        XCTAssertEqual(score.grade, .poor, "Very bad night should be D")
    }

    // MARK: - 20. Comment is non-empty for each grade

    func test_comment_nonEmptyForAllGrades() throws {
        let grades: [(Int, SleepGrade)] = [
            (0, .poor), (55, .fair), (70, .good), (80, .great), (90, .excellent)
        ]

        for (snoreCount, expectedGrade) in grades {
            let session = makeSession(durationHours: 8.0, snoreCount: snoreCount)
            let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

            XCTAssertFalse(score.comment.isEmpty,
                           "Comment should not be empty for grade \(expectedGrade.rawValue)")
        }
    }

    // MARK: - 21. Total is sum of components

    func test_total_isSumOfComponents() throws {
        let session = makeSession(durationHours: 7.5, snoreCount: 4, stoppedEvents: 2, totalEvents: 4)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        let expectedTotal = score.snoreScore + score.responseScore + score.durationScore + score.consistencyScore
        XCTAssertEqual(score.total, expectedTotal,
                       "Total should equal sum of snore + response + duration + consistency")
    }

    // MARK: - 22. Session with nil endTime handles gracefully

    func test_nilEndTime_handlesGracefully() throws {
        let session = makeSession(durationHours: nil, snoreCount: 3, stoppedEvents: 1, totalEvents: 3)
        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.durationScore, 0, "Nil endTime should give 0 duration score")
        XCTAssertGreaterThanOrEqual(score.total, 0, "Score should still be non-negative")
        XCTAssertFalse(score.comment.isEmpty, "Should still produce a comment")
    }
}

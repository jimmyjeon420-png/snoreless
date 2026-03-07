import XCTest
import SwiftData
@testable import SnoreLess

final class EdgeCaseStabilityTests: XCTestCase {

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

    private func makeSession(
        startTime: Date = Date(timeIntervalSince1970: 1_700_000_000),
        endTime: Date? = nil,
        durationHours: Double? = 8.0,
        snoreCount: Int = 0,
        stoppedEvents: Int = 0,
        totalEvents: Int = 0
    ) -> SleepSession {
        let session = SleepSession(startTime: startTime)

        if let explicitEnd = endTime {
            session.endTime = explicitEnd
        } else if let hours = durationHours {
            session.endTime = startTime.addingTimeInterval(hours * 3600)
        }

        session.totalSnoreCount = snoreCount
        session.isActive = (session.endTime == nil)

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

    private func makeSessionAndCheckIn(
        dayOffset: Int,
        hour: Int = 22,
        snoreCount: Int,
        alcohol: Bool = false,
        exercised: Bool = false,
        coffeeAfternoon: Bool = false,
        stressLevel: Int = 3
    ) -> (SleepSession, DailyCheckIn) {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = 15 + dayOffset
        comps.hour = hour
        comps.minute = 0
        let startTime = calendar.date(from: comps)!

        let session = SleepSession(startTime: startTime)
        session.endTime = startTime.addingTimeInterval(8 * 3600)
        session.totalSnoreCount = snoreCount
        session.isActive = false
        session.snoreEvents = []

        var checkInComps = DateComponents()
        checkInComps.year = 2024
        checkInComps.month = 1
        checkInComps.day = 15 + dayOffset
        checkInComps.hour = 20
        checkInComps.minute = 0
        let checkInDate = calendar.date(from: checkInComps)!

        let checkIn = DailyCheckIn(
            date: checkInDate,
            coffeeAfternoon: coffeeAfternoon,
            exercised: exercised,
            alcohol: alcohol,
            stressLevel: stressLevel
        )

        context.insert(session)
        context.insert(checkIn)

        return (session, checkIn)
    }

    /// Replicates the generateAIComment logic from DashboardView for unit testing.
    /// Takes completedSessions (sorted newest-first) and returns the AI comment string.
    private func generateAICommentEquivalent(completedSessions: [SleepSession]) -> String {
        guard completedSessions.count >= 2 else {
            if completedSessions.count == 1 {
                return String(localized: "첫 번째 수면 기록이 완성됐어요. 내일 아침이 기대되네요!")
            }
            return ""
        }

        let latest = completedSessions[0]
        let previous = completedSessions[1]

        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now

        let thisWeek = completedSessions.filter { $0.startTime >= sevenDaysAgo }
        let lastWeek = completedSessions.filter { $0.startTime >= fourteenDaysAgo && $0.startTime < sevenDaysAgo }

        if !thisWeek.isEmpty && !lastWeek.isEmpty {
            let thisWeekAvg = Double(thisWeek.reduce(0) { $0 + $1.totalSnoreCount }) / Double(thisWeek.count)
            let lastWeekAvg = Double(lastWeek.reduce(0) { $0 + $1.totalSnoreCount }) / Double(lastWeek.count)

            if lastWeekAvg > 0 {
                let changePercent = Int(((lastWeekAvg - thisWeekAvg) / lastWeekAvg) * 100)
                if changePercent > 0 {
                    return String(localized: "지난주보다 코골이가 \(changePercent)% 줄었어요. 좋은 변화예요!")
                } else if changePercent < -10 {
                    return String(localized: "지난주보다 코골이가 조금 늘었어요. 오늘 체크인을 기록해보세요.")
                }
            }
        }

        if latest.totalSnoreCount < previous.totalSnoreCount {
            return String(localized: "어젯밤은 전날보다 코골이가 줄었어요. 잘하고 있어요!")
        } else if latest.totalSnoreCount == 0 {
            return String(localized: "어젯밤은 코를 안 골았어요. 편안한 밤이었네요.")
        } else {
            let stoppedRate = latest.totalSnoreCount > 0
                ? Double(latest.snoreEvents.filter(\.stoppedAfterHaptic).count) / Double(latest.totalSnoreCount) * 100
                : 0
            if stoppedRate >= 60 {
                return String(localized: "진동 효과가 잘 작동하고 있어요. \(Int(stoppedRate))%나 멈췄어요!")
            }
        }

        return String(localized: "꾸준히 기록하면 패턴을 찾을 수 있어요.")
    }

    // ========================================================================
    // MARK: - SleepScoreCalculator Edge Cases
    // ========================================================================

    // MARK: 1. Zero-length session (startTime == endTime)

    func test_calculate_zeroLengthSession_doesNotCrash() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: now, endTime: now, durationHours: nil, snoreCount: 0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertGreaterThanOrEqual(score.total, 0, "Zero-length session must not crash and must return non-negative score")
        XCTAssertLessThanOrEqual(score.total, 100)
        XCTAssertFalse(score.comment.isEmpty, "Comment must still be produced")
    }

    // MARK: 2. Very short session (1 minute)

    func test_calculate_veryShortSession_1minute_returnsValidScore() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            durationHours: nil,
            snoreCount: 1,
            stoppedEvents: 0,
            totalEvents: 1
        )

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100)
        // 1 minute is far below the 5-hour minimum, so duration score should be poor (5)
        XCTAssertEqual(score.durationScore, 5, "1 minute sleep should yield lowest duration tier (5)")
    }

    // MARK: 3. Very long session (24 hours)

    func test_calculate_veryLongSession_24hours_returnsValidScore() throws {
        let session = makeSession(durationHours: 24.0, snoreCount: 2, stoppedEvents: 1, totalEvents: 2)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100)
        // 24 hours is above the 11-hour far range, so should be durationPoorScore (5)
        XCTAssertEqual(score.durationScore, 5, "24 hours sleep should yield lowest duration tier (5)")
    }

    // MARK: 4. No snore events = perfect snore score

    func test_calculate_noSnoreEvents_perfectSnoreScore() throws {
        let session = makeSession(durationHours: 8.0, snoreCount: 0, stoppedEvents: 0, totalEvents: 0)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.snoreScore, 30, "0 snore events must yield max snore score of 30")
        XCTAssertEqual(score.responseScore, 30, "0 snore events must yield max response score of 30")
    }

    // MARK: 5. Extreme snoring (100 events)

    func test_calculate_hundredSnoreEvents_returnsValidScore() throws {
        let session = makeSession(
            durationHours: 8.0,
            snoreCount: 100,
            stoppedEvents: 10,
            totalEvents: 100
        )

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100)
        XCTAssertEqual(score.snoreScore, 5, "100 snores (>10) must yield snore score of 5")
        // response: 10/100 = 10% => Int(0.1 * 30) = 3
        XCTAssertEqual(score.responseScore, 3, "10% response rate => Int(0.1 * 30) = 3")
    }

    // MARK: 6. Empty recentSessions

    func test_calculate_emptyRecentSessions_handlesGracefully() throws {
        let session = makeSession(durationHours: 7.5, snoreCount: 3, stoppedEvents: 1, totalEvents: 3)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        // Empty recent sessions => first session bonus => consistency = 15
        XCTAssertEqual(score.consistencyScore, 15, "Empty recent sessions should yield full consistency score")
        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100)
    }

    // MARK: 7. Single recent session

    func test_calculate_singleRecentSession_handlesGracefully() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeSession(startTime: base, durationHours: 8.0, snoreCount: 2)
        let recent = makeSession(startTime: base.addingTimeInterval(-86400), durationHours: 7.5)

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [recent])

        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100)
        // Should compute consistency against the single recent session without crash
        XCTAssertGreaterThanOrEqual(score.consistencyScore, 0)
        XCTAssertLessThanOrEqual(score.consistencyScore, 15)
    }

    // MARK: 8. All snore events stopped after haptic = perfect response

    func test_calculate_allSnoredEventsStoppedAfterHaptic_perfectResponseScore() throws {
        let session = makeSession(
            durationHours: 8.0,
            snoreCount: 10,
            stoppedEvents: 10,
            totalEvents: 10
        )

        let score = SleepScoreCalculator.calculate(session: session, recentSessions: [])

        XCTAssertEqual(score.responseScore, 30, "100% haptic success must yield response score of 30")
    }

    // MARK: 9. Fuzz test: score always between 0 and 100

    func test_calculate_scoreAlwaysBetween0And100() throws {
        for i in 0..<50 {
            let snoreCount = Int.random(in: 0...50)
            let totalEvents = Int.random(in: 0...max(snoreCount, 1))
            let stoppedEvents = Int.random(in: 0...totalEvents)
            let durationHours = Double.random(in: 0...30)
            let baseOffset = Double.random(in: -172800...172800)

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let startTime = base.addingTimeInterval(baseOffset)

            let session = makeSession(
                startTime: startTime,
                durationHours: durationHours,
                snoreCount: snoreCount,
                stoppedEvents: stoppedEvents,
                totalEvents: totalEvents
            )

            // Create 0-3 random recent sessions
            let recentCount = Int.random(in: 0...3)
            var recentSessions: [SleepSession] = []
            for j in 0..<recentCount {
                let recentStart = startTime.addingTimeInterval(-Double(j + 1) * 86400 + Double.random(in: -3600...3600))
                let recent = makeSession(
                    startTime: recentStart,
                    durationHours: Double.random(in: 3...12),
                    snoreCount: Int.random(in: 0...20)
                )
                recentSessions.append(recent)
            }

            let score = SleepScoreCalculator.calculate(session: session, recentSessions: recentSessions)

            XCTAssertGreaterThanOrEqual(score.total, 0, "Fuzz iteration \(i): score must be >= 0, got \(score.total)")
            XCTAssertLessThanOrEqual(score.total, 100, "Fuzz iteration \(i): score must be <= 100, got \(score.total)")
            XCTAssertFalse(score.comment.isEmpty, "Fuzz iteration \(i): comment must not be empty")
        }
    }

    // MARK: 10. Grade matches score boundaries

    func test_calculate_gradeMatchesScore() throws {
        // Test specific known totals by constructing sessions that produce predictable scores
        let testCases: [(snoreCount: Int, totalEvents: Int, stoppedEvents: Int, durationHours: Double, useRecent: Bool, expectedGrade: SleepGrade)] = [
            // snore=30, response=30, duration=25, consistency=15 => 100 => excellent
            (0, 0, 0, 8.0, false, .excellent),
            // snore=25, response=30, duration=25, consistency=15 => 95 => excellent
            (1, 0, 0, 8.0, false, .excellent),
            // snore=25, response=30, duration=25, consistency=5 => 85 => great
            (2, 2, 2, 8.0, true, .great),
            // snore=18, response=30, duration=25, consistency=5 => 78 => good
            (3, 3, 3, 8.0, true, .good),
        ]

        let base = Date(timeIntervalSince1970: 1_700_000_000)

        for (idx, tc) in testCases.enumerated() {
            let session = makeSession(
                startTime: base,
                durationHours: tc.durationHours,
                snoreCount: tc.snoreCount,
                stoppedEvents: tc.stoppedEvents,
                totalEvents: tc.totalEvents
            )

            var recent: [SleepSession] = []
            if tc.useRecent {
                // 1 hour off for consistency = 5
                let r = makeSession(startTime: base.addingTimeInterval(-86400 + 3600), durationHours: 8.0)
                recent.append(r)
            }

            let score = SleepScoreCalculator.calculate(session: session, recentSessions: recent)

            XCTAssertEqual(score.grade, tc.expectedGrade,
                           "Case \(idx): total=\(score.total) should map to \(tc.expectedGrade.rawValue), got \(score.grade.rawValue)")

            // Also verify grade boundaries hold
            switch score.grade {
            case .excellent:
                XCTAssertGreaterThanOrEqual(score.total, 90, "Excellent requires >= 90")
            case .great:
                XCTAssertGreaterThanOrEqual(score.total, 80, "Great requires >= 80")
                XCTAssertLessThan(score.total, 90, "Great requires < 90")
            case .good:
                XCTAssertGreaterThanOrEqual(score.total, 70, "Good requires >= 70")
                XCTAssertLessThan(score.total, 80, "Good requires < 80")
            case .fair:
                XCTAssertGreaterThanOrEqual(score.total, 55, "Fair requires >= 55")
                XCTAssertLessThan(score.total, 70, "Fair requires < 70")
            case .poor:
                XCTAssertLessThan(score.total, 55, "Poor requires < 55")
            }
        }
    }

    // ========================================================================
    // MARK: - PatternAnalyzer Edge Cases
    // ========================================================================

    // MARK: 11. Empty sessions and check-ins

    func test_analyze_emptySessionsAndCheckIns_returnsEmpty() throws {
        let insights = PatternAnalyzer.analyze(sessions: [], checkIns: [])
        XCTAssertTrue(insights.isEmpty, "Empty sessions and check-ins must return empty insights")
    }

    // MARK: 12. Sessions only, no check-ins

    func test_analyze_sessionsOnly_noCheckIns_returnsEmpty() throws {
        let s1 = makeSession(durationHours: 8.0, snoreCount: 5)
        let s2 = makeSession(
            startTime: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-86400),
            durationHours: 7.0,
            snoreCount: 3
        )

        let insights = PatternAnalyzer.analyze(sessions: [s1, s2], checkIns: [])
        XCTAssertTrue(insights.isEmpty, "Sessions without check-ins must return empty insights")
    }

    // MARK: 13. Check-ins only, no sessions

    func test_analyze_checkInsOnly_noSessions_returnsEmpty() throws {
        let c1 = DailyCheckIn(date: Date(), coffeeAfternoon: false, exercised: false, alcohol: true, stressLevel: 4)
        let c2 = DailyCheckIn(date: Date().addingTimeInterval(-86400), coffeeAfternoon: false, exercised: true, alcohol: false, stressLevel: 2)
        // Note: DailyCheckIn init order is (date, coffeeAfternoon, exercised, alcohol, stressLevel)
        context.insert(c1)
        context.insert(c2)

        let insights = PatternAnalyzer.analyze(sessions: [], checkIns: [c1, c2])
        XCTAssertTrue(insights.isEmpty, "Check-ins without sessions must return empty insights")
    }

    // MARK: 14. All check-ins on different dates, no match

    func test_analyze_allCheckInsOnDifferentDates_noMatch_returnsEmpty() throws {
        let calendar = Calendar.current

        // Sessions in January
        var comps1 = DateComponents()
        comps1.year = 2024; comps1.month = 1; comps1.day = 10; comps1.hour = 22
        let s1 = SleepSession(startTime: calendar.date(from: comps1)!)
        s1.endTime = s1.startTime.addingTimeInterval(8 * 3600)
        s1.totalSnoreCount = 5
        s1.snoreEvents = []

        var comps2 = DateComponents()
        comps2.year = 2024; comps2.month = 1; comps2.day = 11; comps2.hour = 23
        let s2 = SleepSession(startTime: calendar.date(from: comps2)!)
        s2.endTime = s2.startTime.addingTimeInterval(7 * 3600)
        s2.totalSnoreCount = 3
        s2.snoreEvents = []

        // Check-ins in completely different months
        var comps3 = DateComponents()
        comps3.year = 2024; comps3.month = 6; comps3.day = 15; comps3.hour = 20
        let c1 = DailyCheckIn(date: calendar.date(from: comps3)!, alcohol: true)

        var comps4 = DateComponents()
        comps4.year = 2024; comps4.month = 7; comps4.day = 20; comps4.hour = 20
        let c2 = DailyCheckIn(date: calendar.date(from: comps4)!, alcohol: true)

        context.insert(s1)
        context.insert(s2)
        context.insert(c1)
        context.insert(c2)

        let insights = PatternAnalyzer.analyze(sessions: [s1, s2], checkIns: [c1, c2])
        XCTAssertTrue(insights.isEmpty, "Non-overlapping dates must return empty insights")
    }

    // MARK: 15. Midnight session matches previous day's check-in

    func test_analyze_midnightSession_matchesPreviousDayCheckIn() throws {
        let calendar = Calendar.current

        // Session starts at 1:00 AM on Jan 16 (should match Jan 15 check-in)
        var sessionComps = DateComponents()
        sessionComps.year = 2024; sessionComps.month = 1; sessionComps.day = 16; sessionComps.hour = 1
        let sessionStart = calendar.date(from: sessionComps)!

        let session = SleepSession(startTime: sessionStart)
        session.endTime = sessionStart.addingTimeInterval(6 * 3600)
        session.totalSnoreCount = 5
        session.snoreEvents = []

        // Check-in on Jan 15 evening
        var checkInComps = DateComponents()
        checkInComps.year = 2024; checkInComps.month = 1; checkInComps.day = 15; checkInComps.hour = 20
        let checkIn = DailyCheckIn(date: calendar.date(from: checkInComps)!, alcohol: true)

        context.insert(session)
        context.insert(checkIn)

        // Need at least 3 matched pairs for analysis, so add more
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 7, alcohol: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 8, alcohol: true)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 2, alcohol: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 3, alcohol: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 1, alcohol: false)

        let insights = PatternAnalyzer.analyze(
            sessions: [session, s2, s3, s4, s5, s6],
            checkIns: [checkIn, c2, c3, c4, c5, c6]
        )

        // The midnight session should have matched to previous day's check-in,
        // contributing to the alcohol analysis. If matching works, we get >= 3 alcohol
        // days (session+s2+s3) and 3 sober days (s4+s5+s6).
        let alcoholInsight = insights.first { $0.icon == "wineglass.fill" }
        XCTAssertNotNil(alcoholInsight,
                        "Midnight session must match previous day check-in and contribute to alcohol analysis")
    }

    // MARK: 16. Afternoon session matches same day's check-in

    func test_analyze_afternoonSession_matchesSameDayCheckIn() throws {
        let calendar = Calendar.current

        // Session starts at 2:00 PM (hour >= 12, should match same day)
        var sessionComps = DateComponents()
        sessionComps.year = 2024; sessionComps.month = 1; sessionComps.day = 15; sessionComps.hour = 14
        let sessionStart = calendar.date(from: sessionComps)!

        let session = SleepSession(startTime: sessionStart)
        session.endTime = sessionStart.addingTimeInterval(2 * 3600)
        session.totalSnoreCount = 6
        session.snoreEvents = []

        // Check-in for Jan 15 (same day)
        var checkInComps = DateComponents()
        checkInComps.year = 2024; checkInComps.month = 1; checkInComps.day = 15; checkInComps.hour = 12
        let checkIn = DailyCheckIn(date: calendar.date(from: checkInComps)!, alcohol: true)

        context.insert(session)
        context.insert(checkIn)

        // Add more to reach the 3-match threshold
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 8, alcohol: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 7, alcohol: true)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 2, alcohol: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 3, alcohol: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 1, alcohol: false)

        let insights = PatternAnalyzer.analyze(
            sessions: [session, s2, s3, s4, s5, s6],
            checkIns: [checkIn, c2, c3, c4, c5, c6]
        )

        let alcoholInsight = insights.first { $0.icon == "wineglass.fill" }
        XCTAssertNotNil(alcoholInsight,
                        "Afternoon session must match same-day check-in and contribute to analysis")
    }

    // MARK: 17. Two matched pairs (below threshold of 3)

    func test_analyze_twoMatchedPairs_belowThreshold_returnsEmpty() throws {
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 10, alcohol: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 8, alcohol: true)

        let insights = PatternAnalyzer.analyze(sessions: [s1, s2], checkIns: [c1, c2])

        XCTAssertTrue(insights.isEmpty, "Fewer than 3 matched pairs must return empty (got \(insights.count))")
    }

    // MARK: 18. Fuzz: all correlation values always between -1 and 1

    func test_analyze_correlationValues_alwaysBetweenNeg1And1() throws {
        for i in 0..<50 {
            var sessions: [SleepSession] = []
            var checkIns: [DailyCheckIn] = []

            // Generate 8 random session/check-in pairs
            for j in 0..<8 {
                let (s, c) = makeSessionAndCheckIn(
                    dayOffset: j + (i * 10), // avoid date collisions across iterations
                    snoreCount: Int.random(in: 0...30),
                    alcohol: Bool.random(),
                    exercised: Bool.random(),
                    coffeeAfternoon: Bool.random(),
                    stressLevel: Int.random(in: 1...5)
                )
                sessions.append(s)
                checkIns.append(c)
            }

            let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: checkIns)

            for insight in insights {
                XCTAssertGreaterThanOrEqual(insight.correlation, -1.0,
                    "Fuzz \(i): correlation \(insight.correlation) must be >= -1.0 (\(insight.title))")
                XCTAssertLessThanOrEqual(insight.correlation, 1.0,
                    "Fuzz \(i): correlation \(insight.correlation) must be <= 1.0 (\(insight.title))")
            }
        }
    }

    // MARK: 19. Zero snore count sessions, no zero division

    func test_analyze_zeroSnoreCountSessions_noZeroDivision() throws {
        // All sessions have 0 snores -- tests for division by zero in ratio calculations
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 0, alcohol: true, exercised: false, coffeeAfternoon: true, stressLevel: 5)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 0, alcohol: true, exercised: false, coffeeAfternoon: true, stressLevel: 4)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 0, alcohol: true, exercised: false, coffeeAfternoon: true, stressLevel: 5)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 0, alcohol: false, exercised: true, coffeeAfternoon: false, stressLevel: 1)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 0, alcohol: false, exercised: true, coffeeAfternoon: false, stressLevel: 2)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 0, alcohol: false, exercised: true, coffeeAfternoon: false, stressLevel: 1)

        let sessions = [s1, s2, s3, s4, s5, s6]
        let allCheckIns = [c1, c2, c3, c4, c5, c6]

        // This must not crash from division by zero
        let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: allCheckIns)

        // With all zeros: avgSober=0 => alcohol guard fails, avgRest=0 => exercise guard fails,
        // avgNoCoffee=0 => coffee guard fails. Should return empty or safe values.
        for insight in insights {
            XCTAssertFalse(insight.correlation.isNaN, "Correlation must not be NaN")
            XCTAssertFalse(insight.correlation.isInfinite, "Correlation must not be infinite")
        }
    }

    // ========================================================================
    // MARK: - DashboardView AI Comment Logic (equivalent)
    // ========================================================================

    // MARK: 20. No sessions = empty string

    func test_generateAIComment_equivalent_noSessions_returnsEmpty() throws {
        let result = generateAICommentEquivalent(completedSessions: [])
        XCTAssertTrue(result.isEmpty, "0 sessions must return empty string, got: '\(result)'")
    }

    // MARK: 21. One session = first-time welcome message

    func test_generateAIComment_equivalent_oneSession_returnsFirstMessage() throws {
        let session = makeSession(durationHours: 8.0, snoreCount: 3)
        let result = generateAICommentEquivalent(completedSessions: [session])

        XCTAssertFalse(result.isEmpty, "1 session must return a welcome message")
        // The Korean message contains the key phrase
        let expected = String(localized: "첫 번째 수면 기록이 완성됐어요. 내일 아침이 기대되네요!")
        XCTAssertEqual(result, expected, "Single session must return the first-session welcome message")
    }

    // MARK: 22. Two sessions = comparison message

    func test_generateAIComment_equivalent_twoSessions_returnsComparison() throws {
        // Create two sessions with dates far in the past (not in this/last week window)
        // so the weekly comparison branch is skipped, and we fall through to the
        // latest vs previous comparison.
        let base = Date(timeIntervalSince1970: 1_600_000_000) // far in the past
        let latest = makeSession(startTime: base, durationHours: 8.0, snoreCount: 2, stoppedEvents: 1, totalEvents: 2)
        let previous = makeSession(
            startTime: base.addingTimeInterval(-86400),
            durationHours: 7.5,
            snoreCount: 5,
            stoppedEvents: 2,
            totalEvents: 5
        )

        // latest.totalSnoreCount (2) < previous.totalSnoreCount (5) => "reduced" message
        let result = generateAICommentEquivalent(completedSessions: [latest, previous])

        XCTAssertFalse(result.isEmpty, "2 sessions must return a comparison message")
        // Should not be the first-session message
        let firstMessage = String(localized: "첫 번째 수면 기록이 완성됐어요. 내일 아침이 기대되네요!")
        XCTAssertNotEqual(result, firstMessage, "2 sessions must not return the first-session message")
    }
}

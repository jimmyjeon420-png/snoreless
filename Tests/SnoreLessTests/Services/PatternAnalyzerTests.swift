import XCTest
import SwiftData
@testable import SnoreLess

final class PatternAnalyzerTests: XCTestCase {

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

    /// Create a session at a given evening time with specified snore count.
    /// The check-in date should match the same calendar day (evening start).
    private func makeSessionAndCheckIn(
        dayOffset: Int,
        snoreCount: Int,
        alcohol: Bool = false,
        exercised: Bool = false,
        coffeeAfternoon: Bool = false,
        stressLevel: Int = 3
    ) -> (SleepSession, DailyCheckIn) {
        let calendar = Calendar.current
        // Base: 2024-01-15 22:00 local
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = 15 + dayOffset
        comps.hour = 22
        comps.minute = 0
        let startTime = calendar.date(from: comps)!

        let session = SleepSession(startTime: startTime)
        session.endTime = startTime.addingTimeInterval(8 * 3600)
        session.totalSnoreCount = snoreCount
        session.isActive = false
        session.snoreEvents = []

        // Check-in for the same calendar day
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

    // MARK: - 1. No check-ins -> empty insights

    func test_noCheckIns_emptyInsights() throws {
        let session = SleepSession()
        session.endTime = session.startTime.addingTimeInterval(8 * 3600)
        session.totalSnoreCount = 5
        context.insert(session)

        let insights = PatternAnalyzer.analyze(sessions: [session], checkIns: [])

        XCTAssertTrue(insights.isEmpty, "No check-ins should produce empty insights")
    }

    // MARK: - 2. Fewer than 3 matched data points -> no insights

    func test_fewerThan3DataPoints_emptyInsights() throws {
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 5, alcohol: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 8, alcohol: true)

        let insights = PatternAnalyzer.analyze(sessions: [s1, s2], checkIns: [c1, c2])

        XCTAssertTrue(insights.isEmpty, "Fewer than 3 matched pairs should produce empty insights")
    }

    // MARK: - 3. Alcohol on 3 days (avg 8) vs off 3 days (avg 3) -> alcohol insight

    func test_alcoholCorrelation_producesInsight() throws {
        // 3 alcohol days with high snore counts
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 7, alcohol: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 8, alcohol: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 9, alcohol: true)

        // 3 sober days with low snore counts
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 2, alcohol: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 3, alcohol: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 4, alcohol: false)

        let sessions = [s1, s2, s3, s4, s5, s6]
        let checkIns = [c1, c2, c3, c4, c5, c6]

        let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: checkIns)

        let alcoholInsight = insights.first { $0.icon == "wineglass.fill" }
        XCTAssertNotNil(alcoholInsight, "Should produce an alcohol insight when ratio >= 1.3")
        XCTAssertFalse(alcoholInsight?.title.isEmpty ?? true, "Title should not be empty")
        XCTAssertFalse(alcoholInsight?.description.isEmpty ?? true, "Description should not be empty")
    }

    // MARK: - 4. Exercise on 3 days (avg 2) vs off 3 days (avg 6) -> exercise insight

    func test_exerciseCorrelation_producesInsight() throws {
        // 3 exercise days with low snore counts
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 1, exercised: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 2, exercised: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 3, exercised: true)

        // 3 rest days with high snore counts
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 5, exercised: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 6, exercised: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 7, exercised: false)

        let sessions = [s1, s2, s3, s4, s5, s6]
        let checkIns = [c1, c2, c3, c4, c5, c6]

        let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: checkIns)

        let exerciseInsight = insights.first { $0.icon == "figure.run" }
        XCTAssertNotNil(exerciseInsight, "Should produce an exercise insight when reduction >= 15%")
        XCTAssertFalse(exerciseInsight?.title.isEmpty ?? true)
        XCTAssertFalse(exerciseInsight?.description.isEmpty ?? true)
    }

    // MARK: - 5. All same snore count -> no meaningful correlation

    func test_sameSnoreCount_noMeaningfulInsights() throws {
        // All days have same snore count=5, mixed conditions
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 5, alcohol: true, exercised: false)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 5, alcohol: true, exercised: false)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 5, alcohol: true, exercised: false)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 5, alcohol: false, exercised: true)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 5, alcohol: false, exercised: true)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 5, alcohol: false, exercised: true)

        let sessions = [s1, s2, s3, s4, s5, s6]
        let checkIns = [c1, c2, c3, c4, c5, c6]

        let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: checkIns)

        // alcohol ratio=1.0 (<1.3), exercise reduction=0% (<15%) -> no insights
        XCTAssertTrue(insights.isEmpty, "Same snore counts across conditions should yield no insights")
    }

    // MARK: - 6. Insights sorted by absolute correlation strength

    func test_insightsSortedByAbsoluteCorrelation() throws {
        // Alcohol: avg 12 vs 3 => ratio 4.0 => strong positive correlation
        // Exercise: avg 2 vs 6 => 66% reduction => strong negative correlation
        // Both should appear, sorted by |correlation|
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 12, alcohol: true, exercised: false)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 12, alcohol: true, exercised: false)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 12, alcohol: true, exercised: false)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 2, alcohol: false, exercised: true)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 2, alcohol: false, exercised: true)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 2, alcohol: false, exercised: true)

        // Need non-exercise days with snores for exercise baseline and non-alcohol days for alcohol baseline
        // Actually we already have: alcohol=true days are non-exercise, alcohol=false are exercise
        // Alcohol: avg(12,12,12)=12 vs avg(2,2,2)=2 => ratio=6 => corr = min(5,1)=1.0
        // Exercise: avg(2,2,2)=2 vs avg(12,12,12)=12 => reduction = (12-2)/12*100 = 83% => corr = -0.83

        let sessions = [s1, s2, s3, s4, s5, s6]
        let checkIns = [c1, c2, c3, c4, c5, c6]

        let insights = PatternAnalyzer.analyze(sessions: sessions, checkIns: checkIns)

        XCTAssertGreaterThanOrEqual(insights.count, 2, "Should have at least 2 insights")

        // Verify sorting: each insight's |correlation| >= next
        for i in 0..<(insights.count - 1) {
            XCTAssertGreaterThanOrEqual(
                abs(insights[i].correlation),
                abs(insights[i + 1].correlation),
                "Insights should be sorted by absolute correlation (descending)"
            )
        }
    }

    // MARK: - 7. Each insight has non-empty icon, title, description

    func test_insightFieldsNonEmpty() throws {
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 10, alcohol: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 9, alcohol: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 11, alcohol: true)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 3, alcohol: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 2, alcohol: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 4, alcohol: false)

        let insights = PatternAnalyzer.analyze(
            sessions: [s1, s2, s3, s4, s5, s6],
            checkIns: [c1, c2, c3, c4, c5, c6]
        )

        XCTAssertFalse(insights.isEmpty, "Should have at least one insight")
        for insight in insights {
            XCTAssertFalse(insight.icon.isEmpty, "Icon should not be empty")
            XCTAssertFalse(insight.title.isEmpty, "Title should not be empty")
            XCTAssertFalse(insight.description.isEmpty, "Description should not be empty")
        }
    }

    // MARK: - 8. Stress correlation

    func test_stressCorrelation_producesInsight() throws {
        // High stress (4+) days
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 8, stressLevel: 5)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 9, stressLevel: 4)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 7, stressLevel: 5)

        // Low stress (<=2) days
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 2, stressLevel: 1)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 3, stressLevel: 2)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 1, stressLevel: 1)

        let insights = PatternAnalyzer.analyze(
            sessions: [s1, s2, s3, s4, s5, s6],
            checkIns: [c1, c2, c3, c4, c5, c6]
        )

        let stressInsight = insights.first { $0.icon == "brain.head.profile" }
        XCTAssertNotNil(stressInsight, "Should produce a stress insight when diff >= 1.0")
    }

    // MARK: - 9. Coffee afternoon correlation

    func test_coffeeCorrelation_producesInsight() throws {
        // Coffee days
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 8, coffeeAfternoon: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 9, coffeeAfternoon: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 10, coffeeAfternoon: true)

        // No coffee days
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 3, coffeeAfternoon: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 4, coffeeAfternoon: false)
        let (s6, c6) = makeSessionAndCheckIn(dayOffset: 5, snoreCount: 2, coffeeAfternoon: false)

        let insights = PatternAnalyzer.analyze(
            sessions: [s1, s2, s3, s4, s5, s6],
            checkIns: [c1, c2, c3, c4, c5, c6]
        )

        let coffeeInsight = insights.first { $0.icon == "cup.and.saucer.fill" }
        XCTAssertNotNil(coffeeInsight, "Should produce a coffee insight when increase >= 20%")
    }

    // MARK: - 10. Mismatched sessions and check-ins (no matching dates)

    func test_mismatchedDates_emptyInsights() throws {
        let calendar = Calendar.current
        // Sessions in January
        var comps1 = DateComponents()
        comps1.year = 2024; comps1.month = 1; comps1.day = 10; comps1.hour = 22
        let s1 = SleepSession(startTime: calendar.date(from: comps1)!)
        s1.endTime = s1.startTime.addingTimeInterval(8 * 3600)
        s1.totalSnoreCount = 5

        // Check-ins in March (no match)
        var comps2 = DateComponents()
        comps2.year = 2024; comps2.month = 3; comps2.day = 10; comps2.hour = 20
        let c1 = DailyCheckIn(date: calendar.date(from: comps2)!, alcohol: true)

        context.insert(s1)
        context.insert(c1)

        let insights = PatternAnalyzer.analyze(sessions: [s1], checkIns: [c1])

        XCTAssertTrue(insights.isEmpty, "Non-matching dates should produce empty insights")
    }

    // MARK: - 11. Insufficient condition-specific data points

    func test_insufficientAlcoholDays_noAlcoholInsight() throws {
        // Only 2 alcohol days (need 3)
        let (s1, c1) = makeSessionAndCheckIn(dayOffset: 0, snoreCount: 10, alcohol: true)
        let (s2, c2) = makeSessionAndCheckIn(dayOffset: 1, snoreCount: 9, alcohol: true)
        let (s3, c3) = makeSessionAndCheckIn(dayOffset: 2, snoreCount: 2, alcohol: false)
        let (s4, c4) = makeSessionAndCheckIn(dayOffset: 3, snoreCount: 3, alcohol: false)
        let (s5, c5) = makeSessionAndCheckIn(dayOffset: 4, snoreCount: 2, alcohol: false)

        let insights = PatternAnalyzer.analyze(
            sessions: [s1, s2, s3, s4, s5],
            checkIns: [c1, c2, c3, c4, c5]
        )

        let alcoholInsight = insights.first { $0.icon == "wineglass.fill" }
        XCTAssertNil(alcoholInsight, "Should not produce alcohol insight with fewer than 3 alcohol days")
    }
}

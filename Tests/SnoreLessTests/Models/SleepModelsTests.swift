import XCTest
import SwiftData
@testable import SnoreLess

final class SleepModelsTests: XCTestCase {

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

    // MARK: - SleepSession Creation

    func test_sleepSession_creation_defaultValues() throws {
        let session = SleepSession()

        XCTAssertNotNil(session.id)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.totalSnoreCount, 0)
        XCTAssertEqual(session.totalSnoreDuration, 0)
        XCTAssertEqual(session.backgroundNoiseLevel, 0)
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.snoreEvents.isEmpty)
        XCTAssertNil(session.checkIn)
    }

    func test_sleepSession_creation_customStartTime() throws {
        let customDate = Date(timeIntervalSince1970: 1_000_000)
        let session = SleepSession(startTime: customDate)

        XCTAssertEqual(session.startTime, customDate)
        XCTAssertTrue(session.isActive)
    }

    func test_sleepSession_isActive_defaultTrue() throws {
        let session = SleepSession()
        XCTAssertTrue(session.isActive, "New session should be active by default")
    }

    func test_sleepSession_isActive_canBeSetToFalse() throws {
        let session = SleepSession()
        session.isActive = false
        XCTAssertFalse(session.isActive)
    }

    // MARK: - SleepSession durationText

    func test_sleepSession_durationText_whileActive_returnsInProgress() throws {
        let session = SleepSession()
        // endTime is nil by default
        XCTAssertEqual(session.durationText, "진행 중")
    }

    func test_sleepSession_durationText_completedSession_returnsFormatted() throws {
        let start = Date(timeIntervalSince1970: 0)
        let session = SleepSession(startTime: start)
        // 7 hours 30 minutes later
        session.endTime = Date(timeIntervalSince1970: 7 * 3600 + 30 * 60)

        XCTAssertEqual(session.durationText, "7시간 30분")
    }

    func test_sleepSession_durationText_zeroMinutes() throws {
        let start = Date(timeIntervalSince1970: 0)
        let session = SleepSession(startTime: start)
        session.endTime = Date(timeIntervalSince1970: 3 * 3600)

        XCTAssertEqual(session.durationText, "3시간 0분")
    }

    // MARK: - SleepSession snoreDurationText

    func test_sleepSession_snoreDurationText_secondsOnly() throws {
        let session = SleepSession()
        session.totalSnoreDuration = 45

        XCTAssertEqual(session.snoreDurationText, "45초")
    }

    func test_sleepSession_snoreDurationText_minutesAndSeconds() throws {
        let session = SleepSession()
        session.totalSnoreDuration = 125 // 2 min 5 sec

        XCTAssertEqual(session.snoreDurationText, "2분 5초")
    }

    func test_sleepSession_snoreDurationText_zero() throws {
        let session = SleepSession()
        session.totalSnoreDuration = 0

        XCTAssertEqual(session.snoreDurationText, "0초")
    }

    // MARK: - SleepSession with 0 events

    func test_sleepSession_zeroEvents_totalSnoreCountIsZero() throws {
        let session = SleepSession()
        context.insert(session)
        try context.save()

        XCTAssertEqual(session.totalSnoreCount, 0)
        XCTAssertTrue(session.snoreEvents.isEmpty)
    }

    // MARK: - SleepSession with multiple events

    func test_sleepSession_multipleEvents_correctCount() throws {
        let session = SleepSession()

        let event1 = SnoreEvent(timestamp: .now, duration: 5, intensity: 60, hapticLevel: 1, stoppedAfterHaptic: true)
        let event2 = SnoreEvent(timestamp: .now, duration: 3, intensity: 55, hapticLevel: 2, stoppedAfterHaptic: false)
        let event3 = SnoreEvent(timestamp: .now, duration: 7, intensity: 70, hapticLevel: 3, stoppedAfterHaptic: true)

        event1.session = session
        event2.session = session
        event3.session = session
        session.snoreEvents = [event1, event2, event3]
        session.totalSnoreCount = session.snoreEvents.count

        context.insert(session)
        try context.save()

        XCTAssertEqual(session.snoreEvents.count, 3)
        XCTAssertEqual(session.totalSnoreCount, 3)
    }

    // MARK: - SnoreEvent Creation

    func test_snoreEvent_creation_defaultValues() throws {
        let event = SnoreEvent()

        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.duration, 0)
        XCTAssertEqual(event.intensity, 0)
        XCTAssertEqual(event.hapticLevel, 1)
        XCTAssertFalse(event.stoppedAfterHaptic)
        XCTAssertNil(event.session)
    }

    func test_snoreEvent_creation_allFields() throws {
        let timestamp = Date(timeIntervalSince1970: 5000)
        let event = SnoreEvent(
            timestamp: timestamp,
            duration: 12.5,
            intensity: 72.3,
            hapticLevel: 3,
            stoppedAfterHaptic: true
        )

        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.duration, 12.5)
        XCTAssertEqual(event.intensity, 72.3, accuracy: 0.01)
        XCTAssertEqual(event.hapticLevel, 3)
        XCTAssertTrue(event.stoppedAfterHaptic)
    }

    func test_snoreEvent_sessionRelationship() throws {
        let session = SleepSession()
        let event = SnoreEvent(duration: 5, intensity: 60)
        event.session = session
        session.snoreEvents.append(event)

        context.insert(session)
        try context.save()

        XCTAssertEqual(event.session?.id, session.id)
        XCTAssertEqual(session.snoreEvents.first?.id, event.id)
    }

    // MARK: - DailyCheckIn Creation

    func test_dailyCheckIn_creation_defaultValues() throws {
        let checkIn = DailyCheckIn()

        XCTAssertNotNil(checkIn.id)
        XCTAssertFalse(checkIn.coffeeAfternoon)
        XCTAssertFalse(checkIn.exercised)
        XCTAssertFalse(checkIn.alcohol)
        XCTAssertEqual(checkIn.stressLevel, 3)
        XCTAssertNil(checkIn.session)
    }

    func test_dailyCheckIn_creation_allFields() throws {
        let date = Date(timeIntervalSince1970: 100_000)
        let checkIn = DailyCheckIn(
            date: date,
            coffeeAfternoon: true,
            exercised: true,
            alcohol: false,
            stressLevel: 5
        )

        XCTAssertEqual(checkIn.date, date)
        XCTAssertTrue(checkIn.coffeeAfternoon)
        XCTAssertTrue(checkIn.exercised)
        XCTAssertFalse(checkIn.alcohol)
        XCTAssertEqual(checkIn.stressLevel, 5)
    }

    func test_dailyCheckIn_sessionRelationship() throws {
        let session = SleepSession()
        let checkIn = DailyCheckIn(stressLevel: 4)
        session.checkIn = checkIn
        checkIn.session = session

        context.insert(session)
        context.insert(checkIn)
        try context.save()

        XCTAssertEqual(session.checkIn?.id, checkIn.id)
        XCTAssertEqual(checkIn.session?.id, session.id)
    }
}

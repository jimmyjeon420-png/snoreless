import Foundation
import SwiftData

/// 수면 데이터 관리
/// 워치 데이터 변환, 통계 계산, 체크인 매칭 담당
class SleepDataStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - 워치 데이터를 SwiftData로 변환 및 저장
    /// SleepSessionData (워치 전송 데이터)를 SleepSession (SwiftData 모델)로 변환하여 저장
    func saveSessionFromWatch(_ data: SleepSessionData) throws -> SleepSession {
        let session = SleepSession(startTime: data.startTime)
        session.endTime = data.endTime
        session.totalSnoreCount = data.snoreEvents.count
        session.totalSnoreDuration = data.totalSnoreDuration
        session.backgroundNoiseLevel = data.backgroundNoiseLevel
        session.isActive = (data.endTime == nil)

        // 코골이 이벤트 변환
        for eventData in data.snoreEvents {
            let event = SnoreEvent(
                timestamp: eventData.timestamp,
                duration: eventData.duration,
                intensity: eventData.intensity,
                hapticLevel: eventData.hapticLevel,
                stoppedAfterHaptic: eventData.stoppedAfterHaptic
            )
            event.session = session
            session.snoreEvents.append(event)
        }

        // 같은 날 체크인이 있으면 매칭
        if let checkIn = findCheckIn(for: data.startTime) {
            session.checkIn = checkIn
            checkIn.session = session
        }

        modelContext.insert(session)
        try modelContext.save()

        return session
    }

    // MARK: - 최근 N일 코골이 통계
    /// 최근 days일간의 일별 코골이 통계 반환
    func snoreStats(forLastDays days: Int) throws -> [DailySnoreStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate<SleepSession> { !$0.isActive },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        let sessions = try modelContext.fetch(descriptor)

        return (0..<days).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!

            let daySessions = sessions.filter {
                $0.startTime >= date && $0.startTime < nextDate
            }

            let totalCount = daySessions.reduce(0) { $0 + $1.totalSnoreCount }
            let totalDuration = daySessions.reduce(0.0) { $0 + $1.totalSnoreDuration }
            let stoppedCount = daySessions.flatMap(\.snoreEvents).filter(\.stoppedAfterHaptic).count

            return DailySnoreStat(
                date: date,
                snoreCount: totalCount,
                totalDuration: totalDuration,
                stoppedByHapticCount: stoppedCount,
                sessionCount: daySessions.count
            )
        }.reversed()
    }

    // MARK: - 체크인 매칭
    /// 주어진 날짜에 해당하는 체크인 찾기
    /// 수면 시작 시각과 같은 날(정오 기준)의 체크인을 매칭
    func findCheckIn(for sessionStart: Date) -> DailyCheckIn? {
        let calendar = Calendar.current
        let sessionDate = calendar.startOfDay(for: sessionStart)

        // 자정 이전(전날 밤)이면 전날 체크인, 이후면 당일 체크인
        let hour = calendar.component(.hour, from: sessionStart)
        let checkInDate: Date
        if hour < 12 {
            // 새벽이면 전날 체크인 매칭
            checkInDate = calendar.date(byAdding: .day, value: -1, to: sessionDate)!
        } else {
            checkInDate = sessionDate
        }

        let nextDate = calendar.date(byAdding: .day, value: 1, to: checkInDate)!

        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> {
                $0.date >= checkInDate && $0.date < nextDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - 전체 통계 요약
    /// 전체 기간 요약 통계
    func overallStats() throws -> OverallStats {
        let descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate<SleepSession> { !$0.isActive }
        )
        let sessions = try modelContext.fetch(descriptor)

        let totalNights = sessions.count
        let totalSnores = sessions.reduce(0) { $0 + $1.totalSnoreCount }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.totalSnoreDuration }
        let allEvents = sessions.flatMap(\.snoreEvents)
        let stoppedCount = allEvents.filter(\.stoppedAfterHaptic).count

        return OverallStats(
            totalNights: totalNights,
            totalSnoreCount: totalSnores,
            totalSnoreDuration: totalDuration,
            hapticSuccessCount: stoppedCount,
            hapticTotalCount: allEvents.count
        )
    }
}

// MARK: - 통계 모델
struct DailySnoreStat: Identifiable {
    let id = UUID()
    let date: Date
    let snoreCount: Int
    let totalDuration: TimeInterval
    let stoppedByHapticCount: Int
    let sessionCount: Int
}

struct OverallStats {
    let totalNights: Int
    let totalSnoreCount: Int
    let totalSnoreDuration: TimeInterval
    let hapticSuccessCount: Int
    let hapticTotalCount: Int

    var hapticSuccessRate: Double {
        guard hapticTotalCount > 0 else { return 0 }
        return Double(hapticSuccessCount) / Double(hapticTotalCount) * 100
    }

    var avgSnoresPerNight: Double {
        guard totalNights > 0 else { return 0 }
        return Double(totalSnoreCount) / Double(totalNights)
    }
}

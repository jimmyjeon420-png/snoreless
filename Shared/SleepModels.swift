import Foundation
import SwiftData

// MARK: - SwiftData 모델

@Model
final class SleepSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var totalSnoreCount: Int
    var totalSnoreDuration: TimeInterval
    var backgroundNoiseLevel: Double
    var isActive: Bool

    @Relationship(deleteRule: .cascade)
    var snoreEvents: [SnoreEvent]

    var checkIn: DailyCheckIn?

    init(startTime: Date = .now) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = nil
        self.totalSnoreCount = 0
        self.totalSnoreDuration = 0
        self.backgroundNoiseLevel = 0
        self.isActive = true
        self.snoreEvents = []
        self.checkIn = nil
    }

    var durationText: String {
        guard let end = endTime else { return "진행 중" }
        let hours = Int(end.timeIntervalSince(startTime)) / 3600
        let minutes = (Int(end.timeIntervalSince(startTime)) % 3600) / 60
        return "\(hours)시간 \(minutes)분"
    }

    var snoreDurationText: String {
        let minutes = Int(totalSnoreDuration) / 60
        let seconds = Int(totalSnoreDuration) % 60
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        }
        return "\(seconds)초"
    }
}

@Model
final class SnoreEvent {
    var id: UUID
    var timestamp: Date
    var duration: TimeInterval
    var intensity: Double
    var hapticLevel: Int
    var stoppedAfterHaptic: Bool

    var session: SleepSession?

    init(timestamp: Date = .now, duration: TimeInterval = 0, intensity: Double = 0, hapticLevel: Int = 1, stoppedAfterHaptic: Bool = false) {
        self.id = UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.intensity = intensity
        self.hapticLevel = hapticLevel
        self.stoppedAfterHaptic = stoppedAfterHaptic
    }
}

@Model
final class DailyCheckIn {
    var id: UUID
    var date: Date
    var coffeeAfternoon: Bool       // 오후에 커피 마셨는지
    var exercised: Bool             // 운동 했는지
    var alcohol: Bool               // 음주 했는지
    var stressLevel: Int            // 1~5

    var session: SleepSession?

    init(date: Date = .now, coffeeAfternoon: Bool = false, exercised: Bool = false, alcohol: Bool = false, stressLevel: Int = 3) {
        self.id = UUID()
        self.date = date
        self.coffeeAfternoon = coffeeAfternoon
        self.exercised = exercised
        self.alcohol = alcohol
        self.stressLevel = stressLevel
    }
}

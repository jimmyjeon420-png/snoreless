import Foundation

// MARK: - Sleep Score Models

enum SleepGrade: String {
    case excellent = "A+"
    case great = "A"
    case good = "B"
    case fair = "C"
    case poor = "D"
}

struct SleepScore {
    let total: Int            // 0-100
    let snoreScore: Int       // 0-30 (fewer snores = higher)
    let responseScore: Int    // 0-30 (higher response rate = higher)
    let durationScore: Int    // 0-25 (7-9 hours optimal)
    let consistencyScore: Int // 0-15 (regular sleep time)
    let grade: SleepGrade
    let comment: String       // AI-style comment
}

// MARK: - Calculator

struct SleepScoreCalculator {

    /// Calculate a sleep quality score for a session, using recent sessions for consistency.
    static func calculate(session: SleepSession, recentSessions: [SleepSession]) -> SleepScore {
        let snore = calcSnoreScore(session: session)
        let response = calcResponseScore(session: session)
        let duration = calcDurationScore(session: session)
        let consistency = calcConsistencyScore(session: session, recentSessions: recentSessions)

        let total = snore + response + duration + consistency
        let grade = gradeFor(total)
        let comment = commentFor(grade)

        return SleepScore(
            total: total,
            snoreScore: snore,
            responseScore: response,
            durationScore: duration,
            consistencyScore: consistency,
            grade: grade,
            comment: comment
        )
    }

    // MARK: - Snore Score (0-30)

    private static func calcSnoreScore(session: SleepSession) -> Int {
        let count = session.totalSnoreCount
        switch count {
        case 0:      return 30
        case 1...2:  return 25
        case 3...5:  return 18
        case 6...10: return 10
        default:     return 5
        }
    }

    // MARK: - Response Score (0-30)

    private static func calcResponseScore(session: SleepSession) -> Int {
        let events = session.snoreEvents
        guard !events.isEmpty else { return 30 } // no snores = perfect response

        let stoppedCount = events.filter(\.stoppedAfterHaptic).count
        let rate = Double(stoppedCount) / Double(events.count)
        return Int(rate * 30.0)
    }

    // MARK: - Duration Score (0-25)

    private static func calcDurationScore(session: SleepSession) -> Int {
        guard let endTime = session.endTime else { return 0 }

        let hours = endTime.timeIntervalSince(session.startTime) / 3600.0

        switch hours {
        case 7.0...9.0:   return 25
        case 6.0..<7.0,
             9.0..<10.0:  return 18  // 9.0 already matched above so 9+..10
        case 5.0..<6.0,
             10.0..<11.0: return 10
        default:          return 5
        }
    }

    // MARK: - Consistency Score (0-15)

    private static func calcConsistencyScore(session: SleepSession, recentSessions: [SleepSession]) -> Int {
        // Need at least 2 other sessions for comparison
        let others = recentSessions.filter { $0.id != session.id }
        guard !others.isEmpty else { return 15 } // first session gets full marks

        let calendar = Calendar.current

        // Average start-time (as seconds from midnight) of recent sessions
        let avgStartSeconds: Double = {
            let seconds = others.compactMap { s -> Double? in
                let comps = calendar.dateComponents([.hour, .minute], from: s.startTime)
                guard let h = comps.hour, let m = comps.minute else { return nil }
                // Handle cross-midnight: treat hours 0-6 as 24-30
                let hour = h < 12 ? h + 24 : h
                return Double(hour * 3600 + m * 60)
            }
            guard !seconds.isEmpty else { return 0 }
            return seconds.reduce(0, +) / Double(seconds.count)
        }()

        let sessionComps = calendar.dateComponents([.hour, .minute], from: session.startTime)
        guard let sh = sessionComps.hour, let sm = sessionComps.minute else { return 0 }
        let sessionHour = sh < 12 ? sh + 24 : sh
        let sessionSeconds = Double(sessionHour * 3600 + sm * 60)

        let diffMinutes = abs(sessionSeconds - avgStartSeconds) / 60.0

        switch diffMinutes {
        case 0..<30:  return 15
        case 30..<60: return 10
        case 60..<120: return 5
        default:       return 0
        }
    }

    // MARK: - Grade

    private static func gradeFor(_ total: Int) -> SleepGrade {
        switch total {
        case 90...100: return .excellent
        case 80..<90:  return .great
        case 70..<80:  return .good
        case 55..<70:  return .fair
        default:       return .poor
        }
    }

    // MARK: - Comment

    private static func commentFor(_ grade: SleepGrade) -> String {
        switch grade {
        case .excellent:
            return String(localized: "완벽한 밤이었어요! 이 조건을 유지해보세요")
        case .great:
            return String(localized: "좋은 수면이에요. 코골이도 잘 관리되고 있어요")
        case .good:
            return String(localized: "괜찮은 밤이에요. 조금만 더 일찍 자보세요")
        case .fair:
            return String(localized: "코골이가 좀 있었어요. 베개 높이를 조절해보세요")
        case .poor:
            return String(localized: "힘든 밤이었네요. 음주나 피로가 영향을 줬을 수 있어요")
        }
    }
}

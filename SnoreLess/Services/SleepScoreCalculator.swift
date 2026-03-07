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

    // MARK: - 점수 배점 상한
    private static let snoreScoreMax: Int = 30
    private static let responseScoreMax: Double = 30.0
    private static let durationScoreMax: Int = 25
    private static let consistencyScoreMax: Int = 15

    // MARK: - 코골이 횟수별 점수
    private static let snoreScoreZero: Int = 30
    private static let snoreScoreLow: Int = 25       // 1-2회
    private static let snoreScoreMid: Int = 18        // 3-5회
    private static let snoreScoreHigh: Int = 10       // 6-10회
    private static let snoreScoreExcessive: Int = 5   // 11회+

    // MARK: - 수면 시간 점수
    private static let durationOptimalScore: Int = 25     // 7-9시간
    private static let durationNearOptimalScore: Int = 18 // 6-7 or 9-10시간
    private static let durationFarScore: Int = 10         // 5-6 or 10-11시간
    private static let durationPoorScore: Int = 5         // 그 외

    // MARK: - 수면 시간 범위 (시간)
    private static let durationOptimalMin: Double = 7.0
    private static let durationOptimalMax: Double = 9.0
    private static let durationNearMin: Double = 6.0
    private static let durationNearMax: Double = 10.0
    private static let durationFarMin: Double = 5.0
    private static let durationFarMax: Double = 11.0

    // MARK: - 일관성 점수 (취침시간 편차 기준, 분)
    private static let consistencyExcellentThreshold: Double = 30   // 0-30분
    private static let consistencyGoodThreshold: Double = 60        // 30-60분
    private static let consistencyFairThreshold: Double = 120       // 60-120분
    private static let consistencyExcellentScore: Int = 15
    private static let consistencyGoodScore: Int = 10
    private static let consistencyFairScore: Int = 5
    private static let consistencyPoorScore: Int = 0

    // MARK: - 크로스 미드나잇 보정 기준 (시)
    private static let crossMidnightHourThreshold: Int = 12

    // MARK: - 등급 경계 (총점 기준)
    private static let gradeExcellentMin: Int = 90
    private static let gradeGreatMin: Int = 80
    private static let gradeGoodMin: Int = 70
    private static let gradeFairMin: Int = 55

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
        case 0:      return snoreScoreZero
        case 1...2:  return snoreScoreLow
        case 3...5:  return snoreScoreMid
        case 6...10: return snoreScoreHigh
        default:     return snoreScoreExcessive
        }
    }

    // MARK: - Response Score (0-30)

    private static func calcResponseScore(session: SleepSession) -> Int {
        let events = session.snoreEvents
        guard !events.isEmpty else { return Int(responseScoreMax) } // no snores = perfect response

        let stoppedCount = events.filter(\.stoppedAfterHaptic).count
        let rate = Double(stoppedCount) / Double(events.count)
        return Int(rate * responseScoreMax)
    }

    // MARK: - Duration Score (0-25)

    private static func calcDurationScore(session: SleepSession) -> Int {
        guard let endTime = session.endTime else { return 0 }

        let hours = endTime.timeIntervalSince(session.startTime) / 3600.0

        switch hours {
        case durationOptimalMin...durationOptimalMax:
            return durationOptimalScore
        case durationNearMin..<durationOptimalMin,
             durationOptimalMax..<durationNearMax:
            return durationNearOptimalScore
        case durationFarMin..<durationNearMin,
             durationNearMax..<durationFarMax:
            return durationFarScore
        default:
            return durationPoorScore
        }
    }

    // MARK: - Consistency Score (0-15)

    private static func calcConsistencyScore(session: SleepSession, recentSessions: [SleepSession]) -> Int {
        // Need at least 2 other sessions for comparison
        let others = recentSessions.filter { $0.id != session.id }
        guard !others.isEmpty else { return consistencyExcellentScore } // first session gets full marks

        let calendar = Calendar.current

        // Average start-time (as seconds from midnight) of recent sessions
        let avgStartSeconds: Double = {
            let seconds = others.compactMap { s -> Double? in
                let comps = calendar.dateComponents([.hour, .minute], from: s.startTime)
                guard let h = comps.hour, let m = comps.minute else { return nil }
                // Handle cross-midnight: treat hours 0-6 as 24-30
                let hour = h < crossMidnightHourThreshold ? h + 24 : h
                return Double(hour * 3600 + m * 60)
            }
            guard !seconds.isEmpty else { return 0 }
            return seconds.reduce(0, +) / Double(seconds.count)
        }()

        let sessionComps = calendar.dateComponents([.hour, .minute], from: session.startTime)
        guard let sh = sessionComps.hour, let sm = sessionComps.minute else { return 0 }
        let sessionHour = sh < crossMidnightHourThreshold ? sh + 24 : sh
        let sessionSeconds = Double(sessionHour * 3600 + sm * 60)

        let diffMinutes = abs(sessionSeconds - avgStartSeconds) / 60.0

        switch diffMinutes {
        case 0..<consistencyExcellentThreshold:  return consistencyExcellentScore
        case consistencyExcellentThreshold..<consistencyGoodThreshold: return consistencyGoodScore
        case consistencyGoodThreshold..<consistencyFairThreshold: return consistencyFairScore
        default:       return consistencyPoorScore
        }
    }

    // MARK: - Grade

    private static func gradeFor(_ total: Int) -> SleepGrade {
        switch total {
        case gradeExcellentMin...100: return .excellent
        case gradeGreatMin..<gradeExcellentMin:  return .great
        case gradeGoodMin..<gradeGreatMin:  return .good
        case gradeFairMin..<gradeGoodMin:  return .fair
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

import Foundation

/// AI 분석기 (Phase 4)
/// 로컬 통계 기반 패턴 분석. 추후 Anthropic API 연동 예정.
class AIAnalyzer {
    // MARK: - 분석 결과
    struct AnalysisResult {
        let insights: [String]
        let generatedAt: Date
    }

    // MARK: - 주간 분석
    /// 최근 7일 세션과 체크인 데이터로 패턴 분석
    /// 데이터가 7일 미만이면 nil 반환 (최소 데이터 요구)
    func analyzeWeekly(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> AnalysisResult? {
        // 최소 3일 이상의 데이터 필요
        guard sessions.count >= 3 else { return nil }

        var insights: [String] = []

        // 음주 vs 비음주 비교
        let alcoholInsight = analyzeAlcoholEffect(sessions: sessions, checkIns: checkIns)
        if let insight = alcoholInsight {
            insights.append(insight)
        }

        // 운동 vs 비운동 비교
        let exerciseInsight = analyzeExerciseEffect(sessions: sessions, checkIns: checkIns)
        if let insight = exerciseInsight {
            insights.append(insight)
        }

        // 스트레스별 비교
        let stressInsight = analyzeStressEffect(sessions: sessions, checkIns: checkIns)
        if let insight = stressInsight {
            insights.append(insight)
        }

        // 커피 효과 분석
        let coffeeInsight = analyzeCoffeeEffect(sessions: sessions, checkIns: checkIns)
        if let insight = coffeeInsight {
            insights.append(insight)
        }

        // 진동 효과 분석
        let hapticInsight = analyzeHapticEffectiveness(sessions: sessions)
        if let insight = hapticInsight {
            insights.append(insight)
        }

        // 인사이트가 없으면 기본 메시지
        if insights.isEmpty {
            insights.append("아직 뚜렷한 패턴이 발견되지 않았습니다. 데이터가 더 쌓이면 분석 정확도가 올라갑니다.")
        }

        return AnalysisResult(insights: insights, generatedAt: .now)
    }

    // MARK: - 음주 효과 분석
    private func analyzeAlcoholEffect(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> String? {
        let (withAlcohol, withoutAlcohol) = partitionByCheckIn(sessions: sessions, checkIns: checkIns) { $0.alcohol }

        guard !withAlcohol.isEmpty, !withoutAlcohol.isEmpty else { return nil }

        let avgWithAlcohol = averageSnoreCount(withAlcohol)
        let avgWithout = averageSnoreCount(withoutAlcohol)

        if avgWithAlcohol > avgWithout * 1.3 {
            let diff = Int(((avgWithAlcohol - avgWithout) / max(avgWithout, 1)) * 100)
            return "술을 마신 날은 코골이가 약 \(diff)% 더 많았습니다. 취침 전 음주를 줄이면 효과가 있을 수 있습니다."
        } else if avgWithout > avgWithAlcohol * 1.3 {
            return "음주 여부와 코골이 사이에 뚜렷한 상관관계가 보이지 않습니다."
        }

        return nil
    }

    // MARK: - 운동 효과 분석
    private func analyzeExerciseEffect(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> String? {
        let (withExercise, withoutExercise) = partitionByCheckIn(sessions: sessions, checkIns: checkIns) { $0.exercised }

        guard !withExercise.isEmpty, !withoutExercise.isEmpty else { return nil }

        let avgWithExercise = averageSnoreCount(withExercise)
        let avgWithout = averageSnoreCount(withoutExercise)

        if avgWithExercise < avgWithout * 0.7 {
            let diff = Int(((avgWithout - avgWithExercise) / max(avgWithout, 1)) * 100)
            return "운동한 날은 코골이가 약 \(diff)% 줄었습니다. 규칙적인 운동이 도움이 될 수 있습니다."
        } else if avgWithExercise > avgWithout * 1.3 {
            return "운동한 날 오히려 코골이가 많았습니다. 취침 직전 격한 운동은 피하는 것이 좋겠습니다."
        }

        return nil
    }

    // MARK: - 스트레스 효과 분석
    private func analyzeStressEffect(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> String? {
        let calendar = Calendar.current

        // 세션과 체크인을 날짜로 매칭
        var stressSnoreMap: [Int: [Int]] = [:]  // 스트레스 레벨 -> [코골이 횟수]

        for session in sessions {
            let sessionDate = calendar.startOfDay(for: session.startTime)
            let hour = calendar.component(.hour, from: session.startTime)
            let checkInDate: Date
            if hour < 12 {
                guard let adjusted = calendar.date(byAdding: .day, value: -1, to: sessionDate) else { continue }
                checkInDate = adjusted
            } else {
                checkInDate = sessionDate
            }

            if let checkIn = checkIns.first(where: {
                calendar.isDate($0.date, inSameDayAs: checkInDate)
            }) {
                stressSnoreMap[checkIn.stressLevel, default: []].append(session.totalSnoreCount)
            }
        }

        guard stressSnoreMap.count >= 2 else { return nil }

        // 저스트레스(1-2) vs 고스트레스(4-5) 비교
        let lowStress = (stressSnoreMap[1, default: []] + stressSnoreMap[2, default: []])
        let highStress = (stressSnoreMap[4, default: []] + stressSnoreMap[5, default: []])

        guard !lowStress.isEmpty, !highStress.isEmpty else { return nil }

        let avgLow = Double(lowStress.reduce(0, +)) / Double(lowStress.count)
        let avgHigh = Double(highStress.reduce(0, +)) / Double(highStress.count)

        if avgHigh > avgLow * 1.3 {
            return "스트레스가 높은 날(4~5)은 낮은 날(1~2)보다 코골이가 더 많았습니다. 취침 전 릴렉스 루틴을 추천합니다."
        }

        return nil
    }

    // MARK: - 커피 효과 분석
    private func analyzeCoffeeEffect(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> String? {
        let (withCoffee, withoutCoffee) = partitionByCheckIn(sessions: sessions, checkIns: checkIns) { $0.coffeeAfternoon }

        guard !withCoffee.isEmpty, !withoutCoffee.isEmpty else { return nil }

        let avgWithCoffee = averageSnoreCount(withCoffee)
        let avgWithout = averageSnoreCount(withoutCoffee)

        if avgWithCoffee > avgWithout * 1.3 {
            return "오후에 커피를 마신 날은 코골이가 더 많은 경향이 있습니다. 오후 커피를 줄여보세요."
        }

        return nil
    }

    // MARK: - 진동 효과 분석
    private func analyzeHapticEffectiveness(sessions: [SleepSession]) -> String? {
        let allEvents = sessions.flatMap(\.snoreEvents)
        guard allEvents.count >= 5 else { return nil }

        let stoppedCount = allEvents.filter(\.stoppedAfterHaptic).count
        let rate = Double(stoppedCount) / Double(allEvents.count) * 100

        if rate >= 60 {
            return "진동 후 코골이가 멈춘 비율이 \(Int(rate))%입니다. 진동 요법이 잘 작동하고 있습니다."
        } else if rate >= 30 {
            return "진동 후 멈춤 비율은 \(Int(rate))%입니다. 감도를 높이면 효과가 개선될 수 있습니다."
        } else {
            return "진동 후 멈춤 비율이 \(Int(rate))%로 낮습니다. 진동 강도나 타이밍 조절을 고려해보세요."
        }
    }

    // MARK: - 유틸리티

    /// 체크인 조건으로 세션 분류
    private func partitionByCheckIn(
        sessions: [SleepSession],
        checkIns: [DailyCheckIn],
        condition: (DailyCheckIn) -> Bool
    ) -> (withCondition: [SleepSession], withoutCondition: [SleepSession]) {
        let calendar = Calendar.current
        var withCondition: [SleepSession] = []
        var withoutCondition: [SleepSession] = []

        for session in sessions {
            let sessionDate = calendar.startOfDay(for: session.startTime)
            let hour = calendar.component(.hour, from: session.startTime)
            let checkInDate: Date
            if hour < 12 {
                guard let adjusted = calendar.date(byAdding: .day, value: -1, to: sessionDate) else { continue }
                checkInDate = adjusted
            } else {
                checkInDate = sessionDate
            }

            if let checkIn = checkIns.first(where: {
                calendar.isDate($0.date, inSameDayAs: checkInDate)
            }) {
                if condition(checkIn) {
                    withCondition.append(session)
                } else {
                    withoutCondition.append(session)
                }
            }
        }

        return (withCondition, withoutCondition)
    }

    /// 평균 코골이 횟수 계산
    private func averageSnoreCount(_ sessions: [SleepSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.totalSnoreCount }
        return Double(total) / Double(sessions.count)
    }

    // MARK: - Phase 4: Anthropic API 연동 자리
    // TODO: 추후 Anthropic Claude API를 연동하여 고급 패턴 분석 및 개인화된 조언 제공
    // func analyzeWithAI(sessions: [SleepSession], checkIns: [DailyCheckIn]) async throws -> AnalysisResult
}

import Foundation

// MARK: - Pattern Insight Model

struct PatternInsight: Identifiable {
    let id = UUID()
    let icon: String        // SF Symbol name
    let title: String
    let description: String
    let correlation: Double  // -1.0 to 1.0
}

// MARK: - Pattern Analyzer

struct PatternAnalyzer {

    /// Analyze correlations between check-in data and snoring patterns.
    /// Returns insights sorted by absolute correlation strength.
    static func analyze(sessions: [SleepSession], checkIns: [DailyCheckIn]) -> [PatternInsight] {
        let matched = matchSessionsToCheckIns(sessions: sessions, checkIns: checkIns)
        guard matched.count >= 3 else { return [] }

        var insights: [PatternInsight] = []

        if let insight = analyzeAlcohol(matched: matched) {
            insights.append(insight)
        }
        if let insight = analyzeExercise(matched: matched) {
            insights.append(insight)
        }
        if let insight = analyzeStress(matched: matched) {
            insights.append(insight)
        }
        if let insight = analyzeLateMeal(sessions: sessions, checkIns: checkIns) {
            insights.append(insight)
        }

        // Sort by absolute correlation strength (strongest first)
        insights.sort { abs($0.correlation) > abs($1.correlation) }

        return insights
    }

    // MARK: - Match sessions to check-ins by date

    private static func matchSessionsToCheckIns(
        sessions: [SleepSession],
        checkIns: [DailyCheckIn]
    ) -> [(session: SleepSession, checkIn: DailyCheckIn)] {
        let calendar = Calendar.current

        return sessions.compactMap { session in
            let sessionDate = calendar.startOfDay(for: session.startTime)
            let hour = calendar.component(.hour, from: session.startTime)
            // If session starts after midnight (before noon), match to previous day's check-in
            let checkInDate: Date
            if hour < 12, let previousDay = calendar.date(byAdding: .day, value: -1, to: sessionDate) {
                checkInDate = previousDay
            } else {
                checkInDate = sessionDate
            }

            if let checkIn = checkIns.first(where: {
                calendar.isDate($0.date, inSameDayAs: checkInDate)
            }) {
                return (session, checkIn)
            }
            return nil
        }
    }

    // MARK: - Alcohol Analysis

    private static func analyzeAlcohol(
        matched: [(session: SleepSession, checkIn: DailyCheckIn)]
    ) -> PatternInsight? {
        let alcoholDays = matched.filter { $0.checkIn.alcohol }
        let soberDays = matched.filter { !$0.checkIn.alcohol }

        guard alcoholDays.count >= 3, soberDays.count >= 3 else { return nil }

        let avgAlcohol = average(alcoholDays.map(\.session.totalSnoreCount))
        let avgSober = average(soberDays.map(\.session.totalSnoreCount))

        guard avgSober > 0 else { return nil }

        let ratio = avgAlcohol / avgSober
        let correlation = min(max((ratio - 1.0), -1.0), 1.0)

        if ratio >= 1.3 {
            let multiplier = String(format: "%.1f", ratio)
            return PatternInsight(
                icon: "wineglass.fill",
                title: String(localized: "음주와 코골이"),
                description: String(localized: "술 마신 날 코골이 \(multiplier)배"),
                correlation: correlation
            )
        }

        return nil
    }

    // MARK: - Exercise Analysis

    private static func analyzeExercise(
        matched: [(session: SleepSession, checkIn: DailyCheckIn)]
    ) -> PatternInsight? {
        let exerciseDays = matched.filter { $0.checkIn.exercised }
        let restDays = matched.filter { !$0.checkIn.exercised }

        guard exerciseDays.count >= 3, restDays.count >= 3 else { return nil }

        let avgExercise = average(exerciseDays.map(\.session.totalSnoreCount))
        let avgRest = average(restDays.map(\.session.totalSnoreCount))

        guard avgRest > 0 else { return nil }

        let reduction = ((avgRest - avgExercise) / avgRest) * 100
        let correlation = -min(max(reduction / 100.0, -1.0), 1.0) // negative = good

        if reduction >= 15 {
            let pct = Int(reduction)
            return PatternInsight(
                icon: "figure.run",
                title: String(localized: "운동과 코골이"),
                description: String(localized: "운동한 날 코골이 \(pct)% 감소"),
                correlation: correlation
            )
        } else if reduction <= -15 {
            return PatternInsight(
                icon: "figure.run",
                title: String(localized: "운동과 코골이"),
                description: String(localized: "운동한 날 코골이가 오히려 늘었어요. 취침 직전 운동은 피해보세요"),
                correlation: correlation
            )
        }

        return nil
    }

    // MARK: - Stress Analysis

    private static func analyzeStress(
        matched: [(session: SleepSession, checkIn: DailyCheckIn)]
    ) -> PatternInsight? {
        let highStress = matched.filter { $0.checkIn.stressLevel >= 4 }
        let lowStress = matched.filter { $0.checkIn.stressLevel <= 2 }

        guard highStress.count >= 3, lowStress.count >= 3 else { return nil }

        let avgHigh = average(highStress.map(\.session.totalSnoreCount))
        let avgLow = average(lowStress.map(\.session.totalSnoreCount))

        let diff = avgHigh - avgLow
        let correlation = min(max(diff / max(avgLow, 1.0), -1.0), 1.0)

        if diff >= 1.0 {
            let extra = Int(diff.rounded())
            return PatternInsight(
                icon: "brain.head.profile",
                title: String(localized: "스트레스와 코골이"),
                description: String(localized: "스트레스 높은 날 코골이 \(extra)회 더"),
                correlation: correlation
            )
        }

        return nil
    }

    // MARK: - Late Meal (Coffee as proxy)

    private static func analyzeLateMeal(
        sessions: [SleepSession],
        checkIns: [DailyCheckIn]
    ) -> PatternInsight? {
        let matched = matchSessionsToCheckIns(sessions: sessions, checkIns: checkIns)

        let coffeeDays = matched.filter { $0.checkIn.coffeeAfternoon }
        let noCoffeeDays = matched.filter { !$0.checkIn.coffeeAfternoon }

        guard coffeeDays.count >= 3, noCoffeeDays.count >= 3 else { return nil }

        let avgCoffee = average(coffeeDays.map(\.session.totalSnoreCount))
        let avgNoCoffee = average(noCoffeeDays.map(\.session.totalSnoreCount))

        guard avgNoCoffee > 0 else { return nil }

        let increase = ((avgCoffee - avgNoCoffee) / avgNoCoffee) * 100
        let correlation = min(max(increase / 100.0, -1.0), 1.0)

        if increase >= 20 {
            return PatternInsight(
                icon: "cup.and.saucer.fill",
                title: String(localized: "오후 커피와 코골이"),
                description: String(localized: "오후 커피가 코골이에 영향을 줄 수 있어요"),
                correlation: correlation
            )
        }

        return nil
    }

    // MARK: - Utility

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

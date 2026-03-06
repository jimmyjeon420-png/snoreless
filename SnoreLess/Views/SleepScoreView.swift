import SwiftUI
import SwiftData
import Charts

struct SleepScoreView: View {
    let score: SleepScore
    let session: SleepSession

    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var allSessions: [SleepSession]

    @Query(sort: \DailyCheckIn.date, order: .reverse)
    private var checkIns: [DailyCheckIn]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Big score circle
                scoreCircle
                    .padding(.top, 8)

                // Comment
                Text(score.comment)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Score breakdown
                scoreBreakdown
                    .padding(.horizontal)

                // 7-day trend
                trendChart
                    .padding(.horizontal)

                // Pattern insights
                patternInsights
                    .padding(.horizontal)

                // Tips
                tipsSection
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.black)
        .navigationTitle(String(localized: "수면 점수"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Score Circle

    private var scoreCircle: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
                .frame(width: 160, height: 160)

            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(score.total) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: gradeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Score text
            VStack(spacing: 2) {
                Text("\(score.total)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(score.grade.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(gradeColors.first ?? .cyan)
            }
        }
    }

    // MARK: - Score Breakdown

    private var scoreBreakdown: some View {
        VStack(spacing: 16) {
            Text(String(localized: "점수 구성"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            scoreRow(
                icon: "moon.zzz.fill",
                label: String(localized: "코골이"),
                score: score.snoreScore,
                maxScore: 30,
                color: .cyan
            )
            scoreRow(
                icon: "hand.tap.fill",
                label: String(localized: "진동 반응"),
                score: score.responseScore,
                maxScore: 30,
                color: .green
            )
            scoreRow(
                icon: "clock.fill",
                label: String(localized: "수면 시간"),
                score: score.durationScore,
                maxScore: 25,
                color: .purple
            )
            scoreRow(
                icon: "repeat",
                label: String(localized: "취침 규칙성"),
                score: score.consistencyScore,
                maxScore: 15,
                color: .orange
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }

    private func scoreRow(icon: String, label: String, score: Int, maxScore: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(score)/\(maxScore)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / CGFloat(maxScore), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - 7-Day Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "최근 7일 점수"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)

            let data = last7DayScores

            if data.isEmpty {
                Text(String(localized: "데이터가 쌓이면 추이가 나타나요"))
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("", item.label),
                        y: .value("", item.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("", item.label),
                        y: .value("", item.score)
                    )
                    .foregroundStyle(.cyan)
                    .symbolSize(30)
                }
                .frame(height: 120)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel()
                            .foregroundStyle(.gray)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }

    // MARK: - Pattern Insights

    @ViewBuilder
    private var patternInsights: some View {
        let insights = PatternAnalyzer.analyze(sessions: Array(allSessions.prefix(30)), checkIns: Array(checkIns.prefix(30)))

        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "패턴 분석"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)

                ForEach(insights) { insight in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(correlationColor(insight.correlation).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: insight.icon)
                                .foregroundStyle(correlationColor(insight.correlation))
                                .font(.callout)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                            Text(insight.description)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6).opacity(0.3))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.4))
            )
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(String(localized: "개선 팁"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)
            }

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }

    // MARK: - Helpers

    private var gradeColors: [Color] {
        switch score.grade {
        case .excellent: return [.green, .cyan]
        case .great:     return [.cyan, .blue]
        case .good:      return [.blue, .purple]
        case .fair:      return [.orange, .yellow]
        case .poor:      return [.red, .orange]
        }
    }

    private func correlationColor(_ correlation: Double) -> Color {
        if correlation < -0.3 { return .green }   // negative = good (e.g. exercise reduces snoring)
        if correlation > 0.3 { return .red }       // positive = bad (e.g. alcohol increases snoring)
        return .orange
    }

    private var tips: [String] {
        var result: [String] = []

        if score.snoreScore <= 10 {
            result.append(String(localized: "코골이가 많았어요. 옆으로 자는 자세를 시도해보세요."))
        }
        if score.responseScore <= 15 {
            result.append(String(localized: "진동 반응률이 낮아요. 감도를 높여보세요."))
        }
        if score.durationScore <= 10 {
            result.append(String(localized: "수면 시간이 부족하거나 과해요. 7-9시간을 목표로 해보세요."))
        }
        if score.consistencyScore <= 5 {
            result.append(String(localized: "취침 시간이 불규칙해요. 매일 같은 시간에 잠들어 보세요."))
        }

        if result.isEmpty {
            result.append(String(localized: "현재 수면 습관을 잘 유지하고 계세요!"))
        }

        return result
    }

    private struct DailyScoreData {
        let date: Date
        let label: String
        let score: Int
    }

    private var last7DayScores: [DailyScoreData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"

        return (0..<7).compactMap { dayOffset -> DailyScoreData? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: today) else { return nil }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!

            let daySessions = allSessions.filter { $0.startTime >= date && $0.startTime < nextDate }
            guard let daySession = daySessions.first else { return nil }

            let dayScore = SleepScoreCalculator.calculate(
                session: daySession,
                recentSessions: allSessions
            )

            return DailyScoreData(
                date: date,
                label: formatter.string(from: date),
                score: dayScore.total
            )
        }
    }
}

#Preview {
    NavigationStack {
        SleepScoreView(
            score: SleepScore(
                total: 82,
                snoreScore: 25,
                responseScore: 22,
                durationScore: 25,
                consistencyScore: 10,
                grade: .great,
                comment: "좋은 수면이에요. 코골이도 잘 관리되고 있어요"
            ),
            session: SleepSession()
        )
    }
    .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
    .preferredColorScheme(.dark)
}

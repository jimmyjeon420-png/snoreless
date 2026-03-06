import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var modelContext

    // 최근 세션 가져오기
    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var allSessions: [SleepSession]

    @Query(sort: \DailyCheckIn.date, order: .reverse)
    private var allCheckIns: [DailyCheckIn]

    // AI 분석기
    private let analyzer = AIAnalyzer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 주간 통계 요약
                    weeklyStatsSection

                    // AI 분석 영역
                    aiAnalysisSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "주간 리포트"))
        }
    }

    // MARK: - 최근 7일 세션
    private var recentSessions: [SleepSession] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allSessions.filter { $0.startTime >= sevenDaysAgo }
    }

    // MARK: - 최근 7일 체크인
    private var recentCheckIns: [DailyCheckIn] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allCheckIns.filter { $0.date >= sevenDaysAgo }
    }

    // MARK: - 주간 통계
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "최근 7일 통계"))
                .font(.headline)

            if recentSessions.isEmpty {
                Text(String(localized: "이번 주 수면 기록이 없습니다"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                let totalSnores = recentSessions.reduce(0) { $0 + $1.totalSnoreCount }
                let avgSnores = totalSnores / max(recentSessions.count, 1)
                let totalDuration = recentSessions.reduce(0.0) { $0 + $1.totalSnoreDuration }
                let avgDurationMinutes = Int(totalDuration / Double(max(recentSessions.count, 1))) / 60

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    statCard(value: "\(recentSessions.count)", label: String(localized: "기록된 밤"))
                    statCard(value: String(localized: "\(avgSnores)회"), label: String(localized: "평균 코골이"))
                    statCard(value: String(localized: "\(avgDurationMinutes)분"), label: String(localized: "평균 코골이 시간"))
                }

                // 진동 효과
                let allEvents = recentSessions.flatMap(\.snoreEvents)
                let stoppedCount = allEvents.filter(\.stoppedAfterHaptic).count
                let totalEvents = allEvents.count
                let successRate = totalEvents > 0 ? Int(Double(stoppedCount) / Double(totalEvents) * 100) : 0

                HStack {
                    Text(String(localized: "진동 후 멈춤 비율"))
                    Spacer()
                    Text("\(successRate)% (\(stoppedCount)/\(totalEvents))")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - AI 분석
    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                Text(String(localized: "AI 분석"))
                    .font(.headline)
            }

            let analysis = analyzer.analyzeWeekly(sessions: recentSessions, checkIns: recentCheckIns)

            if let analysis = analysis {
                ForEach(analysis.insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(insight)
                            .font(.subheadline)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "2주 이상 데이터가 쌓이면 AI 분석을 제공합니다"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 통계 카드
    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WeeklyReportView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
}

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // 완료된 세션만 최신순으로
    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var completedSessions: [SleepSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 카드 1: 지난밤 요약
                    lastNightCard

                    // 카드 2: 오늘의 체크인
                    checkInCard

                    // 카드 3: 최근 7일 바 차트
                    weeklyChartCard

                    // 하단 안내
                    Text("워치에서 '수면 시작'을 눌러주세요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("코골이 방지")
        }
    }

    // MARK: - 지난밤 요약 카드
    @ViewBuilder
    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("지난밤 요약")
                .font(.headline)

            if let lastSession = completedSessions.first {
                HStack(spacing: 24) {
                    statItem(value: "\(lastSession.totalSnoreCount)", label: "코골이 횟수")
                    statItem(value: lastSession.snoreDurationText, label: "코골이 시간")
                    statItem(value: lastSession.durationText, label: "수면 시간")
                }
            } else {
                Text("아직 수면 기록이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 체크인 카드
    private var checkInCard: some View {
        NavigationLink {
            CheckInView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 체크인")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("잠들기 전 컨디션을 기록하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - 주간 차트 카드
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 7일 코골이 횟수")
                .font(.headline)

            if weeklyData.isEmpty {
                Text("데이터가 부족합니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                Chart(weeklyData, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.label),
                        y: .value("횟수", item.count)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 주간 데이터 계산
    private var weeklyData: [DailySnoreCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<7).compactMap { dayOffset -> DailySnoreCount? in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return nil
            }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = completedSessions
                .filter { $0.startTime >= date && $0.startTime < nextDate }
                .reduce(0) { $0 + $1.totalSnoreCount }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "E"

            return DailySnoreCount(date: date, label: formatter.string(from: date), count: count)
        }
        .reversed()
    }

    // MARK: - 통계 항목 헬퍼
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 주간 차트 데이터 모델
private struct DailySnoreCount {
    let date: Date
    let label: String
    let count: Int
}

#Preview {
    DashboardView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
}

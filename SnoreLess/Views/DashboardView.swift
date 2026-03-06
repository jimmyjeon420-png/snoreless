import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var watchConnector: WatchConnector

    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var completedSessions: [SleepSession]

    private let analyzer = AIAnalyzer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 모닝 브리핑 히어로
                    morningBriefingCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // AI 한마디
                    aiCommentCard
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 액션 버튼들
                    actionButtons
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 주간 추이 미니 차트
                    weeklyMiniChart
                        .padding(.horizontal)
                        .padding(.top, 20)

                    // 체크인 카드
                    checkInCard
                        .padding(.horizontal)
                        .padding(.top, 12)

                    // 주간 리포트 링크
                    weeklyReportLink
                        .padding(.horizontal)
                        .padding(.top, 12)

                    // 하단 워치 안내
                    watchStatusFooter
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.black)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("SnoreLess")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
    }

    // MARK: - 모닝 브리핑 히어로 카드
    @ViewBuilder
    private var morningBriefingCard: some View {
        if let lastSession = completedSessions.first {
            let stoppedCount = lastSession.snoreEvents.filter(\.stoppedAfterHaptic).count

            VStack(spacing: 20) {
                // 상단 라벨
                HStack {
                    Text("어젯밤 리포트")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(sessionDateText(lastSession))
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.7))
                }

                // 메인 숫자 - 코골이 횟수
                VStack(spacing: 6) {
                    if lastSession.totalSnoreCount == 0 {
                        Text("0회")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("코를 안 골았어요")
                            .font(.title3)
                            .foregroundStyle(.white)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(lastSession.totalSnoreCount)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(.cyan)
                            Text("회 골았어요")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                    }
                }

                // 세부 정보
                if lastSession.totalSnoreCount > 0 {
                    HStack(spacing: 24) {
                        // 진동 후 멈춤
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("진동 후 \(stoppedCount)회 멈춤")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }

                        // 총 코골이 시간
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("총 \(lastSession.snoreDurationText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // 성공률 프로그레스 바
                    if lastSession.totalSnoreCount > 0 {
                        let successRate = Double(stoppedCount) / Double(lastSession.totalSnoreCount)
                        VStack(spacing: 6) {
                            HStack {
                                Text("진동 효과")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text("\(Int(successRate * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.cyan)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan, .green],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * successRate, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6).opacity(0.6))
            )
        } else {
            // 첫 사용자 — 워치 연결 상태에 따라 안내 분기
            VStack(spacing: 16) {
                if watchConnector.isWatchReachable {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan.opacity(0.6))

                    Text(String(localized: "아직 수면 기록이 없어요"))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Text(String(localized: "워치에서 '수면 시작'을 눌러주세요.\n첫 리포트가 여기에 나타납니다."))
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    Image(systemName: "applewatch")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan.opacity(0.6))

                    Text(String(localized: "Apple Watch에서 수면을 시작해보세요"))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Text(String(localized: "워치에서 SnoreLess 앱을 열고 '잠들기'를 눌러주세요"))
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6).opacity(0.6))
            )
        }
    }

    // MARK: - AI 한마디
    @ViewBuilder
    private var aiCommentCard: some View {
        let comment = generateAIComment()
        if !comment.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.cyan)
                    .font(.body)
                    .padding(.top, 2)

                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.cyan.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - 액션 버튼들
    @ViewBuilder
    private var actionButtons: some View {
        if let lastSession = completedSessions.first {
            HStack(spacing: 12) {
                // 공유 버튼
                NavigationLink {
                    PartnerShareView(session: lastSession)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("공유하기")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                }

                // 녹음 듣기 버튼
                NavigationLink {
                    SnorePlaybackView()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.caption)
                        Text("녹음 듣기")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 주간 미니 차트
    private var weeklyMiniChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 7일")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)

            if weeklyData.isEmpty || weeklyData.allSatisfy({ $0.count == 0 }) {
                Text("데이터가 쌓이면 차트가 나타나요")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                Chart(weeklyData, id: \.date) { item in
                    BarMark(
                        x: .value("", item.label),
                        y: .value("", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .frame(height: 100)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
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

    // MARK: - 체크인 카드
    private var checkInCard: some View {
        NavigationLink {
            CheckInView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundStyle(.orange)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘의 체크인")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Text("잠들기 전 컨디션을 기록하세요")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6).opacity(0.4))
            )
        }
    }

    // MARK: - 주간 리포트 링크
    private var weeklyReportLink: some View {
        NavigationLink {
            WeeklyReportView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.purple)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("주간 리포트")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Text("자세한 분석과 AI 인사이트")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6).opacity(0.4))
            )
        }
    }

    // MARK: - 워치 상태 푸터
    private var watchStatusFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: watchConnector.isWatchReachable
                  ? "applewatch.radiowaves.left.and.right"
                  : "applewatch.slash")
                .font(.caption2)
                .foregroundStyle(watchConnector.isWatchReachable ? .green : .gray)

            Text(watchConnector.isWatchReachable
                 ? "워치 연결됨"
                 : "워치에서 '수면 시작'을 눌러주세요")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.6))
        }
    }

    // MARK: - 날짜 텍스트
    private func sessionDateText(_ session: SleepSession) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d (E)"
        return f.string(from: session.startTime)
    }

    // MARK: - AI 코멘트 생성
    private func generateAIComment() -> String {
        guard completedSessions.count >= 2 else {
            if completedSessions.count == 1 {
                return "첫 번째 수면 기록이 완성됐어요. 내일 아침이 기대되네요!"
            }
            return ""
        }

        let latest = completedSessions[0]
        let previous = completedSessions[1]

        // 이번 주 vs 지난 주 비교
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now

        let thisWeek = completedSessions.filter { $0.startTime >= sevenDaysAgo }
        let lastWeek = completedSessions.filter { $0.startTime >= fourteenDaysAgo && $0.startTime < sevenDaysAgo }

        if !thisWeek.isEmpty && !lastWeek.isEmpty {
            let thisWeekAvg = Double(thisWeek.reduce(0) { $0 + $1.totalSnoreCount }) / Double(thisWeek.count)
            let lastWeekAvg = Double(lastWeek.reduce(0) { $0 + $1.totalSnoreCount }) / Double(lastWeek.count)

            if lastWeekAvg > 0 {
                let changePercent = Int(((lastWeekAvg - thisWeekAvg) / lastWeekAvg) * 100)
                if changePercent > 0 {
                    return "지난주보다 코골이가 \(changePercent)% 줄었어요. 좋은 변화예요!"
                } else if changePercent < -10 {
                    return "지난주보다 코골이가 조금 늘었어요. 오늘 체크인을 기록해보세요."
                }
            }
        }

        // 어젯밤 vs 그 전날 비교
        if latest.totalSnoreCount < previous.totalSnoreCount {
            return "어젯밤은 전날보다 코골이가 줄었어요. 잘하고 있어요!"
        } else if latest.totalSnoreCount == 0 {
            return "어젯밤은 코를 안 골았어요. 편안한 밤이었네요."
        } else {
            let stoppedRate = latest.totalSnoreCount > 0
                ? Double(latest.snoreEvents.filter(\.stoppedAfterHaptic).count) / Double(latest.totalSnoreCount) * 100
                : 0
            if stoppedRate >= 60 {
                return "진동 효과가 잘 작동하고 있어요. \(Int(stoppedRate))%나 멈췄어요!"
            }
        }

        return "꾸준히 기록하면 패턴을 찾을 수 있어요."
    }

    // MARK: - 주간 데이터
    private var weeklyData: [DailySnoreCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<7).compactMap { dayOffset -> DailySnoreCount? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: today) else { return nil }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = completedSessions
                .filter { $0.startTime >= date && $0.startTime < nextDate }
                .reduce(0) { $0 + $1.totalSnoreCount }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "E"

            return DailySnoreCount(date: date, label: formatter.string(from: date), count: count)
        }
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
        .environmentObject(WatchConnector())
        .preferredColorScheme(.dark)
}

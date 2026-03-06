import SwiftUI
import SwiftData

struct HistoryView: View {
    // 완료된 세션만 최신순
    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var sessions: [SleepSession]

    // 날짜 포맷터
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없습니다",
                        systemImage: "moon.zzz",
                        description: Text("워치에서 수면을 기록하면 여기에 표시됩니다")
                    )
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            SleepReportView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                    }
                }
            }
            .navigationTitle("수면 기록")
        }
    }

    // MARK: - 세션 행
    private func sessionRow(_ session: SleepSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.startTime))
                    .font(.headline)
                Text("수면 시간: \(session.durationText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.totalSnoreCount)회")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                Text("코골이")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
}

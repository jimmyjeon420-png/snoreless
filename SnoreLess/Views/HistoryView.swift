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
                        String(localized: "아직 기록이 없어요"),
                        systemImage: "moon.zzz",
                        description: Text(String(localized: "워치에서 수면을 기록하면\n여기에 나타납니다"))
                    )
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            SleepReportView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        .listRowBackground(Color(.systemGray6).opacity(0.4))
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(String(localized: "수면 기록"))
        }
    }

    // MARK: - 세션 행
    private func sessionRow(_ session: SleepSession) -> some View {
        HStack(spacing: 14) {
            // 날짜 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(session.totalSnoreCount == 0
                          ? Color.green.opacity(0.15)
                          : Color.cyan.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: session.totalSnoreCount == 0 ? "checkmark.circle.fill" : "moon.fill")
                    .foregroundStyle(session.totalSnoreCount == 0 ? .green : .cyan)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.startTime))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(session.durationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if session.totalSnoreCount > 0 {
                        let stopped = session.snoreEvents.filter(\.stoppedAfterHaptic).count
                        Text(String(localized: "진동 \(stopped)/\(session.totalSnoreCount) 멈춤"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if session.totalSnoreCount == 0 {
                    Text(String(localized: "조용한 밤"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                } else {
                    Text("\(session.totalSnoreCount)회")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)
                    Text(String(localized: "골았어요"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
        .preferredColorScheme(.dark)
}

import SwiftUI
import SwiftData

struct PartnerShareView: View {
    let session: SleepSession

    @AppStorage("partnerName") private var partnerName = ""
    @State private var shareImage: UIImage?
    @State private var isGenerating = false
    @State private var showShareSheet = false

    @Query(
        filter: #Predicate<SleepSession> { !$0.isActive },
        sort: \SleepSession.startTime,
        order: .reverse
    )
    private var recentSessions: [SleepSession]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 미리보기 카드
                shareCardPreview
                    .padding(.horizontal)

                // 공유 버튼
                Button {
                    generateAndShare()
                } label: {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .tint(.black)
                        }
                        Image(systemName: "square.and.arrow.up")
                        Text(partnerName.isEmpty ? "공유하기" : "\(partnerName)에게 공유하기")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isGenerating)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .navigationTitle("공유 카드")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - 공유 카드 미리보기
    private var shareCardPreview: some View {
        VStack(spacing: 20) {
            // 상단: 날짜 + 앱 이름
            HStack {
                Text(dateFormatter.string(from: session.startTime))
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
                Text("SnoreLess")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.cyan)
            }

            // 메인 메시지
            VStack(spacing: 8) {
                let stoppedCount = session.snoreEvents.filter(\.stoppedAfterHaptic).count

                if session.totalSnoreCount == 0 {
                    Text("어젯밤은 코를 안 골았어요")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Text("어젯밤 코골이 \(session.totalSnoreCount)회")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if stoppedCount > 0 {
                        Text("진동으로 \(stoppedCount)회 멈췄어요")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
            }

            // 주간 미니 그래프
            if !weeklySnoreCounts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 7일")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(weeklySnoreCounts, id: \.date) { item in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        item.isToday
                                            ? Color.cyan
                                            : Color.gray.opacity(0.4)
                                    )
                                    .frame(
                                        width: 28,
                                        height: max(4, CGFloat(item.count) / CGFloat(max(maxCount, 1)) * 60)
                                    )

                                Text(item.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // 하단 메시지
            Text(encouragementMessage)
                .font(.callout)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.95))
        )
    }

    // MARK: - 주간 데이터
    private struct WeeklyItem {
        let date: Date
        let label: String
        let count: Int
        let isToday: Bool
    }

    private var weeklySnoreCounts: [WeeklyItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<7).compactMap { offset -> WeeklyItem? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = recentSessions
                .filter { $0.startTime >= date && $0.startTime < nextDate }
                .reduce(0) { $0 + $1.totalSnoreCount }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "E"

            return WeeklyItem(
                date: date,
                label: formatter.string(from: date),
                count: count,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    private var maxCount: Int {
        weeklySnoreCounts.map(\.count).max() ?? 1
    }

    // MARK: - 격려 메시지
    private var encouragementMessage: String {
        let thisWeekTotal = weeklySnoreCounts.reduce(0) { $0 + $1.count }

        if session.totalSnoreCount == 0 {
            return "편안한 밤이었어요. 계속 이대로!"
        } else if thisWeekTotal <= 10 {
            return "점점 나아지고 있어요. 개선 중!"
        } else {
            return "꾸준히 관리하면 좋아질 거예요"
        }
    }

    // MARK: - 이미지 생성 및 공유
    @MainActor
    private func generateAndShare() {
        isGenerating = true

        let renderer = ImageRenderer(content: shareCardForExport)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }

        isGenerating = false
    }

    // MARK: - 내보내기용 카드 (배경 포함)
    @MainActor
    private var shareCardForExport: some View {
        shareCardPreview
            .padding(20)
            .background(Color.black)
            .frame(width: 380)
    }
}

// MARK: - UIActivityViewController 래퍼
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PartnerShareView(session: SleepSession(startTime: .now))
    }
    .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
}

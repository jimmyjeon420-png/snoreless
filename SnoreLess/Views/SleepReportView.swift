import SwiftUI

struct SleepReportView: View {
    let session: SleepSession

    // 시간 포맷터
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (E)"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 수면 시간 섹션
                sleepTimeSection

                // 코골이 요약 섹션
                snoreSummarySection

                // 코골이 이벤트 타임라인
                snoreTimelineSection

                // 체크인 정보
                checkInSection
            }
            .padding()
        }
        .navigationTitle(dateFormatter.string(from: session.startTime))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 수면 시간
    private var sleepTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수면 시간")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("시작")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timeFormatter.string(from: session.startTime))
                        .font(.title3)
                        .fontWeight(.medium)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("종료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.endTime != nil ? timeFormatter.string(from: session.endTime!) : "-")
                        .font(.title3)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("총 시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.durationText)
                        .font(.title3)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 코골이 요약
    private var snoreSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("코골이 요약")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(session.totalSnoreCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("횟수")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(session.snoreDurationText)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("총 시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    let stopped = session.snoreEvents.filter(\.stoppedAfterHaptic).count
                    Text("\(stopped)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("진동 후 멈춤")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 코골이 이벤트 타임라인
    private var snoreTimelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("코골이 타임라인")
                .font(.headline)

            if session.snoreEvents.isEmpty {
                Text("코골이 이벤트가 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                let sortedEvents = session.snoreEvents.sorted { $0.timestamp < $1.timestamp }
                ForEach(Array(sortedEvents.enumerated()), id: \.element.id) { index, event in
                    HStack(spacing: 12) {
                        // 시각
                        Text(timeFormatter.string(from: event.timestamp))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50, alignment: .leading)

                        // 강도 표시
                        intensityBadge(intensity: event.intensity)

                        // 햅틱 레벨
                        Text("진동 \(event.hapticLevel)단계")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())

                        Spacer()

                        // 멈춤 여부
                        if event.stoppedAfterHaptic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)

                    if index < sortedEvents.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 체크인 정보
    @ViewBuilder
    private var checkInSection: some View {
        if let checkIn = session.checkIn {
            VStack(alignment: .leading, spacing: 8) {
                Text("체크인 정보")
                    .font(.headline)

                VStack(spacing: 8) {
                    checkInRow(icon: "cup.and.saucer.fill", label: "오후 커피", value: checkIn.coffeeAfternoon ? "마심" : "안 마심")
                    checkInRow(icon: "figure.run", label: "운동", value: checkIn.exercised ? "했음" : "안 했음")
                    checkInRow(icon: "wineglass.fill", label: "음주", value: checkIn.alcohol ? "마심" : "안 마심")
                    checkInRow(icon: "brain.head.profile", label: "스트레스", value: "\(checkIn.stressLevel) / 5")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 헬퍼
    private func intensityBadge(intensity: Double) -> some View {
        let label: String
        let color: Color

        if intensity < 50 {
            label = "약"
            color = .green
        } else if intensity < 70 {
            label = "중"
            color = .orange
        } else {
            label = "강"
            color = .red
        }

        return Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    private func checkInRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SleepReportView(session: SleepSession(startTime: .now))
    }
}

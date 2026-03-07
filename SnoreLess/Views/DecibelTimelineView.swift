import SwiftUI
import Charts

/// 밤새 데시벨 변화 타임라인 + 소리 이벤트 마커
struct DecibelTimelineView: View {
    let session: SleepSession

    private var readings: [DecibelReading] {
        session.decibelReadings.sorted { $0.timestamp < $1.timestamp }
    }

    private var events: [SnoreEvent] {
        session.snoreEvents.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 메인 타임라인 차트
                timelineChart
                    .padding(.horizontal)

                // 소리 종류별 요약
                soundTypeSummary
                    .padding(.horizontal)

                // 이벤트 목록
                eventList
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .navigationTitle("소리 타임라인")
    }

    // MARK: - 타임라인 차트

    @ViewBuilder
    private var timelineChart: some View {
        if readings.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray.opacity(0.5))
                Text("데시벨 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("다음 수면부터 소리 변화가 기록됩니다")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("밤새 소리 크기")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)

                Chart {
                    // dB 영역 차트
                    ForEach(readings, id: \.id) { reading in
                        AreaMark(
                            x: .value("시간", reading.timestamp),
                            y: .value("dB", normalizedDb(reading.db))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .cyan.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("시간", reading.timestamp),
                            y: .value("dB", normalizedDb(reading.db))
                        )
                        .foregroundStyle(.cyan.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }

                    // 이벤트 마커
                    ForEach(events, id: \.id) { event in
                        PointMark(
                            x: .value("시간", event.timestamp),
                            y: .value("dB", normalizedDb(event.intensity))
                        )
                        .foregroundStyle(eventColor(for: event.soundEventType))
                        .symbolSize(60)
                        .annotation(position: .top, spacing: 4) {
                            Image(systemName: eventIcon(for: event.soundEventType))
                                .font(.system(size: 8))
                                .foregroundStyle(eventColor(for: event.soundEventType))
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                            .foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                            .foregroundStyle(.gray)
                    }
                }

                // 범례
                HStack(spacing: 16) {
                    legendItem(icon: "moon.zzz.fill", label: "코골이", color: .orange)
                    legendItem(icon: "lungs.fill", label: "기침", color: .yellow)
                    legendItem(icon: "text.bubble.fill", label: "잠꼬대", color: .purple)
                }
                .font(.caption2)
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.4))
            )
        }
    }

    // MARK: - 소리 종류별 요약

    private var soundTypeSummary: some View {
        let snoreCount = events.filter { $0.soundEventType == .snoring }.count
        let coughCount = events.filter { $0.soundEventType == .cough }.count
        let talkingCount = events.filter { $0.soundEventType == .talking }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("소리 분석")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)

            HStack(spacing: 0) {
                soundTypeCard(icon: "moon.zzz.fill", label: "코골이", count: snoreCount, color: .orange)
                soundTypeCard(icon: "lungs.fill", label: "기침", count: coughCount, color: .yellow)
                soundTypeCard(icon: "text.bubble.fill", label: "잠꼬대", count: talkingCount, color: .purple)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }

    private func soundTypeCard(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(count > 0 ? color : .gray.opacity(0.4))

            Text("\(count)회")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? .white : .gray.opacity(0.5))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 이벤트 목록

    @ViewBuilder
    private var eventList: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("감지된 소리")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)

                ForEach(events, id: \.id) { event in
                    HStack(spacing: 12) {
                        Image(systemName: eventIcon(for: event.soundEventType))
                            .font(.body)
                            .foregroundStyle(eventColor(for: event.soundEventType))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(eventLabel(for: event.soundEventType))
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text(timeText(event.timestamp))
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }

                        Spacer()

                        if event.stoppedAfterHaptic {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6).opacity(0.4))
            )
        }
    }

    // MARK: - Helpers

    /// dB를 0~100 범위로 정규화 (-80dB=0, -20dB=100)
    private func normalizedDb(_ db: Double) -> Double {
        let clamped = max(min(db, -20), -80)
        return (clamped + 80) / 60 * 100
    }

    private func eventIcon(for type: SoundEventType) -> String {
        switch type {
        case .snoring: return "moon.zzz.fill"
        case .cough:   return "lungs.fill"
        case .talking: return "text.bubble.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func eventColor(for type: SoundEventType) -> Color {
        switch type {
        case .snoring: return .orange
        case .cough:   return .yellow
        case .talking: return .purple
        case .unknown: return .gray
        }
    }

    private func eventLabel(for type: SoundEventType) -> String {
        switch type {
        case .snoring: return "코골이"
        case .cough:   return "기침"
        case .talking: return "잠꼬대"
        case .unknown: return "알 수 없는 소리"
        }
    }

    private func legendItem(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.gray)
        }
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}

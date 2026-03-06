import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SnoreComplicationEntry: TimelineEntry {
    let date: Date
    let snoreCount: Int
    let sleepScore: Int
}

// MARK: - Timeline Provider

struct SnoreComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnoreComplicationEntry {
        SnoreComplicationEntry(date: Date(), snoreCount: 0, sleepScore: 85)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnoreComplicationEntry) -> Void) {
        let entry = SnoreComplicationEntry(date: Date(), snoreCount: 3, sleepScore: 78)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnoreComplicationEntry>) -> Void) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "lastNightSnoreCount")
        let score = defaults.integer(forKey: "lastNightSleepScore")

        let entry = SnoreComplicationEntry(
            date: Date(),
            snoreCount: count,
            sleepScore: score > 0 ? score : 85
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Circular Small View

struct CircularSmallView: View {
    let entry: SnoreComplicationEntry

    var body: some View {
        Gauge(value: Double(entry.sleepScore), in: 0...100) {
            Text("\(entry.sleepScore)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(scoreGradient)
    }

    private var scoreColor: Color {
        if entry.sleepScore >= 80 { return .green }
        if entry.sleepScore >= 60 { return .orange }
        return .red
    }

    private var scoreGradient: Gradient {
        Gradient(colors: [.red, .orange, .green])
    }
}

// MARK: - Graphic Corner View

struct GraphicCornerView: View {
    let entry: SnoreComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(entry.sleepScore)점")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
            Text("코골이 \(entry.snoreCount)회")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .widgetLabel {
            Gauge(value: Double(entry.sleepScore), in: 0...100) {
                Text("수면")
            }
            .gaugeStyle(.accessoryLinear)
            .tint(scoreGradient)
        }
    }

    private var scoreColor: Color {
        if entry.sleepScore >= 80 { return .green }
        if entry.sleepScore >= 60 { return .orange }
        return .red
    }

    private var scoreGradient: Gradient {
        Gradient(colors: [.red, .orange, .green])
    }
}

// MARK: - Graphic Rectangular View

struct GraphicRectangularView: View {
    let entry: SnoreComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("수면 점수")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(entry.sleepScore)점")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }

            Gauge(value: Double(entry.sleepScore), in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(scoreGradient)

            HStack(spacing: 4) {
                Circle()
                    .fill(entry.snoreCount == 0 ? .green : .orange)
                    .frame(width: 5, height: 5)
                Text(entry.snoreCount == 0 ? "코골이 없음" : "코골이 \(entry.snoreCount)회")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scoreColor: Color {
        if entry.sleepScore >= 80 { return .green }
        if entry.sleepScore >= 60 { return .orange }
        return .red
    }

    private var scoreGradient: Gradient {
        Gradient(colors: [.red, .orange, .green])
    }
}

// MARK: - Complication Widget

struct SnoreComplicationWidget: Widget {
    let kind: String = "SnoreComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnoreComplicationProvider()) { entry in
            SnoreComplicationEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("수면 점수")
        .description("어젯밤 수면 점수와 코골이 횟수를 보여줍니다.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

// MARK: - Entry View (routes to family-specific views)

struct SnoreComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SnoreComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularSmallView(entry: entry)
        case .accessoryCorner:
            GraphicCornerView(entry: entry)
        case .accessoryRectangular:
            GraphicRectangularView(entry: entry)
        default:
            CircularSmallView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    SnoreComplicationWidget()
} timeline: {
    SnoreComplicationEntry(date: Date(), snoreCount: 0, sleepScore: 92)
    SnoreComplicationEntry(date: Date(), snoreCount: 5, sleepScore: 65)
}

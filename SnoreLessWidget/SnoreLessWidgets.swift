import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct SleepWidgetEntry: TimelineEntry {
    let date: Date
    let snoreCount: Int
    let sleepScore: Int
    let grade: String
    let streakDays: Int
    let weeklySnores: [Int] // last 7 days
}

// MARK: - Shared UserDefaults Keys

enum WidgetDataKey {
    static let suiteName = "group.com.nicenoodle.snoreless"
    static let lastNightSnoreCount = "lastNightSnoreCount"
    static let lastNightSleepScore = "lastNightSleepScore"
    static let lastNightGrade = "lastNightGrade"
    static let streakDays = "streakDays"
    static let weeklySnores = "weeklySnores"
    static let lastSessionDate = "lastSessionDate"
}

// MARK: - Timeline Provider

struct SleepWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepWidgetEntry {
        SleepWidgetEntry(
            date: .now,
            snoreCount: 3,
            sleepScore: 82,
            grade: "A",
            streakDays: 5,
            weeklySnores: [4, 2, 5, 3, 1, 6, 3]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> SleepWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetDataKey.suiteName)
        let snoreCount = defaults?.integer(forKey: WidgetDataKey.lastNightSnoreCount) ?? 0
        let sleepScore = defaults?.integer(forKey: WidgetDataKey.lastNightSleepScore) ?? 0
        let grade = defaults?.string(forKey: WidgetDataKey.lastNightGrade) ?? "-"
        let streakDays = defaults?.integer(forKey: WidgetDataKey.streakDays) ?? 0
        let weeklySnores = defaults?.array(forKey: WidgetDataKey.weeklySnores) as? [Int] ?? Array(repeating: 0, count: 7)

        return SleepWidgetEntry(
            date: .now,
            snoreCount: snoreCount,
            sleepScore: sleepScore,
            grade: grade,
            streakDays: streakDays,
            weeklySnores: weeklySnores
        )
    }
}

// MARK: - Grade Color

private func gradeColor(for grade: String) -> Color {
    switch grade {
    case "A+": return .green
    case "A":  return .blue
    case "B":  return .cyan
    case "C":  return .orange
    case "D":  return .red
    default:   return .gray
    }
}

// MARK: - Sleep Score Widget (Small)

struct SleepScoreSmallView: View {
    let entry: SleepWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(String(localized: "어젯밤"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(entry.sleepScore)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(gradeColor(for: entry.grade))

            Text(entry.grade)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(gradeColor(for: entry.grade).opacity(0.2))
                .clipShape(Capsule())
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Mini Bar Chart

struct MiniBarChart: View {
    let data: [Int]
    let maxValue: Int

    init(data: [Int]) {
        self.data = data
        self.maxValue = max(data.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: value))
                    .frame(height: max(CGFloat(value) / CGFloat(maxValue) * 30, 3))
            }
        }
        .frame(height: 30)
    }

    private func barColor(for value: Int) -> Color {
        switch value {
        case 0...2:  return .green
        case 3...5:  return .orange
        default:     return .red
        }
    }
}

// MARK: - Sleep Score Widget (Medium)

struct SleepScoreMediumView: View {
    let entry: SleepWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Score
            VStack(spacing: 4) {
                Text(String(localized: "어젯밤"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(entry.sleepScore)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor(for: entry.grade))

                Text(entry.grade)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(gradeColor(for: entry.grade).opacity(0.2))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
                .padding(.vertical, 8)

            // Right: Stats + Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "nose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "코골이 \(entry.snoreCount)회"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "7일 추이"))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    MiniBarChart(data: entry.weeklySnores)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Streak Widget (Small)

struct StreakSmallView: View {
    let entry: SleepWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(entry.streakDays > 0 ? .orange : .gray)

            Text("\(entry.streakDays)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(entry.streakDays > 0 ? .primary : .secondary)

            Text(String(localized: "일 연속 기록"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Definitions

struct SleepScoreEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SleepWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            SleepScoreMediumView(entry: entry)
        default:
            SleepScoreSmallView(entry: entry)
        }
    }
}

struct SleepScoreWidget: Widget {
    let kind: String = "SleepScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepWidgetProvider()) { entry in
            SleepScoreEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "수면 점수"))
        .description(String(localized: "어젯밤 수면 점수와 코골이 현황"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepWidgetProvider()) { entry in
            StreakSmallView(entry: entry)
        }
        .configurationDisplayName(String(localized: "연속 기록"))
        .description(String(localized: "수면 기록 연속 일수"))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

@main
struct SnoreLessWidgetBundle: WidgetBundle {
    var body: some Widget {
        SleepScoreWidget()
        StreakWidget()
    }
}

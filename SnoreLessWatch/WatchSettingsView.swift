import SwiftUI

/// Watch 설정 화면
struct WatchSettingsView: View {
    @ObservedObject var alarmManager: SmartAlarmManager
    @Binding var hapticIntensity: HapticIntensity

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - 스마트 알람
                VStack(alignment: .leading, spacing: 10) {
                    Label("스마트 알람", systemImage: "alarm.fill")
                        .font(.headline)
                        .foregroundStyle(.cyan)

                    Toggle(isOn: $alarmManager.isAlarmEnabled) {
                        Text("알람 사용")
                            .font(.subheadline)
                    }
                    .tint(.cyan)

                    if alarmManager.isAlarmEnabled {
                        HStack {
                            Picker("시", selection: $alarmManager.alarmHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)시").tag(hour)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Picker("분", selection: $alarmManager.alarmMinute) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { min in
                                    Text(String(format: "%02d분", min)).tag(min)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 60)

                        Text("알람 30분 전부터 얕은 수면을 감지하여 가장 좋은 타이밍에 깨워드려요")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                Divider()
                    .padding(.vertical, 4)

                // MARK: - 진동 강도
                VStack(alignment: .leading, spacing: 10) {
                    Label("진동 강도", systemImage: "waveform.path")
                        .font(.headline)
                        .foregroundStyle(.cyan)

                    Picker("강도", selection: $hapticIntensity) {
                        Text("약").tag(HapticIntensity.light)
                        Text("중").tag(HapticIntensity.medium)
                        Text("강").tag(HapticIntensity.strong)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)

                    Text(hapticIntensityDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hapticIntensityDescription: String {
        switch hapticIntensity {
        case .light:
            return "부드러운 진동. 예민한 분에게 추천"
        case .medium:
            return "기본 강도. 대부분에게 적합"
        case .strong:
            return "강한 진동. 깊이 주무시는 분에게 추천"
        }
    }
}

// MARK: - 진동 강도 enum
enum HapticIntensity: Int, CaseIterable, Identifiable {
    case light = 0
    case medium = 1
    case strong = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .light: return "약"
        case .medium: return "중"
        case .strong: return "강"
        }
    }
}

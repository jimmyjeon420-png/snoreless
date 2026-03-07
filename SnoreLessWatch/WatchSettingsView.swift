import SwiftUI
import WatchKit

/// Watch 설정 화면
struct WatchSettingsView: View {
    @ObservedObject var alarmManager: SmartAlarmManager
    @Binding var hapticIntensity: HapticIntensity

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - 스마트 알람
                VStack(alignment: .leading, spacing: 10) {
                    Label(String(localized: "스마트 알람"), systemImage: "alarm.fill")
                        .font(.headline)
                        .foregroundStyle(.cyan)

                    Toggle(isOn: $alarmManager.isAlarmEnabled) {
                        Text(String(localized: "알람 사용"))
                            .font(.subheadline)
                    }
                    .tint(.cyan)

                    if alarmManager.isAlarmEnabled {
                        HStack {
                            Picker(String(localized: "시"), selection: $alarmManager.alarmHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(String(localized: "\(hour)시")).tag(hour)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Picker(String(localized: "분"), selection: $alarmManager.alarmMinute) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { min in
                                    Text(String(localized: "\(String(format: "%02d", min))분")).tag(min)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 60)

                        Text(String(localized: "알람 30분 전부터 얕은 수면을 감지하여 가장 좋은 타이밍에 깨워드려요"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                Divider()
                    .padding(.vertical, 4)

                // MARK: - 진동 강도
                VStack(alignment: .leading, spacing: 10) {
                    Label(String(localized: "진동 강도"), systemImage: "waveform.path")
                        .font(.headline)
                        .foregroundStyle(.cyan)

                    Picker(String(localized: "강도"), selection: $hapticIntensity) {
                        Text(String(localized: "약")).tag(HapticIntensity.light)
                        Text(String(localized: "중")).tag(HapticIntensity.medium)
                        Text(String(localized: "강")).tag(HapticIntensity.strong)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50)

                    Text(hapticIntensityDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button(String(localized: "진동 테스트")) {
                        let device = WKInterfaceDevice.current()
                        device.play(.click)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            device.play(.click)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            device.play(.click)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle(String(localized: "설정"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hapticIntensityDescription: String {
        switch hapticIntensity {
        case .light:
            return String(localized: "부드러운 진동. 예민한 분에게 추천")
        case .medium:
            return String(localized: "기본 강도. 대부분에게 적합")
        case .strong:
            return String(localized: "강한 진동. 깊이 주무시는 분에게 추천")
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
        case .light: return String(localized: "약")
        case .medium: return String(localized: "중")
        case .strong: return String(localized: "강")
        }
    }
}

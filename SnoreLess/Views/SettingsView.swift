import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var watchConnector: WatchConnector

    // 진동 설정
    @AppStorage("iPhoneEscalationEnabled") private var iPhoneEscalation = false
    @AppStorage("hapticSensitivity") private var sensitivity: Double = 1.0

    // 타이밍 설정
    @AppStorage("escalationDelay1") private var delay1: Int = 5
    @AppStorage("escalationDelay2") private var delay2: Int = 10
    @AppStorage("cooldownDuration") private var cooldown: Int = 30

    var body: some View {
        NavigationStack {
            Form {
                // 진동 설정
                Section {
                    Toggle("아이폰 에스컬레이션", isOn: $iPhoneEscalation)
                    Text("워치 진동으로 코골이가 멈추지 않으면 아이폰도 진동합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("감지 감도")
                            Spacer()
                            Text(String(format: "%.1f", sensitivity))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.5...2.0, step: 0.1)
                        Text("높을수록 작은 소리에도 반응합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("진동 설정")
                }

                // 타이밍 설정
                Section {
                    Stepper("1차에서 2차 간격: \(delay1)초", value: $delay1, in: 3...10)
                    Stepper("2차에서 3차 간격: \(delay2)초", value: $delay2, in: 5...20)
                    Stepper("쿨다운: \(cooldown)초", value: $cooldown, in: 15...60, step: 5)
                } header: {
                    Text("타이밍")
                }

                // 워치 연결 상태
                Section {
                    HStack {
                        Text("워치 연결")
                        Spacer()
                        if watchConnector.isWatchReachable {
                            Label("연결됨", systemImage: "applewatch.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                        } else {
                            Label("연결 안 됨", systemImage: "applewatch.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("상태")
                }

                // 정보
                Section {
                    HStack {
                        Text("앱 버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("정보")
                }
            }
            .navigationTitle("설정")
            .onChange(of: iPhoneEscalation) { _, _ in syncSettingsToWatch() }
            .onChange(of: sensitivity) { _, _ in syncSettingsToWatch() }
            .onChange(of: delay1) { _, _ in syncSettingsToWatch() }
            .onChange(of: delay2) { _, _ in syncSettingsToWatch() }
            .onChange(of: cooldown) { _, _ in syncSettingsToWatch() }
        }
    }

    // MARK: - 워치에 설정 동기화
    private func syncSettingsToWatch() {
        let settings = AppSettings(
            iPhoneEscalationEnabled: iPhoneEscalation,
            hapticSensitivity: sensitivity,
            calibrationDuration: 300,
            escalationDelay1: TimeInterval(delay1),
            escalationDelay2: TimeInterval(delay2),
            cooldownDuration: TimeInterval(cooldown)
        )
        watchConnector.sendSettings(settings)
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchConnector())
}

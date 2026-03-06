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

    // 스마트 알람
    @AppStorage("smartAlarmEnabled") private var smartAlarmEnabled = false
    @AppStorage("smartAlarmHour") private var smartAlarmHour: Int = 7
    @AppStorage("smartAlarmMinute") private var smartAlarmMinute: Int = 0

    // 취침 리마인더
    @AppStorage("bedtimeReminderEnabled") private var bedtimeReminderEnabled = false
    @AppStorage("bedtimeReminderHour") private var bedtimeReminderHour: Int = 23
    @AppStorage("bedtimeReminderMinute") private var bedtimeReminderMinute: Int = 0

    // 파트너 & 녹음
    @AppStorage("partnerName") private var partnerName = ""
    @AppStorage("saveSnoreRecordings") private var saveRecordings = true

    @State private var smartAlarmDate: Date = .now
    @State private var bedtimeDate: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                // 파트너 설정
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .frame(width: 24)
                        TextField("이름 입력", text: $partnerName)
                    }
                } header: {
                    Text("파트너")
                } footer: {
                    Text("공유 카드에 이름이 표시됩니다")
                }

                // 스마트 알람
                Section {
                    Toggle(isOn: $smartAlarmEnabled) {
                        HStack {
                            Image(systemName: "alarm.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text("스마트 알람")
                        }
                    }

                    if smartAlarmEnabled {
                        DatePicker(
                            "알람 시각",
                            selection: $smartAlarmDate,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: smartAlarmDate) { _, newValue in
                            let calendar = Calendar.current
                            smartAlarmHour = calendar.component(.hour, from: newValue)
                            smartAlarmMinute = calendar.component(.minute, from: newValue)
                            syncSmartAlarmToWatch()
                        }
                    }
                } header: {
                    Text("알람")
                } footer: {
                    Text("얕은 수면 구간에서 워치가 깨워줍니다")
                }

                // 취침 리마인더
                Section {
                    Toggle(isOn: $bedtimeReminderEnabled) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(.purple)
                                .frame(width: 24)
                            Text("취침 리마인더")
                        }
                    }

                    if bedtimeReminderEnabled {
                        DatePicker(
                            "리마인더 시각",
                            selection: $bedtimeDate,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: bedtimeDate) { _, newValue in
                            let calendar = Calendar.current
                            bedtimeReminderHour = calendar.component(.hour, from: newValue)
                            bedtimeReminderMinute = calendar.component(.minute, from: newValue)
                            scheduleBedtimeReminder()
                        }
                    }
                } footer: {
                    if bedtimeReminderEnabled {
                        Text("매일 알림을 보내드립니다")
                    }
                }

                // 진동 설정
                Section {
                    Toggle(isOn: $iPhoneEscalation) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            Text("아이폰 추가 진동")
                        }
                    }
                    Text("워치 진동으로 코골이가 멈추지 않으면 아이폰도 진동합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text("감지 감도")
                            Spacer()
                            Text(sensitivityLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.5...2.0, step: 0.1)
                            .tint(.cyan)
                        Text("높을수록 작은 소리에도 반응합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("진동")
                }

                // 타이밍
                Section {
                    Stepper(value: $delay1, in: 3...10) {
                        HStack {
                            Text("1차 후 대기")
                            Spacer()
                            Text("\(delay1)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $delay2, in: 5...20) {
                        HStack {
                            Text("2차 후 대기")
                            Spacer()
                            Text("\(delay2)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $cooldown, in: 15...60, step: 5) {
                        HStack {
                            Text("쿨다운")
                            Spacer()
                            Text("\(cooldown)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("타이밍")
                }

                // 녹음 설정
                Section {
                    Toggle(isOn: $saveRecordings) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text("코골이 녹음 저장")
                        }
                    }

                    NavigationLink {
                        SnorePlaybackView()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text("녹음 목록")
                        }
                    }
                } header: {
                    Text("녹음")
                } footer: {
                    Text("워치에서 감지된 코골이를 녹음합니다")
                }

                // 워치 연결 상태
                Section {
                    HStack {
                        if watchConnector.isWatchReachable {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text("워치 연결됨")
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "applewatch.slash")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text("워치 연결 안 됨")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("상태")
                }

                // 정보
                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("정보")
                }
            }
            .navigationTitle("설정")
            .onAppear {
                initializeDatePickers()
            }
            .onChange(of: iPhoneEscalation) { _, _ in syncSettingsToWatch() }
            .onChange(of: sensitivity) { _, _ in syncSettingsToWatch() }
            .onChange(of: delay1) { _, _ in syncSettingsToWatch() }
            .onChange(of: delay2) { _, _ in syncSettingsToWatch() }
            .onChange(of: cooldown) { _, _ in syncSettingsToWatch() }
            .onChange(of: saveRecordings) { _, newValue in
                syncRecordingSettingToWatch(enabled: newValue)
            }
            .onChange(of: bedtimeReminderEnabled) { _, newValue in
                if newValue {
                    scheduleBedtimeReminder()
                } else {
                    NotificationManager.shared.cancelBedtimeReminder()
                }
            }
        }
    }

    // MARK: - 감도 라벨
    private var sensitivityLabel: String {
        if sensitivity < 0.8 { return "낮음" }
        if sensitivity < 1.3 { return "보통" }
        if sensitivity < 1.7 { return "높음" }
        return "매우 높음"
    }

    // MARK: - DatePicker 초기화
    private func initializeDatePickers() {
        let calendar = Calendar.current
        var alarmComponents = DateComponents()
        alarmComponents.hour = smartAlarmHour
        alarmComponents.minute = smartAlarmMinute
        if let date = calendar.date(from: alarmComponents) {
            smartAlarmDate = date
        }

        var bedtimeComponents = DateComponents()
        bedtimeComponents.hour = bedtimeReminderHour
        bedtimeComponents.minute = bedtimeReminderMinute
        if let date = calendar.date(from: bedtimeComponents) {
            bedtimeDate = date
        }
    }

    // MARK: - 워치 설정 동기화
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

    // MARK: - 스마트 알람 워치 동기화
    private func syncSmartAlarmToWatch() {
        watchConnector.sendSmartAlarm(
            enabled: smartAlarmEnabled,
            hour: smartAlarmHour,
            minute: smartAlarmMinute
        )
    }

    // MARK: - 녹음 설정 워치 동기화
    private func syncRecordingSettingToWatch(enabled: Bool) {
        watchConnector.sendRecordingSetting(enabled: enabled)
    }

    // MARK: - 취침 리마인더
    private func scheduleBedtimeReminder() {
        NotificationManager.shared.scheduleBedtimeReminder(
            hour: bedtimeReminderHour,
            minute: bedtimeReminderMinute
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchConnector())
}

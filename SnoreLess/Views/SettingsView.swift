import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var showDeleteRecordingsAlert = false
    @State private var showResetSessionsAlert = false
    @State private var recordingStorageSize: String = "0 KB"
    @State private var showSyncToast = false
    @State private var micPermissionGranted = true
    @State private var notificationPermissionGranted = true

    var body: some View {
        NavigationStack {
            Form {
                // 파트너 설정
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .frame(width: 24)
                        TextField(String(localized: "이름 입력"), text: $partnerName)
                    }
                } header: {
                    Text(String(localized: "파트너"))
                } footer: {
                    Text(String(localized: "공유 카드에 이름이 표시됩니다"))
                }

                // 스마트 알람
                Section {
                    Toggle(isOn: $smartAlarmEnabled) {
                        HStack {
                            Image(systemName: "alarm.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text(String(localized: "스마트 알람"))
                        }
                    }

                    if smartAlarmEnabled {
                        DatePicker(
                            String(localized: "알람 시각"),
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
                    Text(String(localized: "알람"))
                } footer: {
                    Text(String(localized: "얕은 수면 구간에서 워치가 깨워줍니다"))
                }

                // 취침 리마인더
                Section {
                    Toggle(isOn: $bedtimeReminderEnabled) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(.purple)
                                .frame(width: 24)
                            Text(String(localized: "취침 리마인더"))
                        }
                    }

                    if bedtimeReminderEnabled {
                        DatePicker(
                            String(localized: "리마인더 시각"),
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
                        Text(String(localized: "매일 알림을 보내드립니다"))
                    }
                }

                // 진동 설정
                Section {
                    Toggle(isOn: $iPhoneEscalation) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            Text(String(localized: "아이폰 추가 진동"))
                        }
                    }
                    Text(String(localized: "워치 진동으로 코골이가 멈추지 않으면 아이폰도 진동합니다"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text(String(localized: "감지 감도"))
                            Spacer()
                            Text(sensitivityLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.5...2.0, step: 0.1)
                            .tint(.cyan)
                        Text(String(localized: "높을수록 작은 소리에도 반응합니다"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "진동"))
                }

                // 타이밍
                Section {
                    Stepper(value: $delay1, in: 3...10) {
                        HStack {
                            Text(String(localized: "1차 후 대기"))
                            Spacer()
                            Text("\(delay1)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $delay2, in: 5...20) {
                        HStack {
                            Text(String(localized: "2차 후 대기"))
                            Spacer()
                            Text("\(delay2)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $cooldown, in: 15...60, step: 5) {
                        HStack {
                            Text(String(localized: "쿨다운"))
                            Spacer()
                            Text("\(cooldown)초")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "타이밍"))
                }

                // 녹음 설정
                Section {
                    Toggle(isOn: $saveRecordings) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text(String(localized: "코골이 녹음 저장"))
                        }
                    }

                    NavigationLink {
                        SnorePlaybackView()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text(String(localized: "녹음 목록"))
                        }
                    }
                } header: {
                    Text(String(localized: "녹음"))
                } footer: {
                    Text(String(localized: "워치에서 감지된 코골이를 녹음합니다"))
                }

                // 워치 연결 상태
                Section {
                    HStack {
                        if watchConnector.isWatchReachable {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text(String(localized: "워치 연결됨"))
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "applewatch.slash")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(String(localized: "워치 연결 안 됨"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "상태"))
                }

                // 데이터 관리
                Section {
                    HStack {
                        Image(systemName: "waveform.circle")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Button(String(localized: "녹음 파일 삭제")) {
                            showDeleteRecordingsAlert = true
                        }
                        .foregroundStyle(.red)
                        Spacer()
                        Text(recordingStorageSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "trash.circle")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Button(String(localized: "수면 기록 초기화")) {
                            showResetSessionsAlert = true
                        }
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text(String(localized: "데이터 관리"))
                }
                .alert(String(localized: "녹음 파일 삭제"), isPresented: $showDeleteRecordingsAlert) {
                    Button(String(localized: "삭제"), role: .destructive) {
                        deleteAllRecordings()
                    }
                    Button(String(localized: "취소"), role: .cancel) {}
                } message: {
                    Text(String(localized: "모든 녹음 파일을 삭제합니다. 이 작업은 되돌릴 수 없습니다."))
                }
                .alert(String(localized: "수면 기록 초기화"), isPresented: $showResetSessionsAlert) {
                    Button(String(localized: "초기화"), role: .destructive) {
                        deleteAllSessions()
                    }
                    Button(String(localized: "취소"), role: .cancel) {}
                } message: {
                    Text(String(localized: "모든 수면 기록과 코골이 이벤트가 삭제됩니다. 이 작업은 되돌릴 수 없습니다."))
                }

                // 권한 관리
                Section {
                    HStack {
                        Label(String(localized: "마이크"), systemImage: "mic.fill")
                        Spacer()
                        Text(micPermissionGranted ? String(localized: "허용됨") : String(localized: "거부됨"))
                            .foregroundStyle(micPermissionGranted ? .green : .red)
                    }

                    HStack {
                        Label(String(localized: "알림"), systemImage: "bell.fill")
                        Spacer()
                        Text(notificationPermissionGranted ? String(localized: "허용됨") : String(localized: "거부됨"))
                            .foregroundStyle(notificationPermissionGranted ? .green : .red)
                    }

                    if !micPermissionGranted || !notificationPermissionGranted {
                        Button(String(localized: "설정에서 권한 변경")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "권한 관리"))
                }

                // 정보
                Section {
                    HStack {
                        Text(String(localized: "버전"))
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "정보"))
                }
            }
            .navigationTitle(String(localized: "설정"))
            .overlay(alignment: .bottom) {
                if showSyncToast {
                    Text(String(localized: "워치에 동기화됨"))
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                        .foregroundStyle(.green)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showSyncToast = false }
                            }
                        }
                        .padding(.bottom, 16)
                }
            }
            .onAppear {
                initializeDatePickers()
                calculateRecordingStorageSize()
                checkPermissions()
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
        if sensitivity < 0.8 { return String(localized: "낮음") }
        if sensitivity < 1.3 { return String(localized: "보통") }
        if sensitivity < 1.7 { return String(localized: "높음") }
        return String(localized: "매우 높음")
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
        withAnimation { showSyncToast = true }
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

    // MARK: - 녹음 파일 전체 삭제
    private func deleteAllRecordings() {
        let recordingsDir = SnorePlaybackView.recordingsDirectory
        guard FileManager.default.fileExists(atPath: recordingsDir.path) else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            print("[Settings] 녹음 파일 전체 삭제 완료: \(files.count)개")
        } catch {
            print("[Settings] 녹음 파일 삭제 실패: \(error)")
        }
        calculateRecordingStorageSize()
    }

    // MARK: - 수면 기록 전체 삭제
    private func deleteAllSessions() {
        do {
            try modelContext.delete(model: SnoreEvent.self)
            try modelContext.delete(model: SleepSession.self)
            try modelContext.save()
            print("[Settings] 수면 기록 전체 초기화 완료")
        } catch {
            print("[Settings] 수면 기록 초기화 실패: \(error)")
        }
    }

    // MARK: - 녹음 저장 용량 계산
    private func calculateRecordingStorageSize() {
        let recordingsDir = SnorePlaybackView.recordingsDirectory
        guard FileManager.default.fileExists(atPath: recordingsDir.path) else {
            recordingStorageSize = "0 KB"
            return
        }

        var totalSize: Int64 = 0
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            for file in files {
                let values = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(values.fileSize ?? 0)
            }
        } catch {
            print("[Settings] 용량 계산 실패: \(error)")
        }

        let kb = Double(totalSize) / 1024.0
        if kb < 1024 {
            recordingStorageSize = String(format: "%.0f KB", kb)
        } else {
            recordingStorageSize = String(format: "%.1f MB", kb / 1024.0)
        }
    }

    // MARK: - 권한 상태 확인
    private func checkPermissions() {
        // 마이크 권한
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            micPermissionGranted = true
        default:
            micPermissionGranted = false
        }

        // 알림 권한
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchConnector())
}

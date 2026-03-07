import SwiftUI
import AVFoundation
import WidgetKit

struct SleepTrackingView: View {
    // MARK: - 상태 관리
    @StateObject private var audioMonitor = AudioMonitor()
    @StateObject private var alarmManager = SmartAlarmManager()
    @State private var trackingState: TrackingState = .idle
    @State private var elapsedSeconds: Int = 0
    @State private var sessionStartDate: Date?
    @State private var timer: Timer?
    @State private var showStopConfirm = false
    @State private var detectedPulseOpacity: Double = 1.0
    @State private var hapticIntensity: HapticIntensity = HapticIntensity(
        rawValue: UserDefaults.standard.integer(forKey: StorageKeys.hapticIntensity)
    ) ?? .medium
    @State private var showMicPermissionAlert = false

    // MARK: - #1 캘리브레이션 진행률
    @State private var calibrationProgress: Double = 0
    @State private var showCalibrationComplete = false
    @State private var calibrationTimer: Timer?

    // MARK: - #4 오디오 캡처 인디케이터
    @State private var audioPulse = false

    // MARK: - #5 세션 복구 확인
    @State private var showRecoveryAlert = false
    @State private var pendingRecoveryDate: Date?

    // MARK: - #8 배터리 모니터링
    @State private var batteryLevel: Float = 1.0
    @State private var batteryTimer: Timer?
    @State private var showBatteryAlert = false

    // MARK: - #9 동기화 상태
    @State private var syncStatus: SyncStatus = .idle

    // MARK: - Always-On Display
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    // MARK: - 세션 복구용 UserDefaults 키
    private let kSessionStartDate = StorageKeys.sessionStartDate
    private let kWasMonitoring = StorageKeys.wasMonitoring

    // MARK: - 어젯밤 요약 (UserDefaults 간이 저장)
    @State private var lastNightSummary: String? = nil

    // MARK: - 추적 상태
    enum TrackingState {
        case idle
        case calibrating
        case monitoring
        case detected
    }

    // MARK: - #9 동기화 상태 enum
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                backgroundGradient

                switch trackingState {
                case .idle:
                    idleView
                case .calibrating:
                    calibratingView
                case .monitoring:
                    monitoringView
                case .detected:
                    detectedView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if trackingState == .idle {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            WatchSettingsView(
                                alarmManager: alarmManager,
                                hapticIntensity: $hapticIntensity
                            )
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .onChange(of: hapticIntensity) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: StorageKeys.hapticIntensity)
            audioMonitor.updateHapticIntensity(newValue)
        }
        .onChange(of: audioMonitor.isCalibrating) { _, isCalibrating in
            if isCalibrating {
                trackingState = .calibrating
                startCalibrationProgress()
            } else if audioMonitor.isMonitoring {
                // #1: 캘리브레이션 완료 시 "측정 완료" 표시 후 전환
                calibrationTimer?.invalidate()
                calibrationTimer = nil
                calibrationProgress = 1.0
                showCalibrationComplete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showCalibrationComplete = false
                    trackingState = .monitoring
                }
            }
        }
        .onChange(of: audioMonitor.snoreDetector.state) { _, newState in
            if newState == .snoring {
                trackingState = .detected
                // 2초 후 모니터링으로 자동 복귀
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if trackingState == .detected {
                        trackingState = .monitoring
                    }
                }
            } else if audioMonitor.isMonitoring && !audioMonitor.isCalibrating {
                trackingState = .monitoring
            }
        }
        .onChange(of: alarmManager.isAlarmTriggered) { _, triggered in
            if triggered {
                stopTracking()
            }
        }
        .onAppear {
            loadLastNightSummary()
            restoreSessionIfNeeded()
        }
        .onDisappear {
            // Ensure timer is always cleaned up when view disappears
            timer?.invalidate()
            timer = nil
            calibrationTimer?.invalidate()
            calibrationTimer = nil
            batteryTimer?.invalidate()
            batteryTimer = nil
        }
        .onChange(of: audioMonitor.micPermissionLost) { _, lost in
            if lost {
                showMicPermissionAlert = true
                // #10: 마이크 권한 해제 시 즉시 stop하지 않고 alert에서 선택
                timer?.invalidate()
                timer = nil
                audioMonitor.stopMonitoring()
                alarmManager.stopMonitoring()
            }
        }
        // #10: 마이크 권한 alert (부분 저장 옵션)
        .alert(
            String(localized: "마이크 권한 필요"),
            isPresented: $showMicPermissionAlert
        ) {
            Button(String(localized: "저장")) {
                endTrackingSession(saveData: true)
            }
            Button(String(localized: "삭제"), role: .destructive) {
                endTrackingSession(saveData: false)
            }
        } message: {
            let duration = micPermissionLostDurationText
            Text("마이크 권한이 해제되었습니다. 지금까지의 \(duration) 데이터를 저장할까요?")
        }
        // #5: 세션 복구 확인 alert
        .alert(
            String(localized: "이전 세션 복구"),
            isPresented: $showRecoveryAlert
        ) {
            Button(String(localized: "계속")) {
                performSessionRestore()
            }
            Button(String(localized: "새로 시작"), role: .cancel) {
                clearRecoveryData()
            }
        } message: {
            Text(recoveryAlertMessage)
        }
        // #8: 배터리 경고 alert
        .alert(
            String(localized: "배터리 부족"),
            isPresented: $showBatteryAlert
        ) {
            Button(String(localized: "확인"), role: .cancel) { }
        } message: {
            Text("배터리가 15% 이하입니다. 세션이 중단될 수 있습니다.")
        }
    }

    // MARK: - #10 마이크 권한 해제 시 경과 시간 텍스트
    private var micPermissionLostDurationText: String {
        guard let start = sessionStartDate else { return "" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    // MARK: - #5 복구 alert 메시지
    private var recoveryAlertMessage: String {
        guard let date = pendingRecoveryDate else { return "" }
        let elapsed = Int(Date().timeIntervalSince(date))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분 전에 시작된 세션을 계속할까요?"
        }
        return "\(minutes)분 전에 시작된 세션을 계속할까요?"
    }

    // MARK: - 배경 그라데이션
    private var backgroundGradient: some View {
        Group {
            switch trackingState {
            case .idle:
                Color.black
            case .calibrating:
                LinearGradient(
                    colors: [Color.black, Color.yellow.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom
                )
            case .monitoring:
                LinearGradient(
                    colors: [Color.black, Color.cyan.opacity(0.06)],
                    startPoint: .top, endPoint: .bottom
                )
            case .detected:
                LinearGradient(
                    colors: [Color.black, Color.red.opacity(0.15)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 대기 화면 (Toss 스타일)
    private var idleView: some View {
        VStack(spacing: 0) {
            // #9: 동기화 상태 표시 (세션 종료 직후)
            if syncStatus != .idle {
                syncStatusView
                    .padding(.top, 4)
            }

            Spacer()

            // 큰 원형 잠들기 버튼
            Button(action: startTracking) {
                ZStack {
                    // 외곽 글로우
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 70
                            )
                        )
                        .frame(width: 130, height: 130)

                    // 메인 원
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .cyan.opacity(0.5), radius: 16, x: 0, y: 4)

                    VStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.black)
                        Text(String(localized: "잠들기"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(height: 14)

            // 스마트 알람 표시
            if alarmManager.isAlarmEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 10))
                    Text(String(localized: "스마트 알람 \(alarmManager.alarmTimeText)"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 6)
            }

            // 어젯밤 요약
            if let summary = lastNightSummary {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
            }

            Spacer()
                .frame(height: 8)
        }
    }

    // MARK: - #9 동기화 상태 뷰
    private var syncStatusView: some View {
        HStack(spacing: 4) {
            switch syncStatus {
            case .syncing:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.5)
                Text(String(localized: "동기화 중..."))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text(String(localized: "저장 완료"))
                    .font(.system(size: 11))
                    .foregroundStyle(.green.opacity(0.8))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text(String(localized: "저장 실패"))
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
            case .idle:
                EmptyView()
            }
        }
    }

    // MARK: - 캘리브레이션 화면 (#1: 원형 진행률 + 카운트다운)
    private var calibratingView: some View {
        VStack(spacing: 8) {
            Spacer()

            if showCalibrationComplete {
                // 측정 완료 표시
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 60, height: 60)

                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.green)
                }

                Text(String(localized: "측정 완료"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                // 소음 측정 애니메이션 (원형 진행률)
                ZStack {
                    Circle()
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 3)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: calibrationProgress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: calibrationProgress)

                    Circle()
                        .fill(Color.yellow.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Text("\(calibrationRemainingSeconds)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.yellow)
                }

                Text(String(localized: "소음 측정 중"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text("남은 시간: \(calibrationRemainingSeconds)초")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))

                Text(formattedElapsedTime)
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)
            }

            Spacer()

            // 하단: 터치하면 종료
            stopOverlay
        }
    }

    // MARK: - #1 캘리브레이션 남은 초
    private var calibrationRemainingSeconds: Int {
        max(0, 60 - Int(calibrationProgress * 60))
    }

    // MARK: - 모니터링 화면 (AOD 대응, 최소 UI)
    private var monitoringView: some View {
        VStack(spacing: 0) {
            // #8: 배터리 레벨 (우측 상단)
            if !isLuminanceReduced {
                HStack {
                    // #4: 오디오 캡처 인디케이터 (녹색 펄스)
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .opacity(audioPulse ? 1 : 0.3)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: audioPulse)
                        .onAppear { audioPulse = true }
                        .onDisappear { audioPulse = false }

                    Spacer()

                    batteryIndicatorView
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)
            }

            Spacer()
                .frame(height: isLuminanceReduced ? 8 : 0)

            // 시계 크게
            Text(currentTimeString)
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .foregroundStyle(isLuminanceReduced ? .white.opacity(0.5) : .white)
                .monospacedDigit()

            // AOD: 상태 도트만 표시 / 일반: 코골이 횟수 상세 표시
            if isLuminanceReduced {
                // Always-On Display: 최소 정보 (상태 도트 + 간략 텍스트)
                HStack(spacing: 4) {
                    Circle()
                        .fill(audioMonitor.snoreDetector.snoreCount > 0 ? .orange.opacity(0.6) : .green.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(audioMonitor.snoreDetector.snoreCount > 0
                         ? "\(audioMonitor.snoreDetector.snoreCount)"
                         : String(localized: "OK"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.top, 4)

                // #2: AOD 경과 시간 표시
                Text(formattedElapsedTimeKorean)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.top, 2)
            } else {
                // 코골이 횟수
                if audioMonitor.snoreDetector.snoreCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        Text(String(localized: "코골이 \(audioMonitor.snoreDetector.snoreCount)회"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(String(localized: "조용한 수면 중"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green.opacity(0.7))
                    }
                    .padding(.top, 4)
                }

                // #3: 코골이 감지 중 진동 표시
                if audioMonitor.snoreDetector.state == .snoring {
                    Text(String(localized: "진동 중"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.top, 2)
                }

                // 경과 시간 (작게) - AOD에서는 숨김
                Text(formattedElapsedTime)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 2)
            }

            Spacer()

            // 터치하면 수면 종료 나타남 (AOD에서는 숨김)
            if !isLuminanceReduced {
                stopOverlay
            }
        }
        .onAppear {
            startBatteryMonitoring()
        }
        .onDisappear {
            batteryTimer?.invalidate()
            batteryTimer = nil
        }
    }

    // MARK: - #8 배터리 인디케이터 뷰
    private var batteryIndicatorView: some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIconName)
                .font(.system(size: 10))
                .foregroundStyle(batteryLevel <= 0.15 ? .red : .white.opacity(0.4))
            Text("\(Int(batteryLevel * 100))%")
                .font(.system(size: 10))
                .foregroundStyle(batteryLevel <= 0.15 ? .red : .white.opacity(0.4))
        }
    }

    private var batteryIconName: String {
        if batteryLevel <= 0.15 {
            return "battery.25percent"
        } else if batteryLevel <= 0.5 {
            return "battery.50percent"
        } else if batteryLevel <= 0.75 {
            return "battery.75percent"
        } else {
            return "battery.100percent"
        }
    }

    // MARK: - 코골이 감지 화면 (빨간 펄스)
    private var detectedView: some View {
        VStack(spacing: 8) {
            Spacer()

            if isLuminanceReduced {
                // AOD: 애니메이션 없이 최소 표시
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(audioMonitor.snoreDetector.snoreCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.red.opacity(0.6))
                    )
            } else {
                ZStack {
                    // 펄스 링
                    Circle()
                        .fill(Color.red.opacity(0.15 * detectedPulseOpacity))
                        .frame(width: 100, height: 100)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: detectedPulseOpacity
                        )

                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: "waveform.path")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .onAppear {
                    detectedPulseOpacity = 0.3
                }
                .onDisappear {
                    detectedPulseOpacity = 1.0
                }

                Text(String(localized: "코골이 감지"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.red)

                // #3: 진동 단계 표시
                Text(String(localized: "진동 중"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.7))

                Text(String(localized: "총 \(audioMonitor.snoreDetector.snoreCount)회"))
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }

    // MARK: - 수면 종료 오버레이 (실수 방지)
    private var stopOverlay: some View {
        VStack {
            if showStopConfirm {
                Button(action: stopTracking) {
                    Text(String(localized: "수면 종료"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showStopConfirm = true
                    }
                    // 3초 후 자동 숨김
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            showStopConfirm = false
                        }
                    }
                }) {
                    Text(String(localized: "화면을 터치하면 종료 버튼이 나타나요"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 36)
        .padding(.bottom, 4)
    }

    // MARK: - 현재 시각
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - 경과 시간 포맷
    private var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - #2 경과 시간 한국어 포맷 (AOD용)
    private var formattedElapsedTimeKorean: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    // MARK: - 수면 시작
    private func startTracking() {
        // 마이크 권한 확인
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
        case .denied:
            showMicPermissionAlert = true
            return
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.beginTrackingSession()
                    } else {
                        self.showMicPermissionAlert = true
                    }
                }
            }
            return
        case .granted:
            break
        @unknown default:
            break
        }

        beginTrackingSession()
    }

    private func beginTrackingSession() {
        let now = Date()
        sessionStartDate = now
        elapsedSeconds = 0
        showStopConfirm = false
        calibrationProgress = 0
        showCalibrationComplete = false
        syncStatus = .idle

        audioMonitor.updateHapticIntensity(hapticIntensity)
        audioMonitor.startMonitoring()

        // Only create timer if monitoring actually started
        guard audioMonitor.isMonitoring else {
            print("[SleepTrackingView] audioMonitor.startMonitoring() failed — timer not created")
            sessionStartDate = nil
            return
        }

        // 세션 복구용 저장
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: kSessionStartDate)
        UserDefaults.standard.set(true, forKey: kWasMonitoring)

        alarmManager.startMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    // MARK: - #1 캘리브레이션 진행률 타이머
    private func startCalibrationProgress() {
        calibrationProgress = 0
        showCalibrationComplete = false
        calibrationTimer?.invalidate()
        let startTime = Date()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / 60.0, 1.0)
            DispatchQueue.main.async {
                calibrationProgress = progress
            }
        }
    }

    // MARK: - 수면 종료
    private func stopTracking() {
        timer?.invalidate()
        timer = nil
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        audioPulse = false

        // 세션 복구 데이터 제거
        UserDefaults.standard.removeObject(forKey: kSessionStartDate)
        UserDefaults.standard.set(false, forKey: kWasMonitoring)

        // #7: 짧은 세션 필터
        let sessionDurationMinutes = elapsedSeconds / 60
        let isTestSession = sessionDurationMinutes < 30

        // #6: 확장된 어젯밤 요약 저장
        if isTestSession {
            saveTestSessionSummary(minutes: sessionDurationMinutes)
        } else {
            saveLastNightSummary()
        }

        // #7: 테스트 세션은 컴플리케이션 데이터 저장 건너뜀
        if !isTestSession {
            saveComplicationData()
        }

        // #9: 동기화 상태 표시
        syncStatus = .syncing
        audioMonitor.stopMonitoring()
        alarmManager.stopMonitoring()

        trackingState = .idle
        elapsedSeconds = 0
        sessionStartDate = nil
        showStopConfirm = false

        // #9: 1.5초 후 성공 표시, 3초 후 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            syncStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                syncStatus = .idle
            }
        }
    }

    // MARK: - #10 부분 저장/삭제로 종료
    private func endTrackingSession(saveData: Bool) {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        audioPulse = false

        UserDefaults.standard.removeObject(forKey: kSessionStartDate)
        UserDefaults.standard.set(false, forKey: kWasMonitoring)

        if saveData {
            let sessionDurationMinutes = elapsedSeconds / 60
            let isTestSession = sessionDurationMinutes < 30

            if isTestSession {
                saveTestSessionSummary(minutes: sessionDurationMinutes)
            } else {
                saveLastNightSummary()
            }

            if !isTestSession {
                saveComplicationData()
            }

            syncStatus = .syncing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                syncStatus = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    syncStatus = .idle
                }
            }
        }

        trackingState = .idle
        elapsedSeconds = 0
        sessionStartDate = nil
        showStopConfirm = false
    }

    // MARK: - 세션 자동 복구 (#5: 확인 alert 표시)
    private func restoreSessionIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: kWasMonitoring) else { return }

        let savedTimestamp = defaults.double(forKey: kSessionStartDate)
        guard savedTimestamp > 0 else { return }

        let savedDate = Date(timeIntervalSince1970: savedTimestamp)
        pendingRecoveryDate = savedDate
        showRecoveryAlert = true
    }

    // MARK: - #5 세션 복구 실행
    private func performSessionRestore() {
        guard let savedDate = pendingRecoveryDate else { return }

        sessionStartDate = savedDate
        elapsedSeconds = Int(Date().timeIntervalSince(savedDate))

        audioMonitor.updateHapticIntensity(hapticIntensity)
        audioMonitor.startMonitoring()

        // Only restore timer if monitoring actually started
        guard audioMonitor.isMonitoring else {
            print("[SleepTrackingView] 세션 복구 실패 — 모니터링 시작 안 됨")
            clearRecoveryData()
            return
        }

        alarmManager.startMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }

        pendingRecoveryDate = nil
    }

    // MARK: - #5 복구 데이터 초기화
    private func clearRecoveryData() {
        UserDefaults.standard.removeObject(forKey: kSessionStartDate)
        UserDefaults.standard.set(false, forKey: kWasMonitoring)
        pendingRecoveryDate = nil
        sessionStartDate = nil
        elapsedSeconds = 0
    }

    // MARK: - #8 배터리 모니터링 시작
    private func startBatteryMonitoring() {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        batteryLevel = device.batteryLevel

        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            DispatchQueue.main.async {
                batteryLevel = WKInterfaceDevice.current().batteryLevel
                if batteryLevel >= 0 && batteryLevel <= 0.15 {
                    showBatteryAlert = true
                }
            }
        }

        // 즉시 배터리 부족 확인
        if batteryLevel >= 0 && batteryLevel <= 0.15 {
            showBatteryAlert = true
        }
    }

    // MARK: - 컴플리케이션 데이터 저장
    private func saveComplicationData() {
        let snoreCount = audioMonitor.snoreDetector.snoreCount
        let sleepScore = calculateSleepScore(snoreCount: snoreCount)

        let defaults = UserDefaults.standard
        defaults.set(snoreCount, forKey: StorageKeys.lastNightSnoreCount)
        defaults.set(sleepScore, forKey: StorageKeys.lastNightSleepScore)

        // 컴플리케이션 타임라인 갱신
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 코골이 횟수 기반 간이 수면 점수 (0~100)
    private func calculateSleepScore(snoreCount: Int) -> Int {
        // 기본 점수 95, 코골이 1회당 -5점, 최소 20점
        let score = max(20, 95 - (snoreCount * 5))
        return score
    }

    // MARK: - #6 확장된 어젯밤 요약 저장
    private func saveLastNightSummary() {
        let count = audioMonitor.snoreDetector.snoreCount
        let durationText = sleepDurationText()
        let summary: String
        if count == 0 {
            summary = "어젯밤 \(durationText) 수면 · 코골이 없이 숙면했어요"
        } else {
            summary = "어젯밤 \(durationText) 수면 · 코골이 \(count)회 감지 · 진동 후 조용해졌어요"
        }
        UserDefaults.standard.set(summary, forKey: StorageKeys.lastNightSummary)
        lastNightSummary = summary
    }

    // MARK: - #7 테스트 세션 요약 저장
    private func saveTestSessionSummary(minutes: Int) {
        let summary = "테스트 세션 (\(minutes)분)"
        UserDefaults.standard.set(summary, forKey: StorageKeys.lastNightSummary)
        lastNightSummary = summary
    }

    // MARK: - #6 수면 시간 텍스트
    private func sleepDurationText() -> String {
        guard let start = sessionStartDate else {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)시간 \(minutes)분"
            }
            return "\(minutes)분"
        }
        let elapsed = Int(Date().timeIntervalSince(start))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    private func loadLastNightSummary() {
        lastNightSummary = UserDefaults.standard.string(forKey: StorageKeys.lastNightSummary)
    }
}

#Preview {
    SleepTrackingView()
}

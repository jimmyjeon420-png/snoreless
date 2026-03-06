import SwiftUI

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
        rawValue: UserDefaults.standard.integer(forKey: "hapticIntensity")
    ) ?? .medium

    // MARK: - 어젯밤 요약 (UserDefaults 간이 저장)
    @State private var lastNightSummary: String? = nil

    // MARK: - 추적 상태
    enum TrackingState {
        case idle
        case calibrating
        case monitoring
        case detected
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
            UserDefaults.standard.set(newValue.rawValue, forKey: "hapticIntensity")
            audioMonitor.updateHapticIntensity(newValue)
        }
        .onChange(of: audioMonitor.isCalibrating) { _, isCalibrating in
            if isCalibrating {
                trackingState = .calibrating
            } else if audioMonitor.isMonitoring {
                trackingState = .monitoring
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
        }
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
                        Text("잠들기")
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
                    Text("스마트 알람 \(alarmManager.alarmTimeText)")
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
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }

            Spacer()
                .frame(height: 8)
        }
    }

    // MARK: - 캘리브레이션 화면
    private var calibratingView: some View {
        VStack(spacing: 8) {
            Spacer()

            // 소음 측정 애니메이션
            ZStack {
                Circle()
                    .stroke(Color.yellow.opacity(0.2), lineWidth: 2)
                    .frame(width: 60, height: 60)

                Circle()
                    .fill(Color.yellow.opacity(0.1))
                    .frame(width: 50, height: 50)

                ProgressView()
                    .tint(.yellow)
                    .scaleEffect(0.8)
            }

            Text("소음 측정 중")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.yellow)

            Text("조용히 누워 계세요")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))

            Text(formattedElapsedTime)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 2)

            Spacer()

            // 하단: 터치하면 종료
            stopOverlay
        }
    }

    // MARK: - 모니터링 화면 (AOD 대응, 최소 UI)
    private var monitoringView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 8)

            // 시계 크게
            Text(currentTimeString)
                .font(.system(size: 48, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            // 코골이 횟수
            if audioMonitor.snoreDetector.snoreCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("코골이 \(audioMonitor.snoreDetector.snoreCount)회")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("조용한 수면 중")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green.opacity(0.7))
                }
                .padding(.top, 4)
            }

            // 경과 시간 (작게)
            Text(formattedElapsedTime)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 2)

            Spacer()

            // 터치하면 수면 종료 나타남
            stopOverlay
        }
    }

    // MARK: - 코골이 감지 화면 (빨간 펄스)
    private var detectedView: some View {
        VStack(spacing: 8) {
            Spacer()

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

            Text("코골이 감지")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.red)

            Text("총 \(audioMonitor.snoreDetector.snoreCount)회")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            Spacer()
        }
    }

    // MARK: - 수면 종료 오버레이 (실수 방지)
    private var stopOverlay: some View {
        VStack {
            if showStopConfirm {
                Button(action: stopTracking) {
                    Text("수면 종료")
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
                    Text("화면을 터치하면 종료 버튼이 나타나요")
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

    // MARK: - 수면 시작
    private func startTracking() {
        sessionStartDate = Date()
        elapsedSeconds = 0
        showStopConfirm = false

        audioMonitor.updateHapticIntensity(hapticIntensity)
        audioMonitor.startMonitoring()
        alarmManager.startMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    // MARK: - 수면 종료
    private func stopTracking() {
        timer?.invalidate()
        timer = nil

        // 어젯밤 요약 저장
        saveLastNightSummary()

        audioMonitor.stopMonitoring()
        alarmManager.stopMonitoring()
        trackingState = .idle
        elapsedSeconds = 0
        sessionStartDate = nil
        showStopConfirm = false
    }

    // MARK: - 어젯밤 요약 저장/로드
    private func saveLastNightSummary() {
        let count = audioMonitor.snoreDetector.snoreCount
        let summary: String
        if count == 0 {
            summary = "어젯밤 코골이 없이 숙면했어요"
        } else {
            summary = "어젯밤 \(count)회 감지, 진동 후 조용해졌어요"
        }
        UserDefaults.standard.set(summary, forKey: "lastNightSummary")
    }

    private func loadLastNightSummary() {
        lastNightSummary = UserDefaults.standard.string(forKey: "lastNightSummary")
    }
}

#Preview {
    SleepTrackingView()
}

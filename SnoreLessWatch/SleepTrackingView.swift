import SwiftUI

struct SleepTrackingView: View {
    // MARK: - 상태 관리
    @StateObject private var audioMonitor = AudioMonitor()
    @State private var trackingState: TrackingState = .idle
    @State private var elapsedSeconds: Int = 0
    @State private var sessionStartDate: Date?
    @State private var timer: Timer?

    // MARK: - 추적 상태
    enum TrackingState {
        case idle           // 대기 중
        case calibrating    // 배경 소음 측정 중 (첫 5분)
        case monitoring     // 모니터링 중
        case detected       // 코골이 감지됨
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
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
            .navigationTitle("코골이 방지")
            .navigationBarTitleDisplayMode(.inline)
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
            } else if audioMonitor.isMonitoring && !audioMonitor.isCalibrating {
                trackingState = .monitoring
            }
        }
    }

    // MARK: - 대기 화면
    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)

            Text("수면 모니터링을\n시작하세요")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: startTracking) {
                Text("수면 시작")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding()
    }

    // MARK: - 캘리브레이션 화면
    private var calibratingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("배경 소음 측정 중...")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text("조용히 누워 계세요")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedElapsedTime)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.white)

            Text("현재 소음: \(String(format: "%.1f", audioMonitor.currentLevel)) dB")
                .font(.caption2)
                .foregroundStyle(.secondary)

            stopButton
        }
        .padding()
    }

    // MARK: - 모니터링 화면
    private var monitoringView: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 28))
                .foregroundStyle(.green)
                .symbolEffect(.variableColor.iterative)

            Text("모니터링 중")
                .font(.headline)
                .foregroundStyle(.green)

            Text(formattedElapsedTime)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.white)

            HStack {
                Label("\(audioMonitor.snoreDetector.snoreCount)회", systemImage: "nose")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Spacer()

                Text("\(String(format: "%.0f", audioMonitor.currentLevel)) dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)


            stopButton
        }
        .padding()
    }

    // MARK: - 코골이 감지 화면
    private var detectedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)

            Text("코골이 감지!")
                .font(.headline)
                .foregroundStyle(.red)

            Text(formattedElapsedTime)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.white)

            Text("총 \(audioMonitor.snoreDetector.snoreCount)회 감지")
                .font(.caption)
                .foregroundStyle(.orange)

            stopButton
        }
        .padding()
    }

    // MARK: - 종료 버튼
    private var stopButton: some View {
        Button(action: stopTracking) {
            Text("수면 종료")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
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
        audioMonitor.startMonitoring()

        // 1초마다 경과 시간 업데이트
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    // MARK: - 수면 종료
    private func stopTracking() {
        timer?.invalidate()
        timer = nil
        audioMonitor.stopMonitoring()
        trackingState = .idle
        elapsedSeconds = 0
        sessionStartDate = nil
    }
}

#Preview {
    SleepTrackingView()
}

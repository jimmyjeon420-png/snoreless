import AVFoundation
import WatchKit
import Combine
import Accelerate

/// 마이크 실시간 오디오 모니터링
/// AVAudioEngine으로 마이크 입력을 받아 RMS -> dB 변환 후 SnoreDetector에 전달
class AudioMonitor: ObservableObject {
    // MARK: - 오디오 엔진
    private var audioEngine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount = 8192

    // MARK: - 버퍼 스킵 (배터리 최적화: 3개 중 1개만 처리)
    private var bufferSkipCount = 0

    // MARK: - 코골이 감지기 & 진동 컨트롤러
    let snoreDetector: SnoreDetector
    private let hapticController: HapticController
    private let phoneConnector: PhoneConnector
    private let snoreRecorder: SnoreRecorder

    // MARK: - 공개 상태
    @Published var isMonitoring = false
    @Published var currentLevel: Double = 0  // 현재 소리 레벨 (dB)
    @Published var isCalibrating = false

    // MARK: - 캘리브레이션
    private var calibrationSamples: [Double] = []
    private var backgroundNoiseLevel: Double = -60.0  // 기본 배경 소음 (dB)
    private var calibrationTimer: Timer?
    private let calibrationDuration: TimeInterval = 60   // 1분 캘리브레이션
    private let calibrationInterval: TimeInterval = 0.5   // 0.5초마다 샘플
    private var calibrationStartDate: Date?

    // MARK: - 세션 관리
    private var sessionStartDate: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 초기화
    init() {
        self.snoreDetector = SnoreDetector()
        self.hapticController = HapticController()
        self.phoneConnector = PhoneConnector()
        self.snoreRecorder = SnoreRecorder()

        setupSnoreCallback()
    }

    /// 코골이 감지 콜백 연결
    private func setupSnoreCallback() {
        snoreDetector.onSnoreDetected = { [weak self] eventData in
            guard let self = self else { return }
            // 햅틱 에스컬레이션 시작
            self.hapticController.triggerEscalation(
                snoreDetector: self.snoreDetector,
                phoneConnector: self.phoneConnector
            )
            // 코골이 구간 녹음 (5초 클립)
            self.snoreRecorder.recordSnoreClip()
            // 아이폰에 코골이 로그 전송 (비긴급)
            self.phoneConnector.sendSnoreLog(event: eventData)
        }
    }

    // MARK: - 햅틱 강도 업데이트
    func updateHapticIntensity(_ intensity: HapticIntensity) {
        hapticController.updateIntensity(intensity)
    }

    // MARK: - 모니터링 시작
    func startMonitoring() {
        guard !isMonitoring else { return }

        // AVAudioSession 설정 (watchOS에서는 .record 카테고리 사용)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioMonitor] 오디오 세션 설정 실패: \(error.localizedDescription)")
            return
        }

        // 입력 노드에서 포맷 가져오기
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 기존 탭이 있으면 제거
        inputNode.removeTap(onBus: 0)

        // 오디오 탭 설치 — 3개 버퍼 중 1개만 처리 (배터리 절약)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.bufferSkipCount += 1
            guard self.bufferSkipCount % 3 == 0 else { return }
            self.processAudioBuffer(buffer)
        }

        // 엔진 시작
        do {
            try audioEngine.start()
        } catch {
            print("[AudioMonitor] 오디오 엔진 시작 실패: \(error.localizedDescription)")
            return
        }

        sessionStartDate = Date()
        isMonitoring = true

        // 캘리브레이션 시작
        startCalibration()
    }

    // MARK: - 모니터링 중지
    func stopMonitoring() {
        guard isMonitoring else { return }

        // 캘리브레이션 타이머 정리
        calibrationTimer?.invalidate()
        calibrationTimer = nil

        // 오디오 엔진 정리
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // 오디오 세션 비활성화
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        // 햅틱 정리
        hapticController.reset()

        // 세션 데이터 전송
        if let startDate = sessionStartDate {
            let totalDuration = snoreDetector.eventLog.reduce(0.0) { $0 + $1.duration }
            let sessionData = SleepSessionData(
                startTime: startDate,
                endTime: Date(),
                snoreEvents: snoreDetector.eventLog,
                totalSnoreDuration: totalDuration,
                backgroundNoiseLevel: backgroundNoiseLevel
            )
            phoneConnector.sendSleepSession(sessionData)
        }

        // 감지기 리셋
        snoreDetector.reset()

        // 상태 초기화
        isMonitoring = false
        isCalibrating = false
        currentLevel = 0
        calibrationSamples.removeAll()
        backgroundNoiseLevel = -60.0
        sessionStartDate = nil
        bufferSkipCount = 0
    }

    // MARK: - 오디오 버퍼 처리
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frames = buffer.frameLength
        let data = channelData[0]

        // RMS (Root Mean Square) 계산 — vDSP 벡터 연산으로 배터리 최적화
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frames))

        // dB 변환 (무음 방지를 위해 최솟값 설정)
        let db: Double
        if rms > 0 {
            db = Double(20 * log10(rms))
        } else {
            db = -160.0
        }

        // 메인 스레드에서 상태 업데이트
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevel = db

            // 캘리브레이션 중이 아닐 때만 감지기에 전달
            if !self.isCalibrating {
                self.snoreDetector.processSample(
                    level: db,
                    backgroundNoise: self.backgroundNoiseLevel
                )
            }
        }
    }

    // MARK: - 캘리브레이션 (배경 소음 측정)
    private func startCalibration() {
        isCalibrating = true
        calibrationSamples.removeAll()
        calibrationStartDate = Date()

        // 0.5초마다 현재 레벨을 캘리브레이션 샘플로 수집
        calibrationTimer = Timer.scheduledTimer(
            withTimeInterval: calibrationInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }

            // 현재 레벨 샘플 추가
            self.calibrationSamples.append(self.currentLevel)

            // 5분 경과 확인
            if let startDate = self.calibrationStartDate,
               Date().timeIntervalSince(startDate) >= self.calibrationDuration {
                self.finishCalibration()
            }
        }
    }

    /// 캘리브레이션 완료 — 배경 소음 평균 계산
    private func finishCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil

        if !calibrationSamples.isEmpty {
            let sum = calibrationSamples.reduce(0, +)
            backgroundNoiseLevel = sum / Double(calibrationSamples.count)
            print("[AudioMonitor] 캘리브레이션 완료. 배경 소음: \(String(format: "%.1f", backgroundNoiseLevel)) dB")
        }

        // 감지기에 배경 소음 전달
        snoreDetector.backgroundNoiseLevel = backgroundNoiseLevel
        isCalibrating = false
    }
}

import AVFoundation
import WatchKit
import Combine
import Accelerate

/// 마이크 실시간 오디오 모니터링
/// AVAudioEngine으로 마이크 입력을 받아 RMS -> dB 변환 후 SnoreDetector에 전달
/// ML 분류기(SoundAnalysis)와 dB 기반 감지를 병행하는 듀얼 모드 지원
@MainActor
class AudioMonitor: NSObject, ObservableObject {
    // MARK: - 상수 (nonisolated — 오디오 스레드에서도 안전하게 접근)
    nonisolated(unsafe) private static let defaultBackgroundNoiseDb: Double = -60.0
    nonisolated(unsafe) private static let silenceFloorDb: Double = -160.0
    nonisolated(unsafe) private static let bufferSkipInterval: Int = 3  // dB 처리는 N개 중 1개만

    // MARK: - 오디오 엔진
    private var audioEngine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount = 8192

    // MARK: - 코골이 감지기 & ML 분류기 & 진동 컨트롤러
    let snoreDetector: SnoreDetector
    let snoreClassifier = SnoreClassifier()
    private let hapticController: HapticController
    private let phoneConnector: PhoneConnector
    private let snoreRecorder: SnoreRecorder

    // MARK: - 공개 상태
    @Published var isMonitoring = false
    @Published var currentLevel: Double = 0  // 현재 소리 레벨 (dB)
    @Published var isCalibrating = false
    @Published var engineStartFailed = false
    @Published var environmentTooNoisy = false
    @Published var calibrationProgress: Double = 0  // 0.0 to 1.0

    // MARK: - 캘리브레이션
    private var calibrationSamples: [Double] = []
    private var backgroundNoiseLevel: Double = AudioMonitor.defaultBackgroundNoiseDb
    private var calibrationTimer: Timer?
    private let calibrationDuration: TimeInterval = 60   // 1분 캘리브레이션
    private let calibrationInterval: TimeInterval = 0.5   // 0.5초마다 샘플
    private var calibrationStartDate: Date?

    // MARK: - 데시벨 타임라인
    private var decibelTimeline: [DecibelSample] = []
    private var lastTimelineSampleDate: Date?
    private let timelineSampleInterval: TimeInterval = 30  // 30초 간격
    private static let maxTimelineSamples = 960  // 8시간분

    // MARK: - 세션 관리
    private var sessionStartDate: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Extended Runtime Session (백그라운드 실행 유지)
    private var extendedSession: WKExtendedRuntimeSession?

    // MARK: - 마이크 권한 상태
    @Published var micPermissionLost = false
    private var micPermissionTimer: Timer?

    // MARK: - 초기화
    override init() {
        self.snoreDetector = SnoreDetector()
        self.hapticController = HapticController()
        self.phoneConnector = PhoneConnector()
        self.snoreRecorder = SnoreRecorder()
        super.init()

        setupSnoreCallback()
    }

    deinit {
        // Clean up audio engine, timers, and extended session to prevent resource leaks
        calibrationTimer?.invalidate()
        micPermissionTimer?.invalidate()
        extendedSession?.invalidate()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    /// 코골이 감지 콜백 연결 + ML 분류기 결과 구독
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

        // ML 분류기 available 상태를 SnoreDetector에 전달
        snoreClassifier.$isAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] available in
                self?.snoreDetector.isMLAvailable = available
            }
            .store(in: &cancellables)

        // ML 분류기 결과를 SnoreDetector에 전달 (다중 소리 타입)
        snoreClassifier.$latestResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self = self, self.snoreClassifier.isAvailable else { return }
                if let result = result {
                    self.snoreDetector.processMLResult(soundType: result.soundType, confidence: result.confidence)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 햅틱 강도 업데이트
    func updateHapticIntensity(_ intensity: HapticIntensity) {
        hapticController.updateIntensity(intensity)
    }

    // MARK: - Extended Runtime Session 관리
    private func startExtendedSession() {
        // 기존 세션이 있으면 정리
        extendedSession?.invalidate()

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
        print("[AudioMonitor] Extended Runtime Session 시작 요청")
    }

    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
        print("[AudioMonitor] Extended Runtime Session 종료")
    }

    // MARK: - 마이크 권한 주기적 확인
    private func startMicPermissionMonitoring() {
        micPermissionLost = false
        micPermissionTimer = Timer.scheduledTimer(
            withTimeInterval: 30.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isMonitoring else { return }
                let permission = AVAudioApplication.shared.recordPermission
                if permission == .denied || permission == .undetermined {
                    print("[AudioMonitor] 마이크 권한 상실 감지 — 모니터링 중단")
                    self.micPermissionLost = true
                    self.stopMonitoring()
                }
            }
        }
    }

    private func stopMicPermissionMonitoring() {
        micPermissionTimer?.invalidate()
        micPermissionTimer = nil
    }

    // MARK: - 모니터링 시작
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Extended Runtime Session 시작 (백그라운드 실행 유지)
        startExtendedSession()

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

        // ML 분류기 시작 (SoundAnalysis — watchOS 10+)
        snoreClassifier.startAnalysis(format: recordingFormat)

        // 오디오 탭 설치 — ML 분류기에는 모든 버퍼 전달, dB 처리는 3개 중 1개만 (배터리 절약)
        // Note: installTap callback runs on a background audio thread.
        // Capture classifier directly for background-safe ML analysis,
        // then dispatch state mutations back to MainActor via Task.
        let classifier = snoreClassifier
        // bufferSkipCount is tracked on audio thread to avoid dispatching every buffer
        var audioThreadSkipCount = 0
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            // ML 분류기에는 모든 버퍼를 전달 (정확도 우선) — 백그라운드 스레드에서 직접 호출
            classifier.analyze(buffer: buffer)

            // dB 처리는 N개 중 1개만 (배터리 절약)
            audioThreadSkipCount += 1
            guard audioThreadSkipCount % AudioMonitor.bufferSkipInterval == 0 else { return }

            // 버퍼는 콜백 내에서만 유효하므로 dB를 여기서 계산
            let db = Self.computeDecibels(from: buffer)

            // 숫자만 MainActor로 전달
            Task { @MainActor [weak self] in
                self?.handleDecibelReading(db)
            }
        }

        // 엔진 시작
        do {
            try audioEngine.start()
        } catch {
            print("[AudioMonitor] 오디오 엔진 시작 실패: \(error.localizedDescription)")
            engineStartFailed = true
            return
        }

        sessionStartDate = Date()
        isMonitoring = true

        // 캘리브레이션 시작
        startCalibration()

        // 마이크 권한 주기적 확인 시작
        startMicPermissionMonitoring()
    }

    // MARK: - 모니터링 중지
    func stopMonitoring() {
        guard isMonitoring else { return }

        // Extended Runtime Session 종료
        stopExtendedSession()

        // 마이크 권한 모니터링 종료
        stopMicPermissionMonitoring()

        // 캘리브레이션 타이머 정리
        calibrationTimer?.invalidate()
        calibrationTimer = nil

        // ML 분류기 정리
        snoreClassifier.stopAnalysis()

        // 오디오 엔진 정리
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // 오디오 세션 비활성화 — setActive(false) 실패는 무해함 (다른 앱이 세션을 점유 중일 때 발생 가능)
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
                backgroundNoiseLevel: backgroundNoiseLevel,
                decibelTimeline: decibelTimeline
            )
            phoneConnector.sendSleepSession(sessionData)
        }

        // 감지기 리셋
        snoreDetector.reset()

        // 상태 초기화
        isMonitoring = false
        isCalibrating = false
        currentLevel = 0
        calibrationProgress = 0
        calibrationSamples.removeAll()
        backgroundNoiseLevel = Self.defaultBackgroundNoiseDb
        sessionStartDate = nil
        decibelTimeline.removeAll()
        lastTimelineSampleDate = nil
    }

    // MARK: - 오디오 버퍼 → dB 변환 (오디오 스레드에서 호출, 스레드 안전)
    /// AVAudioPCMBuffer에서 RMS dB를 계산한다. 버퍼가 유효한 오디오 콜백 내에서 호출해야 한다.
    nonisolated static func computeDecibels(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return silenceFloorDb }

        let frames = buffer.frameLength
        let data = channelData[0]

        // RMS (Root Mean Square) 계산 — vDSP 벡터 연산으로 배터리 최적화
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frames))

        if rms > 0 {
            let db = Double(20 * log10(rms))
            // Clamp to valid hearing range: silence floor to 0 dB (full scale)
            return db.isFinite ? max(db, silenceFloorDb) : silenceFloorDb
        } else {
            return silenceFloorDb
        }
    }

    // MARK: - dB 값 처리 (MainActor)
    /// computeDecibels에서 계산된 dB 값을 받아 상태 업데이트 및 감지기 전달
    private func handleDecibelReading(_ db: Double) {
        currentLevel = db

        // 캘리브레이션 중이 아닐 때만 감지기에 전달
        if !isCalibrating {
            snoreDetector.processSample(
                level: db,
                backgroundNoise: backgroundNoiseLevel
            )

            // dB 타임라인 샘플링 (30초 간격)
            let now = Date()
            if let lastSample = lastTimelineSampleDate {
                if now.timeIntervalSince(lastSample) >= timelineSampleInterval {
                    appendTimelineSample(db: db, at: now)
                }
            } else {
                appendTimelineSample(db: db, at: now)
            }
        }
    }

    private func appendTimelineSample(db: Double, at time: Date) {
        guard decibelTimeline.count < Self.maxTimelineSamples else { return }
        decibelTimeline.append(DecibelSample(timestamp: time, db: db))
        lastTimelineSampleDate = time
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
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // 현재 레벨 샘플 추가
                self.calibrationSamples.append(self.currentLevel)

                // 캘리브레이션 진행률 업데이트
                if let startDate = self.calibrationStartDate {
                    self.calibrationProgress = min(Date().timeIntervalSince(startDate) / self.calibrationDuration, 1.0)
                }

                // 캘리브레이션 기간 경과 확인
                if let startDate = self.calibrationStartDate,
                   Date().timeIntervalSince(startDate) >= self.calibrationDuration {
                    self.finishCalibration()
                }
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

        // 환경 소음 경고
        if backgroundNoiseLevel > -45 {
            environmentTooNoisy = true
            print("[AudioMonitor] 환경 소음이 높습니다: \(backgroundNoiseLevel) dB")
        }

        // 감지기에 배경 소음 전달
        snoreDetector.backgroundNoiseLevel = backgroundNoiseLevel
        isCalibrating = false
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension AudioMonitor: WKExtendedRuntimeSessionDelegate {

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        print("[AudioMonitor] Extended Runtime Session 활성화 완료 — 백그라운드 실행 유지")
    }

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        print("[AudioMonitor] Extended Runtime Session 곧 만료 — 상태 저장 시도")
        // 만료 직전: UserDefaults에 세션 상태 보존 (restoreSessionIfNeeded에서 복구)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.isMonitoring {
                UserDefaults.standard.set(true, forKey: StorageKeys.wasMonitoring)
            }
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        let reasonText: String
        switch reason {
        case .none: reasonText = "정상 종료"
        case .sessionInProgress: reasonText = "이미 세션 진행 중"
        case .expired: reasonText = "시간 만료"
        case .resignedFrontmost: reasonText = "포그라운드 상실"
        case .error: reasonText = "오류: \(error?.localizedDescription ?? "알 수 없음")"
        @unknown default: reasonText = "알 수 없는 이유"
        }
        print("[AudioMonitor] Extended Runtime Session 무효화: \(reasonText)")

        // 모니터링 중이었다면 새 세션으로 재시작 시도
        Task { @MainActor [weak self] in
            guard let self = self, self.isMonitoring else { return }
            // 정상 종료(.none)가 아닌 경우에만 재시작
            if reason != .none {
                print("[AudioMonitor] 모니터링 중 세션 만료 — 재시작 시도")
                self.startExtendedSession()
            }
        }
    }
}

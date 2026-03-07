import Foundation
import CoreMotion
import WatchKit
import Combine

/// 스마트 알람 매니저
/// 설정된 알람 시각 30분 전부터 얕은 수면을 감지하여 최적의 타이밍에 깨움
class SmartAlarmManager: ObservableObject {

    // MARK: - 공개 상태
    @Published var isAlarmEnabled: Bool {
        didSet { saveSettings() }
    }
    @Published var alarmHour: Int {
        didSet { saveSettings() }
    }
    @Published var alarmMinute: Int {
        didSet { saveSettings() }
    }
    @Published var isAlarmTriggered = false

    // MARK: - 내부 상태
    private var motionManager = CMMotionManager()
    private var checkTimer: Timer?
    private var alarmTimer: Timer?
    private var isInWindow = false  // 알람 30분 전 윈도우 진입 여부
    private let windowMinutes: TimeInterval = 30 * 60  // 30분

    // MARK: - 얕은 수면 판별
    private var recentAccelMagnitudes: [Double] = []
    private let accelWindowSize = 30  // 최근 30개 샘플 (약 30초)
    private let lightSleepMotionThreshold: Double = 0.02  // 미세한 움직임 임계값
    private let quietNoiseThreshold: Double = 5.0  // 배경소음 대비 dB

    // MARK: - UserDefaults 키
    private let kAlarmEnabled = StorageKeys.smartAlarmEnabled
    private let kAlarmHour = StorageKeys.smartAlarmHour
    private let kAlarmMinute = StorageKeys.smartAlarmMinute

    // MARK: - 초기화
    init() {
        let defaults = UserDefaults.standard
        self.isAlarmEnabled = defaults.bool(forKey: kAlarmEnabled)
        self.alarmHour = defaults.object(forKey: kAlarmHour) as? Int ?? 7
        self.alarmMinute = defaults.object(forKey: kAlarmMinute) as? Int ?? 0
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isAlarmEnabled, forKey: kAlarmEnabled)
        defaults.set(alarmHour, forKey: kAlarmHour)
        defaults.set(alarmMinute, forKey: kAlarmMinute)
    }

    // MARK: - 알람 시각 포맷
    var alarmTimeText: String {
        String(format: "%02d:%02d", alarmHour, alarmMinute)
    }

    // MARK: - 수면 시작 시 호출
    func startMonitoring() {
        guard isAlarmEnabled else { return }
        isAlarmTriggered = false
        isInWindow = false

        // 가속도계 시작
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                let magnitude = sqrt(
                    data.acceleration.x * data.acceleration.x +
                    data.acceleration.y * data.acceleration.y +
                    data.acceleration.z * data.acceleration.z
                )
                // 중력(1.0) 제거 후 움직임만 추출
                let motion = abs(magnitude - 1.0)
                self.recentAccelMagnitudes.append(motion)
                if self.recentAccelMagnitudes.count > self.accelWindowSize {
                    self.recentAccelMagnitudes.removeFirst()
                }
            }
        }

        // 30초마다 알람 윈도우 진입 여부 + 얕은 수면 체크
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkAlarmWindow()
        }
    }

    // MARK: - 수면 종료 시 호출
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
        motionManager.stopAccelerometerUpdates()
        recentAccelMagnitudes.removeAll()
        isInWindow = false
        isAlarmTriggered = false
    }

    // MARK: - 알람 윈도우 체크
    private func checkAlarmWindow() {
        guard isAlarmEnabled, !isAlarmTriggered else { return }

        let now = Date()
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentHour = currentComponents.hour,
              let currentMinute = currentComponents.minute else { return }

        let currentTotalMinutes = currentHour * 60 + currentMinute
        let alarmTotalMinutes = alarmHour * 60 + alarmMinute

        // 알람 시각까지 남은 분
        var minutesUntilAlarm = alarmTotalMinutes - currentTotalMinutes
        if minutesUntilAlarm < 0 {
            minutesUntilAlarm += 24 * 60  // 다음 날
        }

        // 알람 시각 도달 (0분 남음 또는 1분 이내)
        if minutesUntilAlarm == 0 || minutesUntilAlarm >= 24 * 60 - 1 {
            triggerAlarm()
            return
        }

        // 30분 전 윈도우
        if minutesUntilAlarm <= 30 {
            isInWindow = true
            // 얕은 수면 감지되면 바로 깨움
            if isLightSleep() {
                triggerAlarm()
            }
        }
    }

    // MARK: - 얕은 수면 판별
    /// 미세한 움직임이 감지되면 얕은 수면으로 판단
    private func isLightSleep() -> Bool {
        guard recentAccelMagnitudes.count >= 10 else { return false }

        let avgMotion = recentAccelMagnitudes.reduce(0, +) / Double(recentAccelMagnitudes.count)

        // 미세한 움직임이 있으면 (완전 정지가 아니면) 얕은 수면
        return avgMotion > lightSleepMotionThreshold
    }

    // MARK: - 알람 트리거
    private func triggerAlarm() {
        guard !isAlarmTriggered else { return }
        isAlarmTriggered = true

        // 점진적 햅틱: click 3회 -> 잠깐 대기 -> notification 3회
        let device = WKInterfaceDevice.current()

        // 1단계: 부드러운 click
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            device.play(.click)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            device.play(.click)
        }

        // 2단계: 2초 후 notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            device.play(.notification)
        }

        // 모니터링 정리
        checkTimer?.invalidate()
        checkTimer = nil
        motionManager.stopAccelerometerUpdates()
    }
}

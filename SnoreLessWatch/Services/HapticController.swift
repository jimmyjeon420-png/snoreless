import WatchKit
import Foundation

/// 햅틱 엔진 프로토콜 — 테스트 시 MockHapticEngine 주입 가능
protocol HapticEngine {
    func playHaptic(_ type: WKHapticType)
}

/// 실제 디바이스 햅틱 엔진 구현
struct DeviceHapticEngine: HapticEngine {
    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

/// 3단계 에스컬레이션 햅틱 컨트롤러
/// 코골이 확정 시 단계별로 강도를 높여 사용자를 깨움
class HapticController {

    // MARK: - 에스컬레이션 단계
    enum EscalationLevel: Int {
        case first = 1   // 약한 진동 (click)
        case second = 2  // 강한 진동 (notification)
        case third = 3   // 아이폰 에스컬레이션
    }

    // MARK: - 설정
    private let firstWaitDuration: TimeInterval = 5.0   // 1차 후 대기
    private let secondWaitDuration: TimeInterval = 10.0  // 2차 후 대기
    private let finalCooldown: TimeInterval = 30.0       // 최종 쿨다운

    // MARK: - 햅틱 엔진 (테스트 시 주입 가능)
    private let hapticEngine: HapticEngine

    // MARK: - 내부 상태
    private var currentLevel: EscalationLevel = .first
    private var escalationTimer: Timer?
    private var isEscalating = false
    private var settings = AppSettings()
    private var hapticIntensity: HapticIntensity = .medium

    // MARK: - 초기화
    init(hapticEngine: HapticEngine = DeviceHapticEngine()) {
        self.hapticEngine = hapticEngine
    }

    // MARK: - 에스컬레이션 트리거
    /// 코골이 감지 시 호출 — 3단계 에스컬레이션 시작
    func triggerEscalation(snoreDetector: SnoreDetector, phoneConnector: PhoneConnector) {
        guard !isEscalating else { return }
        isEscalating = true
        currentLevel = .first

        executeEscalation(
            snoreDetector: snoreDetector,
            phoneConnector: phoneConnector
        )
    }

    /// 단계별 에스컬레이션 실행
    private func executeEscalation(snoreDetector: SnoreDetector, phoneConnector: PhoneConnector) {
        switch currentLevel {
        case .first:
            // 1차: 약한 진동
            playFirstHaptic()

            // 5초 후 코골이 지속 여부 확인
            escalationTimer = Timer.scheduledTimer(
                withTimeInterval: firstWaitDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                if snoreDetector.isCurrentlySnoring {
                    self.currentLevel = .second
                    self.executeEscalation(
                        snoreDetector: snoreDetector,
                        phoneConnector: phoneConnector
                    )
                } else {
                    // 코골이 멈춤 — 에스컬레이션 종료
                    self.finishEscalation()
                }
            }

        case .second:
            // 2차: 강한 진동
            playSecondHaptic()

            // 10초 후 코골이 지속 여부 확인
            escalationTimer = Timer.scheduledTimer(
                withTimeInterval: secondWaitDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                if snoreDetector.isCurrentlySnoring {
                    self.currentLevel = .third
                    self.executeEscalation(
                        snoreDetector: snoreDetector,
                        phoneConnector: phoneConnector
                    )
                } else {
                    self.finishEscalation()
                }
            }

        case .third:
            // 3차: 아이폰 에스컬레이션 요청
            if settings.iPhoneEscalationEnabled {
                phoneConnector.sendEscalationRequest()
            }

            // 최종 쿨다운 후 에스컬레이션 종료
            escalationTimer = Timer.scheduledTimer(
                withTimeInterval: finalCooldown,
                repeats: false
            ) { [weak self] _ in
                self?.finishEscalation()
            }
        }
    }

    // MARK: - 진동 강도 업데이트
    func updateIntensity(_ intensity: HapticIntensity) {
        hapticIntensity = intensity
    }

    // MARK: - 햅틱 재생

    /// 1차: 연속 진동 (click) — 확실히 느끼도록 반복
    private func playFirstHaptic() {
        let count: Int
        let interval: Double
        switch hapticIntensity {
        case .light:  count = 5;  interval = 0.4
        case .medium: count = 8;  interval = 0.3
        case .strong: count = 12; interval = 0.25
        }
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) { [hapticEngine] in
                hapticEngine.playHaptic(.click)
            }
        }
    }

    /// 2차: 강한 연속 진동 (notification) — 못 무시하게
    private func playSecondHaptic() {
        let count: Int
        let interval: Double
        switch hapticIntensity {
        case .light:  count = 5;  interval = 0.4
        case .medium: count = 10; interval = 0.3
        case .strong: count = 15; interval = 0.2
        }
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) { [hapticEngine] in
                hapticEngine.playHaptic(.notification)
            }
        }
    }

    // MARK: - 에스컬레이션 종료
    private func finishEscalation() {
        escalationTimer?.invalidate()
        escalationTimer = nil
        isEscalating = false
        currentLevel = .first
    }

    // MARK: - 설정 업데이트
    /// PhoneConnector에서 설정 동기화 시 호출
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
    }

    // MARK: - 리셋
    func reset() {
        finishEscalation()
    }
}

import Foundation
import Combine

/// 코골이 판별 로직
/// 배경 소음 대비 진폭, 지속 시간, 반복 패턴으로 코골이를 감지
class SnoreDetector: ObservableObject {

    // MARK: - 감지 상태
    enum DetectionState: Equatable {
        case idle       // 대기 — 소리 없음
        case detecting  // 큰 소리 감지 시작 (아직 확정 아님)
        case confirmed  // 0.6초 이상 지속된 소리 1건 확인
        case snoring    // 30초 내 3회 이상 반복 — 코골이 확정
    }

    // MARK: - 공개 상태
    @Published var state: DetectionState = .idle
    @Published var snoreCount: Int = 0

    // MARK: - 콜백
    var onSnoreDetected: ((SnoreEventData) -> Void)?

    // MARK: - 배경 소음 기준
    var backgroundNoiseLevel: Double = -60.0

    // MARK: - 감지 설정
    private let thresholdAboveBackground: Double = 4.0   // 배경소음 + 4dB면 감지
    private let minDuration: TimeInterval = 0.2          // 0.2초 이상이면 유효
    private let maxDuration: TimeInterval = 8.0          // 최대 지속 시간
    private let repetitionWindow: TimeInterval = 60.0    // 60초 윈도우
    private let repetitionThreshold: Int = 2             // 2회면 확정
    private let cooldownDuration: TimeInterval = 30.0    // 코골이 확정 후 쿨다운

    // MARK: - 내부 추적
    private var detectionStartTime: Date?       // 큰 소리 시작 시점
    private var recentConfirmations: [Date] = [] // 최근 확인된 소리 이벤트 타임스탬프
    private var lastSnoreTime: Date?            // 마지막 코골이 확정 시점
    private var isInCooldown = false

    // MARK: - 이벤트 로그 (세션 종료 시 전송용)
    private(set) var eventLog: [SnoreEventData] = []

    // MARK: - 샘플 처리
    /// AudioMonitor에서 호출 — 매 버퍼마다 현재 dB 레벨 전달
    func processSample(level: Double, backgroundNoise: Double) {
        backgroundNoiseLevel = backgroundNoise
        let threshold = backgroundNoiseLevel + thresholdAboveBackground
        let now = Date()

        // 쿨다운 중이면 무시
        if isInCooldown {
            if let lastSnore = lastSnoreTime,
               now.timeIntervalSince(lastSnore) >= cooldownDuration {
                isInCooldown = false
                state = .idle
            } else {
                return
            }
        }

        let isLoud = level >= threshold

        switch state {
        case .idle:
            if isLoud {
                // 큰 소리 감지 시작
                detectionStartTime = now
                state = .detecting
            }

        case .detecting:
            guard let startTime = detectionStartTime else {
                state = .idle
                return
            }
            let duration = now.timeIntervalSince(startTime)

            if !isLoud {
                // 소리가 멈춤 — 최소 지속 시간 충족 여부 확인
                if duration >= minDuration {
                    confirmSoundEvent(at: now)
                } else {
                    // 너무 짧은 소리 — 무시
                    state = .idle
                    detectionStartTime = nil
                }
            } else if duration > maxDuration {
                // 최대 지속 시간 초과 — 코골이가 아닌 다른 소음
                state = .idle
                detectionStartTime = nil
            }

        case .confirmed:
            if isLoud {
                // 새로운 큰 소리 감지
                detectionStartTime = now
                state = .detecting
            }

        case .snoring:
            // 쿨다운 종료 후 idle로 복귀 (위에서 처리)
            break
        }
    }

    /// 소리 이벤트 1건 확인 — 반복 패턴 체크
    private func confirmSoundEvent(at time: Date) {
        // 오래된 확인 이벤트 제거 (윈도우 밖)
        recentConfirmations = recentConfirmations.filter { event in
            time.timeIntervalSince(event) <= repetitionWindow
        }

        // 현재 이벤트 추가
        recentConfirmations.append(time)

        if recentConfirmations.count >= repetitionThreshold {
            // 코골이 확정
            triggerSnoreEvent(at: time)
        } else {
            state = .confirmed
        }

        detectionStartTime = nil
    }

    /// 코골이 확정 처리
    private func triggerSnoreEvent(at time: Date) {
        snoreCount += 1
        state = .snoring
        lastSnoreTime = time
        isInCooldown = true

        // 이벤트 데이터 생성
        let eventData = SnoreEventData(
            timestamp: time,
            duration: minDuration,
            intensity: 0.7,
            hapticLevel: 0,
            stoppedAfterHaptic: false
        )
        eventLog.append(eventData)

        // 콜백 호출
        onSnoreDetected?(eventData)

        // 반복 기록 초기화
        recentConfirmations.removeAll()
    }

    // MARK: - 현재 코골이 진행 중인지 확인
    /// HapticController에서 에스컬레이션 판단에 사용
    var isCurrentlySnoring: Bool {
        return state == .snoring || state == .detecting
    }

    // MARK: - 리셋
    func reset() {
        state = .idle
        snoreCount = 0
        detectionStartTime = nil
        recentConfirmations.removeAll()
        lastSnoreTime = nil
        isInCooldown = false
        eventLog.removeAll()
    }
}

import Foundation

// MARK: - 워치 <-> 아이폰 통신 메시지

enum SnoreMessageKey {
    static let snoreDetected = "snoreDetected"
    static let escalationRequest = "escalationRequest"
    static let sessionStarted = "sessionStarted"
    static let sessionEnded = "sessionEnded"
    static let snoreLog = "snoreLog"
    static let settings = "settings"
}

struct SnoreEventData: Codable {
    let timestamp: Date
    let duration: TimeInterval      // 코골이 지속 시간 (초)
    let intensity: Double            // 소리 강도 (dB)
    let hapticLevel: Int             // 1=약, 2=중, 3=강(아이폰)
    let stoppedAfterHaptic: Bool     // 햅틱 후 멈췄는지
}

struct SleepSessionData: Codable {
    let startTime: Date
    let endTime: Date?
    let snoreEvents: [SnoreEventData]
    let totalSnoreDuration: TimeInterval
    let backgroundNoiseLevel: Double  // 캘리브레이션된 배경 소음
}

struct AppSettings: Codable {
    var iPhoneEscalationEnabled: Bool = false   // 기본 OFF
    var hapticSensitivity: Double = 1.0         // 0.5~2.0 (감도 조절)
    var calibrationDuration: TimeInterval = 300  // 캘리브레이션 5분
    var escalationDelay1: TimeInterval = 5       // 1차→2차 간격
    var escalationDelay2: TimeInterval = 10      // 2차→3차 간격
    var cooldownDuration: TimeInterval = 30      // 쿨다운

    static let `default` = AppSettings()
}

import Foundation

// MARK: - 워치 <-> 아이폰 통신 메시지

enum SnoreMessageKey {
    // MARK: - 메시지 버전 (워치/아이폰 간 호환성 체크)
    static let messageVersion = "messageVersion"
    static let currentVersion = 1

    static let snoreDetected = "snoreDetected"
    static let escalationRequest = "escalationRequest"
    static let sessionStarted = "sessionStarted"
    static let sessionEnded = "sessionEnded"
    static let snoreLog = "snoreLog"
    static let settings = "settings"

    // 스마트 알람
    static let smartAlarmEnabled = "smartAlarmEnabled"
    static let smartAlarmHour = "smartAlarmHour"
    static let smartAlarmMinute = "smartAlarmMinute"

    // 녹음 설정
    static let recordingEnabled = "recordingEnabled"

    // 파일 전송 메타데이터
    static let snoreRecordingFile = "snoreRecordingFile"
    static let recordingTimestamp = "recordingTimestamp"

    /// Check if a message version is compatible. Returns true if compatible.
    /// Messages without a version field are treated as legacy (v0) and still accepted.
    static func isCompatible(_ message: [String: Any]) -> Bool {
        guard let version = message[messageVersion] as? Int else {
            // Legacy message without version — accept but log
            print("[SnoreMessageKey] 버전 필드 없는 레거시 메시지 수신")
            return true
        }
        if version != currentVersion {
            print("[SnoreMessageKey] ⚠️ 메시지 버전 불일치: received=\(version), expected=\(currentVersion)")
            return false
        }
        return true
    }
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
    var escalationDelay1: TimeInterval = 5       // 1차에서 2차 간격
    var escalationDelay2: TimeInterval = 10      // 2차에서 3차 간격
    var cooldownDuration: TimeInterval = 30      // 쿨다운

    static let `default` = AppSettings()
}

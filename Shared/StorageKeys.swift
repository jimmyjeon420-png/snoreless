import Foundation

/// UserDefaults 키 중앙 관리 — 오타 방지 및 일관성 유지
enum StorageKeys {
    // MARK: - 수면 추적 (watchOS)
    static let sessionStartDate = "sleepTracking.sessionStartDate"
    static let wasMonitoring = "sleepTracking.wasMonitoring"
    static let hapticIntensity = "hapticIntensity"

    // MARK: - 지난밤 요약 (watchOS + Complication)
    static let lastNightSnoreCount = "lastNightSnoreCount"
    static let lastNightSleepScore = "lastNightSleepScore"
    static let lastNightSummary = "lastNightSummary"
    static let lastSessionDate = "lastSessionDate"

    // MARK: - 스마트 알람 (watchOS)
    static let smartAlarmEnabled = "smartAlarm.enabled"
    static let smartAlarmHour = "smartAlarm.hour"
    static let smartAlarmMinute = "smartAlarm.minute"

    // MARK: - 코골이 이벤트 로그 백업
    static let pendingEventLog = "snoreDetector.pendingEventLog"
}

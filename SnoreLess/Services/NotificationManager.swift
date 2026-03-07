import Foundation
import UserNotifications

/// 로컬 알림 관리자
/// 아침 리포트 알림, 취침 리마인더 담당
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - 권한 확인
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - 권한 요청
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            print("[Notification] 권한 요청 결과: \(granted)")
        } catch {
            print("[Notification] 권한 요청 실패: \(error)")
        }
    }

    // MARK: - 아침 리포트 메시지 포맷팅
    /// 테스트 가능한 정적 메서드 — 알림 제목/본문 생성
    static func morningReportMessage(snoreCount: Int, stoppedCount: Int) -> (title: String, body: String) {
        let title = String(localized: "어젯밤 리포트가 준비됐어요")
        let body: String
        if snoreCount == 0 {
            body = String(localized: "어젯밤은 코를 안 골았어요. 편안한 밤이었네요!")
        } else {
            body = String(localized: "코골이 \(snoreCount)회 감지, 진동으로 \(stoppedCount)회 멈췄어요")
        }
        return (title, body)
    }

    // MARK: - 아침 리포트 알림
    /// 수면 종료 후 아침 리포트 알림 예약
    func scheduleMorningReport(snoreCount: Int, stoppedCount: Int) {
        let message = Self.morningReportMessage(snoreCount: snoreCount, stoppedCount: stoppedCount)

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = "MORNING_REPORT"

        // 5초 후 즉시 알림 (수면 종료 직후)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "morning_report_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] 아침 리포트 알림 등록 실패: \(error)")
            } else {
                print("[Notification] 아침 리포트 알림 등록 완료")
            }
        }
    }

    // MARK: - 취침 리마인더 설정
    /// 매일 지정 시각에 취침 리마인더 알림
    func scheduleBedtimeReminder(hour: Int, minute: Int) {
        // 기존 취침 리마인더 제거
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["bedtime_reminder"]
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "곧 잠들 시간이에요")
        content.body = String(localized: "워치에서 수면 시작을 눌러주세요")
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "bedtime_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] 취침 리마인더 등록 실패: \(error)")
            } else {
                print("[Notification] 취침 리마인더 등록 완료: \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    // MARK: - 취침 리마인더 취소
    func cancelBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["bedtime_reminder"]
        )
        print("[Notification] 취침 리마인더 취소")
    }

    // MARK: - 모든 알림 초기화
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

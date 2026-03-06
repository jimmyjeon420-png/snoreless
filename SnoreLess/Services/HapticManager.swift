import UIKit

/// 아이폰 진동 관리자
/// 워치에서 에스컬레이션 요청이 오면 아이폰에서 진동을 발생시킨다
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// 에스컬레이션 진동 실행
    /// 0.5초 간격으로 3회 반복 진동
    func triggerEscalation() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        // 즉시 1회
        generator.notificationOccurred(.warning)

        // 0.5초 후 2회
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generator.notificationOccurred(.warning)
        }

        // 1.0초 후 3회
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generator.notificationOccurred(.warning)
        }
    }

    /// 단일 알림 진동
    func triggerNotification(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// 임팩트 진동 (강도 지정)
    func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

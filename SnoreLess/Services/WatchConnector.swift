import Foundation
import WatchConnectivity
import SwiftData

/// 아이폰 측 WatchConnectivity 매니저
/// 워치에서 오는 코골이 데이터 수신 및 설정 동기화 담당
class WatchConnector: NSObject, ObservableObject {
    // MARK: - 상태
    @Published var isWatchReachable = false
    @Published var lastReceivedSession: SleepSessionData?

    // SwiftData 저장용 (외부에서 modelContext 주입)
    private var modelContext: ModelContext?

    // MARK: - 초기화
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - ModelContext 설정
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - 워치에 설정 전송
    func sendSettings(_ settings: AppSettings) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(settings)
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            dict[SnoreMessageKey.settings] = true
            try WCSession.default.updateApplicationContext(dict)
            print("[WatchConnector] 설정 동기화 완료")
        } catch {
            print("[WatchConnector] 설정 전송 실패: \(error)")
        }
    }

    // MARK: - 수신된 세션 데이터를 SwiftData에 저장
    private func saveSessionData(_ sessionData: SleepSessionData) {
        guard let modelContext = modelContext else {
            print("[WatchConnector] modelContext 미설정, 저장 불가")
            return
        }

        let session = SleepSession(startTime: sessionData.startTime)
        session.endTime = sessionData.endTime
        session.totalSnoreCount = sessionData.snoreEvents.count
        session.totalSnoreDuration = sessionData.totalSnoreDuration
        session.backgroundNoiseLevel = sessionData.backgroundNoiseLevel
        session.isActive = (sessionData.endTime == nil)

        // 코골이 이벤트 변환
        for eventData in sessionData.snoreEvents {
            let event = SnoreEvent(
                timestamp: eventData.timestamp,
                duration: eventData.duration,
                intensity: eventData.intensity,
                hapticLevel: eventData.hapticLevel,
                stoppedAfterHaptic: eventData.stoppedAfterHaptic
            )
            event.session = session
            session.snoreEvents.append(event)
        }

        modelContext.insert(session)

        do {
            try modelContext.save()
            print("[WatchConnector] 세션 저장 완료: 이벤트 \(sessionData.snoreEvents.count)개")
        } catch {
            print("[WatchConnector] 세션 저장 실패: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        if let error = error {
            print("[WatchConnector] 활성화 실패: \(error)")
        } else {
            print("[WatchConnector] 활성화 완료: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchConnector] 세션 비활성화")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // 재활성화
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    // 실시간 메시지 수신 (워치에서 즉시 전송)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // 에스컬레이션 요청 처리
        if message[SnoreMessageKey.escalationRequest] != nil {
            DispatchQueue.main.async {
                HapticManager.shared.triggerEscalation()
            }
            print("[WatchConnector] 에스컬레이션 요청 수신, 진동 실행")
        }
    }

    // reply 핸들러 있는 메시지 수신
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // 에스컬레이션 요청
        if message[SnoreMessageKey.escalationRequest] != nil {
            DispatchQueue.main.async {
                HapticManager.shared.triggerEscalation()
            }
            replyHandler(["status": "ok"])
        }
    }

    // UserInfo 전송 수신 (백그라운드, 수면 세션 로그)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Watch PhoneConnector는 JSONSerialization dict + boolean flag로 전송
        // snoreLog=true 또는 sessionEnded=true 플래그로 구분

        if userInfo[SnoreMessageKey.sessionEnded] != nil {
            // 세션 종료 데이터 — dict에서 SleepSessionData 복원
            decodeAndSaveSession(from: userInfo)
        } else if userInfo[SnoreMessageKey.snoreLog] != nil {
            // 개별 코골이 이벤트 로그 (비긴급)
            decodeAndLogSnoreEvent(from: userInfo)
        }
    }

    /// dict → SleepSessionData 디코딩 후 저장
    private func decodeAndSaveSession(from userInfo: [String: Any]) {
        // flag key를 제거한 순수 데이터 dict를 JSON으로 변환
        var dict = userInfo
        dict.removeValue(forKey: SnoreMessageKey.sessionEnded)

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let sessionData = try? JSONDecoder().decode(SleepSessionData.self, from: data) else {
            print("[WatchConnector] 세션 데이터 디코딩 실패")
            return
        }

        DispatchQueue.main.async {
            self.lastReceivedSession = sessionData
            self.saveSessionData(sessionData)
        }
        print("[WatchConnector] 수면 세션 데이터 수신: 이벤트 \(sessionData.snoreEvents.count)개")
    }

    /// dict → SnoreEventData 디코딩 (개별 이벤트 로깅)
    private func decodeAndLogSnoreEvent(from userInfo: [String: Any]) {
        var dict = userInfo
        dict.removeValue(forKey: SnoreMessageKey.snoreLog)

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let event = try? JSONDecoder().decode(SnoreEventData.self, from: data) else {
            print("[WatchConnector] 코골이 이벤트 디코딩 실패")
            return
        }
        print("[WatchConnector] 코골이 이벤트 수신: \(event.timestamp)")
    }

    // ApplicationContext 수신
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // 워치에서 보내는 컨텍스트 처리 (필요 시 확장)
        print("[WatchConnector] ApplicationContext 수신: \(applicationContext.keys)")
    }
}

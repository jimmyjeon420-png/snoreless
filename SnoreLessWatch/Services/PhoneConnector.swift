import WatchConnectivity
import Foundation

/// WatchConnectivity 기반 아이폰 통신
class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {

    // MARK: - 상태
    @Published var isReachable = false
    private var session: WCSession?

    // MARK: - 설정 수신 콜백
    var onSettingsReceived: ((AppSettings) -> Void)?

    // MARK: - 초기화
    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[PhoneConnector] WCSession 미지원 환경")
            return
        }
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        session = wcSession
    }

    // MARK: - 긴급 메시지 전송 (에스컬레이션)
    func sendEscalationRequest() {
        guard let session = session, session.isReachable else {
            print("[PhoneConnector] 아이폰 연결 불가")
            return
        }

        let message: [String: Any] = [
            SnoreMessageKey.escalationRequest: true,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { reply in
            print("[PhoneConnector] 에스컬레이션 응답: \(reply)")
        }, errorHandler: { error in
            print("[PhoneConnector] 에스컬레이션 오류: \(error.localizedDescription)")
        })
    }

    // MARK: - 코골이 이벤트 로그 전송
    func sendSnoreLog(event: SnoreEventData) {
        guard let session = session else { return }

        guard let data = try? JSONEncoder().encode(event),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var userInfo = dict
        userInfo[SnoreMessageKey.snoreLog] = true
        session.transferUserInfo(userInfo)
    }

    // MARK: - 수면 세션 전송
    func sendSleepSession(_ sleepSession: SleepSessionData) {
        guard let session = session else { return }

        guard let data = try? JSONEncoder().encode(sleepSession),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var userInfo = dict
        userInfo[SnoreMessageKey.sessionEnded] = true
        session.transferUserInfo(userInfo)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
        if let error = error {
            print("[PhoneConnector] 세션 활성화 오류: \(error.localizedDescription)")
        } else {
            print("[PhoneConnector] 세션 활성화 완료")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    /// 설정 동기화 수신
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = try? JSONSerialization.data(withJSONObject: applicationContext),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onSettingsReceived?(settings)
        }
    }

    /// 실시간 메시지 수신
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message[SnoreMessageKey.settings] != nil {
            if let data = try? JSONSerialization.data(withJSONObject: message),
               let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onSettingsReceived?(settings)
                }
            }
            replyHandler(["status": "ok"])
        } else {
            replyHandler(["status": "unknown"])
        }
    }
}

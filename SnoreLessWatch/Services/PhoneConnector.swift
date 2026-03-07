import WatchConnectivity
import Foundation

/// WatchConnectivity 기반 아이폰 통신
class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {

    // MARK: - 상태
    @Published var isReachable = false
    private var session: WCSession?
    private var isSessionReady = false
    private var pendingMessages: [() -> Void] = []

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
        guard isSessionReady else {
            print("[PhoneConnector] 세션 미활성화 — 에스컬레이션 큐잉")
            pendingMessages.append { [weak self] in self?.sendEscalationRequest() }
            return
        }
        guard let session = session, session.isReachable else {
            print("[PhoneConnector] 아이폰 연결 불가")
            return
        }

        let message: [String: Any] = [
            SnoreMessageKey.escalationRequest: true,
            SnoreMessageKey.messageVersion: SnoreMessageKey.currentVersion,
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
        guard isSessionReady else {
            print("[PhoneConnector] 세션 미활성화 — snore log 큐잉")
            pendingMessages.append { [weak self] in self?.sendSnoreLog(event: event) }
            return
        }
        guard let session = session else { return }

        let dict: [String: Any]
        do {
            let data = try JSONEncoder().encode(event)
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[PhoneConnector] snore log serialization returned unexpected type")
                return
            }
            dict = decoded
        } catch {
            print("[PhoneConnector] snore log encoding failed: \(error)")
            return
        }

        var userInfo = dict
        userInfo[SnoreMessageKey.snoreLog] = true
        userInfo[SnoreMessageKey.messageVersion] = SnoreMessageKey.currentVersion
        session.transferUserInfo(userInfo)
    }

    // MARK: - 수면 세션 전송
    func sendSleepSession(_ sleepSession: SleepSessionData) {
        guard isSessionReady else {
            print("[PhoneConnector] 세션 미활성화 — sleep session 큐잉")
            pendingMessages.append { [weak self] in self?.sendSleepSession(sleepSession) }
            return
        }
        guard let session = session else { return }

        let dict: [String: Any]
        do {
            let data = try JSONEncoder().encode(sleepSession)
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[PhoneConnector] sleep session serialization returned unexpected type")
                return
            }
            dict = decoded
        } catch {
            print("[PhoneConnector] sleep session encoding failed: \(error)")
            return
        }

        var userInfo = dict
        userInfo[SnoreMessageKey.sessionEnded] = true
        userInfo[SnoreMessageKey.messageVersion] = SnoreMessageKey.currentVersion
        session.transferUserInfo(userInfo)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isReachable = session.isReachable
            if activationState == .activated && error == nil {
                self.isSessionReady = true
                // Flush any messages queued before session was ready
                let queued = self.pendingMessages
                self.pendingMessages.removeAll()
                for action in queued {
                    action()
                }
            }
        }
        if let error = error {
            print("[PhoneConnector] 세션 활성화 오류: \(error.localizedDescription)")
        } else {
            print("[PhoneConnector] 세션 활성화 완료 (state=\(activationState.rawValue))")
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
        guard SnoreMessageKey.isCompatible(applicationContext) else { return }

        let settings: AppSettings
        do {
            let data = try JSONSerialization.data(withJSONObject: applicationContext)
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("[PhoneConnector] settings decoding from applicationContext failed: \(error)")
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
        guard SnoreMessageKey.isCompatible(message) else {
            replyHandler(["status": "version_mismatch"])
            return
        }

        if message[SnoreMessageKey.settings] != nil {
            do {
                let data = try JSONSerialization.data(withJSONObject: message)
                let settings = try JSONDecoder().decode(AppSettings.self, from: data)
                DispatchQueue.main.async { [weak self] in
                    self?.onSettingsReceived?(settings)
                }
            } catch {
                print("[PhoneConnector] settings decoding from message failed: \(error)")
            }
            replyHandler(["status": "ok"])
        } else {
            replyHandler(["status": "unknown"])
        }
    }
}

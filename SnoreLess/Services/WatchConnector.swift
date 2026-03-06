import Foundation
import WatchConnectivity
import SwiftData

/// 아이폰 측 WatchConnectivity 매니저
/// 워치에서 오는 코골이 데이터 수신, 설정 동기화, 녹음 파일 수신 담당
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

    // MARK: - 스마트 알람 설정 전송
    func sendSmartAlarm(enabled: Bool, hour: Int, minute: Int) {
        guard WCSession.default.activationState == .activated else { return }

        let message: [String: Any] = [
            SnoreMessageKey.smartAlarmEnabled: enabled,
            SnoreMessageKey.smartAlarmHour: hour,
            SnoreMessageKey.smartAlarmMinute: minute
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[WatchConnector] 스마트 알람 전송 실패: \(error)")
            }
        } else {
            // 즉시 전달이 안 되면 applicationContext로 대체
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("[WatchConnector] 스마트 알람 컨텍스트 전송 실패: \(error)")
            }
        }
        print("[WatchConnector] 스마트 알람 동기화: \(enabled ? "ON" : "OFF") \(hour):\(String(format: "%02d", minute))")
    }

    // MARK: - 녹음 설정 전송
    func sendRecordingSetting(enabled: Bool) {
        guard WCSession.default.activationState == .activated else { return }

        let message: [String: Any] = [
            SnoreMessageKey.recordingEnabled: enabled
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[WatchConnector] 녹음 설정 전송 실패: \(error)")
            }
        }
        print("[WatchConnector] 녹음 설정 동기화: \(enabled ? "ON" : "OFF")")
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

            // 아침 리포트 알림
            let stoppedCount = sessionData.snoreEvents.filter(\.stoppedAfterHaptic).count
            NotificationManager.shared.scheduleMorningReport(
                snoreCount: sessionData.snoreEvents.count,
                stoppedCount: stoppedCount
            )
        } catch {
            print("[WatchConnector] 세션 저장 실패: \(error)")
        }
    }

    // MARK: - 녹음 파일 저장
    private func saveRecordingFile(_ fileURL: URL, metadata: [String: Any]) {
        let recordingsDir = SnorePlaybackView.recordingsDirectory

        let timestamp = metadata[SnoreMessageKey.recordingTimestamp] as? TimeInterval ?? Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timestamp)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "snore_\(formatter.string(from: date)).\(fileURL.pathExtension)"

        let destURL = recordingsDir.appendingPathComponent(filename)

        do {
            // 이미 같은 이름 파일 있으면 덮어쓰기
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: destURL)
            print("[WatchConnector] 녹음 파일 저장 완료: \(filename)")
        } catch {
            print("[WatchConnector] 녹음 파일 저장 실패: \(error)")
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
        if userInfo[SnoreMessageKey.sessionEnded] != nil {
            decodeAndSaveSession(from: userInfo)
        } else if userInfo[SnoreMessageKey.snoreLog] != nil {
            decodeAndLogSnoreEvent(from: userInfo)
        }
    }

    // 파일 전송 수신 (코골이 녹음)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        print("[WatchConnector] 파일 수신: \(file.fileURL.lastPathComponent)")
        saveRecordingFile(file.fileURL, metadata: metadata)
    }

    /// dict에서 SleepSessionData 디코딩 후 저장
    private func decodeAndSaveSession(from userInfo: [String: Any]) {
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

    /// dict에서 SnoreEventData 디코딩 (개별 이벤트 로깅)
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
        print("[WatchConnector] ApplicationContext 수신: \(applicationContext.keys)")
    }
}

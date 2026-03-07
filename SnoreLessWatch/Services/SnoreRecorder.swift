import AVFoundation
import WatchConnectivity
import Foundation

/// 코골이 구간 녹음기
/// 코골이 확정 시 5초 오디오 클립을 저장하고 iPhone으로 전송
class SnoreRecorder {

    // MARK: - 설정
    private let maxClipCount = 10
    private let clipDuration: TimeInterval = 5.0
    private let clipExpirationDays: TimeInterval = 7 * 24 * 60 * 60  // 7일

    // MARK: - 내부 상태
    private var audioRecorder: AVAudioRecorder?
    private var isRecording = false
    private var recordingTimer: Timer?
    private var clipDirectory: URL

    // MARK: - 초기화
    init() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            clipDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("SnoreClips", isDirectory: true)
            print("[SnoreRecorder] documents directory unavailable, using temp directory")
            return
        }
        clipDirectory = docs.appendingPathComponent("SnoreClips", isDirectory: true)

        // 디렉토리 생성
        do {
            try FileManager.default.createDirectory(at: clipDirectory, withIntermediateDirectories: true)
        } catch {
            print("[SnoreRecorder] clip directory creation failed: \(error)")
        }
    }

    // MARK: - 녹음 트리거 (코골이 확정 시 호출)
    func recordSnoreClip() {
        guard !isRecording else { return }

        // 파일명: snore_타임스탬프.m4a
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "snore_\(timestamp).m4a"
        let fileURL = clipDirectory.appendingPathComponent(fileName)

        // AAC 녹음 설정
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record(forDuration: clipDuration)
            isRecording = true

            // 5초 후 녹음 완료 처리
            recordingTimer = Timer.scheduledTimer(withTimeInterval: clipDuration + 0.5, repeats: false) { [weak self] _ in
                self?.finishRecording()
            }
        } catch {
            print("[SnoreRecorder] 녹음 시작 실패: \(error.localizedDescription)")
            isRecording = false
        }
    }

    // MARK: - 녹음 완료
    private func finishRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        // 오래된 클립 정리 (최대 10개)
        cleanupOldClips()

        // iPhone으로 전송
        transferLatestClip()
    }

    // MARK: - 오래된 클립 삭제
    private func cleanupOldClips() {
        let fm = FileManager.default
        let files: [URL]
        do {
            files = try fm.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter({ $0.pathExtension == "m4a" })
                .sorted(by: { url1, url2 in
                    // resourceValues failure is harmless here — falls back to distantPast for sort order
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    return date1 < date2
                })
        } catch {
            print("[SnoreRecorder] failed to list clip directory for cleanup: \(error)")
            return
        }

        // 7일 이상 된 클립 만료 삭제
        let now = Date()
        for file in files {
            if let creationDate = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
               now.timeIntervalSince(creationDate) > clipExpirationDays {
                try? fm.removeItem(at: file)
            }
        }

        // 최대 개수 초과 시 오래된 것부터 삭제
        let remaining: [URL]
        do {
            remaining = try fm.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "m4a" }
        } catch { return }

        if remaining.count > maxClipCount {
            let sorted = remaining.sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return d1 < d2
            }
            for file in sorted.prefix(remaining.count - maxClipCount) {
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - iPhone 전송
    private func transferLatestClip() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // 가장 최근 파일 전송
        let fm = FileManager.default
        let files: [URL]
        do {
            files = try fm.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter({ $0.pathExtension == "m4a" })
                .sorted(by: { url1, url2 in
                    // resourceValues failure is harmless here — falls back to distantPast for sort order
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    return date1 > date2
                })
        } catch {
            print("[SnoreRecorder] failed to list clip directory for transfer: \(error)")
            return
        }
        guard let latestFile = files.first else { return }

        let metadata: [String: Any] = [
            "type": "snoreClip",
            "timestamp": Date().timeIntervalSince1970
        ]

        session.transferFile(latestFile, metadata: metadata)
        print("[SnoreRecorder] 클립 전송: \(latestFile.lastPathComponent)")
    }

    // MARK: - 전체 클립 삭제
    func deleteAllClips() {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: nil)
            for file in files {
                do {
                    try fm.removeItem(at: file)
                } catch {
                    print("[SnoreRecorder] failed to delete clip \(file.lastPathComponent): \(error)")
                }
            }
        } catch {
            print("[SnoreRecorder] failed to list clip directory for deletion: \(error)")
        }
    }

    // MARK: - 클립 개수
    var clipCount: Int {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "m4a" }
            return files.count
        } catch {
            print("[SnoreRecorder] failed to count clips: \(error)")
            return 0
        }
    }
}

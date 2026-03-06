import SwiftUI
import AVFoundation

struct SnorePlaybackView: View {
    @State private var recordings: [SnoreRecording] = []
    @State private var currentlyPlaying: URL?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E) HH:mm"
        return f
    }()

    private let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    var body: some View {
        Group {
            if recordings.isEmpty {
                ContentUnavailableView(
                    "녹음이 없습니다",
                    systemImage: "waveform.slash",
                    description: Text("워치에서 코골이가 녹음되면\n여기에서 들을 수 있어요")
                )
            } else {
                List {
                    ForEach(recordings) { recording in
                        recordingRow(recording)
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("코골이 녹음")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadRecordings() }
        .onDisappear { stopPlayback() }
    }

    // MARK: - 녹음 행
    private func recordingRow(_ recording: SnoreRecording) -> some View {
        HStack(spacing: 14) {
            // 재생/정지 버튼
            Button {
                togglePlayback(recording)
            } label: {
                ZStack {
                    Circle()
                        .fill(currentlyPlaying == recording.url ? Color.cyan : Color(.systemGray5))
                        .frame(width: 44, height: 44)

                    if currentlyPlaying == recording.url {
                        // 재생 중 - 정지 아이콘
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .buttonStyle(.plain)

            // 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: recording.date))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(durationFormatter.string(from: recording.duration) ?? "0:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if currentlyPlaying == recording.url {
                        // 재생 진행 바
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray4))
                                    .frame(height: 3)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.cyan)
                                    .frame(width: geo.size.width * playbackProgress, height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }

            Spacer()

            // 파일 크기
            Text(recording.fileSizeText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 녹음 파일 로드
    private func loadRecordings() {
        let recordingsDir = Self.recordingsDirectory

        guard FileManager.default.fileExists(atPath: recordingsDir.path) else {
            recordings = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsDir,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: .skipsHiddenFiles
            )

            recordings = files
                .filter { $0.pathExtension == "m4a" || $0.pathExtension == "wav" || $0.pathExtension == "caf" }
                .compactMap { url -> SnoreRecording? in
                    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let date = values?.creationDate ?? Date()
                    let size = values?.fileSize ?? 0

                    // 재생 시간 계산
                    let duration: TimeInterval
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        duration = player.duration
                    } else {
                        duration = 0
                    }

                    return SnoreRecording(
                        url: url,
                        date: date,
                        duration: duration,
                        fileSize: size
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            print("[Playback] 녹음 파일 로드 실패: \(error)")
            recordings = []
        }
    }

    // MARK: - 재생 토글
    private func togglePlayback(_ recording: SnoreRecording) {
        if currentlyPlaying == recording.url {
            stopPlayback()
        } else {
            startPlayback(recording)
        }
    }

    private func startPlayback(_ recording: SnoreRecording) {
        stopPlayback()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioPlayer?.play()
            currentlyPlaying = recording.url
            playbackProgress = 0

            // 진행 업데이트 타이머
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard let player = audioPlayer else { return }
                if player.isPlaying {
                    playbackProgress = player.currentTime / player.duration
                } else {
                    stopPlayback()
                }
            }
        } catch {
            print("[Playback] 재생 실패: \(error)")
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlaying = nil
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - 삭제
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            if currentlyPlaying == recording.url {
                stopPlayback()
            }
            try? FileManager.default.removeItem(at: recording.url)
        }
        recordings.remove(atOffsets: offsets)
    }

    // MARK: - 녹음 디렉토리
    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SnoreRecordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }
}

// MARK: - 녹음 모델
struct SnoreRecording: Identifiable {
    let id = UUID()
    let url: URL
    let date: Date
    let duration: TimeInterval
    let fileSize: Int

    var fileSizeText: String {
        let kb = Double(fileSize) / 1024.0
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        } else {
            return String(format: "%.1f MB", kb / 1024.0)
        }
    }
}

#Preview {
    NavigationStack {
        SnorePlaybackView()
    }
}

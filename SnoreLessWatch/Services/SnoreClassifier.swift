import SoundAnalysis
import AVFoundation
import Combine
import CoreMedia

/// Apple SoundAnalysis ML classifier for snoring detection
/// Uses Apple's built-in SNClassifySoundRequest (.version1) which includes snoring detection
/// Available on watchOS 10+
class SnoreClassifier: NSObject, ObservableObject {
    private var analyzer: SNAudioStreamAnalyzer?
    private var analysisQueue = DispatchQueue(label: "com.snoreless.analysis")
    private var framePosition: AVAudioFramePosition = 0

    struct ClassificationResult {
        let soundType: SoundEventType
        let confidence: Double
    }

    @Published var latestResult: ClassificationResult? = nil
    @Published var isAvailable = false

    /// 편의 프로퍼티 (기존 코드 호환)
    var isSnoring: Bool { latestResult?.soundType == .snoring && (latestResult?.confidence ?? 0) > confidenceThreshold }
    var confidence: Double { latestResult?.confidence ?? 0 }

    /// Confidence thresholds
    private let confidenceThreshold: Double = 0.5
    private let secondaryThreshold: Double = 0.4  // 기침/잠꼬대용 (더 낮은 기준)

    /// Labels from Apple's classifier
    private let snoringLabels = ["snoring", "breathing", "snore"]
    private let coughLabels = ["cough", "coughing"]
    private let talkingLabels = ["speech", "talking", "conversation"]

    // MARK: - Analysis Control

    /// Set up the audio stream analyzer with the given format
    func startAnalysis(format: AVAudioFormat) {
        analysisQueue.async { [weak self] in
            guard let self = self else { return }

            self.analyzer = SNAudioStreamAnalyzer(format: format)
            self.framePosition = 0

            do {
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                request.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 48000)
                request.overlapFactor = 0.5
                try self.analyzer?.add(request, withObserver: self)

                DispatchQueue.main.async {
                    self.isAvailable = true
                    print("[SnoreClassifier] ML classifier started successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAvailable = false
                    print("[SnoreClassifier] Setup failed (falling back to dB detection): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Feed an audio buffer to the analyzer
    func analyze(buffer: AVAudioPCMBuffer) {
        analysisQueue.async { [weak self] in
            guard let self = self, let analyzer = self.analyzer else { return }
            analyzer.analyze(buffer, atAudioFramePosition: self.framePosition)
            self.framePosition += AVAudioFramePosition(buffer.frameLength)
        }
    }

    /// Stop analysis and clean up
    func stopAnalysis() {
        analysisQueue.async { [weak self] in
            self?.analyzer?.removeAllRequests()
            self?.analyzer = nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = false
            self?.latestResult = nil
            self?.framePosition = 0
        }
    }
}

// MARK: - SNResultsObserving

extension SnoreClassifier: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }

        // 각 소리 타입별 최고 신뢰도 계산
        var bestSnoring: Double = 0
        var bestCough: Double = 0
        var bestTalking: Double = 0

        for classification in classificationResult.classifications {
            let id = classification.identifier.lowercased()
            let conf = Double(classification.confidence)

            if snoringLabels.contains(where: { id.contains($0) }) {
                bestSnoring = max(bestSnoring, conf)
            }
            if coughLabels.contains(where: { id.contains($0) }) {
                bestCough = max(bestCough, conf)
            }
            if talkingLabels.contains(where: { id.contains($0) }) {
                bestTalking = max(bestTalking, conf)
            }
        }

        // 가장 높은 신뢰도의 소리 타입 선택
        let candidates: [(SoundEventType, Double, Double)] = [
            (.snoring, bestSnoring, confidenceThreshold),
            (.cough, bestCough, secondaryThreshold),
            (.talking, bestTalking, secondaryThreshold),
        ]

        let best = candidates
            .filter { $0.1 >= $0.2 }  // 임계값 이상만
            .max(by: { $0.1 < $1.1 })

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let best = best {
                self.latestResult = ClassificationResult(soundType: best.0, confidence: best.1)
            } else {
                self.latestResult = nil
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("[SnoreClassifier] Analysis error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.latestResult = nil
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        // Analysis stream completed
    }
}

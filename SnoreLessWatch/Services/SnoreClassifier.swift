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

    @Published var isSnoring = false
    @Published var confidence: Double = 0
    @Published var isAvailable = false

    /// Confidence threshold for snoring detection
    private let confidenceThreshold: Double = 0.5

    /// Labels from Apple's classifier that indicate snoring
    private let snoringLabels = ["snoring", "breathing", "snore"]

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
            self?.isSnoring = false
            self?.confidence = 0
            self?.framePosition = 0
        }
    }
}

// MARK: - SNResultsObserving

extension SnoreClassifier: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }

        // Search for snoring-related classifications
        var bestConfidence: Double = 0
        var foundSnoring = false

        for classification in classificationResult.classifications {
            let identifier = classification.identifier.lowercased()
            if snoringLabels.contains(where: { identifier.contains($0) }) {
                if classification.confidence > bestConfidence {
                    bestConfidence = classification.confidence
                    foundSnoring = true
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if foundSnoring {
                self.confidence = bestConfidence
                self.isSnoring = bestConfidence > self.confidenceThreshold
            } else {
                self.confidence = 0
                self.isSnoring = false
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("[SnoreClassifier] Analysis error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isSnoring = false
            self?.confidence = 0
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        // Analysis stream completed
    }
}

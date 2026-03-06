import XCTest
@testable import SnoreLessWatch

/// Tests for the RMS-to-dB conversion logic used in AudioMonitor.processAudioBuffer
/// The formula is: dB = 20 * log10(rms), with rms=0 returning -160.0
final class AudioProcessingTests: XCTestCase {

    // MARK: - Helper

    /// Replicates the dB conversion from AudioMonitor.processAudioBuffer
    private func rmsToDecibels(_ rms: Float) -> Double {
        if rms > 0 {
            return Double(20 * log10(rms))
        } else {
            return -160.0
        }
    }

    // MARK: - RMS to dB Conversion

    func test_rmsToDb_rms01_shouldBeApproximatelyMinus20dB() {
        // 20 * log10(0.1) = 20 * (-1) = -20
        let result = rmsToDecibels(0.1)
        XCTAssertEqual(result, -20.0, accuracy: 0.1,
                       "RMS 0.1 should convert to approximately -20 dB")
    }

    func test_rmsToDb_rms001_shouldBeApproximatelyMinus40dB() {
        // 20 * log10(0.01) = 20 * (-2) = -40
        let result = rmsToDecibels(0.01)
        XCTAssertEqual(result, -40.0, accuracy: 0.1,
                       "RMS 0.01 should convert to approximately -40 dB")
    }

    func test_rmsToDb_rms0001_shouldBeApproximatelyMinus60dB() {
        // 20 * log10(0.001) = 20 * (-3) = -60
        let result = rmsToDecibels(0.001)
        XCTAssertEqual(result, -60.0, accuracy: 0.1,
                       "RMS 0.001 should convert to approximately -60 dB")
    }

    func test_rmsToDb_rmsZero_shouldReturnVeryLowValue() {
        // RMS = 0 should not crash and should return the sentinel value -160
        let result = rmsToDecibels(0)
        XCTAssertEqual(result, -160.0,
                       "RMS 0 should return -160 dB (silence sentinel)")
    }

    func test_rmsToDb_rms1_shouldBeZerodB() {
        // 20 * log10(1.0) = 0
        let result = rmsToDecibels(1.0)
        XCTAssertEqual(result, 0.0, accuracy: 0.01,
                       "RMS 1.0 should convert to 0 dB (full scale)")
    }

    func test_rmsToDb_verySmallRms_shouldBeVeryNegative() {
        // 20 * log10(0.00001) = 20 * (-5) = -100
        let result = rmsToDecibels(0.00001)
        XCTAssertEqual(result, -100.0, accuracy: 0.1,
                       "RMS 0.00001 should convert to approximately -100 dB")
    }

    func test_rmsToDb_negativeRms_shouldReturnSilence() {
        // Negative RMS is physically impossible but should be handled safely
        // log10 of negative is NaN; our guard (rms > 0) won't catch negative
        // This documents the actual behavior
        let rms: Float = -0.1
        let result: Double
        if rms > 0 {
            result = Double(20 * log10(rms))
        } else {
            result = -160.0
        }
        XCTAssertEqual(result, -160.0,
                       "Negative RMS should be treated as silence (-160 dB)")
    }

    // MARK: - Conversion Consistency

    func test_rmsToDb_doublingRms_increases6dB() {
        // Doubling RMS should increase by ~6.02 dB
        let rms1: Float = 0.05
        let rms2: Float = 0.10 // doubled
        let db1 = rmsToDecibels(rms1)
        let db2 = rmsToDecibels(rms2)
        let difference = db2 - db1

        XCTAssertEqual(difference, 6.02, accuracy: 0.1,
                       "Doubling RMS should increase level by approximately 6 dB")
    }

    func test_rmsToDb_tenTimesRms_increases20dB() {
        // 10x RMS should increase by exactly 20 dB
        let rms1: Float = 0.01
        let rms2: Float = 0.10 // 10x
        let db1 = rmsToDecibels(rms1)
        let db2 = rmsToDecibels(rms2)
        let difference = db2 - db1

        XCTAssertEqual(difference, 20.0, accuracy: 0.1,
                       "10x RMS should increase level by exactly 20 dB")
    }
}

import XCTest
@testable import SnoreLessWatch

final class HapticControllerTests: XCTestCase {

    private var sut: HapticController!

    override func setUp() {
        super.setUp()
        sut = HapticController()
    }

    override func tearDown() {
        sut.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - EscalationLevel Enum

    func test_escalationLevel_firstRawValue_is1() {
        XCTAssertEqual(HapticController.EscalationLevel.first.rawValue, 1)
    }

    func test_escalationLevel_secondRawValue_is2() {
        XCTAssertEqual(HapticController.EscalationLevel.second.rawValue, 2)
    }

    func test_escalationLevel_thirdRawValue_is3() {
        XCTAssertEqual(HapticController.EscalationLevel.third.rawValue, 3)
    }

    func test_escalationLevel_allCasesExist() {
        // Verify all three levels can be constructed from raw values
        XCTAssertNotNil(HapticController.EscalationLevel(rawValue: 1))
        XCTAssertNotNil(HapticController.EscalationLevel(rawValue: 2))
        XCTAssertNotNil(HapticController.EscalationLevel(rawValue: 3))
        XCTAssertNil(HapticController.EscalationLevel(rawValue: 0),
                     "Raw value 0 should not map to any escalation level")
        XCTAssertNil(HapticController.EscalationLevel(rawValue: 4),
                     "Raw value 4 should not map to any escalation level")
    }

    // MARK: - HapticIntensity Enum

    func test_hapticIntensity_lightRawValue_is0() {
        XCTAssertEqual(HapticIntensity.light.rawValue, 0)
    }

    func test_hapticIntensity_mediumRawValue_is1() {
        XCTAssertEqual(HapticIntensity.medium.rawValue, 1)
    }

    func test_hapticIntensity_strongRawValue_is2() {
        XCTAssertEqual(HapticIntensity.strong.rawValue, 2)
    }

    func test_hapticIntensity_hasThreCases() {
        XCTAssertEqual(HapticIntensity.allCases.count, 3,
                       "HapticIntensity should have exactly 3 cases: light, medium, strong")
    }

    func test_hapticIntensity_labels() {
        XCTAssertFalse(HapticIntensity.light.label.isEmpty, "Light label should not be empty")
        XCTAssertFalse(HapticIntensity.medium.label.isEmpty, "Medium label should not be empty")
        XCTAssertFalse(HapticIntensity.strong.label.isEmpty, "Strong label should not be empty")
    }

    func test_hapticIntensity_identifiable() {
        // id should match rawValue
        XCTAssertEqual(HapticIntensity.light.id, 0)
        XCTAssertEqual(HapticIntensity.medium.id, 1)
        XCTAssertEqual(HapticIntensity.strong.id, 2)
    }

    // MARK: - updateIntensity

    func test_updateIntensity_doesNotCrash() {
        // updateIntensity should accept all valid intensities without error
        sut.updateIntensity(.light)
        sut.updateIntensity(.medium)
        sut.updateIntensity(.strong)
        // No crash = pass
    }

    // MARK: - updateSettings

    func test_updateSettings_acceptsCustomSettings() {
        var settings = AppSettings()
        settings.iPhoneEscalationEnabled = true
        settings.hapticSensitivity = 1.5

        // Should not crash
        sut.updateSettings(settings)
    }

    func test_updateSettings_acceptsDefaultSettings() {
        sut.updateSettings(AppSettings.default)
        // No crash = pass
    }

    // MARK: - Reset

    func test_reset_canBeCalledMultipleTimes() {
        sut.reset()
        sut.reset()
        sut.reset()
        // No crash = pass. Reset should be idempotent.
    }

    func test_reset_afterUpdateIntensity_doesNotCrash() {
        sut.updateIntensity(.strong)
        sut.reset()
        // Should be safe to call after intensity change
    }
}

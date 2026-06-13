import XCTest
@testable import cursorSpeedometer

final class BrightnessControllerTests: XCTestCase {
    private let controller = BrightnessController()
    private let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    func testManualBrightnessUsedWhenAutoDisabled() {
        let brightness = controller.resolvedBrightness(
            at: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: timeZone,
            autoBrightnessEnabled: false,
            manualBrightness: 0.4,
            ambientBrightness: 1.0
        )

        XCTAssertEqual(brightness, 0.4, accuracy: 0.01)
    }

    func testAmbientBrightnessPreferredWhenAvailable() {
        let brightness = controller.resolvedBrightness(
            at: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: timeZone,
            autoBrightnessEnabled: true,
            manualBrightness: 0.4,
            ambientBrightness: 0.2
        )

        XCTAssertLessThan(brightness, 0.5)
    }

    func testSolarFallbackBrightDuringDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 12
        components.timeZone = timeZone
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let brightness = controller.resolvedBrightness(
            at: date,
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: timeZone,
            autoBrightnessEnabled: true,
            manualBrightness: 0.4,
            ambientBrightness: nil
        )

        XCTAssertEqual(brightness, BrightnessController.maxBrightness, accuracy: 0.01)
    }

    func testClampPreventsOutOfRangeValues() {
        XCTAssertEqual(controller.clamp(2.0), BrightnessController.maxBrightness)
        XCTAssertEqual(controller.clamp(0.01), BrightnessController.minBrightness)
    }

    func testDimmingOpacityStaysInRange() {
        XCTAssertEqual(BrightnessClamp.dimmingOpacity(for: 1.0), 0, accuracy: 0.01)
        XCTAssertEqual(BrightnessClamp.dimmingOpacity(for: 0.15), 0.85, accuracy: 0.01)
        XCTAssertEqual(BrightnessClamp.dimmingOpacity(for: 5.0), 0, accuracy: 0.01)
        XCTAssertEqual(BrightnessClamp.dimmingOpacity(for: -1.0), 1, accuracy: 0.01)
    }
}

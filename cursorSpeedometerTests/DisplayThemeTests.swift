import XCTest
@testable import cursorSpeedometer

final class DisplayThemeTests: XCTestCase {
    func testNightPaletteIsDistinct() {
        let night = ThemePalette.palette(for: .night)
        XCTAssertTrue(ThemePaletteValidator.nightUsesRedChannelOnly(night))
    }

    func testAmberPaletteIsDistinct() {
        let amber = ThemePalette.palette(for: .amber)
        XCTAssertTrue(ThemePaletteValidator.amberUsesWarmTones(amber))
    }

    func testDayPaletteDiffersFromNight() {
        let day = ThemePalette.palette(for: .day)
        let night = ThemePalette.palette(for: .night)
        XCTAssertNotEqual(day, night)
    }

    func testIsDayPresetOnlyTrueForDay() {
        XCTAssertTrue(ThemePalette.palette(for: .day).isDayPreset)
        XCTAssertFalse(ThemePalette.palette(for: .night).isDayPreset)
        XCTAssertFalse(ThemePalette.palette(for: .amber).isDayPreset)
    }
}

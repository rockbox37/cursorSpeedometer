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
}

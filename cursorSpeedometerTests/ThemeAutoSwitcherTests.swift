import XCTest
@testable import cursorSpeedometer

final class ThemeAutoSwitcherTests: XCTestCase {
    private let switcher = ThemeAutoSwitcher()
    private let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    func testAutoThemeUsesNightAfterSunset() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 22
        components.timeZone = timeZone
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let theme = switcher.resolvedTheme(
            query: SolarQuery(
                date: date,
                latitude: 37.7749,
                longitude: -122.4194,
                timeZone: timeZone
            ),
            autoThemeEnabled: true,
            pinnedTheme: .day
        )

        XCTAssertEqual(theme, .night)
    }

    func testAutoThemeUsesDayAfterSunrise() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 10
        components.timeZone = timeZone
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let theme = switcher.resolvedTheme(
            query: SolarQuery(
                date: date,
                latitude: 37.7749,
                longitude: -122.4194,
                timeZone: timeZone
            ),
            autoThemeEnabled: true,
            pinnedTheme: .night
        )

        XCTAssertEqual(theme, .day)
    }

    func testManualPinUsedWhenAutoThemeDisabled() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 10
        components.timeZone = timeZone
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let theme = switcher.resolvedTheme(
            query: SolarQuery(
                date: date,
                latitude: 37.7749,
                longitude: -122.4194,
                timeZone: timeZone
            ),
            autoThemeEnabled: false,
            pinnedTheme: .amber
        )

        XCTAssertEqual(theme, .amber)
    }
}

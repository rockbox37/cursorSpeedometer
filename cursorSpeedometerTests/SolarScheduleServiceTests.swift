import XCTest
@testable import cursorSpeedometer

final class SolarScheduleServiceTests: XCTestCase {
    private let service = SolarScheduleService()

    func testSanFranciscoJuneHasDaytimeAtNoon() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 12
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let isDay = service.isDaytime(
            at: date,
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        )

        XCTAssertTrue(isDay)
    }

    func testSanFranciscoJuneHasNighttimeAtMidnight() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 0
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let isDay = service.isDaytime(
            at: date,
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        )

        XCTAssertFalse(isDay)
    }

    func testSunrisePrecedesSunset() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 12
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let schedule = service.schedule(
            for: date,
            latitude: 37.7749,
            longitude: -122.4194,
            timeZone: timeZone
        )

        XCTAssertLessThan(schedule.sunrise, schedule.sunset)
    }
}

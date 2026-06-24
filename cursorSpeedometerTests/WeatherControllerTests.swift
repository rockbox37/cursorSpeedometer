import XCTest
@testable import cursorSpeedometer

private struct FakeWeatherProvider: WeatherProvider {
    let snapshotForUnit: @Sendable (TemperatureUnit, Int) -> WeatherSnapshot

    func fetch(
        latitude: Double,
        longitude: Double,
        unit: TemperatureUnit,
        windowHours: Int
    ) async throws -> WeatherSnapshot {
        snapshotForUnit(unit, windowHours)
    }
}

@MainActor
final class WeatherControllerTests: XCTestCase {
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2
    ) async {
        let start = Date()
        while !condition() && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testUpdateLocationFetchesSnapshot() async {
        let expected = WeatherSnapshot(temperature: 70, unit: .fahrenheit, rainExpectedInHours: 2)
        let controller = WeatherController(
            provider: FakeWeatherProvider { _, _ in expected },
            unit: .fahrenheit
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }

        XCTAssertEqual(controller.snapshot, expected)
    }

    func testNoFetchWithoutLocation() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { unit, _ in
                WeatherSnapshot(temperature: 1, unit: unit, rainExpectedInHours: nil)
            }
        )

        controller.start()
        await waitUntil({ controller.snapshot != nil }, timeout: 0.3)

        XCTAssertNil(controller.snapshot)
        controller.stop()
    }

    func testSetUnitRefetchesWithNewUnit() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { unit, _ in
                WeatherSnapshot(
                    temperature: unit == .celsius ? 21 : 70,
                    unit: unit,
                    rainExpectedInHours: nil
                )
            },
            unit: .fahrenheit
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot?.unit == .fahrenheit }
        XCTAssertEqual(controller.snapshot?.temperature, 70)

        controller.setUnit(.celsius)
        await waitUntil { controller.snapshot?.unit == .celsius }
        XCTAssertEqual(controller.snapshot?.temperature, 21)
    }

    func testSetWindowHoursRefetchesWithNewWindow() async {
        // Echo the requested window back as rainExpectedInHours so we can assert it.
        let controller = WeatherController(
            provider: FakeWeatherProvider { unit, windowHours in
                WeatherSnapshot(temperature: 70, unit: unit, rainExpectedInHours: windowHours)
            },
            unit: .fahrenheit,
            windowHours: 6
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot?.rainExpectedInHours == 6 }

        controller.setWindowHours(3)
        await waitUntil { controller.snapshot?.rainExpectedInHours == 3 }
        XCTAssertEqual(controller.snapshot?.rainExpectedInHours, 3)
    }

    func testWarmReadingUsesStandardRefreshInterval() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _, _ in
                WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: nil)
            },
            unit: .fahrenheit
        )

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }

        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.standardRefreshInterval)
        controller.stop()
    }

    func testNearFreezingReadingUsesFasterRefreshInterval() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _, _ in
                WeatherSnapshot(temperature: 35, unit: .fahrenheit, rainExpectedInHours: nil)
            },
            unit: .fahrenheit
        )

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }

        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.nearFreezingRefreshInterval)
        controller.stop()
    }

    func testStopClearsActiveRefreshInterval() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _, _ in
                WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: nil)
            },
            unit: .fahrenheit
        )

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.activeRefreshInterval != nil }

        controller.stop()
        XCTAssertNil(controller.activeRefreshInterval)
    }
}

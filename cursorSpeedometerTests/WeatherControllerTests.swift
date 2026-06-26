import XCTest
@testable import cursorSpeedometer

private struct FakeWeatherProvider: WeatherProvider {
    let snapshotForConfig: @Sendable (WeatherForecastConfig) -> WeatherSnapshot

    func fetch(
        latitude: Double,
        longitude: Double,
        config: WeatherForecastConfig
    ) async throws -> WeatherSnapshot {
        snapshotForConfig(config)
    }
}

/// Counts how many times a fetch is requested (accessed on the main actor).
private final class CountingWeatherProvider: WeatherProvider, @unchecked Sendable {
    private(set) var fetchCount = 0
    private let snapshot: WeatherSnapshot

    init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    func fetch(
        latitude: Double,
        longitude: Double,
        config: WeatherForecastConfig
    ) async throws -> WeatherSnapshot {
        fetchCount += 1
        return snapshot
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
            provider: FakeWeatherProvider { _ in expected },
            unit: .fahrenheit
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }

        XCTAssertEqual(controller.snapshot, expected)
    }

    func testNoFetchWithoutLocation() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { config in
                WeatherSnapshot(temperature: 1, unit: config.unit, rainExpectedInHours: nil)
            }
        )

        controller.start()
        await waitUntil({ controller.snapshot != nil }, timeout: 0.3)

        XCTAssertNil(controller.snapshot)
        controller.stop()
    }

    func testSetUnitRefetchesWithNewUnit() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { config in
                WeatherSnapshot(
                    temperature: config.unit == .celsius ? 21 : 70,
                    unit: config.unit,
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
            provider: FakeWeatherProvider { config in
                WeatherSnapshot(temperature: 70, unit: config.unit, rainExpectedInHours: config.rainWindowHours)
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

    func testSetLowTempThresholdRefetches() async {
        // Echo the threshold back via lowTempExpectedInHours so we can observe refetch.
        let controller = WeatherController(
            provider: FakeWeatherProvider { config in
                WeatherSnapshot(
                    temperature: 70,
                    unit: config.unit,
                    rainExpectedInHours: nil,
                    lowTempExpectedInHours: config.lowTempThresholdFahrenheit.map { Int($0) }
                )
            },
            unit: .fahrenheit,
            lowTempThresholdFahrenheit: 50
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot?.lowTempExpectedInHours == 50 }

        controller.setLowTempThresholdFahrenheit(45)
        await waitUntil { controller.snapshot?.lowTempExpectedInHours == 45 }
        XCTAssertEqual(controller.snapshot?.lowTempExpectedInHours, 45)
    }

    func testSetLowTempWindowRefetches() async {
        // Echo the low-temp window back via lowTempExpectedInHours.
        let controller = WeatherController(
            provider: FakeWeatherProvider { config in
                WeatherSnapshot(
                    temperature: 70,
                    unit: config.unit,
                    rainExpectedInHours: nil,
                    lowTempExpectedInHours: config.lowTempWindowHours
                )
            },
            unit: .fahrenheit,
            lowTempWindowHours: 6
        )

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot?.lowTempExpectedInHours == 6 }

        controller.setLowTempWindowHours(9)
        await waitUntil { controller.snapshot?.lowTempExpectedInHours == 9 }
        XCTAssertEqual(controller.snapshot?.lowTempExpectedInHours, 9)
    }

    func testWarmReadingUsesStandardRefreshInterval() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _ in
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
            provider: FakeWeatherProvider { _ in
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

    func testRefetchesAfterSignificantMove() async {
        let provider = CountingWeatherProvider(
            snapshot: WeatherSnapshot(temperature: 70, unit: .fahrenheit, rainExpectedInHours: nil)
        )
        let controller = WeatherController(provider: provider, unit: .fahrenheit)

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { provider.fetchCount >= 1 }

        // A small move (~11 m) must not trigger a refetch.
        controller.updateLocation(latitude: 37.0001, longitude: -122)
        // A large move (~11 km) must.
        controller.updateLocation(latitude: 37.1, longitude: -122)
        await waitUntil { provider.fetchCount >= 2 }

        XCTAssertEqual(provider.fetchCount, 2)
        controller.stop()
    }

    func testFasterCadenceWhileRiding() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _ in
                WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: nil)
            },
            unit: .fahrenheit
        )

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }
        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.standardRefreshInterval)

        // Move ~111 m (counts as movement, under the refetch distance) -> riding cadence.
        controller.updateLocation(latitude: 37.001, longitude: -122)
        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.ridingRefreshInterval)
        controller.stop()
    }

    func testRidingCadenceRevertsToStandardAfterIdle() async {
        var current = Date(timeIntervalSince1970: 1_000)
        let controller = WeatherController(
            provider: FakeWeatherProvider { _ in
                WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: nil)
            },
            unit: .fahrenheit,
            now: { current }
        )

        controller.start()
        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.snapshot != nil }

        controller.updateLocation(latitude: 37.001, longitude: -122)
        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.ridingRefreshInterval)

        // Advance past the idle timeout, then a tiny (non-movement) update.
        current = current.addingTimeInterval(WeatherController.ridingIdleTimeout + 1)
        controller.updateLocation(latitude: 37.0011, longitude: -122)
        XCTAssertEqual(controller.activeRefreshInterval, WeatherController.standardRefreshInterval)
        controller.stop()
    }

    func testDistanceMetersApproximatesKnownSpan() {
        // ~0.1° of latitude is ~11.1 km.
        let distance = WeatherController.distanceMeters((latitude: 37, longitude: -122), (latitude: 37.1, longitude: -122))
        XCTAssertEqual(distance, 11_119, accuracy: 200)
    }

    func testStopClearsActiveRefreshInterval() async {
        let controller = WeatherController(
            provider: FakeWeatherProvider { _ in
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

import XCTest
@testable import cursorSpeedometer

private struct FakeAlertProvider: AlertProvider {
    let result: @Sendable () -> SevereWeatherAlert?

    func fetchActiveAlert(latitude: Double, longitude: Double) async throws -> SevereWeatherAlert? {
        result()
    }
}

@MainActor
final class SevereWeatherAlertControllerTests: XCTestCase {
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2
    ) async {
        let start = Date()
        while !condition() && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testUpdateLocationFetchesAlert() async {
        let expected = SevereWeatherAlert(category: .tornado, level: .warning, event: "Tornado Warning")
        let controller = SevereWeatherAlertController(provider: FakeAlertProvider { expected })

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil { controller.alert != nil }

        XCTAssertEqual(controller.alert, expected)
    }

    func testNoFetchWithoutLocation() async {
        let controller = SevereWeatherAlertController(
            provider: FakeAlertProvider {
                SevereWeatherAlert(category: .thunderstorm, level: .watch, event: "Severe Thunderstorm Watch")
            }
        )

        controller.start()
        await waitUntil({ controller.alert != nil }, timeout: 0.3)

        XCTAssertNil(controller.alert)
        controller.stop()
    }

    func testClearsAlertWhenNoneActive() async {
        let controller = SevereWeatherAlertController(provider: FakeAlertProvider { nil })

        controller.updateLocation(latitude: 37, longitude: -122)
        await waitUntil({ controller.alert != nil }, timeout: 0.3)

        XCTAssertNil(controller.alert)
        controller.stop()
    }
}

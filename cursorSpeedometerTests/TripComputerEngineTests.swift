import XCTest
@testable import cursorSpeedometer

final class TripComputerEngineTests: XCTestCase {
    private let engine = TripComputerEngine()
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testJitterFilterSuppressesLowSpeed() {
        let sample = LocationSample(
            speedMetersPerSecond: 0.5,
            timestamp: baseDate,
            horizontalAccuracy: 10,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        let result = engine.process(sample: sample, state: TripComputerState())
        XCTAssertEqual(result.currentSpeedMps, 0)
    }

    func testTracksMaxAndAverageSpeed() {
        let first = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let second = LocationSample(
            speedMetersPerSecond: 20,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: first, state: TripComputerState())
        state = engine.process(sample: second, state: state)

        XCTAssertEqual(state.maxSpeedMps, 20, accuracy: 0.01)
        XCTAssertEqual(state.averageSpeedMps, 15, accuracy: 0.01)
    }

    func testAccumulatesTripAndOdometerDistance() {
        let first = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let second = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00018,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: first, state: TripComputerState())
        state = engine.process(sample: second, state: state)

        XCTAssertEqual(state.tripDistanceMeters, 20, accuracy: 0.5)
        XCTAssertEqual(state.odometerMeters, 20, accuracy: 0.5)
    }

    func testSnapsToZeroWhenPositionBarelyChanges() {
        let moving = LocationSample(
            speedMetersPerSecond: 12,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let stopped = LocationSample(
            speedMetersPerSecond: 1.2,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000001,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: moving, state: TripComputerState())
        state = engine.process(sample: stopped, state: state)

        XCTAssertEqual(state.currentSpeedMps, 0, accuracy: 0.01)
    }

    func testStaleSampleTimeoutClearsSpeed() {
        let sample = LocationSample(
            speedMetersPerSecond: 15,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: sample, state: TripComputerState())
        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(2))

        XCTAssertEqual(state.currentSpeedMps, 0)
    }

    func testResetTripPreservesOdometer() {
        var state = TripComputerState(
            tripDistanceMeters: 100,
            maxSpeedMps: 25,
            odometerMeters: 500
        )
        state = engine.resetTrip(state: state)

        XCTAssertEqual(state.tripDistanceMeters, 0)
        XCTAssertEqual(state.odometerMeters, 500)
        XCTAssertEqual(state.maxSpeedMps, 0)
    }

    func testIgnoresPoorAccuracySamples() {
        let sample = LocationSample(
            speedMetersPerSecond: 15,
            timestamp: baseDate,
            horizontalAccuracy: 80,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        let result = engine.process(sample: sample, state: TripComputerState())
        XCTAssertEqual(result.currentSpeedMps, 0)
    }
}

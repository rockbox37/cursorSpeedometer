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

        let result = engine.process(sample: sample, state: TripComputerState(), now: baseDate)
        XCTAssertEqual(result.currentSpeedMps, 0)
    }

    func testFirstSampleAnchorsWithoutSpeedOrMax() {
        let sample = LocationSample(
            speedMetersPerSecond: 80,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        let result = engine.process(sample: sample, state: TripComputerState(), now: baseDate)

        XCTAssertEqual(result.currentSpeedMps, 0)
        XCTAssertEqual(result.maxSpeedMps, 0)
        XCTAssertEqual(result.lastSample, sample)
    }

    func testTracksMaxAndAverageSpeed() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let moderate = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009,
            coordinateLongitude: -122.0
        )
        let fast = LocationSample(
            speedMetersPerSecond: 20,
            timestamp: baseDate.addingTimeInterval(3),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00045,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moderate, state: state, now: baseDate.addingTimeInterval(1))
        state = engine.process(sample: fast, state: state, now: baseDate.addingTimeInterval(3))

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

        var state = engine.process(sample: first, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: second, state: state, now: baseDate.addingTimeInterval(2))

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

        var state = engine.process(sample: moving, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: stopped, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 0, accuracy: 0.01)
    }

    func testDelayedDeliveryDoesNotZeroSpeedBetweenUpdates() {
        let anchor = LocationSample(
            speedMetersPerSecond: 6,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let moving = LocationSample(
            speedMetersPerSecond: 6,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000054,
            coordinateLongitude: -122.0
        )
        let delayed = LocationSample(
            speedMetersPerSecond: 6,
            timestamp: baseDate.addingTimeInterval(2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000108,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))
        state = engine.process(sample: delayed, state: state, now: baseDate.addingTimeInterval(4))

        XCTAssertEqual(state.currentSpeedMps, 6, accuracy: 0.2)
        XCTAssertEqual(state.lastSample, delayed)
    }

    func testRejectsStaleCachedFixOnResume() {
        let stale = LocationSample(
            speedMetersPerSecond: 50,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        let result = engine.process(
            sample: stale,
            state: TripComputerState(),
            now: baseDate.addingTimeInterval(10)
        )

        XCTAssertNil(result.lastSample)
        XCTAssertEqual(result.currentSpeedMps, 0)
    }

    func testResumeAfterGapDoesNotSpikeMaxSpeed() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let moving = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009,
            coordinateLongitude: -122.0
        )
        let spike = LocationSample(
            speedMetersPerSecond: 90,
            timestamp: baseDate.addingTimeInterval(30),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.01,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))
        state = engine.process(sample: spike, state: state, now: baseDate.addingTimeInterval(30))

        XCTAssertEqual(state.currentSpeedMps, 0)
        XCTAssertEqual(state.maxSpeedMps, 10, accuracy: 0.01)
    }

    func testPositionJumpSpikeReAnchorsWithoutCorruptingMax() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let moving = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009,
            coordinateLongitude: -122.0
        )
        let jump = LocationSample(
            speedMetersPerSecond: 5,
            timestamp: baseDate.addingTimeInterval(2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00072,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))
        state = engine.process(sample: jump, state: state, now: baseDate.addingTimeInterval(2))

        XCTAssertEqual(state.currentSpeedMps, 0)
        XCTAssertEqual(state.maxSpeedMps, 10, accuracy: 0.01)
    }

    func testCruisingSpeedTracksWithoutArtificialCap() {
        let anchor = LocationSample(
            speedMetersPerSecond: 11.2,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)

        for second in 1...5 {
            let sample = LocationSample(
                speedMetersPerSecond: 11.2,
                timestamp: baseDate.addingTimeInterval(Double(second)),
                horizontalAccuracy: 5,
                coordinateLatitude: 37.0 + 0.0001 * Double(second),
                coordinateLongitude: -122.0
            )
            state = engine.process(
                sample: sample,
                state: state,
                now: baseDate.addingTimeInterval(Double(second))
            )
        }

        XCTAssertEqual(state.currentSpeedMps, 11.2, accuracy: 0.5)
        XCTAssertEqual(state.maxSpeedMps, 11.2, accuracy: 0.5)
    }

    func testStaleSampleTimeoutClearsSpeed() {
        let sample = LocationSample(
            speedMetersPerSecond: 15,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: sample, state: TripComputerState(), now: baseDate)
        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(1.5))
        XCTAssertEqual(state.currentSpeedMps, 15, accuracy: 0.01)

        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(4))
        XCTAssertEqual(state.currentSpeedMps, 0)
    }

    func testStaleTimeoutUsesProcessingTimeNotFixTimestamp() {
        let first = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        let second = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1.2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: first, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: second, state: state, now: baseDate.addingTimeInterval(1.2))
        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(2.5))

        XCTAssertEqual(state.currentSpeedMps, 10, accuracy: 0.1)
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

        let result = engine.process(sample: sample, state: TripComputerState(), now: baseDate)
        XCTAssertEqual(result.currentSpeedMps, 0)
    }
}

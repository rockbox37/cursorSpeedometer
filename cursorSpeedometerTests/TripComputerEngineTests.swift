import XCTest
@testable import cursorSpeedometer

// A cohesive suite of engine scenarios; length is intentional.
// swiftlint:disable type_body_length file_length
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
        // Position advances ~10 m in 1s, matching the 10 m/s Doppler reading.
        let moderate = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000089931,
            coordinateLongitude: -122.0
        )
        // Position advances ~40 m over the next 2s, matching the 20 m/s Doppler reading.
        let fast = LocationSample(
            speedMetersPerSecond: 20,
            timestamp: baseDate.addingTimeInterval(3),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000449655,
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

    func testPositionJumpKeepsGpsSpeedWithoutCorruptingMax() {
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
        // Position glitches ~70 m forward in 1s, but the Doppler reading is a sane 5 m/s.
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

        // The trusted Doppler speed is shown instead of flashing 0, and the position
        // glitch never inflates max speed.
        XCTAssertEqual(state.currentSpeedMps, 5, accuracy: 0.01)
        XCTAssertEqual(state.maxSpeedMps, 10, accuracy: 0.01)
    }

    func testNearDuplicateFixAtSpeedDoesNotFlashZero() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10.7,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // ~10.7 m north of the anchor over 1s establishes a cruising speed.
        let moving = LocationSample(
            speedMetersPerSecond: 10.7,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0000964,
            coordinateLongitude: -122.0
        )
        // GPS still reports ~24 mph but the reported position barely moved (a jittery
        // or coalesced fix). The displayed speed must hold, not drop to 0.
        let duplicate = LocationSample(
            speedMetersPerSecond: 10.7,
            timestamp: baseDate.addingTimeInterval(2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009645,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))
        state = engine.process(sample: duplicate, state: state, now: baseDate.addingTimeInterval(2))

        XCTAssertEqual(state.currentSpeedMps, 10.7, accuracy: 0.3)
    }

    func testDisplayedSpeedTracksGpsNotLaggierDerived() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // Reported position advanced only ~8 m (derived ~8 m/s) while the Doppler
        // reading is the more responsive 10 m/s. The display should follow the Doppler.
        let moving = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00007207,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 10, accuracy: 0.3)
    }

    func testLaggingDopplerDuringAccelerationUsesResponsiveDerived() {
        let anchor = LocationSample(
            speedMetersPerSecond: 9,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // The rider is accelerating: position advanced ~13 m in 1s (derived ~13 m/s),
        // but the Doppler reading still lags at 9 m/s. The display must follow the
        // faster, truer position-derived speed instead of staying pinned low.
        let accelerating = LocationSample(
            speedMetersPerSecond: 9,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000117,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: accelerating, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 13, accuracy: 0.5)
    }

    func testLowMovingSpeedIsNotSnappedToZero() {
        let anchor = LocationSample(
            speedMetersPerSecond: 0.9,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // Pulling away at ~2 mph: position advances ~0.9 m in 1s and the Doppler agrees.
        // This is genuine movement, not stopped jitter, so it must read the real speed.
        let creeping = LocationSample(
            speedMetersPerSecond: 0.9,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0000081,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: creeping, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 0.9, accuracy: 0.2)
    }

    func testInvalidDopplerFallsBackToDerivedSpeed() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // Doppler is unavailable (negative). Position advanced ~10 m over 1s.
        let moving = LocationSample(
            speedMetersPerSecond: -1,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009009,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 10, accuracy: 0.5)
    }

    func testEgregiousDopplerSpikeFallsBackToDerived() {
        let anchor = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // Doppler glitches to 50 m/s but position only moved ~10 m (derived ~10 m/s),
        // so the spike is rejected and max speed is not corrupted.
        let spike = LocationSample(
            speedMetersPerSecond: 50,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.00009009,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: spike, state: state, now: baseDate.addingTimeInterval(1))

        XCTAssertEqual(state.currentSpeedMps, 10, accuracy: 0.5)
        XCTAssertEqual(state.maxSpeedMps, 10, accuracy: 0.5)
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
        let anchor = LocationSample(
            speedMetersPerSecond: 15,
            timestamp: baseDate,
            horizontalAccuracy: 5,
            coordinateLatitude: 37.0,
            coordinateLongitude: -122.0
        )
        // ~15 m north of the anchor over 1s yields a ~15 m/s derived speed.
        let moving = LocationSample(
            speedMetersPerSecond: 15,
            timestamp: baseDate.addingTimeInterval(1),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000135,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: anchor, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: moving, state: state, now: baseDate.addingTimeInterval(1))
        XCTAssertEqual(state.currentSpeedMps, 15, accuracy: 0.2)

        // 1s since the last processed update: not stale yet.
        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(2))
        XCTAssertEqual(state.currentSpeedMps, 15, accuracy: 0.2)

        // 4s since the last processed update: speed should clear.
        state = engine.applyStaleSampleTimeout(state: state, now: baseDate.addingTimeInterval(5))
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
        // ~12 m north over 1.2s gives a derived speed matching the 10 m/s GPS reading.
        let second = LocationSample(
            speedMetersPerSecond: 10,
            timestamp: baseDate.addingTimeInterval(1.2),
            horizontalAccuracy: 5,
            coordinateLatitude: 37.000107919,
            coordinateLongitude: -122.0
        )

        var state = engine.process(sample: first, state: TripComputerState(), now: baseDate)
        state = engine.process(sample: second, state: state, now: baseDate.addingTimeInterval(1.2))
        // 1.3s after the last processed update (baseDate+1.2): not stale, so the
        // speed is retained even though the fix timestamp is older.
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
// swiftlint:enable type_body_length file_length

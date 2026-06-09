import Foundation

struct LocationSample: Equatable, Sendable {
    let speedMetersPerSecond: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    let coordinateLatitude: Double
    let coordinateLongitude: Double
}

struct TripComputerState: Equatable, Sendable {
    var currentSpeedMps: Double = 0
    var tripDistanceMeters: Double = 0
    var maxSpeedMps: Double = 0
    var averageSpeedMps: Double = 0
    var odometerMeters: Double = 0
    var speedSampleCount: Int = 0
    var speedSumMps: Double = 0
    var lastSample: LocationSample?
}

struct TripComputerEngine: Sendable {
    static let jitterThresholdKmh = 2.0
    static let jitterThresholdMps = jitterThresholdKmh / 3.6
    static let maxAccuracyMeters = 50.0
    static let staleSampleSeconds = 1.0
    /// Snap to zero when GPS reports movement but position barely changed.
    static let stationaryDistanceMeters = 1.0

    func process(sample: LocationSample, state: TripComputerState) -> TripComputerState {
        guard sample.horizontalAccuracy <= Self.maxAccuracyMeters,
              sample.horizontalAccuracy >= 0 else {
            return state
        }

        var updated = state
        let candidateSpeed = resolvedSpeed(from: sample, previous: state.lastSample)
        let effectiveSpeed = candidateSpeed < Self.jitterThresholdMps ? 0 : candidateSpeed

        if let previous = state.lastSample {
            let delta = sample.timestamp.timeIntervalSince(previous.timestamp)
            if delta > 0, effectiveSpeed > 0 {
                let distance = effectiveSpeed * delta
                updated.tripDistanceMeters += distance
                updated.odometerMeters += distance
            }
        }

        updated.currentSpeedMps = effectiveSpeed
        if effectiveSpeed > updated.maxSpeedMps {
            updated.maxSpeedMps = effectiveSpeed
        }

        if effectiveSpeed > 0 {
            updated.speedSampleCount += 1
            updated.speedSumMps += effectiveSpeed
            updated.averageSpeedMps = updated.speedSumMps / Double(updated.speedSampleCount)
        }

        updated.lastSample = sample
        return updated
    }

    func applyStaleSampleTimeout(state: TripComputerState, now: Date = Date()) -> TripComputerState {
        guard let lastSample = state.lastSample else { return state }
        guard now.timeIntervalSince(lastSample.timestamp) > Self.staleSampleSeconds else { return state }

        var updated = state
        updated.currentSpeedMps = 0
        return updated
    }

    func resetTrip(state: TripComputerState) -> TripComputerState {
        TripComputerState(
            currentSpeedMps: state.currentSpeedMps,
            tripDistanceMeters: 0,
            maxSpeedMps: 0,
            averageSpeedMps: 0,
            odometerMeters: state.odometerMeters,
            speedSampleCount: 0,
            speedSumMps: 0,
            lastSample: state.lastSample
        )
    }

    func resetOdometer(state: TripComputerState) -> TripComputerState {
        var updated = state
        updated.odometerMeters = 0
        return updated
    }

    private func resolvedSpeed(from sample: LocationSample, previous: LocationSample?) -> Double {
        let gpsSpeed = sample.speedMetersPerSecond >= 0 ? sample.speedMetersPerSecond : 0

        guard let previous else {
            return gpsSpeed
        }

        let delta = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard delta > 0 else {
            return gpsSpeed
        }

        let distance = coordinateDistanceMeters(
            fromLatitude: previous.coordinateLatitude,
            fromLongitude: previous.coordinateLongitude,
            toLatitude: sample.coordinateLatitude,
            toLongitude: sample.coordinateLongitude
        )

        if distance < Self.stationaryDistanceMeters {
            return 0
        }

        let derivedSpeed = distance / delta

        if gpsSpeed <= 0 {
            return derivedSpeed
        }

        return min(gpsSpeed, derivedSpeed)
    }

    private func coordinateDistanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = fromLatitude * .pi / 180
        let lat2 = toLatitude * .pi / 180
        let dLat = (toLatitude - fromLatitude) * .pi / 180
        let dLon = (toLongitude - fromLongitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    private func sin(_ value: Double) -> Double { Foundation.sin(value) }
    private func cos(_ value: Double) -> Double { Foundation.cos(value) }
    private func atan2(_ lhs: Double, _ rhs: Double) -> Double { Foundation.atan2(lhs, rhs) }
    private func sqrt(_ value: Double) -> Double { Foundation.sqrt(value) }
}

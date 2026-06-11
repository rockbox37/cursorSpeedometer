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
    var lastProcessedAt: Date?
}

struct TripComputerEngine: Sendable {
    static let jitterThresholdKmh = 2.0
    static let jitterThresholdMps = jitterThresholdKmh / 3.6
    static let maxAccuracyMeters = 50.0
    /// Clear displayed speed only after this long without a processed location update.
    static let staleSampleSeconds = 3.0
    /// Snap to zero when GPS reports movement but position barely changed.
    static let stationaryDistanceMeters = 1.0
    /// Ignore cached GPS fixes older than this when processing.
    static let maxSampleAgeSeconds = 3.0
    /// Gaps longer than this re-anchor without contributing speed or distance.
    static let resumeGapSeconds = 5.0
    /// Hard ceiling for motorcycle / e-bike use (~200 km/h).
    static let maxPlausibleSpeedMps = 55.0
    /// Derived speed wildly above GPS usually means a position glitch.
    static let derivedSpikeMultiplier = 2.5

    func process(
        sample: LocationSample,
        state: TripComputerState,
        now: Date = Date()
    ) -> TripComputerState {
        guard sample.horizontalAccuracy <= Self.maxAccuracyMeters,
              sample.horizontalAccuracy >= 0 else {
            return state
        }

        if state.lastSample == nil,
           now.timeIntervalSince(sample.timestamp) > Self.maxSampleAgeSeconds {
            return state
        }

        if let previous = state.lastSample {
            let gap = sample.timestamp.timeIntervalSince(previous.timestamp)
            if gap <= 0 || gap > Self.resumeGapSeconds {
                return anchorSample(sample, state: state, now: now)
            }
        } else {
            return anchorSample(sample, state: state, now: now)
        }

        let previous = state.lastSample!
        let delta = sample.timestamp.timeIntervalSince(previous.timestamp)
        let components = speedComponents(from: sample, previous: previous)

        if isPositionSpike(components: components) {
            return anchorSample(sample, state: state, now: now)
        }

        var updated = state
        let candidateSpeed = min(components.resolved, Self.maxPlausibleSpeedMps)
        let effectiveSpeed = candidateSpeed < Self.jitterThresholdMps ? 0 : candidateSpeed

        if effectiveSpeed > 0 {
            let distance = effectiveSpeed * delta
            updated.tripDistanceMeters += distance
            updated.odometerMeters += distance
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
        updated.lastProcessedAt = now
        return updated
    }

    private func anchorSample(_ sample: LocationSample, state: TripComputerState, now: Date) -> TripComputerState {
        var updated = state
        updated.currentSpeedMps = 0
        updated.lastSample = sample
        updated.lastProcessedAt = now
        return updated
    }

    func applyStaleSampleTimeout(state: TripComputerState, now: Date = Date()) -> TripComputerState {
        guard let lastProcessedAt = state.lastProcessedAt else { return state }
        guard now.timeIntervalSince(lastProcessedAt) > Self.staleSampleSeconds else { return state }

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
            lastSample: state.lastSample,
            lastProcessedAt: state.lastProcessedAt
        )
    }

    func resetOdometer(state: TripComputerState) -> TripComputerState {
        var updated = state
        updated.odometerMeters = 0
        return updated
    }

    private struct SpeedComponents {
        let resolved: Double
        let derived: Double
        let gps: Double
    }

    private func speedComponents(from sample: LocationSample, previous: LocationSample) -> SpeedComponents {
        let gpsSpeed = sample.speedMetersPerSecond >= 0 ? sample.speedMetersPerSecond : 0
        let delta = sample.timestamp.timeIntervalSince(previous.timestamp)

        guard delta > 0 else {
            return SpeedComponents(resolved: gpsSpeed, derived: gpsSpeed, gps: gpsSpeed)
        }

        let distance = coordinateDistanceMeters(
            fromLatitude: previous.coordinateLatitude,
            fromLongitude: previous.coordinateLongitude,
            toLatitude: sample.coordinateLatitude,
            toLongitude: sample.coordinateLongitude
        )

        if distance < Self.stationaryDistanceMeters {
            return SpeedComponents(resolved: 0, derived: 0, gps: gpsSpeed)
        }

        let derivedSpeed = distance / delta
        let resolvedSpeed = if gpsSpeed <= 0 {
            derivedSpeed
        } else {
            min(gpsSpeed, derivedSpeed)
        }

        return SpeedComponents(resolved: resolvedSpeed, derived: derivedSpeed, gps: gpsSpeed)
    }

    private func isPositionSpike(components: SpeedComponents) -> Bool {
        if components.derived > Self.maxPlausibleSpeedMps {
            return true
        }

        if components.gps > 0,
           components.derived > components.gps * Self.derivedSpikeMultiplier,
           components.derived > 8.0 {
            return true
        }

        return false
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

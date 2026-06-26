import Foundation

@MainActor
final class WeatherController: ObservableObject {
    /// Default refresh cadence while the app is foregrounded and stationary.
    static let standardRefreshInterval: TimeInterval = 900
    /// Faster cadence while the rider is actively moving, so the reading keeps up
    /// with the changing location. Still far under Open-Meteo's free-tier limits.
    static let ridingRefreshInterval: TimeInterval = 300
    /// Faster cadence when it is near or below freezing, where icing risk makes
    /// timely updates valuable. Still far under Open-Meteo's free-tier limits.
    static let nearFreezingRefreshInterval: TimeInterval = 240
    /// Refetch immediately once the rider has moved at least this far (metres)
    /// from where the current reading was fetched.
    static let significantMoveMeters: Double = 5_000
    /// Minimum distance (metres) between consecutive fixes to count as movement,
    /// filtering out GPS jitter while stationary.
    static let movementThresholdMeters: Double = 50
    /// How long after the last detected movement the rider is still considered
    /// "riding" for cadence purposes.
    static let ridingIdleTimeout: TimeInterval = 120

    @Published private(set) var snapshot: WeatherSnapshot?

    /// Currently-scheduled refresh interval (nil while stopped). Exposed for tests.
    private(set) var activeRefreshInterval: TimeInterval?

    private let provider: WeatherProvider
    private let now: () -> Date
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var coordinate: (latitude: Double, longitude: Double)?
    private var lastFetchCoordinate: (latitude: Double, longitude: Double)?
    private var lastObservedCoordinate: (latitude: Double, longitude: Double)?
    private var lastMovementAt: Date?
    private var unit: TemperatureUnit
    private var windowHours: Int
    private var lowTempWindowHours: Int
    private var lowTempThresholdFahrenheit: Double?
    private var isRunning = false

    init(
        provider: WeatherProvider = OpenMeteoWeatherService(),
        unit: TemperatureUnit = .fahrenheit,
        windowHours: Int = OpenMeteoMapper.defaultForecastWindowHours,
        lowTempWindowHours: Int = OpenMeteoMapper.defaultForecastWindowHours,
        lowTempThresholdFahrenheit: Double? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.now = now
        self.unit = unit
        self.windowHours = OpenMeteoMapper.clampWindowHours(windowHours)
        self.lowTempWindowHours = OpenMeteoMapper.clampWindowHours(lowTempWindowHours)
        self.lowTempThresholdFahrenheit = lowTempThresholdFahrenheit
    }

    /// Begin (or resume) periodic refreshes. Safe to call repeatedly.
    func start() {
        isRunning = true
        fetch()
        scheduleTimer(interval: desiredInterval())
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        activeRefreshInterval = nil
        fetchTask?.cancel()
        fetchTask = nil
    }

    func updateLocation(latitude: Double, longitude: Double) {
        let new = (latitude: latitude, longitude: longitude)

        // Track movement (vs. the previous fix) to drive the riding cadence.
        if let previous = lastObservedCoordinate,
           Self.distanceMeters(previous, new) >= Self.movementThresholdMeters {
            lastMovementAt = now()
        }
        lastObservedCoordinate = new

        let isFirstFix = coordinate == nil
        coordinate = new

        if isFirstFix {
            // Fetch immediately once a real location is known.
            fetch()
            return
        }

        // Refetch once the rider has moved a meaningful distance from the last
        // reading, so the temperature keeps up with the location while riding.
        if let fetched = lastFetchCoordinate,
           Self.distanceMeters(fetched, new) >= Self.significantMoveMeters {
            fetch()
            return
        }

        // No refetch needed, but the cadence may need to change as riding starts/stops.
        scheduleTimer(interval: desiredInterval())
    }

    func setUnit(_ unit: TemperatureUnit) {
        guard unit != self.unit else { return }
        self.unit = unit
        fetch()
    }

    /// Update the rain look-ahead window and refresh to reflect the new horizon.
    func setWindowHours(_ hours: Int) {
        let clamped = OpenMeteoMapper.clampWindowHours(hours)
        guard clamped != windowHours else { return }
        windowHours = clamped
        fetch()
    }

    /// Update the low-temperature look-ahead window and refresh.
    func setLowTempWindowHours(_ hours: Int) {
        let clamped = OpenMeteoMapper.clampWindowHours(hours)
        guard clamped != lowTempWindowHours else { return }
        lowTempWindowHours = clamped
        fetch()
    }

    /// Update the low-temperature comfort threshold (in °F) and refresh.
    func setLowTempThresholdFahrenheit(_ fahrenheit: Double?) {
        guard fahrenheit != lowTempThresholdFahrenheit else { return }
        lowTempThresholdFahrenheit = fahrenheit
        fetch()
    }

    private func fetch() {
        guard let coordinate else { return }
        lastFetchCoordinate = coordinate
        let config = WeatherForecastConfig(
            unit: unit,
            rainWindowHours: windowHours,
            lowTempWindowHours: lowTempWindowHours,
            lowTempThresholdFahrenheit: lowTempThresholdFahrenheit
        )
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.provider.fetch(
                    latitude: latitude,
                    longitude: longitude,
                    config: config
                )
                guard !Task.isCancelled else { return }
                self.snapshot = result
                // Adapt the cadence as readings cross the near-freezing threshold.
                self.scheduleTimer(interval: self.desiredInterval())
            } catch {
                // Keep the last good snapshot on a transient failure.
            }
        }
    }

    /// Refresh cadence implied by current conditions: near/below freezing is the
    /// fastest, then a faster cadence while actively riding, else the standard idle rate.
    private func desiredInterval() -> TimeInterval {
        if snapshot?.isNearOrBelowFreezing == true {
            return Self.nearFreezingRefreshInterval
        }
        if isRiding() {
            return Self.ridingRefreshInterval
        }
        return Self.standardRefreshInterval
    }

    /// The rider is "riding" if movement was detected within the idle timeout.
    private func isRiding() -> Bool {
        guard let lastMovementAt else { return false }
        return now().timeIntervalSince(lastMovementAt) < Self.ridingIdleTimeout
    }

    /// Great-circle distance in metres between two coordinates (haversine).
    static func distanceMeters(
        _ from: (latitude: Double, longitude: Double),
        _ to: (latitude: Double, longitude: Double)
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let haversine = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(haversine)))
    }

    /// (Re)schedule the repeating timer, skipping work when the interval is unchanged.
    private func scheduleTimer(interval: TimeInterval) {
        guard isRunning else { return }
        if timer != nil, activeRefreshInterval == interval { return }
        timer?.invalidate()
        activeRefreshInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetch()
            }
        }
    }
}

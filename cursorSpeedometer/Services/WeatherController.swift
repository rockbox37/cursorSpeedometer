import Foundation

@MainActor
final class WeatherController: ObservableObject {
    /// Default refresh cadence while the app is foregrounded.
    static let standardRefreshInterval: TimeInterval = 900
    /// Faster cadence when it is near or below freezing, where icing risk makes
    /// timely updates valuable. Still far under Open-Meteo's free-tier limits.
    static let nearFreezingRefreshInterval: TimeInterval = 240

    @Published private(set) var snapshot: WeatherSnapshot?

    /// Currently-scheduled refresh interval (nil while stopped). Exposed for tests.
    private(set) var activeRefreshInterval: TimeInterval?

    private let provider: WeatherProvider
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var coordinate: (latitude: Double, longitude: Double)?
    private var unit: TemperatureUnit
    private var isRunning = false

    init(provider: WeatherProvider = OpenMeteoWeatherService(), unit: TemperatureUnit = .fahrenheit) {
        self.provider = provider
        self.unit = unit
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
        let isFirstFix = coordinate == nil
        coordinate = (latitude, longitude)
        // Fetch immediately once a real location is known; later moves are picked up
        // by the periodic refresh to avoid hammering the API.
        if isFirstFix {
            fetch()
        }
    }

    func setUnit(_ unit: TemperatureUnit) {
        guard unit != self.unit else { return }
        self.unit = unit
        fetch()
    }

    private func fetch() {
        guard let coordinate else { return }
        let unit = self.unit
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.provider.fetch(latitude: latitude, longitude: longitude, unit: unit)
                guard !Task.isCancelled else { return }
                self.snapshot = result
                // Adapt the cadence as readings cross the near-freezing threshold.
                self.scheduleTimer(interval: self.desiredInterval())
            } catch {
                // Keep the last good snapshot on a transient failure.
            }
        }
    }

    /// Refresh cadence implied by the latest reading: faster near/below freezing.
    private func desiredInterval() -> TimeInterval {
        if snapshot?.isNearOrBelowFreezing == true {
            return Self.nearFreezingRefreshInterval
        }
        return Self.standardRefreshInterval
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

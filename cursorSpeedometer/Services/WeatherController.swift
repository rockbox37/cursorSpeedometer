import Foundation

@MainActor
final class WeatherController: ObservableObject {
    /// How often to refresh the forecast while the app is foregrounded.
    static let refreshInterval: TimeInterval = 900

    @Published private(set) var snapshot: WeatherSnapshot?

    private let provider: WeatherProvider
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var coordinate: (latitude: Double, longitude: Double)?
    private var unit: TemperatureUnit

    init(provider: WeatherProvider = OpenMeteoWeatherService(), unit: TemperatureUnit = .fahrenheit) {
        self.provider = provider
        self.unit = unit
    }

    /// Begin (or resume) periodic refreshes. Safe to call repeatedly.
    func start() {
        fetch()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetch()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
            } catch {
                // Keep the last good snapshot on a transient failure.
            }
        }
    }
}

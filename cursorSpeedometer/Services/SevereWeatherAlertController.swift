import Foundation

@MainActor
final class SevereWeatherAlertController: ObservableObject {
    /// How often to re-check active alerts while the app is foregrounded.
    static let refreshInterval: TimeInterval = 300

    @Published private(set) var alert: SevereWeatherAlert?

    private let provider: AlertProvider
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var coordinate: (latitude: Double, longitude: Double)?
    private var isRunning = false

    init(provider: AlertProvider = NWSAlertService()) {
        self.provider = provider
    }

    /// Begin (or resume) periodic alert checks. Safe to call repeatedly.
    func start() {
        isRunning = true
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
        isRunning = false
        timer?.invalidate()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
    }

    func updateLocation(latitude: Double, longitude: Double) {
        let isFirstFix = coordinate == nil
        coordinate = (latitude, longitude)
        // Check immediately once a real location is known; later moves are picked
        // up by the periodic refresh.
        if isFirstFix {
            fetch()
        }
    }

    private func fetch() {
        guard let coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.provider.fetchActiveAlert(
                    latitude: latitude,
                    longitude: longitude
                )
                guard !Task.isCancelled else { return }
                self.alert = result
            } catch {
                // Keep the last known alert state on a transient failure.
            }
        }
    }
}

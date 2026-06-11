import Foundation

@MainActor
final class RideViewModel: ObservableObject {
    @Published private(set) var state = TripComputerState()

    private let engine = TripComputerEngine()
    private let settings: AppSettings
    private var staleCheckTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        state.odometerMeters = settings.persistedOdometerMeters
        startStaleSpeedCheck()
    }

    deinit {
        staleCheckTimer?.invalidate()
    }

    func handleSample(_ sample: LocationSample) {
        state = engine.process(sample: sample, state: state, now: Date())
        settings.persistedOdometerMeters = state.odometerMeters
    }

    func prepareForResume() {
        state.currentSpeedMps = 0
        state.lastSample = nil
        state.lastProcessedAt = nil
    }

    func resetTrip() {
        state = engine.resetTrip(state: state)
    }

    func resetOdometer() {
        state = engine.resetOdometer(state: state)
        settings.resetOdometer()
    }

    private func startStaleSpeedCheck() {
        staleCheckTimer?.invalidate()
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.state = self.engine.applyStaleSampleTimeout(state: self.state)
            }
        }
    }
}

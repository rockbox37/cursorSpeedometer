import Foundation

@MainActor
final class LeanAngleViewModel: ObservableObject {
    @Published private(set) var state = LeanAngleState()
    @Published private(set) var isActive = false

    private let engine = LeanAngleEngine()
    private let service: LeanAngleService
    private let settings: AppSettings

    /// Supplies current speed (m/s) so max lean is only tracked while moving.
    var speedProvider: () -> Double = { 0 }

    private var latestRawDegrees: Double = 0

    init(service: LeanAngleService, settings: AppSettings) {
        self.service = service
        self.settings = settings
        state.calibrationOffset = settings.leanCalibrationOffset
        service.onSample = { [weak self] gravityX, gravityY in
            self?.handleSample(gravityX: gravityX, gravityY: gravityY)
        }
    }

    var isSensorAvailable: Bool { service.isAvailable }

    func start() {
        guard service.isAvailable else { return }
        service.start()
        isActive = service.isRunning
    }

    func stop() {
        service.stop()
        isActive = false
    }

    func calibrate() {
        state = engine.calibrate(rawDegrees: latestRawDegrees, state: state)
        settings.leanCalibrationOffset = state.calibrationOffset
    }

    func resetMaxLean() {
        state = engine.resetMaxLean(state: state)
    }

    private func handleSample(gravityX: Double, gravityY: Double) {
        latestRawDegrees = engine.rawLeanDegrees(gravityX: gravityX, gravityY: gravityY)
        state = engine.process(
            rawDegrees: latestRawDegrees,
            speedMps: speedProvider(),
            state: state
        )
    }
}

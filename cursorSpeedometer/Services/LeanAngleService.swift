import Foundation
#if canImport(CoreMotion)
import CoreMotion
#endif

@MainActor
final class LeanAngleService: ObservableObject {
    /// Called on each motion sample with the device gravity vector components.
    var onSample: ((_ gravityX: Double, _ gravityY: Double) -> Void)?

    @Published private(set) var isRunning = false

    #if canImport(CoreMotion)
    private let motionManager: CMMotionManager
    #endif

    private static let updateInterval = 1.0 / 30.0

    #if canImport(CoreMotion)
    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
    }

    var isAvailable: Bool { motionManager.isDeviceMotionAvailable }
    #else
    init() {}
    var isAvailable: Bool { false }
    #endif

    func start() {
        #if canImport(CoreMotion)
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = Self.updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.onSample?(motion.gravity.x, motion.gravity.y)
        }
        isRunning = true
        #endif
    }

    func stop() {
        #if canImport(CoreMotion)
        guard motionManager.isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
        #endif
        isRunning = false
    }
}

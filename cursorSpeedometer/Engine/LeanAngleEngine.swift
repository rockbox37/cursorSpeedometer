import Foundation

struct LeanAngleState: Equatable, Sendable {
    /// Smoothed lean relative to calibrated upright. Negative = left, positive = right.
    var currentDegrees: Double = 0
    /// Most negative (left) lean recorded while moving this session.
    var maxLeftDegrees: Double = 0
    /// Most positive (right) lean recorded while moving this session.
    var maxRightDegrees: Double = 0
    /// Raw upright reference captured at calibration; subtracted from raw readings.
    var calibrationOffset: Double = 0
}

struct LeanAngleEngine: Sendable {
    /// Exponential smoothing weight applied to each new reading (0...1).
    static let smoothingFactor = 0.2
    /// Below this speed lean is shown but not recorded into max L/R (stationary tip-over noise).
    static let minTrackingSpeedMps = 2.2
    /// Physically implausible beyond this; clamps sensor glitches.
    static let maxPlausibleDegrees = 90.0

    /// Converts a device gravity vector (portrait orientation) into raw lean degrees.
    /// Upright (gravity ≈ (0, -1)) yields 0°; tilting right yields positive degrees.
    func rawLeanDegrees(gravityX: Double, gravityY: Double) -> Double {
        atan2(gravityX, -gravityY) * 180 / .pi
    }

    func process(rawDegrees: Double, speedMps: Double, state: LeanAngleState) -> LeanAngleState {
        var updated = state

        let calibrated = rawDegrees - state.calibrationOffset
        let clamped = min(max(calibrated, -Self.maxPlausibleDegrees), Self.maxPlausibleDegrees)
        let smoothed = state.currentDegrees + (clamped - state.currentDegrees) * Self.smoothingFactor
        updated.currentDegrees = smoothed

        if speedMps >= Self.minTrackingSpeedMps {
            if smoothed < updated.maxLeftDegrees {
                updated.maxLeftDegrees = smoothed
            }
            if smoothed > updated.maxRightDegrees {
                updated.maxRightDegrees = smoothed
            }
        }

        return updated
    }

    /// Captures the current raw reading as the new upright reference so live lean reads 0°.
    func calibrate(rawDegrees: Double, state: LeanAngleState) -> LeanAngleState {
        var updated = state
        updated.calibrationOffset = rawDegrees
        updated.currentDegrees = 0
        return updated
    }

    /// Clears recorded max lean while preserving calibration.
    func resetMaxLean(state: LeanAngleState) -> LeanAngleState {
        var updated = state
        updated.maxLeftDegrees = 0
        updated.maxRightDegrees = 0
        return updated
    }

    private func atan2(_ lhs: Double, _ rhs: Double) -> Double { Foundation.atan2(lhs, rhs) }
}

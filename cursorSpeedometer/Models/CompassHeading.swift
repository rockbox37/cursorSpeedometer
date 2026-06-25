import Foundation

/// Maps a heading in degrees to an 8-point cardinal/intercardinal label.
enum CompassHeading {
    /// Shown when no valid heading is available.
    static let placeholder = "--"

    private static let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    /// Returns the cardinal label (N, NE, E, ...) for a heading in degrees,
    /// or `placeholder` when the value is missing or invalid (negative/non-finite).
    static func cardinal(forDegrees degrees: Double?) -> String {
        guard let degrees, degrees.isFinite, degrees >= 0 else { return placeholder }
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        let index = Int((positive / 45.0).rounded()) % labels.count
        return labels[index]
    }
}

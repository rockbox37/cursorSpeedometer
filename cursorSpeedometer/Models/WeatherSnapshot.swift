import Foundation

/// A point-in-time weather reading for the rider's current location.
struct WeatherSnapshot: Equatable, Sendable {
    let temperature: Double
    let unit: TemperatureUnit
    /// True when measurable rain is expected within the forecast window.
    let rainExpectedSoon: Bool

    /// Rounded temperature with its unit symbol, e.g. "72°F".
    var temperatureText: String {
        "\(Int(temperature.rounded()))\(unit.symbol)"
    }
}

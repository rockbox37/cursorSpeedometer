import Foundation

enum SpeedUnit: String, CaseIterable, Codable, Sendable {
    case imperial
    case metric

    var speedLabel: String {
        switch self {
        case .imperial: "mph"
        case .metric: "km/h"
        }
    }

    var distanceLabel: String {
        switch self {
        case .imperial: "mi"
        case .metric: "km"
        }
    }

    /// Temperature scale paired with this distance/speed system.
    var temperatureUnit: TemperatureUnit {
        switch self {
        case .imperial: .fahrenheit
        case .metric: .celsius
        }
    }

    /// Picker label for the Settings Speed & Distance option.
    var settingsOptionLabel: String {
        switch self {
        case .imperial: "Imperial (mph/mi)"
        case .metric: "Metric (km/h/km)"
        }
    }

    func formatSpeed(metersPerSecond: Double) -> String {
        let value = switch self {
        case .imperial: metersPerSecond * 2.23694
        case .metric: metersPerSecond * 3.6
        }
        return String(format: "%.0f", max(0, value))
    }

    func formatDistance(meters: Double) -> String {
        let value = switch self {
        case .imperial: meters / 1609.34
        case .metric: meters / 1000.0
        }
        return String(format: "%.2f", max(0, value))
    }
}

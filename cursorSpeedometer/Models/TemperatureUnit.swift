import Foundation

enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case fahrenheit
    case celsius

    /// Suffix shown next to the temperature value (e.g. "72°F").
    var symbol: String {
        switch self {
        case .fahrenheit: "°F"
        case .celsius: "°C"
        }
    }

    /// Value expected by the Open-Meteo `temperature_unit` query parameter.
    var apiValue: String {
        switch self {
        case .fahrenheit: "fahrenheit"
        case .celsius: "celsius"
        }
    }
}

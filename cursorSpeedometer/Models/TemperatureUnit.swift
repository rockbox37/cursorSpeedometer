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

/// The rider's temperature-unit choice. `automatic` follows the Speed & Distance
/// selection; the explicit cases fix the unit regardless of that selection.
enum TemperaturePreference: String, CaseIterable, Codable, Sendable {
    case automatic
    case fahrenheit
    case celsius

    /// Label shown in the Settings picker.
    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .fahrenheit: "Fahrenheit (\(TemperatureUnit.fahrenheit.symbol))"
        case .celsius: "Celsius (\(TemperatureUnit.celsius.symbol))"
        }
    }

    /// Resolve to a concrete unit, deferring to the speed/distance system when automatic.
    func resolvedUnit(following speedUnit: SpeedUnit) -> TemperatureUnit {
        switch self {
        case .automatic: speedUnit.temperatureUnit
        case .fahrenheit: .fahrenheit
        case .celsius: .celsius
        }
    }
}

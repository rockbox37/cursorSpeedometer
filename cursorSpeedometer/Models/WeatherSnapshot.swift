import Foundation

/// Cold-weather severity derived from the current temperature.
enum TemperatureWarning: Equatable, Sendable {
    case none
    case cold
    case freezing
}

/// A point-in-time weather reading for the rider's current location.
struct WeatherSnapshot: Equatable, Sendable {
    /// At or below this (in °F) the rider sees a cold-weather warning.
    static let coldThresholdFahrenheit = 40.0
    /// At or below this (in °F) the rider sees a conspicuous freeze warning.
    static let freezeThresholdFahrenheit = 37.0
    /// Freezing point in °F.
    static let freezingPointFahrenheit = 32.0
    /// Within this many °F of freezing (or colder) counts as "near freezing".
    static let nearFreezingMarginFahrenheit = 5.0

    let temperature: Double
    let unit: TemperatureUnit
    /// Hours until rain is expected within the forecast window (1-based: the
    /// current hour counts as ~1), or nil when no rain is expected.
    let rainExpectedInHours: Int?

    /// True when measurable rain is expected within the forecast window.
    var rainExpectedSoon: Bool { rainExpectedInHours != nil }

    /// Rider-facing rain cue with a timeframe, e.g. "Rain possible within ~3hrs",
    /// or nil when no rain is expected.
    var rainText: String? {
        guard let hours = rainExpectedInHours else { return nil }
        let unitLabel = hours == 1 ? "hr" : "hrs"
        return "Rain possible within ~\(hours)\(unitLabel)"
    }

    /// Rounded temperature with its unit symbol, e.g. "72°F".
    var temperatureText: String {
        "\(Int(temperature.rounded()))\(unit.symbol)"
    }

    /// Temperature normalized to Fahrenheit so thresholds compare identically
    /// regardless of the rider's display unit.
    var temperatureFahrenheit: Double {
        switch unit {
        case .fahrenheit: temperature
        case .celsius: temperature * 9 / 5 + 32
        }
    }

    /// True when the temperature is within 5°F of freezing or colder, where
    /// icing risk warrants more frequent weather refreshes.
    var isNearOrBelowFreezing: Bool {
        temperatureFahrenheit <= Self.freezingPointFahrenheit + Self.nearFreezingMarginFahrenheit
    }

    /// Cold-weather severity; freezing takes priority over cold.
    var temperatureWarning: TemperatureWarning {
        let fahrenheit = temperatureFahrenheit
        if fahrenheit <= Self.freezeThresholdFahrenheit {
            return .freezing
        }
        if fahrenheit <= Self.coldThresholdFahrenheit {
            return .cold
        }
        return .none
    }
}

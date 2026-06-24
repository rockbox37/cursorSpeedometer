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
    /// Hours until the forecast temperature first drops below the rider's
    /// low-temp threshold within the configured window, or nil if it does not.
    var lowTempExpectedInHours: Int?
    /// The rider's low-temp threshold (in °F) used for the warning, when set.
    var lowTempThresholdFahrenheit: Double?

    /// True when measurable rain is expected within the forecast window.
    var rainExpectedSoon: Bool { rainExpectedInHours != nil }

    /// Rider-facing rain cue with a timeframe, e.g. "Rain possible within ~3hrs",
    /// or nil when no rain is expected. Used for the combined accessibility label.
    var rainText: String? {
        guard let primary = rainPrimaryText, let secondary = rainSecondaryText else { return nil }
        return "\(primary) \(secondary)"
    }

    /// First line of the rain cue, e.g. "Rain possible", or nil when no rain is expected.
    var rainPrimaryText: String? {
        rainExpectedInHours == nil ? nil : "Rain possible"
    }

    /// Second line of the rain cue with the timeframe, e.g. "within ~3hrs",
    /// or nil when no rain is expected.
    var rainSecondaryText: String? {
        guard let hours = rainExpectedInHours else { return nil }
        let unitLabel = hours == 1 ? "hr" : "hrs"
        return "within ~\(hours)\(unitLabel)"
    }

    /// Rider-facing forecast cue for a dip below the comfort threshold, e.g.
    /// "Temps may fall to below 50°F within 3 hours", or nil when not expected.
    var lowTempWarningText: String? {
        guard let hours = lowTempExpectedInHours, let thresholdFahrenheit = lowTempThresholdFahrenheit else {
            return nil
        }
        let threshold = displayThreshold(thresholdFahrenheit)
        let hourLabel = hours == 1 ? "hour" : "hours"
        return "Temps may fall to below \(threshold)\(unit.symbol) within \(hours) \(hourLabel)"
    }

    /// The threshold rounded into the snapshot's display unit.
    private func displayThreshold(_ fahrenheit: Double) -> Int {
        switch unit {
        case .fahrenheit: Int(fahrenheit.rounded())
        case .celsius: Int(((fahrenheit - 32) * 5 / 9).rounded())
        }
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

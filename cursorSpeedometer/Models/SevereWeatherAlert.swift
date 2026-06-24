import Foundation

/// Hazard category of a severe-weather alert.
enum SevereWeatherCategory: String, Equatable, Sendable {
    case thunderstorm
    case tornado

    /// Higher value is more dangerous within the same alert level.
    var priority: Int {
        switch self {
        case .thunderstorm: 0
        case .tornado: 1
        }
    }

    /// Noun used when building fallback text.
    var noun: String {
        switch self {
        case .thunderstorm: "Thunderstorm"
        case .tornado: "Tornado"
        }
    }

    /// SF Symbol representing the hazard.
    var iconName: String {
        switch self {
        case .thunderstorm: "cloud.bolt.rain.fill"
        case .tornado: "tornado"
        }
    }
}

/// Severity of an active alert. A warning is more imminent/severe than a watch.
enum SevereWeatherAlertLevel: String, Equatable, Sendable {
    case watch
    case warning

    /// Higher value takes priority across categories.
    var priority: Int {
        switch self {
        case .watch: 0
        case .warning: 1
        }
    }
}

/// An active severe-weather watch or warning for the rider's location.
struct SevereWeatherAlert: Equatable, Sendable {
    let category: SevereWeatherCategory
    let level: SevereWeatherAlertLevel
    /// Official event name from the source, e.g. "Tornado Warning".
    let event: String

    /// Combined severity: warnings outrank watches, and within a level a tornado
    /// outranks a thunderstorm.
    var priority: Int {
        level.priority * 10 + category.priority
    }

    /// Rider-facing text. Falls back to a generic label if the event is empty.
    var text: String {
        event.isEmpty ? defaultText : event
    }

    private var defaultText: String {
        let suffix = level == .warning ? "Warning" : "Watch"
        return "\(category.noun) \(suffix)"
    }
}

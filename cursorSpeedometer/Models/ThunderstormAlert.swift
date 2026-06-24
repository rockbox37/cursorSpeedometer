import Foundation

/// Severity of an active thunderstorm alert. A warning is more imminent/severe
/// than a watch.
enum ThunderstormAlertLevel: String, Equatable, Sendable {
    case watch
    case warning

    /// Higher value takes visual priority when multiple alerts are active.
    var priority: Int {
        switch self {
        case .watch: 0
        case .warning: 1
        }
    }
}

/// An active thunderstorm watch or warning for the rider's location.
struct ThunderstormAlert: Equatable, Sendable {
    let level: ThunderstormAlertLevel
    /// Official event name from the source, e.g. "Severe Thunderstorm Warning".
    let event: String

    /// Rider-facing text. Falls back to a generic label if the event is empty.
    var text: String {
        event.isEmpty ? defaultText : event
    }

    private var defaultText: String {
        switch level {
        case .watch: "Thunderstorm Watch"
        case .warning: "Thunderstorm Warning"
        }
    }
}

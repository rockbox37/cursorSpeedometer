import Foundation

enum GPSSignalStatus: Equatable, Sendable {
    case unavailable
    case searching
    case weak
    case fair
    case good
    case strong

    var filledBars: Int {
        switch self {
        case .unavailable, .searching: 0
        case .weak: 1
        case .fair: 2
        case .good: 3
        case .strong: 4
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .unavailable: "GPS unavailable"
        case .searching: "GPS searching for satellites"
        case .weak: "GPS weak signal"
        case .fair: "GPS fair signal"
        case .good: "GPS good signal"
        case .strong: "GPS strong signal"
        }
    }

    static func resolve(
        authorization: LocationAuthorizationState,
        horizontalAccuracy: Double?,
        lastFixDate: Date?,
        now: Date = Date(),
        staleInterval: TimeInterval = 5
    ) -> GPSSignalStatus {
        guard authorization == .authorized else {
            return .unavailable
        }

        guard let lastFixDate else {
            return .searching
        }

        if now.timeIntervalSince(lastFixDate) > staleInterval {
            return .searching
        }

        guard let horizontalAccuracy, horizontalAccuracy >= 0 else {
            return .searching
        }

        switch horizontalAccuracy {
        case ...8:
            return .strong
        case ...15:
            return .good
        case ...25:
            return .fair
        default:
            return .weak
        }
    }
}

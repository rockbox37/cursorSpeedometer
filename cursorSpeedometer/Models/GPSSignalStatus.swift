import Foundation

/// How urgently a GPS state should be surfaced to the rider. `.critical` means
/// there is no usable fix (so no live speed); `.degraded` means a fix exists but
/// its accuracy is poor enough that the reading may be unreliable.
enum GPSAttentionLevel: Equatable, Sendable {
    case critical
    case degraded
}

enum GPSSignalStatus: Equatable, Sendable {
    case unavailable
    case searching
    case weak
    case fair
    case good
    case strong

    /// Whether (and how urgently) this status warrants a prominent on-screen alert.
    /// `nil` for a healthy fix (`.fair`/`.good`/`.strong`) — only the header bars show.
    var attention: GPSAttentionLevel? {
        switch self {
        case .unavailable, .searching: .critical
        case .weak: .degraded
        case .fair, .good, .strong: nil
        }
    }

    /// Short headline for the GPS alert banner, or `nil` when no alert is warranted.
    var alertTitle: String? {
        switch self {
        case .unavailable: "No GPS Signal"
        case .searching: "Searching for GPS…"
        case .weak: "Weak GPS Signal"
        case .fair, .good, .strong: nil
        }
    }

    /// Smaller guidance line telling the rider how to restore a good fix, or `nil`
    /// when no alert is warranted.
    var alertGuidance: String? {
        switch self {
        case .unavailable:
            "Enable Location Services for this app in Settings."
        case .searching, .weak:
            "Make sure your device has a clear, unobstructed view of the sky."
        case .fair, .good, .strong:
            nil
        }
    }

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

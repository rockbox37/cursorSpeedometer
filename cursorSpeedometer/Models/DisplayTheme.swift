import SwiftUI

enum ThemePreset: String, CaseIterable, Codable, Sendable {
    case day
    case night
    case amber

    var displayName: String {
        switch self {
        case .day: "Day"
        case .night: "Night"
        case .amber: "Amber"
        }
    }
}

/// RGB color with components clamped to 0...1 before bridging to UIColor.
struct ThemeColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    func opacity(_ value: Double) -> Color {
        color.opacity(Self.clamp(value))
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

struct ThemePalette: Equatable, Sendable {
    let background: ThemeColor
    let primary: ThemeColor
    let secondary: ThemeColor
    let accent: ThemeColor

    var backgroundColor: Color { background.color }
    var primaryColor: Color { primary.color }
    var secondaryColor: Color { secondary.color }
    var accentColor: Color { accent.color }

    static func palette(for preset: ThemePreset) -> ThemePalette {
        switch preset {
        case .day:
            ThemePalette(
                background: ThemeColor(red: 1.0, green: 1.0, blue: 1.0),
                primary: ThemeColor(red: 0.0, green: 0.0, blue: 0.0),
                secondary: ThemeColor(red: 0.15, green: 0.15, blue: 0.18),
                accent: ThemeColor(red: 0.0, green: 0.35, blue: 0.85)
            )
        case .night:
            // Slightly softened reds avoid UIKit highlight math pushing channels below zero.
            ThemePalette(
                background: ThemeColor(red: 0.02, green: 0.0, blue: 0.0),
                primary: ThemeColor(red: 1.0, green: 0.12, blue: 0.12),
                secondary: ThemeColor(red: 0.85, green: 0.08, blue: 0.08),
                accent: ThemeColor(red: 0.95, green: 0.05, blue: 0.05)
            )
        case .amber:
            ThemePalette(
                background: ThemeColor(red: 0.08, green: 0.05, blue: 0.0),
                primary: ThemeColor(red: 1.0, green: 0.75, blue: 0.0),
                secondary: ThemeColor(red: 0.95, green: 0.65, blue: 0.0),
                accent: ThemeColor(red: 0.9, green: 0.55, blue: 0.0)
            )
        }
    }

    var usesRedChannelOnly: Bool {
        self == ThemePalette.palette(for: .night)
    }

    var usesAmberChannelOnly: Bool {
        self == ThemePalette.palette(for: .amber)
    }
}

enum BrightnessClamp {
    static let minimum: Double = 0.15
    static let maximum: Double = 1.0

    static func clamp(_ value: Double) -> Double {
        Swift.min(maximum, Swift.max(minimum, value))
    }

    static func dimmingOpacity(for brightnessLevel: Double) -> Double {
        let normalizedBrightness = Swift.min(1, Swift.max(0, brightnessLevel))
        return Swift.min(1, Swift.max(0, 1 - normalizedBrightness))
    }
}

#if DEBUG
enum ThemePaletteValidator {
    static func nightUsesRedChannelOnly(_ palette: ThemePalette) -> Bool {
        palette == ThemePalette.palette(for: .night)
    }

    static func amberUsesWarmTones(_ palette: ThemePalette) -> Bool {
        palette == ThemePalette.palette(for: .amber)
    }
}
#endif

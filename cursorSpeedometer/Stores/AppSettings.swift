import Foundation

private enum ThemeDefaults {
    static let latitude = 37.3349
    static let longitude = -122.0090
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let speedUnit = "speedUnit"
        static let temperaturePreference = "temperaturePreference"
        static let pinnedTheme = "pinnedTheme"
        static let autoThemeEnabled = "autoThemeEnabled"
        static let autoBrightnessEnabled = "autoBrightnessEnabled"
        static let manualBrightness = "manualBrightness"
        static let odometerMeters = "odometerMeters"
        static let rideModeEnabled = "rideModeEnabled"
    }

    private let defaults: UserDefaults

    @Published var speedUnit: SpeedUnit {
        didSet { defaults.set(speedUnit.rawValue, forKey: Key.speedUnit) }
    }

    @Published var temperaturePreference: TemperaturePreference {
        didSet { defaults.set(temperaturePreference.rawValue, forKey: Key.temperaturePreference) }
    }

    /// Concrete temperature unit to display, honoring the preference (or the
    /// Speed & Distance system when the preference is automatic).
    var resolvedTemperatureUnit: TemperatureUnit {
        temperaturePreference.resolvedUnit(following: speedUnit)
    }

    @Published var pinnedTheme: ThemePreset {
        didSet { defaults.set(pinnedTheme.rawValue, forKey: Key.pinnedTheme) }
    }

    @Published var autoThemeEnabled: Bool {
        didSet { defaults.set(autoThemeEnabled, forKey: Key.autoThemeEnabled) }
    }

    @Published var autoBrightnessEnabled: Bool {
        didSet { defaults.set(autoBrightnessEnabled, forKey: Key.autoBrightnessEnabled) }
    }

    @Published var manualBrightness: Double {
        didSet {
            let clamped = BrightnessClamp.clamp(manualBrightness)
            if clamped != manualBrightness { manualBrightness = clamped; return }
            defaults.set(manualBrightness, forKey: Key.manualBrightness)
        }
    }

    @Published var persistedOdometerMeters: Double {
        didSet { defaults.set(persistedOdometerMeters, forKey: Key.odometerMeters) }
    }

    @Published var rideModeEnabled: Bool {
        didSet { defaults.set(rideModeEnabled, forKey: Key.rideModeEnabled) }
    }

    @Published var activeTheme: ThemePreset = .day
    @Published var brightnessLevel: Double = 1.0

    func updateBrightnessLevel(_ value: Double) {
        brightnessLevel = BrightnessClamp.clamp(value)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.speedUnit = SpeedUnit(rawValue: defaults.string(forKey: Key.speedUnit) ?? "") ?? .imperial
        self.temperaturePreference = TemperaturePreference(
            rawValue: defaults.string(forKey: Key.temperaturePreference) ?? ""
        ) ?? .automatic
        self.pinnedTheme = ThemePreset(rawValue: defaults.string(forKey: Key.pinnedTheme) ?? "") ?? .day
        self.autoThemeEnabled = defaults.object(forKey: Key.autoThemeEnabled) as? Bool ?? true
        self.autoBrightnessEnabled = defaults.object(forKey: Key.autoBrightnessEnabled) as? Bool ?? true
        self.manualBrightness = BrightnessClamp.clamp(
            defaults.object(forKey: Key.manualBrightness) as? Double ?? 1.0
        )
        self.persistedOdometerMeters = defaults.double(forKey: Key.odometerMeters)
        self.rideModeEnabled = defaults.object(forKey: Key.rideModeEnabled) as? Bool ?? false
        if self.autoThemeEnabled {
            self.resolveActiveTheme()
        } else {
            self.activeTheme = self.pinnedTheme
        }
        updateBrightnessLevel(self.autoBrightnessEnabled ? 1.0 : self.manualBrightness)
    }

    func selectTheme(_ theme: ThemePreset, pinManual: Bool) {
        pinnedTheme = theme
        if pinManual {
            autoThemeEnabled = false
        }
        activeTheme = theme
    }

    func enableAutoTheme() {
        autoThemeEnabled = true
    }

    func resolveActiveTheme(
        latitude: Double = ThemeDefaults.latitude,
        longitude: Double = ThemeDefaults.longitude,
        at date: Date = Date()
    ) {
        activeTheme = ThemeAutoSwitcher().resolvedTheme(
            query: SolarQuery(
                date: date,
                latitude: latitude,
                longitude: longitude,
                timeZone: .current
            ),
            autoThemeEnabled: autoThemeEnabled,
            pinnedTheme: pinnedTheme
        )
    }

    func resetOdometer() {
        persistedOdometerMeters = 0
    }
}

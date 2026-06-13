import Foundation

struct ThemeAutoSwitcher: Sendable {
    private let solarService = SolarScheduleService()

    func resolvedTheme(
        at date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        autoThemeEnabled: Bool,
        pinnedTheme: ThemePreset
    ) -> ThemePreset {
        guard autoThemeEnabled else {
            return pinnedTheme
        }

        let isDay = solarService.isDaytime(
            at: date,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        return isDay ? .day : .night
    }
}

@MainActor
final class ThemeAutoSwitcherController: ObservableObject {
    private var timer: Timer?

    func start(settings: AppSettings, latitude: Double, longitude: Double) {
        stop()
        refresh(settings: settings, latitude: latitude, longitude: longitude)

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refresh(settings: settings, latitude: latitude, longitude: longitude)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(settings: AppSettings, latitude: Double, longitude: Double) {
        settings.resolveActiveTheme(latitude: latitude, longitude: longitude)
    }
}

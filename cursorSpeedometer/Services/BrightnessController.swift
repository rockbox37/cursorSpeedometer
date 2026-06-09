import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct BrightnessController: Sendable {
    private let solarService = SolarScheduleService()
    static let minBrightness = BrightnessClamp.minimum
    static let maxBrightness = BrightnessClamp.maximum
    static let updateInterval: TimeInterval = 1.0

    func resolvedBrightness(
        at date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        autoBrightnessEnabled: Bool,
        manualBrightness: Double,
        ambientBrightness: Double?
    ) -> Double {
        guard autoBrightnessEnabled else {
            return clamp(manualBrightness)
        }

        if let ambient = ambientBrightness {
            return clamp(mapAmbientToBrightness(ambient))
        }

        let isDay = solarService.isDaytime(
            at: date,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        return isDay ? Self.maxBrightness : Self.minBrightness
    }

    func mapAmbientToBrightness(_ ambient: Double) -> Double {
        let normalized = min(1, max(0, ambient))
        return Self.minBrightness + (normalized * (Self.maxBrightness - Self.minBrightness))
    }

    func clamp(_ value: Double) -> Double {
        BrightnessClamp.clamp(value)
    }
}

@MainActor
final class BrightnessControllerRunner: ObservableObject {
    private let controller = BrightnessController()
    private var timer: Timer?

    func start(settings: AppSettings, latitude: Double, longitude: Double) {
        stop()
        refresh(settings: settings, latitude: latitude, longitude: longitude)

        timer = Timer.scheduledTimer(withTimeInterval: BrightnessController.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(settings: settings, latitude: latitude, longitude: longitude)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(settings: AppSettings, latitude: Double, longitude: Double) {
        #if canImport(UIKit)
        let ambient = UIScreen.main.brightness
        #else
        let ambient: Double? = nil
        #endif

        settings.updateBrightnessLevel(controller.resolvedBrightness(
            at: Date(),
            latitude: latitude,
            longitude: longitude,
            timeZone: .current,
            autoBrightnessEnabled: settings.autoBrightnessEnabled,
            manualBrightness: settings.manualBrightness,
            ambientBrightness: ambient
        ))
    }
}

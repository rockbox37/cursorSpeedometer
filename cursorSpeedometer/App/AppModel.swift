import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AppModel: ObservableObject {
    let settings = AppSettings()
    let rideViewModel: RideViewModel
    let locationService: LocationService
    let themeController = ThemeAutoSwitcherController()
    let brightnessRunner = BrightnessControllerRunner()
    let weatherController = WeatherController()
    let alertController = ThunderstormAlertController()

    private var cancellables = Set<AnyCancellable>()
    private var wasInBackground = false

    init() {
        let viewModel = RideViewModel(settings: settings)
        rideViewModel = viewModel
        locationService = LocationService { sample in
            viewModel.handleSample(sample)
        }

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        weatherController.setUnit(settings.resolvedTemperatureUnit)

        locationService.$coordinate
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.weatherController.updateLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                self?.alertController.updateLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
            .store(in: &cancellables)

        // Drive the weather unit from the resolved preference, reacting to either
        // the Speed & Distance system or the Temperature preference changing.
        settings.$speedUnit
            .sink { [weak self] speedUnit in
                guard let self else { return }
                let resolved = self.settings.temperaturePreference.resolvedUnit(following: speedUnit)
                self.weatherController.setUnit(resolved)
            }
            .store(in: &cancellables)

        settings.$temperaturePreference
            .sink { [weak self] preference in
                guard let self else { return }
                let resolved = preference.resolvedUnit(following: self.settings.speedUnit)
                self.weatherController.setUnit(resolved)
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        locationService.requestPermissionIfNeeded()
        applyRideMode()
        refreshAdaptiveControllers()
        weatherController.start()
        alertController.start()
    }

    func onScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if wasInBackground {
                rideViewModel.prepareForResume()
                wasInBackground = false
            }
            refreshAdaptiveControllers()
            applyRideMode()
            weatherController.start()
            alertController.start()
        case .inactive:
            themeController.stop()
            brightnessRunner.stop()
        case .background:
            wasInBackground = true
            themeController.stop()
            brightnessRunner.stop()
            weatherController.stop()
            alertController.stop()
        @unknown default:
            break
        }
    }

    func onSettingsChanged() {
        applyRideMode()
        refreshAdaptiveControllers()
    }

    private func refreshAdaptiveControllers() {
        let latitude = locationService.coordinate?.latitude ?? 37.3349
        let longitude = locationService.coordinate?.longitude ?? -122.0090

        themeController.start(settings: settings, latitude: latitude, longitude: longitude)
        brightnessRunner.start(settings: settings, latitude: latitude, longitude: longitude)
    }

    private func applyRideMode() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = settings.rideModeEnabled
        #endif
    }
}

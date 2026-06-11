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
    let leanEntitlement = LeanAngleEntitlementStore()
    let leanAngleViewModel: LeanAngleViewModel

    private var cancellables = Set<AnyCancellable>()
    private var wasInBackground = false

    init() {
        let viewModel = RideViewModel(settings: settings)
        rideViewModel = viewModel
        locationService = LocationService { sample in
            viewModel.handleSample(sample)
        }

        let leanViewModel = LeanAngleViewModel(service: LeanAngleService(), settings: settings)
        leanAngleViewModel = leanViewModel
        leanViewModel.speedProvider = { [weak viewModel] in
            viewModel?.state.currentSpeedMps ?? 0
        }

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        locationService.requestPermissionIfNeeded()
        applyRideMode()
        applyLeanAngle()
        refreshAdaptiveControllers()
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
            applyLeanAngle()
        case .inactive:
            themeController.stop()
            brightnessRunner.stop()
        case .background:
            wasInBackground = true
            themeController.stop()
            brightnessRunner.stop()
            leanAngleViewModel.stop()
        @unknown default:
            break
        }
    }

    func onSettingsChanged() {
        applyRideMode()
        applyLeanAngle()
        refreshAdaptiveControllers()
    }

    private func applyLeanAngle() {
        if leanEntitlement.isUnlocked && settings.leanAngleEnabled {
            leanAngleViewModel.start()
        } else {
            leanAngleViewModel.stop()
        }
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

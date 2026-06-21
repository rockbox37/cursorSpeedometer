import SwiftUI

@main
struct CursorSpeedometerApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(appModel: appModel)
                    .onAppear { appModel.onAppear() }
                    .onChange(of: scenePhase) { newPhase in
                        appModel.onScenePhaseChange(newPhase)
                    }
                    .onChange(of: appModel.settings.autoThemeEnabled) { _ in
                        appModel.onSettingsChanged()
                    }
                    .onChange(of: appModel.settings.autoBrightnessEnabled) { _ in
                        appModel.onSettingsChanged()
                    }
                    .onChange(of: appModel.settings.rideModeEnabled) { _ in
                        appModel.onSettingsChanged()
                    }

                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .zIndex(1)
                }
            }
        }
    }
}

struct RootView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            BrandHeaderView(
                settings: appModel.settings,
                locationService: appModel.locationService
            )

            TabView {
                RideView(
                    settings: appModel.settings,
                    rideViewModel: appModel.rideViewModel,
                    locationService: appModel.locationService,
                    weatherController: appModel.weatherController
                )
                .tabItem {
                    Label("Ride", systemImage: "speedometer")
                }

                SettingsView(
                    settings: appModel.settings,
                    rideViewModel: appModel.rideViewModel,
                    locationService: appModel.locationService,
                    onAdaptiveSettingsChanged: appModel.onSettingsChanged
                )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}

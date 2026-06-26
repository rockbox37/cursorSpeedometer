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

enum MainTab: CaseIterable {
    case ride
    case settings

    var title: String {
        switch self {
        case .ride: return "Ride"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .ride: return "speedometer"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedTab: MainTab = .ride

    private var palette: ThemePalette {
        ThemePalette.palette(for: appModel.settings.activeTheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandHeaderView(
                settings: appModel.settings,
                locationService: appModel.locationService
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainTabBar(selectedTab: $selectedTab, palette: palette)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .ride:
            RideView(
                settings: appModel.settings,
                rideViewModel: appModel.rideViewModel,
                locationService: appModel.locationService,
                weatherController: appModel.weatherController,
                alertController: appModel.alertController
            )
        case .settings:
            SettingsView(
                settings: appModel.settings,
                rideViewModel: appModel.rideViewModel,
                locationService: appModel.locationService,
                onAdaptiveSettingsChanged: appModel.onSettingsChanged
            )
        }
    }
}

/// Glove-friendly bottom selector: taller tap targets than the native tab bar.
struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    let palette: ThemePalette

    /// Item height, noticeably taller than the ~49pt native tab bar for gloved use.
    private static let itemHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(palette.backgroundColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.secondaryColor.opacity(0.25))
                .frame(height: 0.5)
        }
    }

    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                Text(tab.title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: Self.itemHeight)
            .foregroundStyle(isSelected ? palette.accentColor : palette.secondaryColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

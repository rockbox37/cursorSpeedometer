import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var rideViewModel: RideViewModel
    @ObservedObject var locationService: LocationService
    let onAdaptiveSettingsChanged: () -> Void
    @Environment(\.openURL) private var openURL

    @State private var showOdometerResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Speed & Distance", selection: $settings.speedUnit) {
                        ForEach(SpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.settingsOptionLabel)
                                .tag(unit)
                        }
                    }
                    Picker("Temperature", selection: $settings.temperaturePreference) {
                        ForEach(TemperaturePreference.allCases, id: \.self) { preference in
                            Text(preference.displayName)
                                .tag(preference)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text(unitsFooterText)
                }

                Section("Display Theme") {
                    Toggle("Auto Theme (Day at sunrise, Night at sunset)", isOn: Binding(
                        get: { settings.autoThemeEnabled },
                        set: { enabled in
                            settings.autoThemeEnabled = enabled
                            settings.resolveActiveTheme(
                                latitude: locationService.coordinate?.latitude ?? 37.3349,
                                longitude: locationService.coordinate?.longitude ?? -122.0090
                            )
                            onAdaptiveSettingsChanged()
                        }
                    ))

                    if !settings.autoThemeEnabled {
                        Picker("Theme", selection: Binding(
                            get: { settings.pinnedTheme },
                            set: { settings.selectTheme($0, pinManual: true) }
                        )) {
                            ForEach(ThemePreset.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("Currently showing: \(settings.activeTheme.displayName)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Brightness") {
                    Toggle("Auto Brightness", isOn: $settings.autoBrightnessEnabled)

                    if !settings.autoBrightnessEnabled {
                        Slider(value: $settings.manualBrightness, in: 0.15...1.0) {
                            Text("Brightness")
                        }
                        .onChange(of: settings.manualBrightness) { newValue in
                            settings.updateBrightnessLevel(newValue)
                        }
                    }
                }

                Section("Ride Mode") {
                    Toggle("Keep Screen Awake", isOn: $settings.rideModeEnabled)
                }

                Section("Odometer") {
                    Button("Reset Odometer", role: .destructive) {
                        showOdometerResetConfirm = true
                    }
                }

                Section("Permissions") {
                    Label(locationStatusText, systemImage: "location.fill")
                    #if canImport(UIKit)
                    Button("Open System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    #endif
                }

                Section("About") {
                    AboutSectionView()
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset odometer to zero?",
                isPresented: $showOdometerResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Odometer", role: .destructive) {
                    rideViewModel.resetOdometer()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var unitsFooterText: String {
        let effective = settings.resolvedTemperatureUnit.symbol
        switch settings.temperaturePreference {
        case .automatic:
            return "Temperature follows Speed & Distance — currently \(effective)."
        case .fahrenheit, .celsius:
            return "Temperature is fixed to \(effective), regardless of Speed & Distance."
        }
    }

    private var locationStatusText: String {
        switch locationService.authorizationState {
        case .authorized: "Location: Authorized"
        case .denied: "Location: Denied"
        case .notDetermined: "Location: Not Determined"
        }
    }
}

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var rideViewModel: RideViewModel
    @ObservedObject var locationService: LocationService
    @ObservedObject var leanEntitlement: LeanAngleEntitlementStore
    let onAdaptiveSettingsChanged: () -> Void
    @Environment(\.openURL) private var openURL

    @State private var showOdometerResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Speed & Distance", selection: $settings.speedUnit) {
                        ForEach(SpeedUnit.allCases, id: \.self) { unit in
                            Text(unit == .imperial ? "Imperial (mph/mi)" : "Metric (km/h/km)")
                                .tag(unit)
                        }
                    }
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

                Section {
                    Toggle("Show Lean Angle", isOn: $settings.leanAngleEnabled)
                        .disabled(!leanEntitlement.isUnlocked)
                    if !leanEntitlement.isUnlocked {
                        Text("Unlock Lean Angle Pro to track real-time and max lean (coming soon).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Lean Angle")
                } footer: {
                    if leanEntitlement.isUnlocked {
                        Text("Calibrate with your phone mounted upright on the bike for accurate readings.")
                    }
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

    private var locationStatusText: String {
        switch locationService.authorizationState {
        case .authorized: "Location: Authorized"
        case .denied: "Location: Denied"
        case .notDetermined: "Location: Not Determined"
        }
    }
}

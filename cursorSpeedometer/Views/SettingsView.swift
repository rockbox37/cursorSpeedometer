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

                Section {
                    Stepper(
                        value: $settings.rainWarningWindowHours,
                        in: OpenMeteoMapper.minForecastWindowHours...OpenMeteoMapper.maxForecastWindowHours
                    ) {
                        Text("Rain warning window: ~\(settings.rainWarningWindowHours) \(rainWindowUnitLabel)")
                    }
                } header: {
                    Text("Weather Warnings")
                } footer: {
                    Text("Warn when rain is expected within this many hours ahead.")
                }

                Section {
                    Stepper(value: lowTempThresholdBinding, in: lowTempThresholdRange, step: 1) {
                        Text("Comfort threshold: \(lowTempThresholdBinding.wrappedValue)\(temperatureSymbol)")
                    }
                    Stepper(
                        value: $settings.lowTempWarningWindowHours,
                        in: OpenMeteoMapper.minForecastWindowHours...OpenMeteoMapper.maxForecastWindowHours
                    ) {
                        Text("Warn within: ~\(settings.lowTempWarningWindowHours) \(lowTempWindowUnitLabel)")
                    }
                } header: {
                    Text("Low Temperature Threshold")
                } footer: {
                    Text(
                        "The lowest temperature you're comfortable riding in. "
                        + "You'll be warned when the forecast is expected to drop below it within the window."
                    )
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

    private var rainWindowUnitLabel: String {
        settings.rainWarningWindowHours == 1 ? "hr" : "hrs"
    }

    private var lowTempWindowUnitLabel: String {
        settings.lowTempWarningWindowHours == 1 ? "hr" : "hrs"
    }

    private var temperatureSymbol: String {
        settings.resolvedTemperatureUnit.symbol
    }

    /// The comfort threshold expressed (and edited) in the resolved display unit,
    /// while stored canonically in Fahrenheit.
    private var lowTempThresholdBinding: Binding<Int> {
        Binding(
            get: { displayTemperature(settings.lowTempThresholdFahrenheit) },
            set: { settings.lowTempThresholdFahrenheit = fahrenheit(fromDisplay: $0) }
        )
    }

    private var lowTempThresholdRange: ClosedRange<Int> {
        let low = displayTemperature(AppSettings.minLowTempThresholdFahrenheit)
        let high = displayTemperature(AppSettings.maxLowTempThresholdFahrenheit)
        return low...high
    }

    private func displayTemperature(_ fahrenheit: Double) -> Int {
        switch settings.resolvedTemperatureUnit {
        case .fahrenheit: Int(fahrenheit.rounded())
        case .celsius: Int(((fahrenheit - 32) * 5 / 9).rounded())
        }
    }

    private func fahrenheit(fromDisplay value: Int) -> Double {
        switch settings.resolvedTemperatureUnit {
        case .fahrenheit: Double(value)
        case .celsius: Double(value) * 9 / 5 + 32
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

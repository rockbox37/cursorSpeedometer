import SwiftUI

struct RideView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var rideViewModel: RideViewModel
    @ObservedObject var locationService: LocationService

    private var palette: ThemePalette {
        ThemePalette.palette(for: settings.activeTheme)
    }

    var body: some View {
        ZStack {
            palette.backgroundColor.ignoresSafeArea()

            Color.black
                .opacity(BrightnessClamp.dimmingOpacity(for: settings.brightnessLevel))
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                rideModeIndicator
                speedDisplay
                statsGrid
                controls
            }
            .padding()
        }
        .onAppear {
            locationService.requestPermissionIfNeeded()
        }
    }

    @ViewBuilder
    private var rideModeIndicator: some View {
        if settings.rideModeEnabled {
            HStack {
                Spacer()
                Label("Ride", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentColor)
            }
        }
    }

    private var speedDisplay: some View {
        VStack(spacing: 8) {
            Text(rideViewModel.state.currentSpeedMps.formattedSpeed(using: settings.speedUnit))
                .font(.system(size: 130, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(settings.speedUnit.speedLabel)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.secondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatTile(
                title: "Trip",
                value: rideViewModel.state.tripDistanceMeters.formattedDistance(using: settings.speedUnit),
                unit: settings.speedUnit.distanceLabel,
                palette: palette
            )
            StatTile(
                title: "Odometer",
                value: rideViewModel.state.odometerMeters.formattedDistance(using: settings.speedUnit),
                unit: settings.speedUnit.distanceLabel,
                palette: palette
            )
            StatTile(
                title: "Max",
                value: rideViewModel.state.maxSpeedMps.formattedSpeed(using: settings.speedUnit),
                unit: settings.speedUnit.speedLabel,
                palette: palette
            )
            StatTile(
                title: "Average",
                value: rideViewModel.state.averageSpeedMps.formattedSpeed(using: settings.speedUnit),
                unit: settings.speedUnit.speedLabel,
                palette: palette
            )
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if locationService.authorizationState == .denied {
                Text("Location access is required for GPS speed. Enable it in Settings.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.secondaryColor)
            }

            Button("Reset Trip") {
                rideViewModel.resetTrip()
            }
            .font(.headline)
            .foregroundStyle(palette.backgroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(palette.accentColor)
            .clipShape(Capsule())
        }
    }
}

private extension Double {
    func formattedSpeed(using unit: SpeedUnit) -> String {
        unit.formatSpeed(metersPerSecond: self)
    }

    func formattedDistance(using unit: SpeedUnit) -> String {
        unit.formatDistance(meters: self)
    }
}

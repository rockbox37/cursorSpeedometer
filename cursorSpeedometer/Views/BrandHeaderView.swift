import SwiftUI

struct BrandHeaderView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationService: LocationService

    private var palette: ThemePalette {
        ThemePalette.palette(for: settings.activeTheme)
    }

    private var gpsStatus: GPSSignalStatus {
        GPSSignalStatus.resolve(
            authorization: locationService.authorizationState,
            horizontalAccuracy: locationService.latestSample?.horizontalAccuracy,
            lastFixDate: locationService.latestSample?.timestamp
        )
    }

    var body: some View {
        ZStack {
            Text("MotoSpeedy")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(palette.accentColor)

            HStack(alignment: .center) {
                GPSSignalStatusView(status: gpsStatus, palette: palette)
                Spacer()
                AppClockView(palette: palette)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(palette.backgroundColor)
    }
}

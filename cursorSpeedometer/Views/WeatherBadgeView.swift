import SwiftUI

struct WeatherBadgeView: View {
    let snapshot: WeatherSnapshot?
    let palette: ThemePalette

    var body: some View {
        if let snapshot {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.medium")
                    .font(.callout)
                    .foregroundStyle(palette.secondaryColor)

                Text(snapshot.temperatureText)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryColor)

                if snapshot.rainExpectedSoon {
                    Image(systemName: "cloud.rain.fill")
                        .font(.callout)
                        .foregroundStyle(palette.accentColor)
                        .accessibilityLabel("Rain expected within 6 hours")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

import SwiftUI

struct WeatherBadgeView: View {
    let snapshot: WeatherSnapshot?
    let palette: ThemePalette

    private static let coldColor = Color(red: 0.10, green: 0.45, blue: 0.90)
    private static let freezeColor = Color(red: 0.55, green: 0.85, blue: 1.0)
    /// Red used for the rain warning in the Day theme, for contrast on a bright background.
    private static let daytimeRainColor = Color(red: 0.85, green: 0.12, blue: 0.12)

    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .font(.title3)
                        .foregroundStyle(palette.secondaryColor)

                    Text(snapshot.temperatureText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(temperatureColor(for: snapshot.temperatureWarning))

                    warningBadge(for: snapshot.temperatureWarning)
                }
                .accessibilityElement(children: .combine)

                    if let primary = snapshot.rainPrimaryText, let secondary = snapshot.rainSecondaryText {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.rain.fill")
                            Text(primary)
                        }
                        Text(secondary)
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(rainColor)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(snapshot.rainText ?? "\(primary) \(secondary)")
                }
            }
        }
    }

    /// Red in the Day theme for contrast; the accent color otherwise (Night/Amber
    /// palettes are already red/amber).
    private var rainColor: Color {
        palette.isDayPreset ? Self.daytimeRainColor : palette.accentColor
    }

    private func temperatureColor(for warning: TemperatureWarning) -> Color {
        switch warning {
        case .none: palette.primaryColor
        case .cold: Self.coldColor
        case .freezing: Self.freezeColor
        }
    }

    @ViewBuilder
    private func warningBadge(for warning: TemperatureWarning) -> some View {
        switch warning {
        case .none:
            EmptyView()
        case .cold:
            Label("COLD", systemImage: "thermometer.snowflake")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Self.coldColor))
                .accessibilityLabel("Cold weather warning")
        case .freezing:
            Label("FREEZE", systemImage: "snowflake")
                .font(.callout.weight(.heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Self.freezeColor))
                .accessibilityLabel("Freeze warning, icy conditions possible")
        }
    }
}

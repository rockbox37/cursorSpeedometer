import SwiftUI

/// Conspicuous main-screen banner shown while a severe-weather watch/warning is active.
struct SevereWeatherAlertBanner: View {
    let alert: SevereWeatherAlert?

    private static let warningColor = Color(red: 0.85, green: 0.12, blue: 0.12)
    private static let watchColor = Color(red: 0.95, green: 0.62, blue: 0.0)

    var body: some View {
        if let alert {
            HStack(spacing: 8) {
                Image(systemName: alert.category.iconName)
                    .font(.title3.weight(.bold))
                Text(alert.text)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color(for: alert.level), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(alert.text), severe weather alert active")
        }
    }

    private func color(for level: SevereWeatherAlertLevel) -> Color {
        switch level {
        case .warning: Self.warningColor
        case .watch: Self.watchColor
        }
    }
}

#if DEBUG
#Preview("Severe weather banners") {
    VStack(spacing: 12) {
        SevereWeatherAlertBanner(
            alert: SevereWeatherAlert(category: .tornado, level: .warning, event: "Tornado Warning")
        )
        SevereWeatherAlertBanner(
            alert: SevereWeatherAlert(category: .tornado, level: .watch, event: "Tornado Watch")
        )
        SevereWeatherAlertBanner(
            alert: SevereWeatherAlert(category: .thunderstorm, level: .warning, event: "Severe Thunderstorm Warning")
        )
        SevereWeatherAlertBanner(
            alert: SevereWeatherAlert(category: .thunderstorm, level: .watch, event: "Severe Thunderstorm Watch")
        )
    }
    .padding()
    .background(Color.black)
}
#endif

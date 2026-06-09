import SwiftUI

struct BrandHeaderView: View {
    @ObservedObject var settings: AppSettings

    private var palette: ThemePalette {
        ThemePalette.palette(for: settings.activeTheme)
    }

    var body: some View {
        ZStack {
            Text("MotoSpeedy")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(palette.accentColor)

            HStack {
                Spacer()
                AppClockView(palette: palette)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(palette.backgroundColor)
    }
}

import SwiftUI

struct BrandHeaderView: View {
    @ObservedObject var settings: AppSettings

    private var palette: ThemePalette {
        ThemePalette.palette(for: settings.activeTheme)
    }

    var body: some View {
        Text("MotoSpeedy")
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(palette.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(palette.backgroundColor)
    }
}

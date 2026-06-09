import SwiftUI

struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryColor)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryColor)
            Text(unit)
                .font(.caption)
                .foregroundStyle(palette.secondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(palette.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

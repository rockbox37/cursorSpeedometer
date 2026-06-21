import SwiftUI

struct GPSSignalStatusView: View {
    let status: GPSSignalStatus
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.caption2)
            Text("GPS")
                .font(.caption2.weight(.medium))
            signalBars
        }
        .foregroundStyle(palette.secondaryColor.opacity(0.72))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.accessibilityLabel)
    }

    private var signalBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < status.filledBars ? palette.accentColor.opacity(0.85) : palette.secondaryColor.opacity(0.25))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        4 + CGFloat(index + 1) * 1.5
    }
}

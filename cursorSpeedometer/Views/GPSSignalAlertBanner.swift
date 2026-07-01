import SwiftUI

/// Prominent Ride-screen alert shown when GPS is lost or degraded. Speed is the
/// app's primary function and depends on a GPS fix, so a missing/poor signal is
/// surfaced far more conspicuously than the small header bars.
///
/// Colors are resolved from the active `ThemePalette` so the banner stays
/// high-contrast and legible in every theme (Day, Night all-red, Amber):
/// `.critical` inverts figure/ground (filled with the primary color, text in the
/// background color); `.degraded` uses a softer outlined treatment so a merely
/// weak fix reads as less alarming than a total loss.
struct GPSSignalAlertBanner: View {
    let status: GPSSignalStatus
    let palette: ThemePalette

    var body: some View {
        if let attention = status.attention,
           let title = status.alertTitle {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: attention))
                    .font(.title.weight(.bold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    if let guidance = status.alertGuidance {
                        // At least 50% larger than the former .footnote (~13pt) so the
                        // tip stays readable at a glance while riding; the title steps
                        // up in turn to keep the headline above the guidance.
                        Text(guidance)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground(for: attention))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(for: attention))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText(title: title))
        }
    }

    private func iconName(for attention: GPSAttentionLevel) -> String {
        switch attention {
        case .critical: "location.slash.fill"
        case .degraded: "exclamationmark.triangle.fill"
        }
    }

    private func foreground(for attention: GPSAttentionLevel) -> Color {
        switch attention {
        // Inverted: text in the background color reads clearly on the filled banner.
        case .critical: palette.backgroundColor
        // Softer: keep the primary color as text on a tinted fill.
        case .degraded: palette.primaryColor
        }
    }

    @ViewBuilder
    private func background(for attention: GPSAttentionLevel) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        switch attention {
        case .critical:
            shape.fill(palette.primaryColor)
        case .degraded:
            shape
                .fill(palette.primaryColor.opacity(0.12))
                .overlay {
                    shape.strokeBorder(palette.primaryColor.opacity(0.6), lineWidth: 1.5)
                }
        }
    }

    private func accessibilityText(title: String) -> String {
        if let guidance = status.alertGuidance {
            return "\(title). \(guidance)"
        }
        return title
    }
}

#if DEBUG
#Preview("GPS alert banners") {
    let statuses: [GPSSignalStatus] = [.unavailable, .searching, .weak]
    return VStack(spacing: 20) {
        ForEach([ThemePreset.day, .night, .amber], id: \.self) { preset in
            let palette = ThemePalette.palette(for: preset)
            VStack(spacing: 10) {
                ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                    GPSSignalAlertBanner(status: status, palette: palette)
                }
            }
            .padding()
            .background(palette.backgroundColor)
        }
    }
    .padding()
}
#endif

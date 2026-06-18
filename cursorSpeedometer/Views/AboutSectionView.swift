import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AboutSectionView: View {
    var body: some View {
        VStack(spacing: 12) {
            brandingHeader

            Text(
                "MotoSpeedy: Made for riders like you! MotoSpeedy will never "
                    + "track your location, capture or sell your personal information."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var brandingHeader: some View {
        VStack(spacing: 6) {
            if UIImage(named: "AboutMotorcycle") != nil {
                Image("AboutMotorcycle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary.opacity(0.75))
                    .frame(width: 86, height: 86)
            } else {
                Image(systemName: "motorcycle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .foregroundStyle(.secondary.opacity(0.75))
            }

            Text("MotoSpeedy")
                .font(.headline.weight(.bold))
        }
    }
}

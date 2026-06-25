import SwiftUI

struct CompassHeadingView: View {
    let headingDegrees: Double?
    let palette: ThemePalette

    var body: some View {
        let label = CompassHeading.cardinal(forDegrees: headingDegrees)
        Text(label)
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(palette.primaryColor)
            .accessibilityLabel(label == CompassHeading.placeholder ? "Heading unavailable" : "Heading \(label)")
    }
}

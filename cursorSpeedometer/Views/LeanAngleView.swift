import SwiftUI

struct LeanAngleView: View {
    @ObservedObject var viewModel: LeanAngleViewModel
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 16) {
            indicator

            Text(Self.signedDegrees(viewModel.state.currentDegrees))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryColor)
                .accessibilityLabel("Lean angle \(Self.signedDegrees(viewModel.state.currentDegrees))")

            HStack(spacing: 16) {
                StatTile(
                    title: "Max Left",
                    value: Self.magnitudeDegrees(viewModel.state.maxLeftDegrees),
                    unit: "° left",
                    palette: palette
                )
                StatTile(
                    title: "Max Right",
                    value: Self.magnitudeDegrees(viewModel.state.maxRightDegrees),
                    unit: "° right",
                    palette: palette
                )
            }

            HStack(spacing: 12) {
                Button("Calibrate Upright") {
                    viewModel.calibrate()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accentColor)

                Button("Reset Max") {
                    viewModel.resetMaxLean()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryColor)
            }

            if !viewModel.isSensorAvailable {
                Text("Motion sensor unavailable on this device.")
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    private var indicator: some View {
        ZStack {
            referenceGuide
            RearMotorcycleShape()
                .fill(palette.primaryColor)
                .frame(width: 70, height: 96)
                .rotationEffect(.degrees(viewModel.state.currentDegrees), anchor: .bottom)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8),
                           value: viewModel.state.currentDegrees)
        }
        .frame(height: 120)
    }

    private var referenceGuide: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(palette.secondaryColor.opacity(0.25))
                .frame(width: 1.5, height: 110)
            Capsule()
                .fill(palette.accent.opacity(0.4))
                .frame(width: 56, height: 3)
        }
    }

    static func signedDegrees(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)°" }
        if rounded < 0 { return "\(rounded)°" }
        return "0°"
    }

    static func magnitudeDegrees(_ value: Double) -> String {
        "\(Int(abs(value).rounded()))"
    }
}

/// Stylized rear-view motorcycle silhouette that pivots at the tire contact patch.
struct RearMotorcycleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Rear tire (narrow vertical slab at the bottom center).
        let tireWidth = w * 0.22
        path.addRoundedRect(
            in: CGRect(x: (w - tireWidth) / 2, y: h * 0.62, width: tireWidth, height: h * 0.38),
            cornerSize: CGSize(width: tireWidth / 2, height: tireWidth / 2)
        )

        // Body / tank tapering up from the tire.
        let bodyTopWidth = w * 0.5
        let bodyBottomWidth = w * 0.28
        path.move(to: CGPoint(x: (w - bodyBottomWidth) / 2, y: h * 0.66))
        path.addLine(to: CGPoint(x: (w - bodyTopWidth) / 2, y: h * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: (w + bodyTopWidth) / 2, y: h * 0.3),
            control: CGPoint(x: w / 2, y: h * 0.22)
        )
        path.addLine(to: CGPoint(x: (w + bodyBottomWidth) / 2, y: h * 0.66))
        path.closeSubpath()

        // Handlebars across the top.
        let barWidth = w * 0.92
        let barHeight = h * 0.09
        path.addRoundedRect(
            in: CGRect(x: (w - barWidth) / 2, y: h * 0.16, width: barWidth, height: barHeight),
            cornerSize: CGSize(width: barHeight / 2, height: barHeight / 2)
        )

        // Mirror / bar-end weights.
        let endRadius = w * 0.09
        path.addEllipse(in: CGRect(x: 0, y: h * 0.1, width: endRadius * 2, height: endRadius * 2))
        path.addEllipse(in: CGRect(x: w - endRadius * 2, y: h * 0.1, width: endRadius * 2, height: endRadius * 2))

        // Headlight / cowl.
        let headDiameter = w * 0.34
        path.addEllipse(in: CGRect(x: (w - headDiameter) / 2, y: 0, width: headDiameter, height: headDiameter))

        return path
    }
}

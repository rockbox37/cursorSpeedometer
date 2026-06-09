import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SplashView: View {
    let onFinished: () -> Void

    @State private var scale: CGFloat = 0.35
    @State private var opacity: Double = 1.0
    @State private var didStart = false

    private let duration: TimeInterval = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            splashLogo
                .scaleEffect(scale)
                .opacity(opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("MotoSpeedy")
        }
        .onAppear(perform: runAnimation)
    }

    @ViewBuilder
    private var splashLogo: some View {
        VStack(spacing: 0) {
            if UIImage(named: "SplashMotorcycle") != nil {
                Image("SplashMotorcycle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
            } else {
                Image(systemName: "motorcycle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .foregroundStyle(.white)
            }

            Text("MotoSpeedy")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, UIImage(named: "SplashMotorcycle") != nil ? -56 : -36)
        }
    }

    private func runAnimation() {
        guard !didStart else { return }
        didStart = true

        withAnimation(.easeOut(duration: duration)) {
            scale = 1.85
            opacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            onFinished()
        }
    }
}

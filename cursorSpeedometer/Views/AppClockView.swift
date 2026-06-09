import SwiftUI

struct AppClockView: View {
    let palette: ThemePalette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryColor.opacity(0.85))
                .accessibilityLabel("Current time \(context.date.formatted(date: .omitted, time: .shortened))")
        }
    }
}

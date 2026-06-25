import SwiftUI

struct AppClockView: View {
    let palette: ThemePalette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryColor)
                .accessibilityLabel("Current time \(context.date.formatted(date: .omitted, time: .shortened))")
        }
    }
}

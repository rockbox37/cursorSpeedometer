import Foundation

struct SolarSchedule: Equatable, Sendable {
    let sunrise: Date
    let sunset: Date
}

struct SolarScheduleService: Sendable {
    func schedule(for date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> SolarSchedule {
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: timeZone, from: date)
        components.hour = 12
        components.minute = 0
        components.second = 0
        let noon = calendar.date(from: components) ?? date

        let sunrise = solarEvent(
            on: noon,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            rising: true
        )
        let sunset = solarEvent(
            on: noon,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            rising: false
        )
        return SolarSchedule(sunrise: sunrise, sunset: sunset)
    }

    func isDaytime(at date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> Bool {
        let events = schedule(for: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
        return date >= events.sunrise && date < events.sunset
    }

    private func solarEvent(
        on date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        rising: Bool
    ) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let lngHour = longitude / 15.0
        let t = rising
            ? dayOfYear + ((6 - lngHour) / 24)
            : dayOfYear + ((18 - lngHour) / 24)

        let m = 0.9856 * t - 3.289
        var l = m + 1.916 * sin(deg2rad(m)) + 0.020 * sin(2 * deg2rad(m)) + 282.634
        l = normalizeDegrees(l)

        var ra = rad2deg(atan(0.91764 * tan(deg2rad(l))))
        ra = normalizeDegrees(ra)
        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra += (lQuadrant - raQuadrant)
        ra /= 15

        let sinDec = 0.39782 * sin(deg2rad(l))
        let cosDec = cos(asin(sinDec))
        let cosH = rising
            ? (cos(deg2rad(90.833)) - sinDec * sin(deg2rad(latitude)))
                / (cosDec * cos(deg2rad(latitude)))
            : (cos(deg2rad(90.833)) - sinDec * sin(deg2rad(latitude)))
                / (cosDec * cos(deg2rad(latitude)))

        let clampedCosH = min(1, max(-1, cosH))
        let h = rising
            ? 360 - rad2deg(acos(clampedCosH))
            : rad2deg(acos(clampedCosH))
        let hours = h / 15
        let eventUT = normalizeHours(hours + ra - (0.06571 * t) - 6.622)
        let eventLocal = eventUT - lngHour + Double(timeZone.secondsFromGMT(for: date)) / 3600
        let normalized = normalizeHours(eventLocal)

        var components = calendar.dateComponents(in: timeZone, from: date)
        let hour = Int(normalized)
        let minute = Int((normalized - Double(hour)) * 60)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private func deg2rad(_ value: Double) -> Double { value * .pi / 180 }
    private func rad2deg(_ value: Double) -> Double { value * 180 / .pi }
    private func sin(_ value: Double) -> Double { Foundation.sin(value) }
    private func cos(_ value: Double) -> Double { Foundation.cos(value) }
    private func tan(_ value: Double) -> Double { Foundation.tan(value) }
    private func asin(_ value: Double) -> Double { Foundation.asin(value) }
    private func acos(_ value: Double) -> Double { Foundation.acos(value) }
    private func atan(_ value: Double) -> Double { Foundation.atan(value) }

    private func normalizeDegrees(_ value: Double) -> Double {
        var result = value
        while result < 0 { result += 360 }
        while result >= 360 { result -= 360 }
        return result
    }

    private func normalizeHours(_ value: Double) -> Double {
        var result = value
        while result < 0 { result += 24 }
        while result >= 24 { result -= 24 }
        return result
    }
}

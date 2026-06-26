import Foundation

/// Parameters that shape a forecast fetch: display unit, the rain look-ahead
/// window, and the low-temperature warning window + threshold.
struct WeatherForecastConfig: Equatable, Sendable {
    var unit: TemperatureUnit
    var rainWindowHours: Int
    var lowTempWindowHours: Int
    /// Threshold (in °F) below which a forecast dip triggers a low-temp warning,
    /// or nil to disable the low-temp analysis.
    var lowTempThresholdFahrenheit: Double?

    init(
        unit: TemperatureUnit = .fahrenheit,
        rainWindowHours: Int = OpenMeteoMapper.defaultForecastWindowHours,
        lowTempWindowHours: Int = OpenMeteoMapper.defaultForecastWindowHours,
        lowTempThresholdFahrenheit: Double? = nil
    ) {
        self.unit = unit
        self.rainWindowHours = rainWindowHours
        self.lowTempWindowHours = lowTempWindowHours
        self.lowTempThresholdFahrenheit = lowTempThresholdFahrenheit
    }

    /// Hours of hourly forecast the request must cover to satisfy both analyses.
    /// The +1 accounts for hourly index 0 being the elapsed current hour, so the
    /// low-temp look-ahead still has `window` genuinely-future buckets after it.
    var forecastHours: Int {
        OpenMeteoMapper.clampWindowHours(max(rainWindowHours, lowTempWindowHours)) + 1
    }
}

/// Fetches current weather for a coordinate. Abstracted so it can be faked in tests.
protocol WeatherProvider: Sendable {
    func fetch(
        latitude: Double,
        longitude: Double,
        config: WeatherForecastConfig
    ) async throws -> WeatherSnapshot
}

enum WeatherServiceError: Error, Equatable {
    case invalidURL
    case badResponse
}

/// Raw Open-Meteo forecast payload (https://open-meteo.com — free, no API key).
struct OpenMeteoResponse: Decodable, Equatable {
    let current: OpenMeteoCurrent
    let hourly: OpenMeteoHourly?
}

struct OpenMeteoCurrent: Decodable, Equatable {
    let temperature2m: Double

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
    }
}

struct OpenMeteoHourly: Decodable, Equatable {
    let precipitationProbability: [Int?]?
    let precipitation: [Double?]?
    let temperature2m: [Double?]?

    enum CodingKeys: String, CodingKey {
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case temperature2m = "temperature_2m"
    }
}

/// Pure translation between the Open-Meteo payload and the app's snapshot model.
enum OpenMeteoMapper {
    /// Hourly probability at or above this percent counts as "rain expected".
    static let rainProbabilityThreshold = 50
    /// Hourly precipitation at or above this many millimetres counts as rain.
    static let rainAmountThresholdMm = 0.2
    /// Default number of upcoming hourly buckets to consider.
    static let defaultForecastWindowHours = 6
    /// Smallest user-selectable look-ahead window.
    static let minForecastWindowHours = 1
    /// Largest user-selectable look-ahead window.
    static let maxForecastWindowHours = 12

    /// Clamp an arbitrary window to the supported range.
    static func clampWindowHours(_ hours: Int) -> Int {
        min(maxForecastWindowHours, max(minForecastWindowHours, hours))
    }

    static func snapshot(from response: OpenMeteoResponse, config: WeatherForecastConfig) -> WeatherSnapshot {
        snapshot(
            from: response,
            unit: config.unit,
            windowHours: config.rainWindowHours,
            lowTempWindowHours: config.lowTempWindowHours,
            lowTempThresholdFahrenheit: config.lowTempThresholdFahrenheit
        )
    }

    static func snapshot(
        from response: OpenMeteoResponse,
        unit: TemperatureUnit,
        windowHours: Int = defaultForecastWindowHours,
        lowTempWindowHours: Int = defaultForecastWindowHours,
        lowTempThresholdFahrenheit: Double? = nil
    ) -> WeatherSnapshot {
        let probabilities = response.hourly?.precipitationProbability ?? []
        let amounts = response.hourly?.precipitation ?? []
        let temperatures = response.hourly?.temperature2m ?? []

        let currentFahrenheit = toFahrenheit(response.current.temperature2m, unit: unit)
        let lowTempHours = lowTempThresholdFahrenheit.flatMap { threshold in
            hoursUntilLowTemp(
                currentFahrenheit: currentFahrenheit,
                temperatures: temperatures,
                thresholdFahrenheit: threshold,
                unit: unit,
                windowHours: lowTempWindowHours
            )
        }

        return WeatherSnapshot(
            temperature: response.current.temperature2m,
            unit: unit,
            rainExpectedInHours: hoursUntilRain(
                probabilities: probabilities,
                amounts: amounts,
                windowHours: windowHours
            ),
            lowTempExpectedInHours: lowTempHours,
            lowTempThresholdFahrenheit: lowTempThresholdFahrenheit
        )
    }

    /// Returns the 1-based hour of the first upcoming bucket that meets the rain
    /// thresholds (the current hour counts as ~1), or nil if none does in the window.
    private static func hoursUntilRain(probabilities: [Int?], amounts: [Double?], windowHours: Int) -> Int? {
        for index in 0..<clampWindowHours(windowHours) {
            let probability = index < probabilities.count ? (probabilities[index] ?? 0) : 0
            let amount = index < amounts.count ? (amounts[index] ?? 0) : 0
            if probability >= rainProbabilityThreshold || amount >= rainAmountThresholdMm {
                return index + 1
            }
        }
        return nil
    }

    /// Hours ahead (next full hour = 1) of the first *future* forecast bucket
    /// whose temperature falls below the threshold, or nil.
    ///
    /// This is a forward-looking "may fall below" alert, so it only applies when
    /// the current temperature is at/above the threshold (otherwise the cold/freeze
    /// cues cover the present), and it ignores hourly index 0, which is the
    /// already-elapsed current hour and can read below the threshold near the
    /// dawn minimum even while the live temperature is climbing.
    private static func hoursUntilLowTemp(
        currentFahrenheit: Double,
        temperatures: [Double?],
        thresholdFahrenheit: Double,
        unit: TemperatureUnit,
        windowHours: Int
    ) -> Int? {
        guard currentFahrenheit >= thresholdFahrenheit else { return nil }
        let window = clampWindowHours(windowHours)
        for hoursAhead in 1...window {
            guard hoursAhead < temperatures.count, let temperature = temperatures[hoursAhead] else { continue }
            if toFahrenheit(temperature, unit: unit) < thresholdFahrenheit {
                return hoursAhead
            }
        }
        return nil
    }

    private static func toFahrenheit(_ temperature: Double, unit: TemperatureUnit) -> Double {
        unit == .celsius ? temperature * 9 / 5 + 32 : temperature
    }
}

struct OpenMeteoWeatherService: WeatherProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeURL(
        latitude: Double,
        longitude: Double,
        unit: TemperatureUnit,
        windowHours: Int = OpenMeteoMapper.defaultForecastWindowHours
    ) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
            URLQueryItem(name: "hourly", value: "precipitation_probability,precipitation,temperature_2m"),
            URLQueryItem(name: "forecast_hours", value: String(OpenMeteoMapper.clampWindowHours(windowHours))),
            URLQueryItem(name: "temperature_unit", value: unit.apiValue),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    func fetch(
        latitude: Double,
        longitude: Double,
        config: WeatherForecastConfig = WeatherForecastConfig()
    ) async throws -> WeatherSnapshot {
        guard let url = Self.makeURL(
            latitude: latitude,
            longitude: longitude,
            unit: config.unit,
            windowHours: config.forecastHours
        ) else {
            throw WeatherServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return OpenMeteoMapper.snapshot(from: decoded, config: config)
    }
}

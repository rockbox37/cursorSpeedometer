import Foundation

/// Fetches current weather for a coordinate. Abstracted so it can be faked in tests.
protocol WeatherProvider: Sendable {
    func fetch(latitude: Double, longitude: Double, unit: TemperatureUnit) async throws -> WeatherSnapshot
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

    enum CodingKeys: String, CodingKey {
        case precipitationProbability = "precipitation_probability"
        case precipitation
    }
}

/// Pure translation between the Open-Meteo payload and the app's snapshot model.
enum OpenMeteoMapper {
    /// Hourly probability at or above this percent counts as "rain expected".
    static let rainProbabilityThreshold = 50
    /// Hourly precipitation at or above this many millimetres counts as rain.
    static let rainAmountThresholdMm = 0.2
    /// Number of upcoming hourly buckets to consider.
    static let forecastWindowHours = 6

    static func snapshot(from response: OpenMeteoResponse, unit: TemperatureUnit) -> WeatherSnapshot {
        let probabilities = (response.hourly?.precipitationProbability ?? []).prefix(forecastWindowHours)
        let amounts = (response.hourly?.precipitation ?? []).prefix(forecastWindowHours)

        let rainByProbability = probabilities.contains { ($0 ?? 0) >= rainProbabilityThreshold }
        let rainByAmount = amounts.contains { ($0 ?? 0) >= rainAmountThresholdMm }

        return WeatherSnapshot(
            temperature: response.current.temperature2m,
            unit: unit,
            rainExpectedSoon: rainByProbability || rainByAmount
        )
    }
}

struct OpenMeteoWeatherService: WeatherProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeURL(latitude: Double, longitude: Double, unit: TemperatureUnit) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
            URLQueryItem(name: "hourly", value: "precipitation_probability,precipitation"),
            URLQueryItem(name: "forecast_hours", value: String(OpenMeteoMapper.forecastWindowHours)),
            URLQueryItem(name: "temperature_unit", value: unit.apiValue),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    func fetch(latitude: Double, longitude: Double, unit: TemperatureUnit) async throws -> WeatherSnapshot {
        guard let url = Self.makeURL(latitude: latitude, longitude: longitude, unit: unit) else {
            throw WeatherServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return OpenMeteoMapper.snapshot(from: decoded, unit: unit)
    }
}

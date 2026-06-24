import Foundation

/// Fetches the active severe-weather alert for a coordinate. Abstracted for testing.
protocol AlertProvider: Sendable {
    func fetchActiveAlert(latitude: Double, longitude: Double) async throws -> SevereWeatherAlert?
}

enum AlertServiceError: Error, Equatable {
    case invalidURL
    case badResponse
}

/// Raw National Weather Service active-alerts payload (GeoJSON).
/// https://www.weather.gov/documentation/services-web-api (free, US-only).
struct NWSAlertResponse: Decodable, Equatable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Decodable, Equatable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Decodable, Equatable {
    let event: String?
    /// "Alert", "Update", or "Cancel". Canceled alerts are ignored.
    let messageType: String?
}

/// Pure translation from the NWS payload to the app's severe-weather alert model.
enum NWSAlertMapper {
    static func alert(from response: NWSAlertResponse) -> SevereWeatherAlert? {
        var best: SevereWeatherAlert?
        for feature in response.features {
            guard let alert = alert(from: feature.properties) else { continue }
            if best == nil || alert.priority > best!.priority {
                best = alert
            }
        }
        return best
    }

    private static func alert(from properties: NWSAlertProperties) -> SevereWeatherAlert? {
        if properties.messageType?.caseInsensitiveCompare("Cancel") == .orderedSame {
            return nil
        }
        guard let event = properties.event else { return nil }
        let lowered = event.lowercased()

        let category: SevereWeatherCategory
        if lowered.contains("tornado") {
            category = .tornado
        } else if lowered.contains("thunderstorm") {
            category = .thunderstorm
        } else {
            return nil
        }

        let level: SevereWeatherAlertLevel
        if lowered.contains("warning") {
            level = .warning
        } else if lowered.contains("watch") {
            level = .watch
        } else {
            return nil
        }

        return SevereWeatherAlert(category: category, level: level, event: event)
    }
}

struct NWSAlertService: AlertProvider {
    /// NWS requires a descriptive User-Agent identifying the application.
    static let userAgent = "MotoSpeedy/1.0 (github.com/rockbox37/cursorSpeedometer)"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")
        components?.queryItems = [
            URLQueryItem(name: "point", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "status", value: "actual"),
            URLQueryItem(name: "message_type", value: "alert,update")
        ]
        return components?.url
    }

    func fetchActiveAlert(latitude: Double, longitude: Double) async throws -> SevereWeatherAlert? {
        guard let url = Self.makeURL(latitude: latitude, longitude: longitude) else {
            throw AlertServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AlertServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(NWSAlertResponse.self, from: data)
        return NWSAlertMapper.alert(from: decoded)
    }
}

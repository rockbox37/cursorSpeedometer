import Foundation

/// Fetches the active thunderstorm alert for a coordinate. Abstracted for testing.
protocol AlertProvider: Sendable {
    func fetchActiveThunderstormAlert(latitude: Double, longitude: Double) async throws -> ThunderstormAlert?
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

/// Pure translation from the NWS payload to the app's thunderstorm alert model.
enum NWSAlertMapper {
    static func thunderstormAlert(from response: NWSAlertResponse) -> ThunderstormAlert? {
        var best: ThunderstormAlert?
        for feature in response.features {
            guard let alert = alert(from: feature.properties) else { continue }
            if best == nil || alert.level.priority > best!.level.priority {
                best = alert
            }
        }
        return best
    }

    private static func alert(from properties: NWSAlertProperties) -> ThunderstormAlert? {
        if properties.messageType?.caseInsensitiveCompare("Cancel") == .orderedSame {
            return nil
        }
        guard let event = properties.event else { return nil }
        let lowered = event.lowercased()
        guard lowered.contains("thunderstorm") else { return nil }
        if lowered.contains("warning") {
            return ThunderstormAlert(level: .warning, event: event)
        }
        if lowered.contains("watch") {
            return ThunderstormAlert(level: .watch, event: event)
        }
        return nil
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

    func fetchActiveThunderstormAlert(latitude: Double, longitude: Double) async throws -> ThunderstormAlert? {
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
        return NWSAlertMapper.thunderstormAlert(from: decoded)
    }
}

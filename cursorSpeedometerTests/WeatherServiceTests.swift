import XCTest
@testable import cursorSpeedometer

final class WeatherServiceTests: XCTestCase {
    private func response(
        temperature: Double = 70,
        probabilities: [Int?]? = nil,
        amounts: [Double?]? = nil
    ) -> OpenMeteoResponse {
        OpenMeteoResponse(
            current: OpenMeteoCurrent(temperature2m: temperature),
            hourly: OpenMeteoHourly(
                precipitationProbability: probabilities,
                precipitation: amounts
            )
        )
    }

    func testSnapshotPassesTemperatureAndUnitThrough() {
        let snapshot = OpenMeteoMapper.snapshot(from: response(temperature: 66.8), unit: .fahrenheit)
        XCTAssertEqual(snapshot.temperature, 66.8, accuracy: 0.001)
        XCTAssertEqual(snapshot.unit, .fahrenheit)
    }

    func testRainExpectedWhenProbabilityMeetsThreshold() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [0, 10, 60, 0, 0, 0]),
            unit: .celsius
        )
        XCTAssertTrue(snapshot.rainExpectedSoon)
    }

    func testRainExpectedWhenPrecipitationAmountMeetsThreshold() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(amounts: [0, 0, 0.5, 0, 0, 0]),
            unit: .fahrenheit
        )
        XCTAssertTrue(snapshot.rainExpectedSoon)
    }

    func testNoRainWhenBelowThresholds() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [0, 20, 49, 10, 0, 0], amounts: [0, 0, 0.1, 0, 0, 0]),
            unit: .fahrenheit
        )
        XCTAssertFalse(snapshot.rainExpectedSoon)
    }

    func testRainOutsideSixHourWindowIsIgnored() {
        // High chance only in the 7th and 8th hours: outside the window.
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [0, 0, 0, 0, 0, 0, 90, 90]),
            unit: .fahrenheit
        )
        XCTAssertFalse(snapshot.rainExpectedSoon)
    }

    func testMissingHourlyDataMeansNoRain() {
        let snapshot = OpenMeteoMapper.snapshot(from: response(), unit: .fahrenheit)
        XCTAssertFalse(snapshot.rainExpectedSoon)
    }

    func testNullProbabilityEntriesAreTreatedAsZero() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [nil, nil, nil, nil, nil, nil]),
            unit: .fahrenheit
        )
        XCTAssertFalse(snapshot.rainExpectedSoon)
    }

    func testTemperatureTextRoundsAndAppendsSymbol() {
        let warm = WeatherSnapshot(temperature: 66.8, unit: .fahrenheit, rainExpectedSoon: false)
        XCTAssertEqual(warm.temperatureText, "67°F")

        let cool = WeatherSnapshot(temperature: 21.2, unit: .celsius, rainExpectedSoon: true)
        XCTAssertEqual(cool.temperatureText, "21°C")
    }

    func testSpeedUnitMapsToTemperatureUnit() {
        XCTAssertEqual(SpeedUnit.imperial.temperatureUnit, .fahrenheit)
        XCTAssertEqual(SpeedUnit.metric.temperatureUnit, .celsius)
    }

    func testMakeURLContainsExpectedQueryItems() throws {
        let url = try XCTUnwrap(
            OpenMeteoWeatherService.makeURL(latitude: 37.5, longitude: -122.25, unit: .celsius)
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(components.host, "api.open-meteo.com")
        XCTAssertEqual(items["latitude"], "37.5")
        XCTAssertEqual(items["longitude"], "-122.25")
        XCTAssertEqual(items["temperature_unit"], "celsius")
        XCTAssertEqual(items["forecast_hours"], "6")
        XCTAssertEqual(items["hourly"], "precipitation_probability,precipitation")
        XCTAssertEqual(items["current"], "temperature_2m")
    }

    func testFetchDecodesSnapshotFromPayload() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.responseData = Data(Self.samplePayload.utf8)
        let service = OpenMeteoWeatherService(session: Self.stubbedSession())

        let snapshot = try await service.fetch(latitude: 37, longitude: -122, unit: .fahrenheit)

        XCTAssertEqual(snapshot.temperature, 66.8, accuracy: 0.001)
        XCTAssertEqual(snapshot.unit, .fahrenheit)
        XCTAssertFalse(snapshot.rainExpectedSoon)
    }

    func testFetchThrowsOnHTTPError() async {
        StubURLProtocol.statusCode = 500
        StubURLProtocol.responseData = Data("{}".utf8)
        let service = OpenMeteoWeatherService(session: Self.stubbedSession())

        do {
            _ = try await service.fetch(latitude: 37, longitude: -122, unit: .fahrenheit)
            XCTFail("Expected fetch to throw on a 500 response")
        } catch {
            // Expected.
        }
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static let samplePayload = """
    {
      "current": { "temperature_2m": 66.8 },
      "hourly": {
        "precipitation_probability": [0, 0, 0, 0, 0, 0],
        "precipitation": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      }
    }
    """
}

class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData: Data?
    nonisolated(unsafe) static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url,
           let response = HTTPURLResponse(
               url: url,
               statusCode: Self.statusCode,
               httpVersion: nil,
               headerFields: nil
           ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = Self.responseData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

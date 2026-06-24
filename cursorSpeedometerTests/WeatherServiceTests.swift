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
        // First qualifying bucket is index 2 -> ~3 hours out (1-based).
        XCTAssertEqual(snapshot.rainExpectedInHours, 3)
    }

    func testRainExpectedWhenPrecipitationAmountMeetsThreshold() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(amounts: [0, 0, 0.5, 0, 0, 0]),
            unit: .fahrenheit
        )
        XCTAssertTrue(snapshot.rainExpectedSoon)
        XCTAssertEqual(snapshot.rainExpectedInHours, 3)
    }

    func testCurrentHourRainReportsOneHour() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [80, 0, 0, 0, 0, 0]),
            unit: .fahrenheit
        )
        XCTAssertEqual(snapshot.rainExpectedInHours, 1)
    }

    func testEarliestQualifyingBucketWins() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [0, 55, 90, 0, 0, 0]),
            unit: .fahrenheit
        )
        XCTAssertEqual(snapshot.rainExpectedInHours, 2)
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
        XCTAssertNil(snapshot.rainExpectedInHours)
    }

    func testMissingHourlyDataMeansNoRain() {
        let snapshot = OpenMeteoMapper.snapshot(from: response(), unit: .fahrenheit)
        XCTAssertFalse(snapshot.rainExpectedSoon)
        XCTAssertNil(snapshot.rainExpectedInHours)
    }

    func testNullProbabilityEntriesAreTreatedAsZero() {
        let snapshot = OpenMeteoMapper.snapshot(
            from: response(probabilities: [nil, nil, nil, nil, nil, nil]),
            unit: .fahrenheit
        )
        XCTAssertFalse(snapshot.rainExpectedSoon)
        XCTAssertNil(snapshot.rainExpectedInHours)
    }

    func testRainTextFormatsTimeframeWithPluralization() {
        let oneHour = WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: 1)
        XCTAssertEqual(oneHour.rainText, "Rain possible within ~1hr")

        let threeHours = WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: 3)
        XCTAssertEqual(threeHours.rainText, "Rain possible within ~3hrs")
    }

    func testRainTextIsNilWhenNoRainExpected() {
        let dry = WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: nil)
        XCTAssertNil(dry.rainText)
        XCTAssertNil(dry.rainPrimaryText)
        XCTAssertNil(dry.rainSecondaryText)
    }

    func testRainSplitsIntoTwoLines() {
        let oneHour = WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: 1)
        XCTAssertEqual(oneHour.rainPrimaryText, "Rain possible")
        XCTAssertEqual(oneHour.rainSecondaryText, "within ~1hr")

        let threeHours = WeatherSnapshot(temperature: 60, unit: .fahrenheit, rainExpectedInHours: 3)
        XCTAssertEqual(threeHours.rainPrimaryText, "Rain possible")
        XCTAssertEqual(threeHours.rainSecondaryText, "within ~3hrs")
    }

    func testTemperatureTextRoundsAndAppendsSymbol() {
        let warm = WeatherSnapshot(temperature: 66.8, unit: .fahrenheit, rainExpectedInHours: nil)
        XCTAssertEqual(warm.temperatureText, "67°F")

        let cool = WeatherSnapshot(temperature: 21.2, unit: .celsius, rainExpectedInHours: 2)
        XCTAssertEqual(cool.temperatureText, "21°C")
    }

    private func warning(fahrenheit: Double) -> TemperatureWarning {
        WeatherSnapshot(temperature: fahrenheit, unit: .fahrenheit, rainExpectedInHours: nil)
            .temperatureWarning
    }

    private func warning(celsius: Double) -> TemperatureWarning {
        WeatherSnapshot(temperature: celsius, unit: .celsius, rainExpectedInHours: nil)
            .temperatureWarning
    }

    func testNoWarningAboveColdThreshold() {
        XCTAssertEqual(warning(fahrenheit: 41), .none)
        XCTAssertEqual(warning(fahrenheit: 72), .none)
    }

    func testColdWarningAtOrBelowFortyButAboveFreeze() {
        XCTAssertEqual(warning(fahrenheit: 40), .cold)
        XCTAssertEqual(warning(fahrenheit: 38), .cold)
        XCTAssertEqual(warning(fahrenheit: 37.5), .cold)
    }

    func testFreezeWarningAtOrBelowThirtySeven() {
        XCTAssertEqual(warning(fahrenheit: 37), .freezing)
        XCTAssertEqual(warning(fahrenheit: 30), .freezing)
        XCTAssertEqual(warning(fahrenheit: 0), .freezing)
    }

    func testWarningThresholdsHoldInCelsius() {
        // 10°C = 50°F (none), ~4.4°C = 40°F (cold), ~2.8°C = 37°F (freezing).
        XCTAssertEqual(warning(celsius: 10), .none)
        XCTAssertEqual(warning(celsius: 4), .cold)
        XCTAssertEqual(warning(celsius: 3), .cold)
        XCTAssertEqual(warning(celsius: 2), .freezing)
        XCTAssertEqual(warning(celsius: -5), .freezing)
    }

    private func nearFreezing(fahrenheit: Double) -> Bool {
        WeatherSnapshot(temperature: fahrenheit, unit: .fahrenheit, rainExpectedInHours: nil)
            .isNearOrBelowFreezing
    }

    private func nearFreezing(celsius: Double) -> Bool {
        WeatherSnapshot(temperature: celsius, unit: .celsius, rainExpectedInHours: nil)
            .isNearOrBelowFreezing
    }

    func testNotNearFreezingAboveMargin() {
        // Freezing 32°F + 5°F margin = 37°F threshold.
        XCTAssertFalse(nearFreezing(fahrenheit: 38))
        XCTAssertFalse(nearFreezing(fahrenheit: 60))
    }

    func testNearFreezingAtOrBelowThreshold() {
        XCTAssertTrue(nearFreezing(fahrenheit: 37))
        XCTAssertTrue(nearFreezing(fahrenheit: 33))
        XCTAssertTrue(nearFreezing(fahrenheit: 32))
        XCTAssertTrue(nearFreezing(fahrenheit: 0))
    }

    func testNearFreezingThresholdHoldsInCelsius() {
        // 3°C = 37.4°F (above), 2°C = 35.6°F (within margin).
        XCTAssertFalse(nearFreezing(celsius: 3))
        XCTAssertTrue(nearFreezing(celsius: 2))
        XCTAssertTrue(nearFreezing(celsius: -5))
    }

    func testTemperatureFahrenheitConversion() {
        let celsius = WeatherSnapshot(temperature: 0, unit: .celsius, rainExpectedInHours: nil)
        XCTAssertEqual(celsius.temperatureFahrenheit, 32, accuracy: 0.001)

        let fahrenheit = WeatherSnapshot(temperature: 50, unit: .fahrenheit, rainExpectedInHours: nil)
        XCTAssertEqual(fahrenheit.temperatureFahrenheit, 50, accuracy: 0.001)
    }

    func testSpeedUnitMapsToTemperatureUnit() {
        XCTAssertEqual(SpeedUnit.imperial.temperatureUnit, .fahrenheit)
        XCTAssertEqual(SpeedUnit.metric.temperatureUnit, .celsius)
    }

    func testSettingsOptionLabelNamesSpeedAndDistance() {
        let imperial = SpeedUnit.imperial.settingsOptionLabel
        XCTAssertTrue(imperial.contains("Imperial"))
        XCTAssertTrue(imperial.contains("mph"))
        XCTAssertTrue(imperial.contains("mi"))

        let metric = SpeedUnit.metric.settingsOptionLabel
        XCTAssertTrue(metric.contains("Metric"))
        XCTAssertTrue(metric.contains("km/h"))
        XCTAssertTrue(metric.contains("km"))
    }

    func testAutomaticPreferenceFollowsSpeedUnit() {
        XCTAssertEqual(TemperaturePreference.automatic.resolvedUnit(following: .imperial), .fahrenheit)
        XCTAssertEqual(TemperaturePreference.automatic.resolvedUnit(following: .metric), .celsius)
    }

    func testExplicitPreferenceIgnoresSpeedUnit() {
        XCTAssertEqual(TemperaturePreference.fahrenheit.resolvedUnit(following: .imperial), .fahrenheit)
        XCTAssertEqual(TemperaturePreference.fahrenheit.resolvedUnit(following: .metric), .fahrenheit)
        XCTAssertEqual(TemperaturePreference.celsius.resolvedUnit(following: .imperial), .celsius)
        XCTAssertEqual(TemperaturePreference.celsius.resolvedUnit(following: .metric), .celsius)
    }

    @MainActor
    func testAppSettingsResolvesAndPersistsTemperaturePreference() {
        let suite = "test.temperature.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.temperaturePreference, .automatic)

        settings.speedUnit = .metric
        XCTAssertEqual(settings.resolvedTemperatureUnit, .celsius)

        settings.temperaturePreference = .fahrenheit
        XCTAssertEqual(settings.resolvedTemperatureUnit, .fahrenheit)

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.temperaturePreference, .fahrenheit)
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

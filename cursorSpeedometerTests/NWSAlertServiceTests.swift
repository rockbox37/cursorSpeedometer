import XCTest
@testable import cursorSpeedometer

final class NWSAlertServiceTests: XCTestCase {
    private func response(_ features: [(event: String?, messageType: String?)]) -> NWSAlertResponse {
        NWSAlertResponse(
            features: features.map {
                NWSAlertFeature(properties: NWSAlertProperties(event: $0.event, messageType: $0.messageType))
            }
        )
    }

    func testWarningTakesPriorityOverWatch() {
        let alert = NWSAlertMapper.thunderstormAlert(from: response([
            (event: "Severe Thunderstorm Watch", messageType: "Alert"),
            (event: "Severe Thunderstorm Warning", messageType: "Alert")
        ]))
        XCTAssertEqual(alert?.level, .warning)
        XCTAssertEqual(alert?.event, "Severe Thunderstorm Warning")
    }

    func testWatchDetectedWhenNoWarning() {
        let alert = NWSAlertMapper.thunderstormAlert(from: response([
            (event: "Severe Thunderstorm Watch", messageType: "Alert")
        ]))
        XCTAssertEqual(alert?.level, .watch)
    }

    func testCanceledAlertsAreIgnored() {
        let alert = NWSAlertMapper.thunderstormAlert(from: response([
            (event: "Severe Thunderstorm Warning", messageType: "Cancel")
        ]))
        XCTAssertNil(alert)
    }

    func testNonThunderstormEventsAreIgnored() {
        let alert = NWSAlertMapper.thunderstormAlert(from: response([
            (event: "Flood Warning", messageType: "Alert"),
            (event: "Heat Advisory", messageType: "Alert")
        ]))
        XCTAssertNil(alert)
    }

    func testThunderstormStatementWithoutWatchOrWarningIsIgnored() {
        let alert = NWSAlertMapper.thunderstormAlert(from: response([
            (event: "Severe Thunderstorm Statement", messageType: "Alert")
        ]))
        XCTAssertNil(alert)
    }

    func testEmptyFeaturesYieldNoAlert() {
        XCTAssertNil(NWSAlertMapper.thunderstormAlert(from: response([])))
    }

    func testAlertTextFallsBackWhenEventEmpty() {
        XCTAssertEqual(ThunderstormAlert(level: .warning, event: "").text, "Thunderstorm Warning")
        XCTAssertEqual(ThunderstormAlert(level: .watch, event: "").text, "Thunderstorm Watch")
    }

    func testMakeURLContainsPointAndHost() throws {
        let url = try XCTUnwrap(NWSAlertService.makeURL(latitude: 37.5, longitude: -122.25))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(components.host, "api.weather.gov")
        XCTAssertEqual(components.path, "/alerts/active")
        XCTAssertEqual(items["point"], "37.5,-122.25")
    }

    func testFetchDecodesAlertAndSendsUserAgent() async throws {
        NWSStubURLProtocol.statusCode = 200
        NWSStubURLProtocol.responseData = Data(Self.samplePayload.utf8)
        NWSStubURLProtocol.lastUserAgent = nil
        let service = NWSAlertService(session: Self.stubbedSession())

        let alert = try await service.fetchActiveThunderstormAlert(latitude: 37, longitude: -122)

        XCTAssertEqual(alert?.level, .warning)
        XCTAssertEqual(NWSStubURLProtocol.lastUserAgent, NWSAlertService.userAgent)
    }

    func testFetchThrowsOnHTTPError() async {
        NWSStubURLProtocol.statusCode = 500
        NWSStubURLProtocol.responseData = Data("{}".utf8)
        let service = NWSAlertService(session: Self.stubbedSession())

        do {
            _ = try await service.fetchActiveThunderstormAlert(latitude: 37, longitude: -122)
            XCTFail("Expected fetch to throw on a 500 response")
        } catch {
            // Expected.
        }
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NWSStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static let samplePayload = """
    {
      "features": [
        { "properties": { "event": "Severe Thunderstorm Warning", "messageType": "Alert" } }
      ]
    }
    """
}

class NWSStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData: Data?
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastUserAgent: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastUserAgent = request.value(forHTTPHeaderField: "User-Agent")
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

import XCTest
@testable import cursorSpeedometer

final class GPSSignalStatusTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testUnavailableWhenLocationDenied() {
        let status = GPSSignalStatus.resolve(
            authorization: .denied,
            horizontalAccuracy: 5,
            lastFixDate: now,
            now: now
        )

        XCTAssertEqual(status, .unavailable)
        XCTAssertEqual(status.filledBars, 0)
    }

    func testSearchingWithoutFix() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: nil,
            lastFixDate: nil,
            now: now
        )

        XCTAssertEqual(status, .searching)
    }

    func testSearchingWhenFixIsStale() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: 5,
            lastFixDate: now.addingTimeInterval(-6),
            now: now
        )

        XCTAssertEqual(status, .searching)
    }

    func testStrongForHighAccuracyFix() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: 6,
            lastFixDate: now,
            now: now
        )

        XCTAssertEqual(status, .strong)
        XCTAssertEqual(status.filledBars, 4)
    }

    func testGoodForModerateAccuracyFix() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: 12,
            lastFixDate: now,
            now: now
        )

        XCTAssertEqual(status, .good)
        XCTAssertEqual(status.filledBars, 3)
    }

    func testFairForLowerAccuracyFix() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: 20,
            lastFixDate: now,
            now: now
        )

        XCTAssertEqual(status, .fair)
        XCTAssertEqual(status.filledBars, 2)
    }

    func testWeakForPoorAccuracyFix() {
        let status = GPSSignalStatus.resolve(
            authorization: .authorized,
            horizontalAccuracy: 40,
            lastFixDate: now,
            now: now
        )

        XCTAssertEqual(status, .weak)
        XCTAssertEqual(status.filledBars, 1)
    }

    // MARK: - Attention / alert content

    func testCriticalAttentionForNoUsableFix() {
        XCTAssertEqual(GPSSignalStatus.unavailable.attention, .critical)
        XCTAssertEqual(GPSSignalStatus.searching.attention, .critical)
    }

    func testDegradedAttentionForWeakFix() {
        XCTAssertEqual(GPSSignalStatus.weak.attention, .degraded)
    }

    func testNoAttentionForHealthyFix() {
        XCTAssertNil(GPSSignalStatus.fair.attention)
        XCTAssertNil(GPSSignalStatus.good.attention)
        XCTAssertNil(GPSSignalStatus.strong.attention)
    }

    func testAlertContentPresentForAttentionStates() {
        for status in [GPSSignalStatus.unavailable, .searching, .weak] {
            XCTAssertNotNil(status.alertTitle, "\(status) should have an alert title")
            XCTAssertNotNil(status.alertGuidance, "\(status) should have guidance")
        }
    }

    func testUnavailableGuidancePointsToSettings() {
        XCTAssertEqual(GPSSignalStatus.unavailable.alertGuidance,
                       "Enable Location Services for this app in Settings.")
    }

    func testSearchingAndWeakGuidanceMentionClearSky() {
        let expected = "Make sure your device has a clear, unobstructed view of the sky."
        XCTAssertEqual(GPSSignalStatus.searching.alertGuidance, expected)
        XCTAssertEqual(GPSSignalStatus.weak.alertGuidance, expected)
    }

    func testNoAlertContentForHealthyFix() {
        for status in [GPSSignalStatus.fair, .good, .strong] {
            XCTAssertNil(status.alertTitle, "\(status) should have no alert title")
            XCTAssertNil(status.alertGuidance, "\(status) should have no guidance")
        }
    }
}

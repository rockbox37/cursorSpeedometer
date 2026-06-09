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
}

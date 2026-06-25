import XCTest
@testable import cursorSpeedometer

final class CompassHeadingTests: XCTestCase {
    func testCardinalForPrincipalDirections() {
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 0), "N")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 45), "NE")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 90), "E")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 135), "SE")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 180), "S")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 225), "SW")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 270), "W")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 315), "NW")
    }

    func testCardinalRoundsToNearestSector() {
        // Just inside the NE sector (22.5° boundary) and just inside N again.
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 23), "NE")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 22), "N")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 100), "E")
    }

    func testCardinalWrapsAroundNorth() {
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 338), "N")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 360), "N")
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: 405), "NE")
    }

    func testPlaceholderForMissingOrInvalid() {
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: nil), CompassHeading.placeholder)
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: -1), CompassHeading.placeholder)
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: .nan), CompassHeading.placeholder)
        XCTAssertEqual(CompassHeading.cardinal(forDegrees: .infinity), CompassHeading.placeholder)
    }
}

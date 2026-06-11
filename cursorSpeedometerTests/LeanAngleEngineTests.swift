import XCTest
@testable import cursorSpeedometer

final class LeanAngleEngineTests: XCTestCase {
    private let engine = LeanAngleEngine()

    func testUprightGravityIsZeroDegrees() {
        XCTAssertEqual(engine.rawLeanDegrees(gravityX: 0, gravityY: -1), 0, accuracy: 0.001)
    }

    func testLeanRightIsPositive() {
        let degrees = engine.rawLeanDegrees(gravityX: 0.5, gravityY: -0.8660254)
        XCTAssertEqual(degrees, 30, accuracy: 0.01)
    }

    func testLeanLeftIsNegative() {
        let degrees = engine.rawLeanDegrees(gravityX: -0.5, gravityY: -0.8660254)
        XCTAssertEqual(degrees, -30, accuracy: 0.01)
    }

    func testSmoothingMovesTowardTarget() {
        let state = engine.process(rawDegrees: 30, speedMps: 10, state: LeanAngleState())
        XCTAssertEqual(state.currentDegrees, 6, accuracy: 0.001)
    }

    func testConvergesToTargetOverManySamples() {
        var state = LeanAngleState()
        for _ in 0..<100 {
            state = engine.process(rawDegrees: 35, speedMps: 10, state: state)
        }
        XCTAssertEqual(state.currentDegrees, 35, accuracy: 0.5)
    }

    func testTracksMaxLeftAndRightWhileMoving() {
        var state = LeanAngleState()
        for _ in 0..<100 {
            state = engine.process(rawDegrees: 40, speedMps: 10, state: state)
        }
        for _ in 0..<100 {
            state = engine.process(rawDegrees: -25, speedMps: 10, state: state)
        }
        XCTAssertEqual(state.maxRightDegrees, 40, accuracy: 0.5)
        XCTAssertEqual(state.maxLeftDegrees, -25, accuracy: 0.5)
    }

    func testDoesNotTrackMaxBelowMovingThreshold() {
        var state = LeanAngleState()
        for _ in 0..<100 {
            state = engine.process(rawDegrees: 40, speedMps: 1.0, state: state)
        }
        XCTAssertEqual(state.maxRightDegrees, 0, accuracy: 0.001)
        XCTAssertGreaterThan(state.currentDegrees, 0)
    }

    func testClampsImplausibleReadings() {
        let state = engine.process(rawDegrees: 200, speedMps: 10, state: LeanAngleState())
        // Clamped to 90 before smoothing: 90 * 0.2 = 18, not 200 * 0.2 = 40.
        XCTAssertEqual(state.currentDegrees, 18, accuracy: 0.001)
    }

    func testCalibrationOffsetIsSubtracted() {
        var state = engine.calibrate(rawDegrees: 12, state: LeanAngleState())
        XCTAssertEqual(state.calibrationOffset, 12, accuracy: 0.001)
        XCTAssertEqual(state.currentDegrees, 0, accuracy: 0.001)

        for _ in 0..<100 {
            state = engine.process(rawDegrees: 12, speedMps: 10, state: state)
        }
        XCTAssertEqual(state.currentDegrees, 0, accuracy: 0.5)
    }

    func testResetMaxLeanPreservesCalibration() {
        var state = LeanAngleState(
            currentDegrees: 10,
            maxLeftDegrees: -30,
            maxRightDegrees: 45,
            calibrationOffset: 5
        )
        state = engine.resetMaxLean(state: state)

        XCTAssertEqual(state.maxLeftDegrees, 0)
        XCTAssertEqual(state.maxRightDegrees, 0)
        XCTAssertEqual(state.calibrationOffset, 5)
    }
}

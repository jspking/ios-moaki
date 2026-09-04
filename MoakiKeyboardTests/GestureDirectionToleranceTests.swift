import CoreGraphics
import XCTest

@testable import MoakiKeyboardCore

/// Angles use the 0-360 space where right is 0, up is 90, left is 180 and
/// down is 270. Every basic vowel owns `cardinalHalfAngle` degrees on either
/// side of its own axis, and ㅣ(↗)/ㅡ(↘) take over the wedges in between only
/// once the stroke passes `diagonalThreshold`.
final class GestureDirectionToleranceTests: XCTestCase {

    private let halfAngle = KeyboardMetrics.cardinalHalfAngle
    private let diagonalThreshold = KeyboardMetrics.diagonalThreshold

    // MARK: - Symmetric windows

    func testEachBasicVowelOwnsTheSameWindowOnBothSidesOfItsAxis() {
        for (axis, expected) in [(0, GestureDirection.right), (90, .up), (180, .left), (270, .down)] {
            let axis = CGFloat(axis)
            XCTAssertEqual(bearing(atDegrees: axis), expected, "axis \(axis)")
            XCTAssertEqual(bearing(atDegrees: axis - halfAngle), expected, "axis \(axis) minus half angle")
            XCTAssertEqual(bearing(atDegrees: axis + halfAngle), expected, "axis \(axis) plus half angle")
        }
    }

    func testAngleJustInsideEachBoundaryStaysWithTheBasicVowel() {
        XCTAssertEqual(bearing(atDegrees: 29), .right)
        XCTAssertEqual(bearing(atDegrees: 61), .up)
        XCTAssertEqual(bearing(atDegrees: 119), .up)
        XCTAssertEqual(bearing(atDegrees: 151), .left)
        XCTAssertEqual(bearing(atDegrees: 209), .left)
        XCTAssertEqual(bearing(atDegrees: 241), .down)
        XCTAssertEqual(bearing(atDegrees: 299), .down)
        XCTAssertEqual(bearing(atDegrees: 331), .right)
    }

    func testAngleJustOutsideEachBoundaryBecomesADiagonalBearing() {
        XCTAssertEqual(bearing(atDegrees: 31), .upRight)
        XCTAssertEqual(bearing(atDegrees: 59), .upRight)
        XCTAssertEqual(bearing(atDegrees: 121), .upLeft)
        XCTAssertEqual(bearing(atDegrees: 149), .upLeft)
        XCTAssertEqual(bearing(atDegrees: 211), .downLeft)
        XCTAssertEqual(bearing(atDegrees: 239), .downLeft)
        XCTAssertEqual(bearing(atDegrees: 301), .downRight)
        XCTAssertEqual(bearing(atDegrees: 329), .downRight)
    }

    func testUpAndDownDriftTheSameAmountToEitherSide() {
        XCTAssertEqual(vowel(atDegrees: 90 - halfAngle, distance: 40), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 90 + halfAngle, distance: 40), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 270 - halfAngle, distance: 40), .ㅜ)
        XCTAssertEqual(vowel(atDegrees: 270 + halfAngle, distance: 40), .ㅜ)
    }

    // MARK: - Diagonal length gate

    func testDiagonalWedgeNeedsTheFullDistanceBeforeItBecomesIOrEu() {
        XCTAssertEqual(vowel(atDegrees: 45, distance: diagonalThreshold - 1), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 45, distance: diagonalThreshold), .ㅣ)
        XCTAssertEqual(vowel(atDegrees: 45, distance: diagonalThreshold + 1), .ㅣ)

        XCTAssertEqual(vowel(atDegrees: 315, distance: diagonalThreshold - 1), .ㅜ)
        XCTAssertEqual(vowel(atDegrees: 315, distance: diagonalThreshold), .ㅡ)
        XCTAssertEqual(vowel(atDegrees: 315, distance: diagonalThreshold + 1), .ㅡ)
    }

    func testShortStrokeInTheOverlapBandFallsBackToTheNearestBasicVowel() {
        XCTAssertEqual(vowel(atDegrees: 35, distance: 40), .ㅏ)
        XCTAssertEqual(vowel(atDegrees: 55, distance: 40), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 305, distance: 40), .ㅜ)
        XCTAssertEqual(vowel(atDegrees: 325, distance: 40), .ㅏ)
    }

    func testLongBasicVowelStrokeIsNeverPromotedToADiagonalVowel() {
        for distance in [diagonalThreshold, diagonalThreshold * 2, diagonalThreshold * 4] {
            XCTAssertEqual(vowel(atDegrees: 0, distance: distance), .ㅏ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 90, distance: distance), .ㅗ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 180, distance: distance), .ㅓ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 270, distance: distance), .ㅜ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 90 - halfAngle, distance: distance), .ㅗ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 270 + halfAngle, distance: distance), .ㅜ, "\(distance)pt")
        }
    }

    /// ↖ and ↙ stand for no vowel of their own, so they resolve to whichever
    /// basic vowel is closest no matter how far the finger travels.
    func testLeftDiagonalsResolveByAngleAloneAtAnyDistance() {
        for distance in [CGFloat(25), 40, diagonalThreshold, diagonalThreshold * 3] {
            XCTAssertEqual(vowel(atDegrees: 130, distance: distance), .ㅗ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 140, distance: distance), .ㅓ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 230, distance: distance), .ㅜ, "\(distance)pt")
            XCTAssertEqual(vowel(atDegrees: 220, distance: distance), .ㅓ, "\(distance)pt")
        }
    }

    /// A stroke drawn exactly between two axes has to pick one; ㅗ and ㅜ win,
    /// because those are the vowels users most often miss.
    func testStrokeExactlyBetweenTwoAxesPrefersTheVerticalVowel() {
        XCTAssertEqual(vowel(atDegrees: 135, distance: 40), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 225, distance: 40), .ㅜ)
        XCTAssertEqual(vowel(atDegrees: 45, distance: 40), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 315, distance: 40), .ㅜ)
    }

    // MARK: - Helpers

    private func vector(atDegrees degrees: CGFloat, distance: CGFloat) -> CGVector {
        let radians = degrees * .pi / 180
        return CGVector(dx: cos(radians) * distance, dy: -sin(radians) * distance)
    }

    /// Angle-only reading, with no length gate applied.
    private func bearing(atDegrees degrees: CGFloat) -> GestureDirection? {
        GestureDirection.from(vector: vector(atDegrees: degrees, distance: 40))
    }

    private func vowel(atDegrees degrees: CGFloat, distance: CGFloat) -> Jungseong? {
        let candidate = GestureDirection.from(
            vector: vector(atDegrees: degrees, distance: distance),
            threshold: KeyboardMetrics.gestureThreshold,
            diagonalThreshold: KeyboardMetrics.diagonalThreshold
        )
        guard let candidate else { return nil }
        return VowelResolver().resolve(directions: [candidate]).vowel
    }
}

import CoreGraphics
import XCTest

@testable import MoakiKeyboardCore

final class GestureDirectionToleranceTests: XCTestCase {
    func testUpAllowsTwentyDegreesOfRightDrift() {
        XCTAssertEqual(direction(atDegrees: 70), .up)
        XCTAssertEqual(direction(atDegrees: 75), .up)
    }

    func testUpRightStillIncludesDeliberateDiagonalStroke() {
        XCTAssertEqual(direction(atDegrees: 45), .upRight)
        XCTAssertEqual(direction(atDegrees: 69), .upRight)
    }

    func testDownAllowsTwentyDegreesOfRightDrift() {
        XCTAssertEqual(direction(atDegrees: 285), .down)
        XCTAssertEqual(direction(atDegrees: 289), .down)
    }

    func testDownRightStillIncludesDeliberateDiagonalStroke() {
        XCTAssertEqual(direction(atDegrees: 300), .downRight)
        XCTAssertEqual(direction(atDegrees: 315), .downRight)
    }

    func testAdjustedDirectionsResolveToExpectedBasicVowels() {
        XCTAssertEqual(vowel(atDegrees: 75), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 285), .ㅜ)
    }

    /// ㅡ and ㅣ moved to long strokes, so a short diagonal no longer selects a
    /// vowel of its own; every diagonal folds onto the vertical axis.
    func testShortDiagonalsFoldOntoVerticalVowels() {
        XCTAssertEqual(vowel(atDegrees: 45), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 135), .ㅗ)
        XCTAssertEqual(vowel(atDegrees: 225), .ㅜ)
        XCTAssertEqual(vowel(atDegrees: 315), .ㅜ)
    }

    private func direction(atDegrees degrees: CGFloat) -> GestureDirection? {
        let radians = degrees * .pi / 180
        let distance: CGFloat = 40
        let vector = CGVector(
            dx: cos(radians) * distance,
            dy: -sin(radians) * distance
        )
        return GestureDirection.from(vector: vector)
    }

    private func vowel(atDegrees degrees: CGFloat) -> Jungseong? {
        guard let direction = direction(atDegrees: degrees) else { return nil }
        return VowelResolver().resolve(directions: [direction]).vowel
    }
}

import CoreGraphics
import XCTest

@testable import MoakiKeyboardCore

/// End-to-end checks that drive `GestureAnalyzer` with sampled touch paths, the
/// way a finger reports them, and read the vowel back out of `VowelResolver`.
/// The unit tests either side of this cover angles and patterns in isolation;
/// these cover the two working together.
final class VowelGesturePathTests: XCTestCase {

    private let long = SharedKeyboardPreferences.defaultLongStrokeLength + 25

    // MARK: - Basic vowels

    func testBasicVowels() {
        XCTAssertEqual(vowel([(0, 50)]), .ㅏ)
        XCTAssertEqual(vowel([(180, 50)]), .ㅓ)
        XCTAssertEqual(vowel([(90, 50)]), .ㅗ)
        XCTAssertEqual(vowel([(270, 50)]), .ㅜ)
        XCTAssertEqual(vowel([(0, long)]), .ㅡ)
        XCTAssertEqual(vowel([(90, long)]), .ㅣ)
    }

    /// The misfire this rule set was written for: a vertical drag that leans
    /// either way stays ㅗ/ㅜ while they stay below the long-stroke threshold.
    func testVerticalStrokesToleratePlusAndMinusThirtyDegrees() {
        for length in [CGFloat(30), 60] {
            XCTAssertEqual(vowel([(60, length)]), .ㅗ, "60° at \(length)pt")
            XCTAssertEqual(vowel([(90, length)]), .ㅗ, "90° at \(length)pt")
            XCTAssertEqual(vowel([(120, length)]), .ㅗ, "120° at \(length)pt")
            XCTAssertEqual(vowel([(240, length)]), .ㅜ, "240° at \(length)pt")
            XCTAssertEqual(vowel([(270, length)]), .ㅜ, "270° at \(length)pt")
            XCTAssertEqual(vowel([(300, length)]), .ㅜ, "300° at \(length)pt")
        }
    }

    func testHorizontalStrokesToleratePlusAndMinusThirtyDegrees() {
        for length in [CGFloat(30), 60] {
            XCTAssertEqual(vowel([(330, length)]), .ㅏ, "330° at \(length)pt")
            XCTAssertEqual(vowel([(30, length)]), .ㅏ, "30° at \(length)pt")
            XCTAssertEqual(vowel([(150, length)]), .ㅓ, "150° at \(length)pt")
            XCTAssertEqual(vowel([(210, length)]), .ㅓ, "210° at \(length)pt")
        }
    }

    func testLongStrokesResolveByAxis() {
        XCTAssertEqual(vowel([(45, 40)]), .ㅗ, "a short up-right drag is still ㅗ")
        XCTAssertEqual(vowel([(45, long)]), .ㅣ)
        XCTAssertEqual(vowel([(315, 40)]), .ㅜ, "a short down-right drag is still ㅜ")
        XCTAssertEqual(vowel([(315, long)]), .ㅣ)
    }

    // MARK: - Y vowels

    func testYVowels() {
        XCTAssertEqual(vowel([(90, 50), (270, 50), (90, 50)]), .ㅛ)
        XCTAssertEqual(vowel([(270, 50), (90, 50), (270, 50)]), .ㅠ)
        XCTAssertEqual(vowel([(0, 50), (180, 50), (0, 50)]), .ㅑ)
        XCTAssertEqual(vowel([(180, 50), (0, 50), (180, 50)]), .ㅕ)
    }

    // MARK: - Compound vowels

    func testCompoundVowels() {
        XCTAssertEqual(vowel([(90, 60), (0, 60)]), .ㅘ)
        XCTAssertEqual(vowel([(90, 60), (0, 60), (180, 60)]), .ㅙ)
        XCTAssertEqual(vowel([(270, 60), (180, 60)]), .ㅝ)
        XCTAssertEqual(vowel([(270, 60), (180, 60), (0, 60)]), .ㅞ)
        XCTAssertEqual(vowel([(90, 60), (270, 60)]), .ㅚ)
        XCTAssertEqual(vowel([(270, 60), (90, 60)]), .ㅟ)
    }

    func testAeAndEVowels() {
        XCTAssertEqual(vowel([(0, 60), (180, 60)]), .ㅐ)
        XCTAssertEqual(vowel([(0, 60), (180, 60), (0, 60), (180, 60)]), .ㅒ)
        XCTAssertEqual(vowel([(180, 60), (0, 60)]), .ㅔ)
        XCTAssertEqual(vowel([(180, 60), (0, 60), (180, 60), (0, 60)]), .ㅖ)
    }

    func testEui() {
        XCTAssertEqual(vowel([(0, long), (90, 50)]), .ㅢ)
    }

    // MARK: - Skewed strokes

    /// The return stroke of a Y vowel rarely comes back exactly along the line
    /// it went out on. A skewed return still has to register.
    func testSkewedReturnStrokesStillResolve() {
        XCTAssertEqual(vowel([(0, 60), (215, 30), (0, 60)]), .ㅑ)
        XCTAssertEqual(vowel([(180, 60), (35, 30), (180, 60)]), .ㅕ)
        XCTAssertEqual(vowel([(90, 60), (285, 30), (90, 60)]), .ㅛ)
        XCTAssertEqual(vowel([(270, 60), (105, 30), (270, 60)]), .ㅠ)
    }

    // MARK: - Helpers

    /// Replay a path made of (bearing in degrees, length in points) segments.
    private func vowel(_ segments: [(CGFloat, CGFloat)], step: CGFloat = 4) -> Jungseong? {
        let analyzer = GestureAnalyzer()
        var point = CGPoint(x: 150, y: 250)
        analyzer.addPoint(point)

        for (degrees, length) in segments {
            let radians = degrees * .pi / 180
            let origin = point
            var travelled: CGFloat = 0
            while travelled < length {
                travelled = min(travelled + step, length)
                point = CGPoint(
                    x: origin.x + cos(radians) * travelled,
                    y: origin.y - sin(radians) * travelled
                )
                analyzer.addPoint(point)
            }
        }

        return VowelResolver().resolve(strokes: analyzer.finalizeStrokes()).vowel
    }
}
